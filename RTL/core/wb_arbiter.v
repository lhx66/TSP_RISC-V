`include "defines.v"

module TSP_Wb_arbiter (
    input clk,
    input rst_n,

    // 执行模块交互
    output wb_common_ready_o,
    output wb_muldiv_ready_o, // 多周期指令写回许可
    input common_wb_en,
    input [`REGFILE_IDX_WIDTH-1:0] common_rd,
    input [`REGFILE_DAT_WIDTH-1:0] common_rd_op,
    `ifdef USE_RV32M
        input muldiv_wb_en,
        input [`REGFILE_DAT_WIDTH-1:0] muldiv_rd_op,
        input [`REGFILE_IDX_WIDTH-1:0] muldiv_rd,
    `endif
    output oitf_wb_en_o,//OITF清除使能
    output [`REGFILE_IDX_WIDTH-1:0] oitf_wb_rd_o,// OITF要清除的寄存器序号

    // 与访存控制器交互
    input        ls_ctrl_wb_en,   // Load指令完成，请求写回
    input [`REGFILE_IDX_WIDTH-1:0] ls_ctrl_wb_rd, // 写回的寄存器索引
    input [31:0] ls_ctrl_wb_data,  // 符号扩展后的最终写回数据
    output wb_ls_ready_o,

    // 与寄存器组交互
    output wb_arbiter_en_o,
    output [`REGFILE_IDX_WIDTH-1:0] wb_arbiter_rd_o,
    output [31:0] wb_arbiter_dat
);

//OITF交互
assign wb_arbiter_en_o = muldiv_wb_en | ls_ctrl_wb_en | common_wb_en;
assign wb_arbiter_rd_o = (muldiv_wb_en)  ? muldiv_rd : 
                         (ls_ctrl_wb_en) ? ls_ctrl_wb_rd : common_rd;
assign wb_arbiter_dat  = (muldiv_wb_en)  ? muldiv_rd_op : 
                         (ls_ctrl_wb_en) ? ls_ctrl_wb_data : common_rd_op;

// 2. 纯粹的优先级反压逻辑 (优先级: MulDiv > LS > Common)
assign wb_muldiv_ready_o = 1'b1; 
assign wb_ls_ready_o     = ~muldiv_wb_en;
assign wb_common_ready_o = ~(muldiv_wb_en | ls_ctrl_wb_en);

// 3. 专供 OITF 清除的信号 (只有长指令写回才清空 OITF)
assign oitf_wb_en_o = muldiv_wb_en | ls_ctrl_wb_en;
assign oitf_wb_rd_o = (muldiv_wb_en) ? muldiv_rd : ls_ctrl_wb_rd;



endmodule