`include "defines.v"

module TSP_Regfiles(
    input clk,
    input rst_n,

//读寄存器 由于RISC-V指令至多两个操作数，因此只需两个读接口
    output [`REGFILE_DAT_WIDTH-1:0] r_dat1,
    input [`REGFILE_IDX_WIDTH-1:0] r_reg_idx1,
    output [`REGFILE_DAT_WIDTH-1:0] r_dat2,
    input [`REGFILE_IDX_WIDTH-1:0] r_reg_idx2,

//写回操作接口
    input wb_en,
    input [`REGFILE_IDX_WIDTH-1:0] wb_reg_idx,
    input [`REGFILE_DAT_WIDTH-1:0] wb_dat
);

//通用寄存器组建模
wire [`REGFILE_DAT_WIDTH-1:0] RV32I_regs [(1<<`REGFILE_IDX_WIDTH)-1:0];

//写回操作
genvar i;
generate
    for(i=1;i<(1<<`REGFILE_IDX_WIDTH);i=i+1) begin: x1_31
        REGs_WLWR #(`REGFILE_DAT_WIDTH,0) RV32I_reg_i(wb_en&(wb_reg_idx==i),wb_dat,RV32I_regs[i],clk,rst_n);
    end
endgenerate

//读操作接口
assign r_dat1 = (r_reg_idx1==0)?`REGFILE_DAT_WIDTH'h0:RV32I_regs[r_reg_idx1];
assign r_dat2 = (r_reg_idx2==0)?`REGFILE_DAT_WIDTH'h0:RV32I_regs[r_reg_idx2];

endmodule