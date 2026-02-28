`include "defines.v"

module TSP_Ifu(
    input clk,
    input rst_n,

    //取指信息
    input  [`INST_ADDR_WIDTH-1:0] next_pc_i,    //待取指令地址
    input                    ifu_permission, //取指许可

    //取指结果（下一拍有效）
    output [`INST_MAX_WIDTH-1:0] inst_o,
    output                       inst_valid_o,
    output [`INST_ADDR_WIDTH-1:0]     inst_pc_o,  //当前取指令地址
    output                       inst_err_o
);

//ITCM例化
Iram u_Iram(
    .clk            (clk),
    .rst_n          (rst_n),
    .inst_req_i     (ifu_permission),
    .inst_pc_i      (next_pc_i),
    .iram_ack_o     (inst_valid_o),
    .iram_err_o     (inst_err_o),
    .iram_inst_load (inst_o)
);

//锁存当前取指地址
REGs_WLWR #(`INST_ADDR_WIDTH, 0) DECODE_PC_REG(ifu_permission, next_pc_i, inst_pc_o, clk, rst_n);

endmodule
