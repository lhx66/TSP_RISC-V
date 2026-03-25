`include "../core/defines.v"

module TSP_Sram(
    input clk,
    input rst_n,

    // ==========================================
    // AXI4-Lite Slave 接口
    // ==========================================
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

// AXI4-Lite Slave 状态机
reg awready_r, wready_r, bvalid_r;
reg arready_r, rvalid_r;

assign s_axi_awready = awready_r;
assign s_axi_wready  = wready_r;
assign s_axi_bvalid  = bvalid_r;
assign s_axi_bresp   = 2'b00; // OKAY

assign s_axi_arready = arready_r;
assign s_axi_rvalid  = rvalid_r;
assign s_axi_rresp   = 2'b00; // OKAY

wire axi_aw_ready_cond = s_axi_awvalid && s_axi_wvalid && !awready_r && !bvalid_r;
wire axi_ar_ready_cond = s_axi_arvalid && !arready_r && !rvalid_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        awready_r <= 1'b0; wready_r  <= 1'b0; bvalid_r  <= 1'b0;
        arready_r <= 1'b0; rvalid_r  <= 1'b0;
    end else begin
        // 写状态流转
        if (axi_aw_ready_cond) begin
            awready_r <= 1'b1; wready_r  <= 1'b1;
        end else begin
            awready_r <= 1'b0; wready_r  <= 1'b0;
        end

        if (awready_r && wready_r) bvalid_r <= 1'b1; 
        else if (s_axi_bready && bvalid_r) bvalid_r <= 1'b0; 

        // 读状态流转
        if (axi_ar_ready_cond) arready_r <= 1'b1;
        else                   arready_r <= 1'b0;

        if (arready_r) rvalid_r <= 1'b1; 
        else if (s_axi_rready && rvalid_r) rvalid_r <= 1'b0;
    end
end

// ====================================================================
// 读数据锁存逻辑 (适配 1 拍读延迟的 RAM)
// ====================================================================
wire [31:0] ram_rdata_out;
reg  [31:0] rdata_latch;

// 当 arready_r 为 1 的当拍，RAM 刚好输出有效数据，此时将其锁存
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        rdata_latch <= 32'b0;
    end else if (arready_r) begin
        rdata_latch <= ram_rdata_out;
    end
end

// 将锁存器中的数据输出到 AXI 读数据通道
assign s_axi_rdata = rdata_latch;

// ====================================================================
// 例化通用 TSP_RAM 作为数据内存 (32KB)
// ====================================================================
/*
TSP_RAM #(
    .RAM_DEPTH(`SRAM_KB) // 8192 字 = 32KB
) u_Data_Ram (
    .clk(clk), .rst_n(rst_n),
    
    // 仅使用 Port A 作为 AXI 的数据存取口
    .portA_en   (axi_aw_ready_cond | axi_ar_ready_cond),
    .portA_we   (axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),
    .portA_addr ((axi_aw_ready_cond ? s_axi_awaddr : s_axi_araddr) & 32'h0000_FFFF),
    .portA_wdata(s_axi_wdata),
    .portA_rdata(ram_rdata_out), // 接入内部 wire，供 latch 采样
    
    // Port B 悬空彻底禁用
    .portB_en(1'b0), .portB_we(4'b0), .portB_addr(32'b0), .portB_wdata(32'b0)
);*/

RAM u_Data_Ram (
  .wr_data(s_axi_wdata),          // input [31:0]
  .addr((axi_aw_ready_cond ? s_axi_awaddr : s_axi_araddr) & 32'h0000_FFFF),                // input [11:0]
  .wr_en(axi_aw_ready_cond | axi_ar_ready_cond),              // input
  .wr_byte_en(axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),    // input [3:0]
  .clk(clk),                  // input
  .rst(~rst_n),                  // input
  .rd_data(ram_rdata_out)           // output [31:0]
);


endmodule