`include "defines.v"

module Exu_bjp(
    input clk,
    input rst_n,

    input [`INST_ADDR_WIDTH-1:0] bjp_pc, 
    input INST_BJP, 
    input INST_JALR, // <==== 【新增端口】用来识别动态跳转指令

    input branch_taken, 
    input [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc, 

    input pre_pc_taken_i, 
    
    input [`INST_ADDR_WIDTH-1:0] global_pc_i, 
    output [`BTB_ENTRY_WIDTH-1:0] BTB_update,  
    output                        BTB_update_valid, 
    
    output [`INST_ADDR_WIDTH-1:0] pc_correct_o, 
    output                        pc_redirect_o 
);

    reg [`INST_ADDR_WIDTH-1:0] bjp_pc_r;
    reg                        pre_pc_taken_r;
    reg                        is_jalr_r; // <==== 锁存 JALR 标志

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_pc_r       <= `PC_RSTVAL;
            pre_pc_taken_r <= 1'b0;
            is_jalr_r      <= 1'b0;
        end else if (INST_BJP) begin
            bjp_pc_r       <= bjp_pc;
            pre_pc_taken_r <= pre_pc_taken_i;
            is_jalr_r      <= INST_JALR; // 记住它是不是 JALR
        end
    end

    wire BTB_update_valid_raw;
    REGs_NLWR #(1,0) BTB_update_valid_reg(INST_BJP, BTB_update_valid_raw, clk, rst_n);

    assign pc_correct_o = branch_taken ? bjp_cal_pre_pc : (bjp_pc_r + 4);

    wire flush_not_taken = (~branch_taken) & pre_pc_taken_r;
    wire flush_taken_dir = branch_taken & (~pre_pc_taken_r);
    
    // ====================================================================
    // 【核心修复】：JALR 的目标地址是动态的，BTB 极容易预测错目标！
    // 只要 JALR 之前被 BTB 预测为了“跳转”，强制触发冲刷以纠正真实的寄存器目标地址！
    // ====================================================================
    wire flush_jalr_target = is_jalr_r & pre_pc_taken_r;

    wire bjp_mispredict = flush_not_taken | flush_taken_dir | flush_jalr_target;

    assign pc_redirect_o = BTB_update_valid_raw & bjp_mispredict;

    wire [`BTB_TAG_WIDTH-1:0] BTB_tag = bjp_pc_r[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW];
    assign BTB_update = {branch_taken, BTB_tag, bjp_cal_pre_pc[`REGFILE_DAT_WIDTH-1:2]};
    
    // 【核心修复 2】：不要把 JALR 放入 BTB，防止污染其它正常的分支预测表
    assign BTB_update_valid = BTB_update_valid_raw & (~is_jalr_r);

endmodule