`include "../core/defines.v"

module TSP_AXI_Interconnect(
    input clk, input rst_n,

    // Master 接口 (接 CPU 的 ls_ctrl)
    input  wire [31:0] s_axi_awaddr, input  wire s_axi_awvalid, output wire s_axi_awready,
    input  wire [31:0] s_axi_wdata,  input  wire [3:0] s_axi_wstrb, input  wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0]  s_axi_bresp,  output wire s_axi_bvalid,  input  wire s_axi_bready,
    input  wire [31:0] s_axi_araddr, input  wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata,  output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input  wire s_axi_rready,

    // Slave 1: SRAM (0x2000_0000)
    output wire [31:0] m1_axi_awaddr, output wire m1_axi_awvalid, input  wire m1_axi_awready,
    output wire [31:0] m1_axi_wdata,  output wire [3:0] m1_axi_wstrb, output wire m1_axi_wvalid, input  wire m1_axi_wready,
    input  wire [1:0]  m1_axi_bresp,  input  wire m1_axi_bvalid,  output wire m1_axi_bready,
    output wire [31:0] m1_axi_araddr, output wire m1_axi_arvalid, input  wire m1_axi_arready,
    input  wire [31:0] m1_axi_rdata,  input  wire [1:0] m1_axi_rresp, input  wire m1_axi_rvalid, output wire m1_axi_rready,

    // Slave 2: UART (0x4000_0000)
    output wire [31:0] m2_axi_awaddr, output wire m2_axi_awvalid, input  wire m2_axi_awready,
    output wire [31:0] m2_axi_wdata,  output wire [3:0] m2_axi_wstrb, output wire m2_axi_wvalid, input  wire m2_axi_wready,
    input  wire [1:0]  m2_axi_bresp,  input  wire m2_axi_bvalid,  output wire m2_axi_bready,
    output wire [31:0] m2_axi_araddr, output wire m2_axi_arvalid, input  wire m2_axi_arready,
    input  wire [31:0] m2_axi_rdata,  input  wire [1:0] m2_axi_rresp, input  wire m2_axi_rvalid, output wire m2_axi_rready,

    // Slave 3: IRAM (0x0000_0000) 供访存指令读写
    output wire [31:0] m3_axi_awaddr, output wire m3_axi_awvalid, input  wire m3_axi_awready,
    output wire [31:0] m3_axi_wdata,  output wire [3:0] m3_axi_wstrb, output wire m3_axi_wvalid, input  wire m3_axi_wready,
    input  wire [1:0]  m3_axi_bresp,  input  wire m3_axi_bvalid,  output wire m3_axi_bready,
    output wire [31:0] m3_axi_araddr, output wire m3_axi_arvalid, input  wire m3_axi_arready,
    input  wire [31:0] m3_axi_rdata,  input  wire [1:0] m3_axi_rresp, input  wire m3_axi_rvalid, output wire m3_axi_rready
);

wire aw_is_m1 = (s_axi_awaddr[31:28] == `SRAM_ADDR);
wire aw_is_m2 = (s_axi_awaddr[31:28] == `UART_ADDR);
wire aw_is_m3 = (s_axi_awaddr[31:28] == 4'h0); 

wire ar_is_m1 = (s_axi_araddr[31:28] == `SRAM_ADDR);
wire ar_is_m2 = (s_axi_araddr[31:28] == `UART_ADDR);
wire ar_is_m3 = (s_axi_araddr[31:28] == 4'h0); 

// 注意我们扩展了 3 bit
wire [2:0] decoded_w_target = aw_is_m1 ? 3'd1 : (aw_is_m2 ? 3'd2 : (aw_is_m3 ? 3'd3 : 3'd4));
wire [2:0] decoded_r_target = ar_is_m1 ? 3'd1 : (ar_is_m2 ? 3'd2 : (ar_is_m3 ? 3'd3 : 3'd4));

reg [2:0] w_target, r_target;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        w_target <= 3'd0; r_target <= 3'd0;
    end else begin
        if (s_axi_awvalid && s_axi_awready) w_target <= decoded_w_target;
        else if (s_axi_bvalid && s_axi_bready) w_target <= 3'd0;

        if (s_axi_arvalid && s_axi_arready) r_target <= decoded_r_target;
        else if (s_axi_rvalid && s_axi_rready) r_target <= 3'd0;
    end
end

wire [2:0] current_w_target = (w_target == 3'd0 && s_axi_awvalid) ? decoded_w_target : w_target;
wire [2:0] current_r_target = (r_target == 3'd0 && s_axi_arvalid) ? decoded_r_target : r_target;

// 数据线广播
assign m1_axi_awaddr = s_axi_awaddr; assign m2_axi_awaddr = s_axi_awaddr; assign m3_axi_awaddr = s_axi_awaddr;
assign m1_axi_wdata  = s_axi_wdata;  assign m2_axi_wdata  = s_axi_wdata;  assign m3_axi_wdata  = s_axi_wdata;
assign m1_axi_wstrb  = s_axi_wstrb;  assign m2_axi_wstrb  = s_axi_wstrb;  assign m3_axi_wstrb  = s_axi_wstrb;
assign m1_axi_araddr = s_axi_araddr; assign m2_axi_araddr = s_axi_araddr; assign m3_axi_araddr = s_axi_araddr;

// 信号路由
assign m1_axi_awvalid = s_axi_awvalid & (current_w_target == 3'd1) & (w_target == 3'd0);
assign m2_axi_awvalid = s_axi_awvalid & (current_w_target == 3'd2) & (w_target == 3'd0);
assign m3_axi_awvalid = s_axi_awvalid & (current_w_target == 3'd3) & (w_target == 3'd0);

assign m1_axi_wvalid  = s_axi_wvalid  & (current_w_target == 3'd1);
assign m2_axi_wvalid  = s_axi_wvalid  & (current_w_target == 3'd2);
assign m3_axi_wvalid  = s_axi_wvalid  & (current_w_target == 3'd3);

assign m1_axi_bready  = s_axi_bready  & (current_w_target == 3'd1);
assign m2_axi_bready  = s_axi_bready  & (current_w_target == 3'd2);
assign m3_axi_bready  = s_axi_bready  & (current_w_target == 3'd3);

assign m1_axi_arvalid = s_axi_arvalid & (current_r_target == 3'd1) & (r_target == 3'd0);
assign m2_axi_arvalid = s_axi_arvalid & (current_r_target == 3'd2) & (r_target == 3'd0);
assign m3_axi_arvalid = s_axi_arvalid & (current_r_target == 3'd3) & (r_target == 3'd0);

assign m1_axi_rready  = s_axi_rready  & (current_r_target == 3'd1);
assign m2_axi_rready  = s_axi_rready  & (current_r_target == 3'd2);
assign m3_axi_rready  = s_axi_rready  & (current_r_target == 3'd3);

// 写汇聚
assign s_axi_awready = (w_target == 3'd0) ? (
                           (decoded_w_target == 3'd1) ? m1_axi_awready : 
                           (decoded_w_target == 3'd2) ? m2_axi_awready : 
                           (decoded_w_target == 3'd3) ? m3_axi_awready : 1'b1
                       ) : 1'b0;

assign s_axi_wready  = (current_w_target == 3'd1) ? m1_axi_wready : 
                       (current_w_target == 3'd2) ? m2_axi_wready : 
                       (current_w_target == 3'd3) ? m3_axi_wready : 1'b1;

assign s_axi_bvalid  = (current_w_target == 3'd1) ? m1_axi_bvalid : 
                       (current_w_target == 3'd2) ? m2_axi_bvalid : 
                       (current_w_target == 3'd3) ? m3_axi_bvalid : 1'b1;

assign s_axi_bresp   = (current_w_target == 3'd1) ? m1_axi_bresp : 
                       (current_w_target == 3'd2) ? m2_axi_bresp : 
                       (current_w_target == 3'd3) ? m3_axi_bresp : 2'b11;

// 读汇聚
assign s_axi_arready = (r_target == 3'd0) ? (
                           (decoded_r_target == 3'd1) ? m1_axi_arready : 
                           (decoded_r_target == 3'd2) ? m2_axi_arready : 
                           (decoded_r_target == 3'd3) ? m3_axi_arready : 1'b1
                       ) : 1'b0;

assign s_axi_rvalid  = (current_r_target == 3'd1) ? m1_axi_rvalid : 
                       (current_r_target == 3'd2) ? m2_axi_rvalid : 
                       (current_r_target == 3'd3) ? m3_axi_rvalid : 1'b1;

assign s_axi_rdata   = (current_r_target == 3'd1) ? m1_axi_rdata : 
                       (current_r_target == 3'd2) ? m2_axi_rdata : 
                       (current_r_target == 3'd3) ? m3_axi_rdata : 32'h0;

assign s_axi_rresp   = (current_r_target == 3'd1) ? m1_axi_rresp : 
                       (current_r_target == 3'd2) ? m2_axi_rresp : 
                       (current_r_target == 3'd3) ? m3_axi_rresp : 2'b11;
endmodule