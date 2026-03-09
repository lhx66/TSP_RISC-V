`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    
    input                         ifu_permission, 
    output                        ifu_ready_o,

    input                         flush_i, // 冲刷信号

    output [`INST_MAX_WIDTH-1:0]  inst_o,
    output                        inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,  
    output                        inst_err_o,

    input idec_ready_i
);

wire iram_ack_o;
wire [`INST_MAX_WIDTH-1:0] iram_rdata; // 接 SRAM 实时吐出的数据


// 只要允许取指且没冲刷，就一直读！冻结时 PC 是不变的，SRAM 反复读同一个地址，为解锁做准备。
wire inst_req_i = ifu_permission;

Iram u_Iram(
    .clk            (clk),
    .rst_n          (rst_n),
    .inst_req_i     (inst_req_i),
    .inst_pc_i      (next_pc_i),
    .iram_ack_o     (iram_ack_o),
    .iram_err_o     (inst_err_o),
    .iram_inst_load (iram_rdata) // 注意：这里接内部线，不直接输出
);

// ====================================================================
// 核心防御机制：IF Skid Buffer (取指滑板缓冲)
// 专门解决 SRAM 1拍延迟导致的 "指令吞噬 (Swallow Bug)"
// ====================================================================
reg [`INST_MAX_WIDTH-1:0] inst_buffer_r;
reg                       use_buffer_r; // 1: 缓冲生效中, 0: 透明透传中

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        use_buffer_r  <= 1'b0;
        inst_buffer_r <= 32'h00000013; // 复位输出 NOP
    end else begin
        if (flush_i) begin
            // 发生跳转冲刷，立刻清空捕鼠夹
            use_buffer_r  <= 1'b0;
        end 
        else if (~idec_ready_i && ~use_buffer_r) begin
            // 【冻结瞬间】：下游突然堵塞，但 SRAM 本周期刚刚吐出了有效指令！
            // 赶紧把它抓到缓冲寄存器里，死死锁住！
            inst_buffer_r <= iram_rdata;
            use_buffer_r  <= 1'b1;
        end 
        else if (idec_ready_i) begin
            // 下游恢复通畅，释放捕鼠夹，切回实时数据
            use_buffer_r  <= 1'b0;
        end
    end
end

// MUX 多路选择：处于堵塞保护期时，喂给译码器的是缓冲里的数据；通畅时是 SRAM 实时数据
assign inst_o = use_buffer_r ? inst_buffer_r : iram_rdata;

// ====================================================================
// PC 与 控制信号透传
// ====================================================================
// 锁存当前取指地址（仅当下游不阻塞时才更新登记，否则保持原样）
wire update_pc_reg = inst_req_i & ifu_ready_o;
REGs_WLWR #(`INST_ADDR_WIDTH, 0) DECODE_PC_REG0(update_pc_reg, next_pc_i, inst_pc_o, clk, rst_n);

// 有效信号保护：如果缓冲里有东西，说明指令绝对有效
assign inst_valid_o = iram_ack_o | use_buffer_r;

// 反压信号直接透传，连接整个流水线
assign ifu_ready_o = idec_ready_i;

endmodule