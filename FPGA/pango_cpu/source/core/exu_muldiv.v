`include "defines.v"

module TSP_Exu_muldiv( //乘法器和除法器内都最多一条指令 还需解决数据冒险/同一周期写回
    input clk,
    input rst_n,
    //译码输入 (Valid-Ready 握手)
    input                           inst_dec_valid_i,
    output                          exu_ready_o,   // 【修改点】输出 ready 反压信号
    
    input  [`REGFILE_DAT_WIDTH-1:0] rs1_op,
    input  [`REGFILE_DAT_WIDTH-1:0] rs2_op,
    input  [`REGFILE_IDX_WIDTH-1:0] rd_i,
    
    //写回输出
    output [`REGFILE_DAT_WIDTH-1:0] rd_op,
    output [`REGFILE_IDX_WIDTH-1:0] rd_o,
    output                          wb_en,
    input                           wb_muldiv_ready_i,

    //指令类型
    input INST_MUL, input INST_MULH, input INST_MULHSU, input INST_MULHU,
    input INST_DIV, input INST_DIVU, input INST_REM, input INST_REMU
);

// --------------------------------------------------------------------
// 1. 指令分类与 Ready 动态反压逻辑
// --------------------------------------------------------------------
wire is_mul = INST_MUL | INST_MULH | INST_MULHSU | INST_MULHU;
wire is_div = INST_DIV | INST_DIVU | INST_REM | INST_REMU;

// 内部状态维护
reg mul_busy_r;
reg div_busy_r;

wire mul_ready = ~mul_busy_r;
wire div_ready = ~div_busy_r;

