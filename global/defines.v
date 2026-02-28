`ifndef DEFINES_V
`define DEFINES_V

//常量定义
`define Enable 1
`define Disable 0

//系统定义
`define INST_MAX_WIDTH 32 //指令最高支持位数 ILEN
`define RV32_INST_WIDTH 32 //RV32指令位数
`define INST_ADDR_WIDTH 32 //指令寻址空间位数(拓展到4GB) 要求与XLEN相等
`define IRAM_DEPTH (16*1024/4) //Iram大小(KB)
`define REGFILE_DAT_WIDTH 32 //通用寄存器组位宽（固定32） "XLEN"
`define REGFILE_IDX_WIDTH 5 //RISC-V规定共32个通用寄存器，索引位宽

//编译相关
//`define USE_RAM_IPcore
`define USE_RV32M //乘除法扩展指令集
`define PC_RSTVAL 16'h1000 //PC复位时的启动地址

`define REGs_LPD //寄存器功耗控制low-power dissipation
`ifdef REGs_LPD
//开关控制+复位信号 With Load With Reset
    module REGs_WLWR # (
    parameter RW = 32,
    parameter RST_VAL = 0
    ) (
        input               lden,
        input      [RW-1:0] din,
        output reg[RW-1:0] qout,
        input               clk,
        input               rst_n
    );

    always @(posedge clk or negedge rst_n)  begin
    if (~rst_n)
        qout <= RST_VAL;
    else if (lden == `Enable)
        qout <= #1 din;
    end

    endmodule

//开关控制+无复位信号 With Load No Reset
module REGs_WLNR #(
    parameter RW = 32
) (
    input               lden,
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk
);

always @(posedge clk) begin
    if (lden == `Enable)
        qout <= #1 din;
end

endmodule

//无开关控制+复位信号 No Load With Reset
module REGs_NLWR # (
parameter RW = 32,
parameter RST_VAL = 0
) (
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk,
    input               rst_n
);

always @(posedge clk or negedge rst_n) begin
if (~rst_n)
    qout <= RST_VAL;
else
    qout <= #1 din;
end

endmodule

//无开关控制+无复位信号
module REGs_NLNR # (
parameter RW = 32
) (
    input      [RW-1:0] din,
    output reg [RW-1:0] qout,
    input               clk
);

always @(posedge clk) begin
    qout <= #1 din;
end

endmodule
`endif

`endif