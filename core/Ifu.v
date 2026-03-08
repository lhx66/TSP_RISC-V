`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    
    input                         ifu_permission, 
    output                        ifu_ready_o,

    // 【必须补回】为了消除 SRAM 肚子里的一拍“幽灵指令”，必须知道是否发生了重定向
    input                         flush_i, 

    output [`INST_MAX_WIDTH-1:0]  inst_o,
    output                        inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,  
    output                        inst_err_o,

    input idec_ready_i
);

wire iram_ack_o;

// 【修复1：防幽灵】如果发生 flush_i，立刻把对 SRAM 的请求撤掉，这样下个周期就不会吐出错误的指令。
// 【修复2：防丢失】不要把 ifu_ready_o 放在这里！就算阻塞，也要一直发请求以维持 SRAM 数据！
wire inst_req_i = ifu_permission & (~flush_i);

Iram u_Iram(
    .clk            (clk),
    .rst_n          (rst_n),
    .inst_req_i     (inst_req_i),
    .inst_pc_i      (next_pc_i),
    .iram_ack_o     (iram_ack_o),
    .iram_err_o     (inst_err_o),
    .iram_inst_load (inst_o)
);

// 锁存当前取指地址（仅当下游不阻塞时才更新登记，否则保持原样）
wire update_pc_reg = inst_req_i & ifu_ready_o;
REGs_WLWR #(`INST_ADDR_WIDTH, 0) DECODE_PC_REG0(update_pc_reg, next_pc_i, inst_pc_o, clk, rst_n);

assign inst_valid_o = iram_ack_o;

// 反压信号直接透传
assign ifu_ready_o = idec_ready_i;

endmodule