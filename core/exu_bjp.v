`include "defines.v"

module Exu_bjp( //级联在Exu_common后
    input clk,
    input rst_n,

    //交互派遣模块
    input [`INST_ADDR_WIDTH-1:0] bjp_pc, //bjp指令对应的PC值，用于选取tag  inst_pc_o
    input INST_BJP, //bxx + jal + jalr RV32I_Btype|INST_JAL|INST_JALR

    //交互Exu_common模块
    input branch_taken, //是否跳转
    input [`REGFILE_DAT_WIDTH-1:0] bjp_cal_pre_pc, //B系列指令计算出的跳转地址

    //程序计数器交互
    input [`INST_ADDR_WIDTH-1:0] global_pc_i,  //PC
    output [`BTB_ENTRY_WIDTH-1:0] BTB_update,       // 格式见 defines.v BTB字段布局
    output                    BTB_update_valid,  // 执行阶段写回BTB
    input pre_pc_taken_i, // 连接pre_pc_taken_rr
    //预测错误重定向
    output [`INST_ADDR_WIDTH-1:0] pc_correct_o,  // 正确的下一条 PC
    output                        pc_redirect_o   // 预测错误，强制重定向
);

// 由于执行在译码下一级（分支预测），所以要打一拍PC寄存器，该值即是上次预测的PC
wire [`INST_ADDR_WIDTH-1:0] pre_pc_r;
REGs_NLWR #(`INST_ADDR_WIDTH,0) pre_pc_reg(global_pc_i,pre_pc_r,clk,rst_n);

assign pc_correct_o = ((~pre_pc_taken_i)&branch_taken)?bjp_cal_pre_pc:
                        (bjp_pc+4); //如果预测了需要跳转，但不用跳，正确地址是地址+4  ；预测不跳但是跳，正确地址是bjp计算出的结果
assign pc_redirect_o = (branch_taken & (bjp_cal_pre_pc!=pre_pc_r)) | //Btype指令需要跳，而且目的地址与真实地址不符，则预测错误；
                       ((~branch_taken) & (pre_pc_taken_i) & (global_pc_i!=bjp_pc+4));                                           //Btype指令不用跳转，但是之前分支预测选择了跳转，而且没有跳转到+4的位置，则预测错误

wire [`BTB_TAG_WIDTH-1:0] BTB_tag = bjp_pc[`BTB_TAG_PC_HIGH:`BTB_TAG_PC_LOW];
assign BTB_update = {branch_taken,BTB_tag,bjp_cal_pre_pc[`REGFILE_DAT_WIDTH-1:2]};
// 条目字段布局（高位→低位）：
//   [BTB_ENTRY_WIDTH-1]                    : 预测位 taken(1)/not-taken(0)
//   [BTB_ENTRY_WIDTH-2 : BTB_TARGET_WIDTH] : tag = PC[BTB_TAG_PC_HIGH:BTB_TAG_PC_LOW]
//   [BTB_TARGET_WIDTH-1 : 0]               : 目标字地址（字节地址需左移2位拼接）
REGs_NLWR #(1,0) BTB_update_valid_reg(INST_BJP,BTB_update_valid,clk,rst_n);

endmodule