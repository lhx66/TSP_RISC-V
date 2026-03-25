`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    // ==========================================
    // 1. CPU 取指流控制
    // ==========================================
    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    
    input                         ifu_permission, 
    output                        ifu_ready_o,

    input                         flush_i, // 冲刷信号

    output [`INST_MAX_WIDTH-1:0]  inst_o,
    output                        inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,  
    output                        inst_err_o,

    input idec_ready_i,

    // 为预测状态专门加一个 1 bit 的跟随寄存器
    input  pre_pc_taken_i,
    output pre_pc_taken_o,

    // ==========================================
    // 2. AXI4-Lite Slave 接口 (用于程序下载与调试)
    // ==========================================
    // --- 写地址通道 (AW) ---
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    // --- 写数据通道 (W) ---
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    // --- 写响应通道 (B) ---
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    // --- 读地址通道 (AR) ---
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    // --- 读数据通道 (R) ---
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

// ====================================================================
// A. 轻量级 AXI4-Lite Slave 状态机 (控制 RAM 的 Port B)
// ====================================================================
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
        awready_r <= 1'b0;
        wready_r  <= 1'b0;
        bvalid_r  <= 1'b0;
        arready_r <= 1'b0;
        rvalid_r  <= 1'b0;
    end else begin
        // --- 写逻辑 ---
        if (axi_aw_ready_cond) begin
            awready_r <= 1'b1;
            wready_r  <= 1'b1;
        end else begin
            awready_r <= 1'b0;
            wready_r  <= 1'b0;
        end

        if (awready_r && wready_r) begin
            bvalid_r <= 1'b1; 
        end else if (s_axi_bready && bvalid_r) begin
            bvalid_r <= 1'b0; 
        end

        // --- 读逻辑 ---
        if (axi_ar_ready_cond) begin
            arready_r <= 1'b1;
        end else begin
            arready_r <= 1'b0;
        end

        if (arready_r) begin
            rvalid_r <= 1'b1; 
        end else if (s_axi_rready && rvalid_r) begin
            rvalid_r <= 1'b0;
        end
    end
end

// ====================================================================
// B. 例化双端口 IRAM (True Dual-Port RAM)
// ====================================================================
wire iram_ack_o;
wire [`INST_MAX_WIDTH-1:0] iram_rdata; 

wire inst_req_i = ifu_permission;

/*
TSP_RAM #(
    .RAM_DEPTH(`IRAM_KB),   
    .INIT_FILE(`IRAM_BOOT_PATH) 
) u_Iram (
    .clk(clk), .rst_n(rst_n),
    
    .portA_en(inst_req_i),
    .portA_we(4'b0000),         
    .portA_addr(next_pc_i),
    .portA_wdata(32'b0),
    .portA_rdata(iram_rdata),
    .portA_ack(iram_ack_o),
    .portA_err(inst_err_o),

    .portB_en(axi_aw_ready_cond | axi_ar_ready_cond),
    .portB_we(axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),
    .portB_addr(axi_aw_ready_cond ? s_axi_awaddr : s_axi_araddr),
    .portB_wdata(s_axi_wdata),
    .portB_rdata(s_axi_rdata)
);*/

Dual_RAM u_Iram (
  .a_addr(next_pc_i[13:2]),                // input [9:0]
  .a_wr_data(32'b0),          // input [31:0]
  .a_rd_data(iram_rdata),          // output [31:0]
  .a_wr_en(1'b0),              // input
  .a_wr_byte_en(4'b0000),    // input [3:0]
  .a_clk(clk),                  // input
  .a_rst(~rst_n),                  // input
  .b_addr(axi_aw_ready_cond ? s_axi_awaddr[13:2] : s_axi_araddr[13:2]),                // input [9:0]
  .b_wr_data(s_axi_wdata),          // input [31:0]
  .b_rd_data(s_axi_rdata),          // output [31:0]
  .b_wr_en(axi_aw_ready_cond | axi_ar_ready_cond),              // input
  .b_wr_byte_en(axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),    // input [3:0]
  .b_clk(clk),                  // input
  .b_rst(~rst_n)                   // input
);

REGs_NLWR #(1,0) iram_ack_reg(inst_req_i,iram_ack_o,clk,rst_n);

// ====================================================================
// C. 【核心修复 1】：取指上下文对齐寄存器 (登机牌机制)
// 必须把发给 SRAM 的地址和预测状态延迟一拍，才能和一拍后吐出来的指令完美对齐！
// ====================================================================
reg [`INST_ADDR_WIDTH-1:0] fetch_pc_delay_r;
reg                        fetch_taken_delay_r;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        fetch_pc_delay_r    <= `PC_RSTVAL;
        fetch_taken_delay_r <= 1'b0;
    end else if (ifu_permission) begin 
        // 只要向 SRAM 发起了读请求，就把这拍的 PC 和 预测状态锁存下来
        fetch_pc_delay_r    <= next_pc_i;
        fetch_taken_delay_r <= pre_pc_taken_i;
    end
end

// ====================================================================
// D. IF Skid Buffer (取指滑板缓冲) + 幽灵气泡屏蔽
// ====================================================================
reg [`INST_MAX_WIDTH-1:0]  inst_buffer_r;
reg                        use_buffer_r; 
reg                        flush_r;
reg                        pre_pc_taken_r;
reg [`INST_ADDR_WIDTH-1:0] pc_buffer_r;

wire [`INST_MAX_WIDTH-1:0] safe_iram_rdata = (iram_rdata == 32'h00000000) ? 32'h0000006f : iram_rdata;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) flush_r <= 1'b0;
    else        flush_r <= flush_i;
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        use_buffer_r   <= 1'b0;
        inst_buffer_r  <= 32'h00000013; 
        pc_buffer_r    <= `PC_RSTVAL;
        pre_pc_taken_r <= 1'b0;
    end else begin
        if (flush_i) begin
            use_buffer_r  <= 1'b0;
        end 
        else if (~idec_ready_i && ~use_buffer_r && iram_ack_o && ~flush_i && ~flush_r) begin
            use_buffer_r   <= 1'b1;
            inst_buffer_r  <= safe_iram_rdata;
            // 【核心修复 2】：锁存时，必须用延迟对齐后的历史 PC 和预测结果！
            pc_buffer_r    <= fetch_pc_delay_r;
            pre_pc_taken_r <= fetch_taken_delay_r;
        end 
        else if (idec_ready_i) begin
            use_buffer_r  <= 1'b0;
        end
    end
end

// ====================================================================
// E. 最终输出与 PC 透传
// ====================================================================
// 【核心修复 3】：旁路输出时，绝不能用实时的 next_pc_i，必须用对齐后的 fetch_pc_delay_r！
assign inst_o         = use_buffer_r ? inst_buffer_r  : safe_iram_rdata;
assign inst_pc_o      = use_buffer_r ? pc_buffer_r    : fetch_pc_delay_r;
assign pre_pc_taken_o = use_buffer_r ? pre_pc_taken_r : fetch_taken_delay_r;

assign inst_valid_o   = (iram_ack_o | use_buffer_r) & ~flush_i & ~flush_r;
assign ifu_ready_o    = idec_ready_i;

endmodule