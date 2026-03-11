`include "defines.v"

module Exu_bjp(
    input clk,
    input rst_n,

    // 交互派遣模块
    input [`INST_ADDR_WIDTH-1:0] bjp_pc, 
    input INST_BJP, // 接收 bjp_fire 脉冲

    // 交互Exu_common模块
    input branch_taken, 
    input [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc, 

    // 程序计数器交互
    input [`INST_ADDR_WIDTH-1:0] global_pc_i,  // 实时接收 IFU 当前输出的下一条 PC
    output [`BTB_ENTRY_WIDTH-1:0] BTB_update,  
    output                        BTB_update_valid, 
//    input pre_pc_taken_i, 
    
    // 预测错误重定向
    output [`INST_ADDR_WIDTH-1:0] pc_correct_o, 
    output                        pc_redirect_o 
);

    // ====================================================================
    // 核心修复 1：专属状态锁存器
    // 当分支指令进入时，立刻把它自己的 PC 锁死
    // ====================================================================
    reg [`INST_ADDR_WIDTH-1:0] bjp_pc_r;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_pc_r <= `PC_RSTVAL;
        end else if (INST_BJP) begin
            bjp_pc_r <= bjp_pc; // 锁存当前分支指令的专属 PC
        end
    end

    // 延迟一拍，在 Exu_common 计算结果出来时刚好拉高，仅持续一拍
    REGs_NLWR #(1,0) BTB_update_valid_reg(INST_BJP, BTB_update_valid, clk, rst_n);

    // ====================================================================
    // 核心修复 2：绝对真理的 PC 纠错逻辑
    // 如果跳了，正确目标就是算出来的目标；如果没跳，正确目标就是“专属PC + 4”
    // ====================================================================
    assign pc_correct_o = branch_taken ? bjp_cal_pre_pc : (bjp_pc_r + 4);

    // 冲刷判定逻辑优化 (仅在结果有效的那一拍触发！)：
    // 注意：在 BTB_update_valid 有效时，global_pc_i 恰好是 IFU 刚吐出来的下一条 PC
    // 1. 如果真跳了，但取到的下一条指令不是算出来的目标，冲刷！
    // 2. 如果没跳，但取到的下一条指令不是 PC+4，冲刷！
    assign pc_redirect_o = BTB_update_valid & (
        (branch_taken & (bjp_cal_pre_pc != global_pc_i)) | 
        ((~branch_taken) & (global_pc_i != bjp_pc_r + 4))
    );

    // ====================================================================
    // 核心修复 3：修正 BTB 更新标签
    // 必须使用专属的 bjp_pc_r 作为 tag
    // ====================================================================
    wire [`BTB_TAG_WIDTH-1:0] BTB_tag = bjp_pc_r[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW];
    assign BTB_update = {branch_taken, BTB_tag, bjp_cal_pre_pc[`REGFILE_DAT_WIDTH-1:2]};

endmodule