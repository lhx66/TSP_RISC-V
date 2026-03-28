`include "defines.v"

module TSP_Exu_muldiv( 
    input clk,
    input rst_n,
    input                           inst_dec_valid_i,
    output                          exu_ready_o,   
    
    input  [`REGFILE_DAT_WIDTH-1:0] rs1_op,
    input  [`REGFILE_DAT_WIDTH-1:0] rs2_op,
    input  [`REGFILE_IDX_WIDTH-1:0] rd_i,
    
    output [`REGFILE_DAT_WIDTH-1:0] rd_op,
    output [`REGFILE_IDX_WIDTH-1:0] rd_o,
    output                          wb_en,
    input                           wb_muldiv_ready_i,

    input INST_MUL, input INST_MULH, input INST_MULHSU, input INST_MULHU,
    input INST_DIV, input INST_DIVU, input INST_REM, input INST_REMU
);

    wire is_mul = INST_MUL | INST_MULH | INST_MULHSU | INST_MULHU;
    wire is_div = INST_DIV | INST_DIVU | INST_REM | INST_REMU;

    // ====================================================================
    // 防弹级写回状态机 (彻底解决被仲裁器拒收导致的丢数据问题)
    // ====================================================================
    localparam IDLE     = 2'd0;
    localparam CALC_MUL = 2'd1;
    localparam CALC_DIV = 2'd2;
    localparam WAIT_WB  = 2'd3;

    reg [1:0] state;
    
    wire mul_done; 
    wire div_done; 

    wire mul_fire = inst_dec_valid_i & is_mul & (state == IDLE);
    wire div_fire = inst_dec_valid_i & is_div & (state == IDLE);

    assign exu_ready_o = (state == IDLE); // 只有在IDLE才允许派遣新指令
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (mul_fire) state <= CALC_MUL;
                    else if (div_fire) state <= CALC_DIV;
                end
                CALC_MUL: begin
                    if (mul_done) state <= WAIT_WB;
                end
                CALC_DIV: begin
                    if (div_done) state <= WAIT_WB;
                end
                WAIT_WB: begin
                    // 【终极修复】：死死抱住结果，直到仲裁器点头同意接收！
                    if (wb_muldiv_ready_i) state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // 锁存目标寄存器与操作类型
    reg [`REGFILE_IDX_WIDTH-1:0] rd_r;
    reg [2:0]                    op_type_r;
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rd_r <= 0;
            op_type_r <= 0;
        end else if (state == IDLE && (mul_fire || div_fire)) begin
            rd_r <= rd_i;
            op_type_r <= INST_MUL ? 3'd0 :
                         (INST_MULH | INST_MULHSU | INST_MULHU) ? 3'd1 :
                         (INST_DIV | INST_DIVU) ? 3'd2 : 3'd3;
        end
    end

    // ==========================================
    // 乘除法运算核心
    // ==========================================
    wire unsigned_rs1op = INST_MULHU;
    wire unsigned_rs2op = INST_MULHSU | INST_MULHU;
    wire [63:0] mul_P;

    Simple_Multiplier_32 u_multiplier (
        .clk(clk), .rst_n(rst_n),
        .ld(mul_fire),
        .unsigned_m(unsigned_rs1op), .unsigned_r(unsigned_rs2op),
        .m(rs1_op), .r(rs2_op),
        .valid(mul_done), .p(mul_P)
    );

    wire unsigned_divop = INST_DIVU | INST_REMU;
    wire [31:0] quo, rem;

    Simple_Divider_32 u_divider (
        .clk(clk), .rst_n(rst_n),
        .vld(div_fire),
        .is_unsigned(unsigned_divop),
        .a(rs1_op), .b(rs2_op),
        .quo(quo), .rem(rem), .ack(div_done)
    );

    // ==========================================
    // 结果保持与输出缓存
    // ==========================================
    reg [31:0] res_r;
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) res_r <= 32'd0;
        else if (mul_done) res_r <= (op_type_r == 3'd0) ? mul_P[31:0] : mul_P[63:32];
        else if (div_done) res_r <= (op_type_r == 3'd2) ? quo : rem;
    end

    assign wb_en = (state == WAIT_WB);
    assign rd_o  = rd_r;
    assign rd_op = res_r;

endmodule

// ==========================================
// 极简 32 周期乘法器 (带进位与隔离锁)
// ==========================================
module Simple_Multiplier_32 #(parameter N = 32) (
    input clk, input rst_n, input ld,
    input unsigned_m, input unsigned_r,
    input [N-1:0] m, input [N-1:0] r,
    output valid, output [2*N-1:0] p
);
    reg [5:0] count; 
    reg is_busy, valid_reg;
    reg [2*N-1:0] prod; 
    reg sign_p;
    reg [N-1:0] abs_m_reg; 
    
    wire sign_m = ~unsigned_m & m[N-1];
    wire sign_r = ~unsigned_r & r[N-1];
    wire [N-1:0] abs_m = sign_m ? (~m + 1'b1) : m;
    wire [N-1:0] abs_r = sign_r ? (~r + 1'b1) : r;
    
    wire [N:0] sum = prod[2*N-1:N] + abs_m_reg; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0; is_busy <= 0; valid_reg <= 0; 
            prod <= 0; sign_p <= 0; abs_m_reg <= 0;
        end else begin
            valid_reg <= 0;
            if (ld && !is_busy) begin
                count <= 32; is_busy <= 1; 
                prod <= {{N{1'b0}}, abs_r};
                sign_p <= sign_m ^ sign_r;
                abs_m_reg <= abs_m; 
            end else if (is_busy && count > 0) begin
                if (prod[0]) prod <= {sum, prod[N-1:1]}; 
                else         prod <= {1'b0, prod[2*N-1:1]};
                    
                count <= count - 1;
                if (count == 1) begin is_busy <= 0; valid_reg <= 1; end
            end
        end
    end
    assign p = sign_p ? (~prod + 1'b1) : prod;
    assign valid = valid_reg;
endmodule

// ==========================================
// 极简 32 周期除法器
// ==========================================
module Simple_Divider_32 #(parameter XLEN = 32) (
    input clk, input rst_n, input vld, input is_unsigned,
    input [XLEN-1:0] a, input [XLEN-1:0] b,
    output [XLEN-1:0] quo, output [XLEN-1:0] rem, output ack
);
    reg [5:0] count; reg is_busy, ack_reg;
    reg [XLEN-1:0] P, A, divisor, orig_a;
    reg sign_quo, sign_rem, div_by_0;
    
    wire sign_a = ~is_unsigned & a[XLEN-1];
    wire sign_b = ~is_unsigned & b[XLEN-1];
    wire [XLEN-1:0] abs_a = sign_a ? (~a + 1'b1) : a;
    wire [XLEN-1:0] abs_b = sign_b ? (~b + 1'b1) : b;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0; is_busy <= 0; ack_reg <= 0;
            P <= 0; A <= 0; divisor <= 0; orig_a <= 0;
            sign_quo <= 0; sign_rem <= 0; div_by_0 <= 0;
        end else begin
            ack_reg <= 0;
            if (vld && !is_busy) begin
                count <= 32; is_busy <= 1;
                P <= 0; A <= abs_a; divisor <= abs_b;
                sign_quo <= sign_a ^ sign_b; sign_rem <= sign_a;
                div_by_0 <= (b == 0); orig_a <= a;
            end else if (is_busy && count > 0) begin
                if ({P[XLEN-2:0], A[XLEN-1]} >= divisor) begin
                    P <= {P[XLEN-2:0], A[XLEN-1]} - divisor;
                    A <= {A[XLEN-2:0], 1'b1};
                end else begin
                    P <= {P[XLEN-2:0], A[XLEN-1]};
                    A <= {A[XLEN-2:0], 1'b0};
                end
                count <= count - 1;
                if (count == 1) begin is_busy <= 0; ack_reg <= 1; end
            end
        end
    end
    assign quo = div_by_0 ? {XLEN{1'b1}} : (sign_quo ? (~A + 1'b1) : A);
    assign rem = div_by_0 ? orig_a       : (sign_rem ? (~P + 1'b1) : P);
    assign ack = ack_reg;
endmodule