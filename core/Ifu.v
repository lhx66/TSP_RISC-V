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

// 写通道握手条件：只有地址和数据都有效，且不在等待响应时，才准备接收
wire axi_aw_ready_cond = s_axi_awvalid && s_axi_wvalid && !awready_r && !bvalid_r;
// 读通道握手条件
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
            bvalid_r <= 1'b1; // 写完毕，发出响应
        end else if (s_axi_bready && bvalid_r) begin
            bvalid_r <= 1'b0; // 响应被接收，结束
        end

        // --- 读逻辑 ---
        if (axi_ar_ready_cond) begin
            arready_r <= 1'b1;
        end else begin
            arready_r <= 1'b0;
        end

        if (arready_r) begin
            rvalid_r <= 1'b1; // 读地址已被 RAM 接收，下一拍数据必出
        end else if (s_axi_rready && rvalid_r) begin
            rvalid_r <= 1'b0;
        end
    end
end

// ====================================================================
// B. 例化双端口 IRAM (True Dual-Port RAM)
// ====================================================================
wire iram_ack_o;
wire [`INST_MAX_WIDTH-1:0] iram_rdata; // 接 SRAM Port A 实时吐出的数据

wire inst_req_i = ifu_permission;

TSP_RAM #(
    .RAM_DEPTH(16384),   // 64KB IRAM
    .INIT_FILE(`IRAM_BOOT_PATH) // 仿真时默认加载的程序
) u_Iram (
    .clk(clk), .rst_n(rst_n),
    
    // Port A (IFU 取指，纯读)
    .portA_en(inst_req_i),
    .portA_we(4'b0000),         // 禁止写入
    .portA_addr(next_pc_i),
    .portA_wdata(32'b0),
    .portA_rdata(iram_rdata),
    .portA_ack(iram_ack_o),
    .portA_err(inst_err_o),

    // Port B (AXI Slave 下载，读写)
    .portB_en(axi_aw_ready_cond | axi_ar_ready_cond),
    .portB_we(axi_aw_ready_cond ? s_axi_wstrb : 4'b0000),
    .portB_addr(axi_aw_ready_cond ? s_axi_awaddr : s_axi_araddr),
    .portB_wdata(s_axi_wdata),
    .portB_rdata(s_axi_rdata)
);

// ====================================================================
// C. 核心防御机制：IF Skid Buffer (取指滑板缓冲) + 幽灵气泡屏蔽
// ====================================================================
reg [`INST_MAX_WIDTH-1:0] inst_buffer_r;
reg                       use_buffer_r; 

// 【核心修复 1】：增加冲刷残影寄存器 (Flush Shadow)
// 记住上一拍是否发生了冲刷，用于屏蔽 SRAM 因 1 拍延迟吐出的错误指令
reg flush_r;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) flush_r <= 1'b0;
    else        flush_r <= flush_i;
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        use_buffer_r  <= 1'b0;
        inst_buffer_r <= 32'h00000013; // 复位输出 NOP (ADDI x0, x0, 0)
    end else begin
        if (flush_i) begin
            use_buffer_r  <= 1'b0; // 发生冲刷时，当拍立刻清空缓冲
        end 
        // 【核心修复 2】：严格限制入队条件
        // 只有流水线阻塞、缓冲为空、且当拍既没有被冲刷，也不是冲刷残影时，才允许锁存 SRAM 数据
        else if (~idec_ready_i && ~use_buffer_r && iram_ack_o && ~flush_i && ~flush_r) begin
            inst_buffer_r <= iram_rdata;
            use_buffer_r  <= 1'b1;
        end 
        // 流水线恢复流动时，释放缓冲
        else if (idec_ready_i) begin
            use_buffer_r  <= 1'b0;
        end
    end
end

assign inst_o = use_buffer_r ? inst_buffer_r : iram_rdata;

// ====================================================================
// D. PC 与 控制信号透传
// ====================================================================
wire update_pc_reg = inst_req_i & ifu_ready_o;
REGs_WLWR #(`INST_ADDR_WIDTH, 0) DECODE_PC_REG0(update_pc_reg, next_pc_i, inst_pc_o, clk, rst_n);

// 【核心修复 3】：双重掩码把关！
// inst_valid_o 必须同时免疫当拍冲刷 (flush_i) 和上一拍的 SRAM 垃圾数据 (flush_r)
assign inst_valid_o = (iram_ack_o | use_buffer_r) & ~flush_i & ~flush_r;
assign ifu_ready_o  = idec_ready_i;

endmodule