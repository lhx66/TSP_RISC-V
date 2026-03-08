`include "defines.v"

module TSP_Wb_arbiter (
    input clk,
    input rst_n,

    // 执行模块交互
    output wb_common_ready_o,
    output wb_ls_ready_o,
    output wb_muldiv_ready_o, //多周期指令写回许可
    input common_wb_en,
    `ifdef USE_RV32M
        input muldiv_wb_en,
    `endif
    input [`REGFILE_IDX_WIDTH-1:0] common_rd,
    input [`REGFILE_IDX_WIDTH-1:0] muldiv_rd,
    output [`REGFILE_IDX_WIDTH-1:0] oitf_wb_rd,// OITF要清除的寄存器序号

    // 与访存控制器交互
    input        ls_ctrl_wb_en,   // Load指令完成，请求写回
    input [`REGFILE_IDX_WIDTH-1:0] ls_ctrl_wb_rd, // 写回的寄存器索引
    input [31:0] ls_ctrl_wb_data  // 【补全】符号扩展后的最终写回数据
);

reg [1:0] wb_pointer; //指示正在写回的操作 0:复位 1:单周期信号 2:load写回 3:乘除法写回
always @(*) begin
    if(~rst_n)
        wb_pointer = 2'd0;
    else if(muldiv_wb_en) //乘除法优先级最高
        wb_pointer = 2'd3;
    else if(ls_ctrl_wb_en_o)
end

endmodule