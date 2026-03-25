`include "defines.v"

module Exu_bjp(
    input clk,
    input rst_n,

    // ================= 交互派遣模块 (Dispatcher) =================
    input [`INST_ADDR_WIDTH-1:0] bjp_pc, 
    input INST_BJP, // 指令进入 BJP 执行单元的触发脉冲

    // ================= 交互 Exu_common 模块 =====================
    input branch_taken, // ALU 计算出的真实结果：到底该不该跳？
    input [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc, // ALU 算出的真实目标地址

    // ================= 新增：流水线级间传递下来的预测标志 =================
    // 注意：这个信号到达这里时，必须已经和 bjp_pc 处于同一节拍！
    input pre_pc_taken_i, 
    
    // ================= 程序计数器与 BTB 交互 =====================
    input [`INST_ADDR_WIDTH-1:0] global_pc_i, // 实时 PC（仅用于特殊调试，不再用于冲刷判定）
    output [`BTB_ENTRY_WIDTH-1:0] BTB_update,  
    output                        BTB_update_valid, 
    
    // ================= 预测错误重定向 (Flush) =====================
    output [`INST_ADDR_WIDTH-1:0] pc_correct_o, 
    output                        pc_redirect_o 
);

    // ====================================================================
    // 1. 私人行李锁存区
    // 当指令真正进入执行级时，将它的 PC 和 预测状态 永久锁死，防止被新指令冲刷掉
    // ====================================================================
    reg [`INST_ADDR_WIDTH-1:0] bjp_pc_r;
    reg                        pre_pc_taken_r;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_pc_r       <= `PC_RSTVAL;
            pre_pc_taken_r <= 1'b0;
        end else if (INST_BJP) begin
            bjp_pc_r       <= bjp_pc;         // 锁存指令的专属 PC
            pre_pc_taken_r <= pre_pc_taken_i; // 锁存指令专属的“预测方向”
        end
    end

    // 延迟一拍产生 valid 信号，等待 ALU 计算完成
    REGs_NLWR #(1,0) BTB_update_valid_reg(INST_BJP, BTB_update_valid, clk, rst_n);

    // ====================================================================
    // 2. 绝对真理的目标地址计算
    // ====================================================================
    // 如果实际要跳，就去 ALU 算出的地址；如果实际不跳，就乖乖回 PC + 4
    assign pc_correct_o = branch_taken ? bjp_cal_pre_pc : (bjp_pc_r + 4);

    // ====================================================================
    // 3. 基于“历史预测记录”的完美冲刷判定 (Flush Logic)
    // 这里的判定只在结算的那一拍 (BTB_update_valid) 生效
    // ====================================================================
    
    // 误判情况 A：实际没跳，但当年 BTB 预测跳了 -> 必须冲刷，把 PC 强行拽回 PC+4
    wire flush_not_taken = (~branch_taken) & pre_pc_taken_r;
    
    // 误判情况 B：实际跳了，但当年 BTB 预测没跳 -> 必须冲刷，把 PC 强行拽到目标地址
    wire flush_taken_dir = branch_taken & (~pre_pc_taken_r);
    
    // (注：这里暂不处理 JALR 预测跳了但目标地址算错的极端别名情况，
    // 因为这需要流水线额外传下 pre_target_pc。对于目前的死机问题，方向判定足够了)

    // 综合冲刷条件：只要方向预测错了，就必须发射冲刷信号！
    wire bjp_mispredict = flush_not_taken | flush_taken_dir;

    assign pc_redirect_o = BTB_update_valid & bjp_mispredict;

    // ====================================================================
    // 4. 更新 BTB 表项
    // ====================================================================
    // 取 PC 的中间位作为 BTB 的 Tag
    wire [`BTB_TAG_WIDTH-1:0] BTB_tag = bjp_pc_r[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW];
    
    // 封装更新数据：{是否跳转, Tag标签, 目标地址的有效位}
    assign BTB_update = {branch_taken, BTB_tag, bjp_cal_pre_pc[`REGFILE_DAT_WIDTH-1:2]};

endmodule