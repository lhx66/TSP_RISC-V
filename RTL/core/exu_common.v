`include "defines.v"

module TSP_Exu_common(
    input clk,
    input rst_n,

    input idec_valid_i,                         //译码valid
    output exu_common_ready_o,                      //本模块就绪

    input  [`REGFILE_DAT_WIDTH-1:0] rs1_op,         //源寄存器1操作数
    input  [`REGFILE_DAT_WIDTH-1:0] rs2_op,         //源寄存器2操作数
    input  [`REGFILE_IDX_WIDTH-1:0] rd_i,           //目标寄存器索引
    input  [`REGFILE_DAT_WIDTH-1:0] imm_i,          //符号扩展后的立即数
    input  [`REGFILE_DAT_WIDTH-1:0] bjp_pc,         //跳转指令的PC值

    output reg [`REGFILE_DAT_WIDTH-1:0] rd_op,      //rd写回操作数（已寄存）
    output reg [`REGFILE_IDX_WIDTH-1:0] rd_o,           //目标寄存器索引
    output reg                          common_wb_en,       //rd写回使能（已寄存）
    input                               wb_common_ready_i,
    output reg                          branch_taken, //B-type分支跳转（已寄存）
    output reg [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc, //计算出的跳转目的地址

    output [`REGFILE_DAT_WIDTH-1:0] ls_addr_adder_result, //计算出的访存地址

    //指令类型
    // R-type
    input INST_ADD,
    input INST_SUB,
    input INST_XOR,
    input INST_OR,
    input INST_AND,
    input INST_SLL,
    input INST_SRL,
    input INST_SRA,
    input INST_SLT,
    input INST_SLTU,
    // I-type
    input INST_ADDI,
    input INST_XORI,
    input INST_ORI,
    input INST_ANDI,
    input INST_SLLI,
    input INST_SRLI,
    input INST_SRAI,
    input INST_SLTI,
    input INST_SLTIU,
    // U-type
    input INST_LUI,
    input INST_AUIPC,
    // J-type
    input INST_JAL,
    // I-type jump
    input INST_JALR,
    // B-type
    input RV32I_Btype,
    input INST_BEQ,
    input INST_BNE,
    input INST_BLT,
    input INST_BGE,
    input INST_BLTU,
    input INST_BGEU,
    // I-type：LOAD
    input INST_LB, INST_LH, INST_LW, INST_LBU, INST_LHU,
    // S-type
    input INST_SB, INST_SH, INST_SW
);

//─────────────────────────────────────────
// 加法器（组合）
// ADD/SUB/ADDI/JALR : op1=rs1
// JAL/AUIPC/B-type  : op1=PC
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] adder_op1 =
    (INST_ADD | INST_SUB | INST_ADDI | INST_JALR |
     INST_LB | INST_LH | INST_LW | INST_LBU | INST_LHU |
     INST_SB | INST_SH | INST_SW)  ? rs1_op :
    (INST_JAL | INST_AUIPC | RV32I_Btype)           ? bjp_pc :
                                                      {`REGFILE_DAT_WIDTH{1'b0}};

wire [`REGFILE_DAT_WIDTH-1:0] adder_op2 =
    INST_ADD                                                         ? rs2_op    :
    INST_SUB                                                         ? (~rs2_op) :
    (INST_ADDI | INST_AUIPC | INST_JAL | INST_JALR | RV32I_Btype | INST_LB | 
     INST_LH | INST_LW | INST_LBU | INST_LHU |
     INST_SB | INST_SH | INST_SW)  ? imm_i     :
                                                                       {`REGFILE_DAT_WIDTH{1'b0}};

wire [`REGFILE_DAT_WIDTH-1:0] adder_result = adder_op1 + adder_op2 + INST_SUB;

//─────────────────────────────────────────
// XOR（组合）
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] xor_op2 = INST_XOR  ? rs2_op :
                                        INST_XORI ? imm_i  : {`REGFILE_DAT_WIDTH{1'b0}};
wire [`REGFILE_DAT_WIDTH-1:0] xor_result = rs1_op ^ xor_op2;

//─────────────────────────────────────────
// OR / AND（组合）
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] or_result  = rs1_op | (INST_ORI  ? imm_i : rs2_op);
wire [`REGFILE_DAT_WIDTH-1:0] and_result = rs1_op & (INST_ANDI ? imm_i : rs2_op);

//─────────────────────────────────────────
// 移位（组合，复用单个右移器）
//─────────────────────────────────────────
wire        is_sll = INST_SLL  | INST_SLLI;
wire        is_sra = INST_SRA  | INST_SRAI;
wire [4:0]  shamt  = (INST_SLLI | INST_SRLI | INST_SRAI) ? imm_i[4:0] : rs2_op[4:0];

wire [`REGFILE_DAT_WIDTH-1:0] rs1_rev;
genvar k;
generate
    for (k = 0; k < `REGFILE_DAT_WIDTH; k = k + 1) begin : GEN_REV_IN
        assign rs1_rev[k] = rs1_op[`REGFILE_DAT_WIDTH-1-k];
    end
endgenerate

wire [`REGFILE_DAT_WIDTH-1:0] shift_in  = is_sll ? rs1_rev : rs1_op;
wire [`REGFILE_DAT_WIDTH-1:0] shift_raw = is_sra ? ($signed(rs1_op) >>> shamt)
                                                  : (shift_in >> shamt);

wire [`REGFILE_DAT_WIDTH-1:0] sll_rev;
generate
    for (k = 0; k < `REGFILE_DAT_WIDTH; k = k + 1) begin : GEN_REV_OUT
        assign sll_rev[k] = shift_raw[`REGFILE_DAT_WIDTH-1-k];
    end
endgenerate

wire [`REGFILE_DAT_WIDTH-1:0] shift_result = is_sll ? sll_rev : shift_raw;

//─────────────────────────────────────────
// 比较器（组合）
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] cmp_op2 = (INST_SLTI | INST_SLTIU) ? imm_i : rs2_op;

wire cmp_eq   = (rs1_op == cmp_op2);
wire cmp_lt_s = ($signed(rs1_op) < $signed(cmp_op2));
wire cmp_lt_u = (rs1_op < cmp_op2);

wire [`REGFILE_DAT_WIDTH-1:0] slt_result  = {{(`REGFILE_DAT_WIDTH-1){1'b0}}, cmp_lt_s};
wire [`REGFILE_DAT_WIDTH-1:0] sltu_result = {{(`REGFILE_DAT_WIDTH-1){1'b0}}, cmp_lt_u};

//─────────────────────────────────────────
// JAL/JALR 返回地址（组合）
//─────────────────────────────────────────
wire [`REGFILE_DAT_WIDTH-1:0] pc_plus4 = bjp_pc + 32'd4; //或许有办法复用别的加法器

//─────────────────────────────────────────
// 结果选择与输出寄存（EX→WB 流水寄存器）
//─────────────────────────────────────────
// 【核心修改1：反压与保持逻辑】
// 只要我当前没有“被仲裁器拒收的数据”，就是 Ready
assign exu_common_ready_o = ~(common_wb_en & ~wb_common_ready_i);

wire exu_common_fire = idec_valid_i & exu_common_ready_o;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        rd_op          <= {`REGFILE_DAT_WIDTH{1'b0}};
        common_wb_en   <= 1'b0;
        branch_taken   <= 1'b0;
        rd_o           <= {`REGFILE_IDX_WIDTH{1'b0}};
        bjp_cal_pre_pc <= {`REGFILE_DAT_WIDTH{1'b0}};
    end else begin  
        // 【核心修改2：仲裁器未接收时的状态保持】
        if (common_wb_en && ~wb_common_ready_i) begin
            // 仲裁器没空，死死抱住当前数据不变
            common_wb_en <= 1'b1;
        end 
        else begin
            // 仲裁器收下了，或者当前处于空闲状态：
            // 注意！这里是直接赋值，如果 fire 为 0，common_wb_en 就会被瞬间清零！不再像机枪一样突突突了！
            common_wb_en  <= exu_common_fire & (
                      INST_ADD  | INST_SUB  | INST_XOR  | INST_OR   | INST_AND  |
                      INST_SLL  | INST_SRL  | INST_SRA  | INST_SLT  | INST_SLTU |
                      INST_ADDI | INST_XORI | INST_ORI  | INST_ANDI |
                      INST_SLLI | INST_SRLI | INST_SRAI | INST_SLTI | INST_SLTIU|
                      INST_LUI  | INST_AUIPC |
                      INST_JAL  | INST_JALR);
                      
            branch_taken <= exu_common_fire & (
                            (INST_BEQ  &  cmp_eq)   |
                            (INST_BNE  & ~cmp_eq)   |
                            (INST_BLT  &  cmp_lt_s) |
                            (INST_BGE  & ~cmp_lt_s) |
                            (INST_BLTU &  cmp_lt_u) |
                            (INST_BGEU & ~cmp_lt_u))|
                            INST_JAL | INST_JALR;

            // 数据载荷：只有发生 fire 时才更新数据，否则保持旧值也无所谓（因为上面 wb_en 已经清 0 了）
            if (exu_common_fire) begin
                rd_op <=
                    (INST_ADD  | INST_SUB  | INST_ADDI | INST_AUIPC)  ? adder_result :
                    (INST_XOR  | INST_XORI)                           ? xor_result   :
                    (INST_OR   | INST_ORI)                            ? or_result    :
                    (INST_AND  | INST_ANDI)                           ? and_result   :
                    (INST_SLL  | INST_SRL  | INST_SRA  |
                     INST_SLLI | INST_SRLI | INST_SRAI)               ? shift_result :
                    (INST_SLT  | INST_SLTI)                           ? slt_result   :
                    (INST_SLTU | INST_SLTIU)                          ? sltu_result  :
                    INST_LUI                                          ? imm_i        :
                    (INST_JAL  | INST_JALR)                           ? pc_plus4     :
                                                                        {`REGFILE_DAT_WIDTH{1'b0}};
                rd_o <= rd_i;
                bjp_cal_pre_pc <= (INST_JALR) ? {adder_result[31:1], 1'b0} : adder_result; 
            end
        end
    end
end

// 传递访存地址计算结果，到访存模块中再进行打拍
assign ls_addr_adder_result = adder_result;

endmodule