// 【核心逻辑】当前模块的 ready 信号是动态的：
// 如果上一级想发乘法，就看乘法器是否 ready；想发除法，就看除法器是否 ready。
// 如果既不是乘法也不是除法（虽然这不该分发到这个模块），默认拉高。
assign exu_ready_o = (is_mul ? mul_ready : 1'b1) & 
                     (is_div ? div_ready : 1'b1) &
                     wb_muldiv_ready_i;

// 真正的“握手成功”触发脉冲 (Fire)
wire mul_fire = inst_dec_valid_i & is_mul & mul_ready;
wire div_fire = inst_dec_valid_i & is_div & div_ready;


// --------------------------------------------------------------------
// 2. 乘法器独立状态机与例化
// --------------------------------------------------------------------
reg [`REGFILE_IDX_WIDTH-1:0] mul_rd_r;
reg [1:0]                    mul_op_type_r;
wire mul_wb_en; 

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        mul_busy_r    <= 1'b0;
        mul_rd_r      <= 0;
        mul_op_type_r <= 2'd0;
    end else begin
        if (mul_wb_en) begin
            mul_busy_r <= 1'b0; // 算完释放
        end 
        else if (mul_fire) begin
            mul_busy_r <= 1'b1; // 接客锁死
            mul_rd_r   <= rd_i;
            mul_op_type_r <= (INST_MUL) ? 2'd0 : 2'd1; // 0代表低32位，1代表高32位
        end
    end
end

wire unsigned_rs1op = INST_MULHU;
wire unsigned_rs2op = INST_MULHSU | INST_MULHU;
wire [2*`REGFILE_DAT_WIDTH-1:0] mul_P;

Booth_Multiplier_4xB #(
    .N(`REGFILE_DAT_WIDTH)
) Exu_multiplier(
    .rst_n(rst_n),                   // 低电平有效复位
    .clk(clk),
    .ld(mul_fire),                   // 用握手成功的 fire 信号启动
    .unsigned_m(unsigned_rs1op),
    .unsigned_r(unsigned_rs2op),
    .m(rs1_op),
    .r(rs2_op),
    .valid(mul_wb_en),
    .p(mul_P)
);


// --------------------------------------------------------------------
// 3. 除法器独立状态机与例化
// --------------------------------------------------------------------
reg [`REGFILE_IDX_WIDTH-1:0] div_rd_r;
reg [1:0]                    div_op_type_r;
wire div_wb_en;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        div_busy_r    <= 1'b0;
        div_rd_r      <= 0;
        div_op_type_r <= 2'd0;
    end else begin
        if (div_wb_en) begin
            div_busy_r <= 1'b0;
        end 
        else if (div_fire) begin
            div_busy_r <= 1'b1;
            div_rd_r   <= rd_i;
            div_op_type_r <= (INST_DIV | INST_DIVU) ? 2'd2 : 2'd3; // 2代表商，3代表余数
        end
    end
end

wire unsigned_divop = INST_DIVU | INST_REMU;
wire [`REGFILE_DAT_WIDTH-1:0] quo, rem;

divfunc #(
    .XLEN(`REGFILE_DAT_WIDTH),
    .STAGE_LIST(32'hFFFFFFFF)
) Exu_divider(
    .clk(clk),
    .rst_n(rst_n),                  // 低电平有效复位
    .a(rs1_op),
    .b(rs2_op),
    .vld(div_fire),                 // 用握手成功的 fire 信号启动
    .is_unsigned(unsigned_divop),
    .quo(quo),
    .rem(rem),
    .ack(div_wb_en)
);


// --------------------------------------------------------------------
// 4. 写回输出仲裁 (Mux)
// --------------------------------------------------------------------
assign wb_en = mul_wb_en | div_wb_en;

// 谁出结果，就输出谁的目标寄存器地址
assign rd_o = mul_wb_en ? mul_rd_r : 
              div_wb_en ? div_rd_r : 0;

// 解析乘除法最终数据
wire [`REGFILE_DAT_WIDTH-1:0] mul_res = (mul_op_type_r == 2'd0) ? mul_P[`REGFILE_DAT_WIDTH-1:0] : 
                                                                  mul_P[2*`REGFILE_DAT_WIDTH-1:`REGFILE_DAT_WIDTH];
wire [`REGFILE_DAT_WIDTH-1:0] div_res = (div_op_type_r == 2'd2) ? quo : rem;

// 谁出结果，就输出谁的数据
assign rd_op = mul_wb_en ? mul_res :
               div_wb_en ? div_res : 0;

endmodule



//BOOTH乘法器
module Booth_Multiplier_4xB #(
    parameter N = 16                // Width = N: multiplicand & multiplier
)(
    input   rst_n,                  // 低电平有效复位
    input   clk,                    // Clock

    input   ld,                     // Load Registers and Start Multiplier
    input   unsigned_m,             // 1: M is Unsigned, 0: M is Signed
    input   unsigned_r,             // 1: R is Unsigned, 0: R is Signed

    input   [(N - 1):0] m,          // Multiplicand
    input   [(N - 1):0] r,          // Multiplier
    output     valid,          // Product Valid
    output [((2*N) - 1):0] p   // Product <= M * R
);

////////////////////////////////////////////////////////////////////////////////
//
//  Local Parameters
//

localparam pNumCycles   = ((N + 3) / 4);    // No. cycles product

////////////////////////////////////////////////////////////////////////////////
//
//  Declarations
//

reg     [4:0] Cntr;                     // Operation Counter
reg     [4:0] Booth;                    // Booth Recoding Field
reg     Guard;                          // Shift Bit for Booth Recoding
reg     [(N + 3):0] A;                  // Multiplicand w/ guards
wire    [(N + 3):0] Mx16;               // Multiplicand products w/ guards
wire    [(N + 3):0] Mx8;                // Multiplicand products w/ guards
wire    [(N + 3):0] Mx4;                // Multiplicand products w/ guards
wire    [(N + 3):0] Mx2;                // Multiplicand products w/ guards
wire    [(N + 3):0] Mx1;                // Multiplicand products w/ guards
reg     MnP_B, M_Sel_B, En_B;           // Operand B Control Triple
reg     MnP_C, M_Sel_C, En_C;           // Operand C Control Triple
reg     MnP_D, M_Sel_D, En_D;           // Operand D Control Triple
wire    [(N + 3):0] Hi;                 // Upper Half of Product w/ guards
reg     [(N + 3):0] B, C, D;            // Adder tree Operand Inputs
reg     Ci_B, Ci_C, Ci_D;               // Adder tree Carry Inputs
wire    [(N + 3):0] U, T, S;            // Adder Tree Outputs w/ guards
reg     [((2*N) + 3):0] Prod;           // Double Length Product w/ guards

// 1. 声明内部寄存器
reg reg_Unsigned_M;
reg reg_Unsigned_R;

// 2. 在 ld 阶段锁存符号
always @(posedge clk) begin
    if(~rst_n) begin
        reg_Unsigned_M <= 1'b0;
        reg_Unsigned_R <= 1'b0;
    end else if(ld) begin
        reg_Unsigned_M <= unsigned_m; // 锁存外部输入
        reg_Unsigned_R <= unsigned_r; // 锁存外部输入
    end
end

// 3. 将后续组合逻辑里用到的 unsigned_m/r 全部替换为 reg_Unsigned_M/R
wire both_unsigned = reg_Unsigned_M & reg_Unsigned_R;


////////////////////////////////////////////////////////////////////////////////
//
//  Implementation
//

always @(posedge clk)
begin
    if(~rst_n)
        Cntr <= #1 0;
    else if(ld)
        Cntr <= #1 pNumCycles;
    else if(|Cntr)
        Cntr <= #1 (Cntr - 1);
end

//  Multiplicand Register
//      扩展严格依赖 unsigned_m

always @(posedge clk)
begin
    if(~rst_n)
        A <= #1 0;
    else if(ld)
        A <= #1 ((unsigned_m) ? {4'b0, m} : {{4{m[(N - 1)]}}, m});
end

assign Mx16 = ((unsigned_m) ? {      A, 4'b0} : {             A, 4'b0});
assign Mx8  = ((unsigned_m) ? {1'b0, A, 3'b0} : {{1{A[N-1]}}, A, 3'b0});
assign Mx4  = ((unsigned_m) ? {2'b0, A, 2'b0} : {{2{A[N-1]}}, A, 2'b0});
assign Mx2  = ((unsigned_m) ? {3'b0, A, 1'b0} : {{3{A[N-1]}}, A, 1'b0});
assign Mx1  = ((unsigned_m) ? {4'b0, A      } : {{4{A[N-1]}}, A      });


always @(*) Booth <= {Prod[3:0], Guard};    // Booth's Multiplier Recoding field

assign Hi = Prod[((2*N) + 3):N];            // Upper Half of Product Register


// -----------------------------------------------------------------------------
// For the first column - B (控制逻辑依赖 unsigned_r)
// -----------------------------------------------------------------------------
always @(*)
begin
    case({reg_Unsigned_R, Booth})
        // Signed Operations
        6'b000000 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b000001 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b000010 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b000011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b000100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b000101 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M - 1*M)
        6'b000110 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M - 1*M)
        6'b000111 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b001000 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b001001 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 1*M)
        6'b001010 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 1*M)
        6'b001011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 2*M)
        6'b001100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 2*M)
        6'b001101 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M - 1*M)
        6'b001110 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M - 1*M)
        6'b001111 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 0*M)
        6'b010000 : {MnP_B, M_Sel_B, En_B} <= 3'b101; // (P -  8*M + 0*M - 0*M)
        6'b010001 : {MnP_B, M_Sel_B, En_B} <= 3'b101; // (P -  8*M + 0*M + 1*M)
        6'b010010 : {MnP_B, M_Sel_B, En_B} <= 3'b101; // (P -  8*M + 0*M + 1*M)
        6'b010011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 2*M)
        6'b010100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 2*M)
        6'b010101 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 1*M)
        6'b010110 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 1*M)
        6'b010111 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 0*M)
        6'b011000 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M - 0*M)
        6'b011001 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M + 1*M)
        6'b011010 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 4*M + 1*M)
        6'b011011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 0*M - 2*M)
        6'b011100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 0*M - 2*M)
        6'b011101 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 0*M - 1*M)
        6'b011110 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M - 0*M - 1*M)
        6'b011111 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        // Unsigned Operations
        6'b100000 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100001 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100010 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b100011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b100100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b100101 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b100110 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M - 1*M)
        6'b100111 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M - 1*M)
        6'b101000 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b101001 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b101010 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 1*M)
        6'b101011 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 1*M)
        6'b101100 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 2*M)
        6'b101101 : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 4*M + 2*M)
        6'b101110 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M - 1*M)
        6'b101111 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M - 1*M)
        6'b110000 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 0*M)
        6'b110001 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 0*M)
        6'b110010 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 1*M)
        6'b110011 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 1*M)
        6'b110100 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 2*M)
        6'b110101 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 0*M + 2*M)
        6'b110110 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M - 1*M)
        6'b110111 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M - 1*M)
        6'b111000 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 0*M)
        6'b111001 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 0*M)
        6'b111010 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111011 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111100 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 2*M)
        6'b111101 : {MnP_B, M_Sel_B, En_B} <= 3'b001; // (P +  8*M + 4*M + 2*M)
        6'b111110 : {MnP_B, M_Sel_B, En_B} <= 3'b011; // (P + 16*M + 0*M - 1*M)
        6'b111111 : {MnP_B, M_Sel_B, En_B} <= 3'b011; // (P + 16*M + 0*M - 1*M)
        default   : {MnP_B, M_Sel_B, En_B} <= 3'b000; // (P +  0*M + 0*M + 0*M)
    endcase
end

// -----------------------------------------------------------------------------
// For the second column - C (控制逻辑依赖 unsigned_r)
// -----------------------------------------------------------------------------
always @(*)
begin
    case({reg_Unsigned_R, Booth})
        // Signed Operations
        6'b000000 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b000001 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b000010 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b000011 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b000100 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b000101 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M - 1*M)
        6'b000110 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M - 1*M)
        6'b000111 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 0*M)
        6'b001000 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 0*M)
        6'b001001 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b001010 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b001011 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 2*M)
        6'b001100 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 2*M)
        6'b001101 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M - 1*M)
        6'b001110 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M - 1*M)
        6'b001111 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b010000 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P -  8*M + 0*M + 0*M)
        6'b010001 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P -  8*M + 0*M + 1*M)
        6'b010010 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P -  8*M + 0*M + 1*M)
        6'b010011 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 2*M)
        6'b010100 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 2*M)
        6'b010101 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 1*M)
        6'b010110 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 1*M)
        6'b010111 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 0*M)
        6'b011000 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M - 0*M)
        6'b011001 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M + 1*M)
        6'b011010 : {MnP_C, M_Sel_C, En_C} <= 3'b101; // (P +  0*M - 4*M + 1*M)
        6'b011011 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M - 2*M)
        6'b011100 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M - 2*M)
        6'b011101 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M - 1*M)
        6'b011110 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M - 1*M)
        6'b011111 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        // Unsigned Operations
        6'b100000 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100001 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100010 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b100011 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 1*M)
        6'b100100 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b100101 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 2*M)
        6'b100110 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M - 1*M)
        6'b100111 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M - 1*M)
        6'b101000 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 0*M)
        6'b101001 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 0*M)
        6'b101010 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b101011 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b101100 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 2*M)
        6'b101101 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  0*M + 4*M + 2*M)
        6'b101110 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M - 1*M)
        6'b101111 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M - 1*M)
        6'b110000 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b110001 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b110010 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 1*M)
        6'b110011 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 1*M)
        6'b110100 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 2*M)
        6'b110101 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  8*M + 0*M + 2*M)
        6'b110110 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M - 1*M)
        6'b110111 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M - 1*M)
        6'b111000 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 0*M)
        6'b111001 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 0*M)
        6'b111010 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111011 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111100 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 2*M)
        6'b111101 : {MnP_C, M_Sel_C, En_C} <= 3'b001; // (P +  8*M + 4*M + 2*M)
        6'b111110 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P + 16*M + 0*M - 1*M)
        6'b111111 : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P + 16*M + 0*M - 1*M)
        default   : {MnP_C, M_Sel_C, En_C} <= 3'b000; // (P +  0*M + 0*M + 0*M)
    endcase
end

// -----------------------------------------------------------------------------
// For the third column - D (控制逻辑依赖 unsigned_r)
// -----------------------------------------------------------------------------
always @(*)
begin
    case({reg_Unsigned_R, Booth})
        // Signed Operations
        6'b000000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b000001 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 0*M + 1*M)
        6'b000010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 0*M + 1*M)
        6'b000011 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 0*M + 2*M)
        6'b000100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 0*M + 2*M)
        6'b000101 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 4*M - 1*M)
        6'b000110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 4*M - 1*M)
        6'b000111 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b001000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b001001 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b001010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b001011 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 4*M + 2*M)
        6'b001100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 4*M + 2*M)
        6'b001101 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 0*M - 1*M)
        6'b001110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 0*M - 1*M)
        6'b001111 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b010000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P -  8*M + 0*M + 0*M)
        6'b010001 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P -  8*M + 0*M + 1*M)
        6'b010010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P -  8*M + 0*M + 1*M)
        6'b010011 : {MnP_D, M_Sel_D, En_D} <= 3'b111; // (P +  0*M - 4*M - 2*M)
        6'b010100 : {MnP_D, M_Sel_D, En_D} <= 3'b111; // (P +  0*M - 4*M - 2*M)
        6'b010101 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M - 4*M - 1*M)
        6'b010110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M - 4*M - 1*M)
        6'b010111 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M - 4*M + 0*M)
        6'b011000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M - 4*M + 0*M)
        6'b011001 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M - 4*M + 1*M)
        6'b011010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M - 4*M + 1*M)
        6'b011011 : {MnP_D, M_Sel_D, En_D} <= 3'b111; // (P +  0*M + 0*M - 2*M)
        6'b011100 : {MnP_D, M_Sel_D, En_D} <= 3'b111; // (P +  0*M + 0*M - 2*M)
        6'b011101 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 0*M - 1*M)
        6'b011110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 0*M - 1*M)
        6'b011111 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        // Unsigned Operations
        6'b100000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100001 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 0*M + 0*M)
        6'b100010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 0*M + 1*M)
        6'b100011 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 0*M + 1*M)
        6'b100100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 0*M + 2*M)
        6'b100101 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 0*M + 2*M)
        6'b100110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 4*M - 1*M)
        6'b100111 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  0*M + 4*M - 1*M)
        6'b101000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b101001 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 4*M + 0*M)
        6'b101010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b101011 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  0*M + 4*M + 1*M)
        6'b101100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 4*M + 2*M)
        6'b101101 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  0*M + 4*M + 2*M)
        6'b101110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 0*M - 1*M)
        6'b101111 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 0*M - 1*M)
        6'b110000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b110001 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  8*M + 0*M + 0*M)
        6'b110010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  8*M + 0*M + 1*M)
        6'b110011 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  8*M + 0*M + 1*M)
        6'b110100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  8*M + 0*M + 2*M)
        6'b110101 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  8*M + 0*M + 2*M)
        6'b110110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 4*M - 1*M)
        6'b110111 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P +  8*M + 4*M - 1*M)
        6'b111000 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  8*M + 4*M + 0*M)
        6'b111001 : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  8*M + 4*M + 0*M)
        6'b111010 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111011 : {MnP_D, M_Sel_D, En_D} <= 3'b001; // (P +  8*M + 4*M + 1*M)
        6'b111100 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  8*M + 4*M + 2*M)
        6'b111101 : {MnP_D, M_Sel_D, En_D} <= 3'b011; // (P +  8*M + 4*M + 2*M)
        6'b111110 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P + 16*M + 0*M - 1*M)
        6'b111111 : {MnP_D, M_Sel_D, En_D} <= 3'b101; // (P + 16*M + 0*M - 1*M)
        default   : {MnP_D, M_Sel_D, En_D} <= 3'b000; // (P +  0*M + 0*M + 0*M)
    endcase
end

//  Compute the first operand - B

always @(*)
begin
    case({MnP_B, M_Sel_B, En_B})
        3'b001  : {Ci_B, B} <= {1'b0,  Mx8};
        3'b011  : {Ci_B, B} <= {1'b0,  Mx16};
        3'b101  : {Ci_B, B} <= {1'b1, ~Mx8};
        3'b111  : {Ci_B, B} <= {1'b1, ~Mx16};
        default : {Ci_B, B} <= 0;
    endcase
end

//  Compute the second operand - C

always @(*)
begin
    case({MnP_C, M_Sel_C, En_C})
        3'b001  : {Ci_C, C} <= {1'b0,  Mx4};
        3'b011  : {Ci_C, C} <= {1'b0,  Mx4};
        3'b101  : {Ci_C, C} <= {1'b1, ~Mx4};
        3'b111  : {Ci_C, C} <= {1'b1, ~Mx4};
        default : {Ci_C, C} <= 0;
    endcase
end

//  Compute the second operand - D

always @(*)
begin
    case({MnP_D, M_Sel_D, En_D})
        3'b001  : {Ci_D, D} <= {1'b0,  Mx1};
        3'b011  : {Ci_D, D} <= {1'b0,  Mx2};
        3'b101  : {Ci_D, D} <= {1'b1, ~Mx1};
        3'b111  : {Ci_D, D} <= {1'b1, ~Mx2};
        default : {Ci_D, D} <= 0;
    endcase
end

//  Compute Partial Sum - Cascaded Adders

assign U = Hi + B + Ci_B;
assign T =  U + C + Ci_C;
assign S =  T + D + Ci_D;

//  Double Length Product Register
//      Shift logic relies on `both_unsigned`

always @(posedge clk)
begin
    if(~rst_n)
        Prod <= #1 0;
    else if(ld)
        Prod <= #1 r;
    else if(|Cntr)  // 只要任意一方有符号，移位就进行符号扩展，否则补 0
        Prod <= #1 ((both_unsigned) ? { 4'b0,          S, Prod[(N - 1):4]}
                                    : {{4{S[(N + 3)]}}, S, Prod[(N - 1):4]});
end

always @(posedge clk)
begin
    if(~rst_n)
        Guard <= #1 0;
    else if(ld)
        Guard <= #1 0;
    else if(|Cntr)
        Guard <= #1 Prod[3];
end

//  Assign the product less the four guard bits to the output port
assign p = (Cntr == 1)?{S, Prod[(N - 1):4]}:0;

//  Count the number of shifts
assign valid = (Cntr == 1);

endmodule




`define N(n) [(n)-1:0]
`define FFx(signal,bits) always @(posedge clk or negedge rst_n) if (~rst_n) signal <= bits; else

module divfunc
#(
    parameter XLEN = 32,
    parameter `N(XLEN) STAGE_LIST = 32'h11111111
)
(
    input              clk,
    input              rst_n,        // 低电平有效复位
    input  `N(XLEN)    a,
    input  `N(XLEN)    b,
    input              vld,
    input              is_unsigned,

    output `N(XLEN)    quo,
    output `N(XLEN)    rem,
    output             ack
);

    // ====================================================================
    // 1. 静态提取：全局只存一份的寄存器 (节省了大量打拍面积)
    // ====================================================================
    wire a_is_neg = (~is_unsigned) & a[XLEN-1];
    wire b_is_neg = (~is_unsigned) & b[XLEN-1];
    
    wire [XLEN-1:0] abs_a = a_is_neg ? (~a + 1'b1) : a;
    wire [XLEN-1:0] abs_b = b_is_neg ? (~b + 1'b1) : b;
    wire            is_div_by_0 = (b == 0);
    wire            s_quo = a_is_neg ^ b_is_neg;
    wire            s_rem = a_is_neg;

    // 静态寄存器：只在 vld 有效的那一拍抓取数据
    reg [XLEN-1:0] divisor_r;
    reg [XLEN-1:0] div_orig_r;
    reg            s_quo_r;
    reg            s_rem_r;
    reg            is_div_by_0_r;

    always @(posedge clk) begin
        if (vld) begin
            divisor_r     <= abs_b;
            div_orig_r    <= a;          // 用于除以0时输出原被除数
            s_quo_r       <= s_quo;
            s_rem_r       <= s_rem;
            is_div_by_0_r <= is_div_by_0;
        end
    end

    // 【核心技巧】共享信号路由：
    // vld 当拍（Cycle 0），由于寄存器还未打入，使用组合逻辑的 abs_b；
    // 之后的周期（Cycle 1~7），使用已经存好的 divisor_r。
    wire [XLEN-1:0] shared_divisor  = vld ? abs_b       : divisor_r;
    wire [XLEN-1:0] shared_div_orig = vld ? a           : div_orig_r;
    wire            shared_s_quo    = vld ? s_quo       : s_quo_r;
    wire            shared_s_rem    = vld ? s_rem       : s_rem_r;
    wire            shared_is_div_0 = vld ? is_div_by_0 : is_div_by_0_r;


    // ====================================================================
    // 2. 动态流水线：只保留必须打拍的核心数据 (ready, dividend, quotient)
    // ====================================================================
    reg            ready    [0:XLEN];
    reg [XLEN-1:0] dividend [0:XLEN];
    reg [XLEN-1:0] quotient [0:XLEN];

    always @* begin
        ready[0]    = vld;
        dividend[0] = abs_a;
        quotient[0] = 0;
    end

    generate
        genvar i;
        for (i=0; i<XLEN; i=i+1) begin: gen_div
            
            wire [i:0]      m = dividend[i] >> (XLEN-i-1);
            // 运算全部使用全局共享的 shared_divisor，不再需要 divisor[i]
            wire [i:0]      n = shared_divisor[i:0];
            
            wire            q = (|(shared_divisor >> (i+1))) ? 1'b0 : (m >= n);
            wire [i:0]      t = q ? (m - n) : m;
            wire [XLEN-1:0] u = dividend[i] << (i+1);
            wire [XLEN+i:0] d = {t, u} >> (i+1);

            if (STAGE_LIST[XLEN-i-1]) begin: gen_ff
                `FFx(ready[i+1], 0)
                ready[i+1] <= ready[i];

                `FFx(dividend[i+1], 0)
                dividend[i+1] <= d[XLEN-1:0]; 

                `FFx(quotient[i+1], 0)
                quotient[i+1] <= quotient[i] | (q << (XLEN-i-1));

            end else begin: gen_comb
                always @* begin
                    ready[i+1]    = ready[i];
                    dividend[i+1] = d[XLEN-1:0];
                    quotient[i+1] = quotient[i] | (q << (XLEN-i-1));
                end
            end
        end
    endgenerate


    // ====================================================================
    // 3. 后处理：使用全局共享的符号位恢复结果
    // ====================================================================
    wire [XLEN-1:0] final_quo = shared_s_quo ? (~quotient[XLEN] + 1'b1) : quotient[XLEN];
    wire [XLEN-1:0] final_rem = shared_s_rem ? (~dividend[XLEN] + 1'b1) : dividend[XLEN];

    assign quo = shared_is_div_0 ? {XLEN{1'b1}} : final_quo;
    assign rem = shared_is_div_0 ? shared_div_orig : final_rem;
    
    assign ack = ready[XLEN];

endmodule


/****乘法器除法器解耦版，后续可以对乘除法器进行阻塞，
而现在乘除法器优先级最高不会阻塞，暂不使用
`include "defines.v"

module TSP_Exu_muldiv( 
    input clk,
    input rst_n,
    // 译码输入 (Valid-Ready 握手)
    input                           inst_dec_valid_i,
    output                          exu_ready_o,   
    
    input  [`REGFILE_DAT_WIDTH-1:0] rs1_op,
    input  [`REGFILE_DAT_WIDTH-1:0] rs2_op,
    input  [`REGFILE_IDX_WIDTH-1:0] rd_i,
    
    // 写回输出
    output [`REGFILE_DAT_WIDTH-1:0] rd_op,
    output [`REGFILE_IDX_WIDTH-1:0] rd_o,
    output                          wb_en,
    input                           wb_muldiv_ready_i,

    // 指令类型
    input INST_MUL, input INST_MULH, input INST_MULHSU, input INST_MULHU,
    input INST_DIV, input INST_DIVU, input INST_REM, input INST_REMU
);

wire is_mul = INST_MUL | INST_MULH | INST_MULHSU | INST_MULHU;
wire is_div = INST_DIV | INST_DIVU | INST_REM | INST_REMU;

// ====================================================================
// 1. 完全独立的双通道状态机 (Fully Decoupled State Machines)
// ====================================================================
reg mul_busy_r, div_busy_r;
reg mul_wb_pending_r, div_wb_pending_r;

// 只要自己不忙，且自己的出口没被堵住，就可以接客！互不影响！
wire mul_ready = ~mul_busy_r & ~mul_wb_pending_r;
wire div_ready = ~div_busy_r & ~div_wb_pending_r;

// 动态反压：进来的指令想用谁，就看谁是否 ready
assign exu_ready_o = (is_mul ? mul_ready : 1'b1) & 
                     (is_div ? div_ready : 1'b1);

wire fire = inst_dec_valid_i & exu_ready_o;
wire mul_fire = fire & is_mul;
wire div_fire = fire & is_div;

// ====================================================================
// 2. 例化底层 IP 与信息锁存
// ====================================================================
reg [`REGFILE_IDX_WIDTH-1:0] mul_rd_r, div_rd_r;
reg [1:0]                    mul_op_type_r, div_op_type_r;

wire ip_mul_valid;
wire ip_div_ack;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        mul_busy_r    <= 1'b0;
        div_busy_r    <= 1'b0;
        mul_rd_r      <= 0;
        div_rd_r      <= 0;
        mul_op_type_r <= 2'd0;
        div_op_type_r <= 2'd0;
    end else begin
        if (ip_mul_valid) mul_busy_r <= 1'b0;
        if (ip_div_ack)   div_busy_r <= 1'b0;

        if (mul_fire) begin
            mul_busy_r    <= 1'b1;
            mul_rd_r      <= rd_i;
            mul_op_type_r <= (INST_MUL) ? 2'd0 : 2'd1;
        end
        if (div_fire) begin
            div_busy_r    <= 1'b1;
            div_rd_r      <= rd_i;
            div_op_type_r <= (INST_DIV | INST_DIVU) ? 2'd2 : 2'd3;
        end
    end
end

wire unsigned_rs1op = INST_MULHU;
wire unsigned_rs2op = INST_MULHSU | INST_MULHU;
wire [2*`REGFILE_DAT_WIDTH-1:0] mul_P;

Booth_Multiplier_4xB #(.N(`REGFILE_DAT_WIDTH)) Exu_multiplier(
    .rst_n(rst_n), 
    .clk(clk),
    .ld(mul_fire), 
    .unsigned_m(unsigned_rs1op),
    .unsigned_r(unsigned_rs2op),
    .m(rs1_op),
    .r(rs2_op),
    .valid(ip_mul_valid), 
    .p(mul_P)
);

wire unsigned_divop = INST_DIVU | INST_REMU;
wire [`REGFILE_DAT_WIDTH-1:0] quo, rem;

divfunc #(
    .XLEN(`REGFILE_DAT_WIDTH),
    .STAGE_LIST(32'h11111111) // 你的 8 拍神仙除法器
) Exu_divider(
    .clk(clk),
    .rst_n(rst_n), 
    .a(rs1_op),
    .b(rs2_op),
    .vld(div_fire), 
    .is_unsigned(unsigned_divop),
    .quo(quo),
    .rem(rem),
    .ack(ip_div_ack) 
);

// ====================================================================
// 3. 内部写回仲裁器 (Internal Write-Back Arbiter)
// ====================================================================
wire [`REGFILE_DAT_WIDTH-1:0] mul_res = (mul_op_type_r == 2'd0) ? mul_P[`REGFILE_DAT_WIDTH-1:0] : mul_P[2*`REGFILE_DAT_WIDTH-1:`REGFILE_DAT_WIDTH];
wire [`REGFILE_DAT_WIDTH-1:0] div_res = (div_op_type_r == 2'd2) ? quo : rem;

reg [`REGFILE_DAT_WIDTH-1:0] mul_wb_data_r, div_wb_data_r;

// 各自通道的写回请求与数据透传
wire mul_chan_req = mul_wb_pending_r | ip_mul_valid;
wire div_chan_req = div_wb_pending_r | ip_div_ack;

wire [`REGFILE_DAT_WIDTH-1:0] mul_chan_data = mul_wb_pending_r ? mul_wb_data_r : mul_res;
wire [`REGFILE_DAT_WIDTH-1:0] div_chan_data = div_wb_pending_r ? div_wb_data_r : div_res;

// 🚦 优先级仲裁：乘法优先。只有乘法不发请求时，才轮到除法！
wire mul_wb_fire = mul_chan_req & wb_muldiv_ready_i;
wire div_wb_fire = div_chan_req & ~mul_chan_req & wb_muldiv_ready_i;

assign wb_en = mul_chan_req | div_chan_req;
assign rd_o  = mul_chan_req ? mul_rd_r      : div_rd_r;
assign rd_op = mul_chan_req ? mul_chan_data : div_chan_data;

// 内部捕鼠夹逻辑 (Hold State Registers)
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        mul_wb_pending_r <= 1'b0;
        div_wb_pending_r <= 1'b0;
        mul_wb_data_r    <= 0;
        div_wb_data_r    <= 0;
    end else begin
        // 乘法器捕网：吐出了数据，但由于全局堵塞没发出去，死死锁住！
        if (ip_mul_valid && ~mul_wb_fire) begin
            mul_wb_pending_r <= 1'b1;
            mul_wb_data_r    <= mul_res;
        end else if (mul_wb_pending_r && mul_wb_fire) begin
            mul_wb_pending_r <= 1'b0;
        end

        // 除法器捕网：吐出了数据，但全局堵塞，【或者被乘法器抢了跑道】，死死锁住！
        if (ip_div_ack && ~div_wb_fire) begin
            div_wb_pending_r <= 1'b1;
            div_wb_data_r    <= div_res;
        end else if (div_wb_pending_r && div_wb_fire) begin
            div_wb_pending_r <= 1'b0;
        end
    end
end

endmodule
****/