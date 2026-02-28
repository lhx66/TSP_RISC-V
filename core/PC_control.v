`include "defines.v"

//PC计数器 包含BPU
module PC_control(
    input clk,
    input rst_n,

    output reg [`INST_ADDR_WIDTH-1:0] global_pc_o,
    output                            global_pc_valid_o,

    input RV32I_Btype,
    input INST_JAL,
    input INST_JALR,
    input [`REGFILE_DAT_WIDTH-1:0] jmp_imm_i,
    input [`REGFILE_DAT_WIDTH-1:0] jalr_rs1_dat_i //JALR用到的rs1寄存器值
);

//─────────────────────────────────────────
// 跳转目标 ALU 操作数
// JAL/B-type : op1 = PC,         op2 = imm  → dspc = PC + imm
// JALR       : op1 = rs1_value,  op2 = imm  → dspc = rs1 + imm
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] jmp_op1 = INST_JALR ? jalr_rs1_dat_i //jalr读取rs1考虑RAW相关性
                            : {{(`REGFILE_DAT_WIDTH-`INST_ADDR_WIDTH){1'b0}}, global_pc_o};
wire [`REGFILE_DAT_WIDTH-1:0] jmp_op2 = jmp_imm_i;

//─────────────────────────────────────────
// 静态分支预测：负偏移（向后跳）预测采用，JAL/JALR 无条件采用
//─────────────────────────────────────────
wire pre_pc_taken = (RV32I_Btype & jmp_imm_i[`REGFILE_DAT_WIDTH-1])
                  | INST_JAL
                  | INST_JALR; //BTFNT静态预测

wire [`REGFILE_DAT_WIDTH-1:0] pre_pc_full = jmp_op1 + jmp_op2;
wire [`INST_ADDR_WIDTH-1:0]   pre_pc      = pre_pc_full[`INST_ADDR_WIDTH-1:0];

always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        global_pc_o <= `PC_RSTVAL;
    else if (~pre_pc_taken)
        global_pc_o <= global_pc_o + 4;
    else
        global_pc_o <= pre_pc;
end

// 复位结束后 PC 立即有效（异步复位，rst_n 拉高时 PC 已持有 PC_RSTVAL）
assign global_pc_valid_o = rst_n;

endmodule
