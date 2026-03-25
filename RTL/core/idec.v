`include "defines.v"

//用于寄存器-寄存器操作的 R 类型指令，用
//于短立即数和访存 load 操作的 I 型指令，用于访存 store 操作的 S 型指令，用于条件跳转操
//作的 B 类型指令，用于长立即数的 U 型指令和用于无条件跳转的 J 型指令
module TSP_Idec(
    input clk,
    input rst_n,
    input [`INST_MAX_WIDTH-1:0] inst_i,//指令
    input inst_valid_i,
    input flush_i,
    output idec_ready_o,//译码模块就绪
    input [`INST_ADDR_WIDTH-1:0] next_pc_i,
    output [`INST_ADDR_WIDTH-1:0] inst_pc_o,

    //译码结果 与派遣模块交互
    output [`REGFILE_IDX_WIDTH-1:0] rs1_o,      //源寄存器1索引
    output [`REGFILE_IDX_WIDTH-1:0] rs2_o,      //源寄存器2索引
    output [`REGFILE_IDX_WIDTH-1:0] rd_o,    //目标寄存器索引
    output [`REGFILE_DAT_WIDTH-1:0] imm_o,      //符号扩展后的立即数

    output idec_valid_o,
    input disp_ready_i,
    // R-type
    output INST_ADD, INST_SUB, INST_SLL, INST_SLT, INST_SLTU,
    output INST_XOR, INST_SRL, INST_SRA, INST_OR,  INST_AND,
    // I-type：OP-IMM
    output INST_ADDI, INST_SLTI, INST_SLTIU, INST_XORI,
    output INST_ORI,  INST_ANDI, INST_SLLI,  INST_SRLI, INST_SRAI,
    // I-type：LOAD
    output INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU,
    // I-type：其他
    output INST_JALR, INST_FENCE,
    // I-type：SYSTEM
    output INST_ECALL, INST_EBREAK,
    output INST_CSRRW, INST_CSRRS, INST_CSRRC,
    output INST_CSRRWI,INST_CSRRSI,INST_CSRRCI,
    // S-type
    output INST_SB, INST_SH, INST_SW,
    // B-type
    output INST_BEQ, INST_BNE, INST_BLT,
    output INST_BGE, INST_BLTU,INST_BGEU,
    // U-type
    output INST_LUI, INST_AUIPC,
    // J-type
    output INST_JAL,
`ifdef USE_RV32M
    // M-type
    output INST_MUL,    INST_MULH, INST_MULHSU, INST_MULHU,
    output INST_DIV,    INST_DIVU, INST_REM, INST_REMU,
`endif
    output RV32I_Btype, //供BPU使用
    output RV32M_type
); //instruction decoder

assign inst_pc_o = next_pc_i;
wire [6:0] RV32I_opcode = inst_i[6:0];
wire [4:0] RV32I_rd     = inst_i[11:7];
wire [2:0] RV32I_funct3 = inst_i[14:12];
wire [4:0] RV32I_rs1    = inst_i[19:15];
wire [4:0] RV32I_rs2    = inst_i[24:20];
wire [6:0] RV32I_funct7 = inst_i[31:25];

