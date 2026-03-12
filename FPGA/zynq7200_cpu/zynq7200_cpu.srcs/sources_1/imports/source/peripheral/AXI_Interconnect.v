`include "../core/defines.v"

module TSP_AXI_Interconnect(
    input clk,
    input rst_n,

    // ==========================================
    // Master 接口 (接 CPU 的 ls_ctrl)
    // ==========================================
    input  wire [31:0] s_axi_awaddr, input  wire s_axi_awvalid, output wire s_axi_awready,
    input  wire [31:0] s_axi_wdata,  input  wire [3:0] s_axi_wstrb, input  wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0]  s_axi_bresp,  output wire s_axi_bvalid,  input  wire s_axi_bready,
    input  wire [31:0] s_axi_araddr, input  wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata,  output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input  wire s_axi_rready,

    // ==========================================
    // Slave 1: SRAM (接 数据内存, 0x2000_0000 区间)
    // ==========================================
    output wire [31:0] m1_axi_awaddr, output wire m1_axi_awvalid, input  wire m1_axi_awready,
    output wire [31:0] m1_axi_wdata,  output wire [3:0] m1_axi_wstrb, output wire m1_axi_wvalid, input  wire m1_axi_wready,
    input  wire [1:0]  m1_axi_bresp,  input  wire m1_axi_bvalid,  output wire m1_axi_bready,
    output wire [31:0] m1_axi_araddr, output wire m1_axi_arvalid, input  wire m1_axi_arready,
    input  wire [31:0] m1_axi_rdata,  input  wire [1:0] m1_axi_rresp, input  wire m1_axi_rvalid, output wire m1_axi_rready,

    // ==========================================
    // Slave 2: UART (接 串口外设, 0x4000_0000 区间)
    // ==========================================
    output wire [31:0] m2_axi_awaddr, output wire m2_axi_awvalid, input  wire m2_axi_awready,
    output wire [31:0] m2_axi_wdata,  output wire [3:0] m2_axi_wstrb, output wire m2_axi_wvalid, input  wire m2_axi_wready,
    input  wire [1:0]  m2_axi_bresp,  input  wire m2_axi_bvalid,  output wire m2_axi_bready,
    output wire [31:0] m2_axi_araddr, output wire m2_axi_arvalid, input  wire m2_axi_arready,
    input  wire [31:0] m2_axi_rdata,  input  wire [1:0] m2_axi_rresp, input  wire m2_axi_rvalid, output wire m2_axi_rready
);

// -------------------------------------------------------------
// 1. 地址解码器 (Address Decoder)
// -------------------------------------------------------------
wire aw_is_m1 = (s_axi_awaddr[31:28] == `SRAM_ADDR); // 0x2xxx_xxxx
wire aw_is_m2 = (s_axi_awaddr[31:28] == `UART_ADDR); // 0x4xxx_xxxx

wire ar_is_m1 = (s_axi_araddr[31:28] == `SRAM_ADDR);
wire ar_is_m2 = (s_axi_araddr[31:28] == `UART_ADDR);

// 目标定义: 0=IDLE(空闲), 1=SRAM, 2=UART, 3=DECERR(未映射地址)
wire [1:0] decoded_w_target = aw_is_m1 ? 2'd1 : (aw_is_m2 ? 2'd2 : 2'd3);
wire [1:0] decoded_r_target = ar_is_m1 ? 2'd1 : (ar_is_m2 ? 2'd2 : 2'd3);

// -------------------------------------------------------------
// 2. 状态锁存器 (严格按序机制)
// -------------------------------------------------------------
reg [1:0] w_target, r_target;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        w_target <= 2'd0; // 复位时处于 IDLE
        r_target <= 2'd0; 
    end else begin
        // 写通道：记录当前目标，直到 B 通道回复结束
        if (s_axi_awvalid && s_axi_awready) begin
            w_target <= decoded_w_target;
        end else if (s_axi_bvalid && s_axi_bready) begin
            w_target <= 2'd0; // 回复 IDLE
        end

        // 读通道：记录当前目标，直到 R 通道回复结束
        if (s_axi_arvalid && s_axi_arready) begin
            r_target <= decoded_r_target;
        end else if (s_axi_rvalid && s_axi_rready) begin
            r_target <= 2'd0; // 回复 IDLE
        end
    end
end

// 当处于 IDLE 时，目标由输入地址当拍决定；否则保持锁定
wire [1:0] current_w_target = (w_target == 2'd0 && s_axi_awvalid) ? decoded_w_target : w_target;
wire [1:0] current_r_target = (r_target == 2'd0 && s_axi_arvalid) ? decoded_r_target : r_target;

// -------------------------------------------------------------
// 3. 信号路由：Master 广播到 Slaves
// -------------------------------------------------------------
// 地址和数据线直接广播
assign m1_axi_awaddr = s_axi_awaddr; assign m2_axi_awaddr = s_axi_awaddr;
assign m1_axi_wdata  = s_axi_wdata;  assign m2_axi_wdata  = s_axi_wdata;
assign m1_axi_wstrb  = s_axi_wstrb;  assign m2_axi_wstrb  = s_axi_wstrb;
assign m1_axi_araddr = s_axi_araddr; assign m2_axi_araddr = s_axi_araddr;

// Valid 分发：只给目标从机发送 Valid
assign m1_axi_awvalid = s_axi_awvalid & (current_w_target == 2'd1) & (w_target == 2'd0);
assign m2_axi_awvalid = s_axi_awvalid & (current_w_target == 2'd2) & (w_target == 2'd0);

assign m1_axi_wvalid  = s_axi_wvalid  & (current_w_target == 2'd1);
assign m2_axi_wvalid  = s_axi_wvalid  & (current_w_target == 2'd2);

assign m1_axi_bready  = s_axi_bready  & (current_w_target == 2'd1);
assign m2_axi_bready  = s_axi_bready  & (current_w_target == 2'd2);

assign m1_axi_arvalid = s_axi_arvalid & (current_r_target == 2'd1) & (r_target == 2'd0);
assign m2_axi_arvalid = s_axi_arvalid & (current_r_target == 2'd2) & (r_target == 2'd0);

assign m1_axi_rready  = s_axi_rready  & (current_r_target == 2'd1);
assign m2_axi_rready  = s_axi_rready  & (current_r_target == 2'd2);

// -------------------------------------------------------------
// 4. 信号路由：Slaves 聚合回 Master (多路选择 + 异常处理)
// -------------------------------------------------------------

// --- Write Channels ---
// 仅在 IDLE 时接收新的 AW 请求。如果访问非法地址 (Target 3)，当拍回 Ready
assign s_axi_awready = (w_target == 2'd0) ? (
                           (decoded_w_target == 2'd1) ? m1_axi_awready : 
                           (decoded_w_target == 2'd2) ? m2_axi_awready : 1'b1
                       ) : 1'b0;

assign s_axi_wready  = (current_w_target == 2'd1) ? m1_axi_wready : 
                       (current_w_target == 2'd2) ? m2_axi_wready : 
                       (current_w_target == 2'd3) ? 1'b1 : 1'b0;

assign s_axi_bvalid  = (current_w_target == 2'd1) ? m1_axi_bvalid : 
                       (current_w_target == 2'd2) ? m2_axi_bvalid : 
                       (current_w_target == 2'd3) ? 1'b1 : 1'b0;

assign s_axi_bresp   = (current_w_target == 2'd1) ? m1_axi_bresp : 
                       (current_w_target == 2'd2) ? m2_axi_bresp : 
                       (current_w_target == 2'd3) ? 2'b11 : 2'b00; // 2'b11 = DECERR

// --- Read Channels ---
// 仅在 IDLE 时接收新的 AR 请求。
assign s_axi_arready = (r_target == 2'd0) ? (
                           (decoded_r_target == 2'd1) ? m1_axi_arready : 
                           (decoded_r_target == 2'd2) ? m2_axi_arready : 1'b1
                       ) : 1'b0;

assign s_axi_rvalid  = (current_r_target == 2'd1) ? m1_axi_rvalid : 
                       (current_r_target == 2'd2) ? m2_axi_rvalid : 
                       (current_r_target == 2'd3) ? 1'b1 : 1'b0;

assign s_axi_rdata   = (current_r_target == 2'd1) ? m1_axi_rdata : 
                       (current_r_target == 2'd2) ? m2_axi_rdata : 32'h00000000;

assign s_axi_rresp   = (current_r_target == 2'd1) ? m1_axi_rresp : 
                       (current_r_target == 2'd2) ? m2_axi_rresp : 
                       (current_r_target == 2'd3) ? 2'b11 : 2'b00; // 2'b11 = DECERR

endmodule