//─────────────────────────────────────────
// 指令格式类型（6种）
//─────────────────────────────────────────
wire RV32I_Rtype = (RV32I_opcode == 7'b0110011);
wire RV32I_Itype = (RV32I_opcode == 7'b0010011)  // OP-IMM
                 | (RV32I_opcode == 7'b0000011)   // LOAD
                 | (RV32I_opcode == 7'b1100111)   // JALR
                 | (RV32I_opcode == 7'b0001111)   // FENCE
                 | (RV32I_opcode == 7'b1110011);  // SYSTEM

wire RV32I_Stype = (RV32I_opcode == 7'b0100011);

assign RV32I_Btype = (RV32I_opcode == 7'b1100011);
wire RV32I_Utype = (RV32I_opcode == 7'b0110111)  // LUI
                 | (RV32I_opcode == 7'b0010111);  // AUIPC

wire RV32I_Jtype = (RV32I_opcode == 7'b1101111);
//─────────────────────────────────────────
// 具体指令识别
//─────────────────────────────────────────

// R-type：OP（opcode=0110011）
assign INST_ADD  = RV32I_Rtype & (RV32I_funct3==3'b000) & (RV32I_funct7==7'b0000000);
assign INST_SUB  = RV32I_Rtype & (RV32I_funct3==3'b000) & (RV32I_funct7==7'b0100000);
assign INST_SLL  = RV32I_Rtype & (RV32I_funct3==3'b001) & (RV32I_funct7==7'b0000000);
assign INST_SLT  = RV32I_Rtype & (RV32I_funct3==3'b010) & (RV32I_funct7==7'b0000000);
assign INST_SLTU = RV32I_Rtype & (RV32I_funct3==3'b011) & (RV32I_funct7==7'b0000000);
assign INST_XOR  = RV32I_Rtype & (RV32I_funct3==3'b100) & (RV32I_funct7==7'b0000000);
assign INST_SRL  = RV32I_Rtype & (RV32I_funct3==3'b101) & (RV32I_funct7==7'b0000000);
assign INST_SRA  = RV32I_Rtype & (RV32I_funct3==3'b101) & (RV32I_funct7==7'b0100000);
assign INST_OR   = RV32I_Rtype & (RV32I_funct3==3'b110) & (RV32I_funct7==7'b0000000);
assign INST_AND  = RV32I_Rtype & (RV32I_funct3==3'b111) & (RV32I_funct7==7'b0000000);
// I-type：OP-IMM（opcode=0010011）
wire RV32I_OPimm = (RV32I_opcode == 7'b0010011);
assign INST_ADDI  = RV32I_OPimm & (RV32I_funct3==3'b000);
assign INST_SLTI  = RV32I_OPimm & (RV32I_funct3==3'b010);
assign INST_SLTIU = RV32I_OPimm & (RV32I_funct3==3'b011);
assign INST_XORI  = RV32I_OPimm & (RV32I_funct3==3'b100);
assign INST_ORI   = RV32I_OPimm & (RV32I_funct3==3'b110);
assign INST_ANDI  = RV32I_OPimm & (RV32I_funct3==3'b111);
assign INST_SLLI  = RV32I_OPimm & (RV32I_funct3==3'b001) & (RV32I_funct7==7'b0000000);
assign INST_SRLI  = RV32I_OPimm & (RV32I_funct3==3'b101) & (RV32I_funct7==7'b0000000);
assign INST_SRAI  = RV32I_OPimm & (RV32I_funct3==3'b101) & (RV32I_funct7==7'b0100000);

// I-type：LOAD（opcode=0000011）
assign RV32I_LOAD = (RV32I_opcode == 7'b0000011);
assign INST_LB  = RV32I_LOAD & (RV32I_funct3==3'b000);
assign INST_LH  = RV32I_LOAD & (RV32I_funct3==3'b001);
assign INST_LW  = RV32I_LOAD & (RV32I_funct3==3'b010);
assign INST_LBU = RV32I_LOAD & (RV32I_funct3==3'b100);
assign INST_LHU = RV32I_LOAD & (RV32I_funct3==3'b101);
// I-type：JALR（opcode=1100111）
assign INST_JALR = (RV32I_opcode == 7'b1100111) & (RV32I_funct3==3'b000);

// I-type：FENCE（opcode=0001111）
assign INST_FENCE = (RV32I_opcode == 7'b0001111) & (RV32I_funct3==3'b000);
// I-type：SYSTEM（opcode=1110011）
assign RV32I_SYSTEM = (RV32I_opcode == 7'b1110011);
assign INST_ECALL  = RV32I_SYSTEM & (RV32I_funct3==3'b000) & (inst_i[31:20]==12'b000000000000);
assign INST_EBREAK = RV32I_SYSTEM & (RV32I_funct3==3'b000) & (inst_i[31:20]==12'b000000000001);
assign INST_CSRRW  = RV32I_SYSTEM & (RV32I_funct3==3'b001);
assign INST_CSRRS  = RV32I_SYSTEM & (RV32I_funct3==3'b010);
assign INST_CSRRC  = RV32I_SYSTEM & (RV32I_funct3==3'b011);
assign INST_CSRRWI = RV32I_SYSTEM & (RV32I_funct3==3'b101);
assign INST_CSRRSI = RV32I_SYSTEM & (RV32I_funct3==3'b110);
assign INST_CSRRCI = RV32I_SYSTEM & (RV32I_funct3==3'b111);

// S-type：STORE（opcode=0100011）
assign INST_SB = RV32I_Stype & (RV32I_funct3==3'b000);
assign INST_SH = RV32I_Stype & (RV32I_funct3==3'b001);
assign INST_SW = RV32I_Stype & (RV32I_funct3==3'b010);

// B-type：BRANCH（opcode=1100011）
assign INST_BEQ  = RV32I_Btype & (RV32I_funct3==3'b000);
assign INST_BNE  = RV32I_Btype & (RV32I_funct3==3'b001);
assign INST_BLT  = RV32I_Btype & (RV32I_funct3==3'b100);
assign INST_BGE  = RV32I_Btype & (RV32I_funct3==3'b101);
assign INST_BLTU = RV32I_Btype & (RV32I_funct3==3'b110);
assign INST_BGEU = RV32I_Btype & (RV32I_funct3==3'b111);
// U-type
assign INST_LUI   = (RV32I_opcode == 7'b0110111);
assign INST_AUIPC = (RV32I_opcode == 7'b0010111);

// J-type
assign INST_JAL = RV32I_Jtype;
//─────────────────────────────────────────
// RV32M 乘除法扩展（opcode=0110011，funct7=0000001）
//─────────────────────────────────────────
`ifdef USE_RV32M
assign RV32M_type = (RV32I_opcode == 7'b0110011) & (RV32I_funct7 == 7'b0000001);
assign INST_MUL    = RV32M_type & (RV32I_funct3 == 3'b000);
// 有符号×有符号，取低32位
assign INST_MULH   = RV32M_type & (RV32I_funct3 == 3'b001); // 有符号×有符号，取高32位
assign INST_MULHSU = RV32M_type & (RV32I_funct3 == 3'b010);
// 有符号×无符号，取高32位
assign INST_MULHU  = RV32M_type & (RV32I_funct3 == 3'b011);
// 无符号×无符号，取高32位
assign INST_DIV    = RV32M_type & (RV32I_funct3 == 3'b100);
// 有符号除法
assign INST_DIVU   = RV32M_type & (RV32I_funct3 == 3'b101);
// 无符号除法
assign INST_REM    = RV32M_type & (RV32I_funct3 == 3'b110);
// 有符号取余
assign INST_REMU   = RV32M_type & (RV32I_funct3 == 3'b111); // 无符号取余
`endif

//─────────────────────────────────────────
// 立即数重组
//─────────────────────────────────────────
wire [31:0] imm_I = {{20{inst_i[31]}}, inst_i[31:20]};
wire [31:0] imm_S = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
wire [31:0] imm_B = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
wire [31:0] imm_U = {inst_i[31:12], 12'b0};
wire [31:0] imm_J = {{11{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
//─────────────────────────────────────────
// 输出驱动
//─────────────────────────────────────────
assign rs1_o = RV32I_rs1;
assign rs2_o = RV32I_rs2;
assign rd_o  = RV32I_rd;
// 立即数按格式选择（R-type 无立即数，输出0）
assign imm_o = RV32I_Itype ? imm_I :
               RV32I_Stype ? imm_S :
               RV32I_Btype ? imm_B :
               RV32I_Utype ? imm_U :
               RV32I_Jtype ? imm_J :
                             {`REGFILE_DAT_WIDTH{1'b0}};
assign idec_valid_o = inst_valid_i & (~flush_i);
assign idec_ready_o = disp_ready_i;//译码模块全为组合逻辑，直接传递派遣模块

//非法指令处理
wire is_legal_inst =
    // R-type
    INST_ADD | INST_SUB | INST_SLL | INST_SLT | INST_SLTU |
    INST_XOR | INST_SRL | INST_SRA | INST_OR  | INST_AND |
    // I-type OP-IMM
    INST_ADDI | INST_SLTI | INST_SLTIU | INST_XORI |
    INST_ORI | INST_ANDI | INST_SLLI | INST_SRLI | INST_SRAI |
    // I-type LOAD
    INST_LB | INST_LH | INST_LW | INST_LBU | INST_LHU |
    // I-type JALR
    INST_JALR |
    // I-type FENCE
    INST_FENCE |
    // I-type SYSTEM
    INST_ECALL | INST_EBREAK |
    INST_CSRRW | INST_CSRRS | INST_CSRRC |
    INST_CSRRWI | INST_CSRRSI | INST_CSRRCI |
    // S-type
    INST_SB | INST_SH | INST_SW |
    // B-type
    INST_BEQ | INST_BNE | INST_BLT | INST_BGE | INST_BLTU | INST_BGEU |
    // U-type
    INST_LUI | INST_AUIPC |
    // J-type
    INST_JAL
`ifdef USE_RV32M
    // M-type
    | INST_MUL | INST_MULH | INST_MULHSU | INST_MULHU |
    INST_DIV | INST_DIVU | INST_REM | INST_REMU
`endif
    ;
wire illegal_inst_o = inst_valid_i & (~is_legal_inst);

endmodule