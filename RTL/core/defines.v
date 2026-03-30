`ifndef DEFINES_V
`define DEFINES_V

//常量定义
`define Enable 1
`define Disable 0

//系统定义
`define INST_MAX_WIDTH 32 //指令最高支持位数 ILEN
`define RV32_INST_WIDTH 32 //RV32指令位数
`define INST_ADDR_WIDTH 32 //指令寻址空间位数(拓展到4GB) 要求与XLEN相等
`define REGFILE_DAT_WIDTH 32 //通用寄存器组位宽（固定32） "XLEN"
`define REGFILE_IDX_WIDTH 5 //RISC-V规定共32个通用寄存器，索引位宽

`define IRAM_ADDR 4'h0 // 0x0000_0000 寻址空间定义
`define SRAM_ADDR 4'h2 // 0x2000_0000
`define UART_ADDR 4'h4 // 0x4000_0000
`define TIMER_ADDR 4'h6 // 0x6000_0000

`define IRAM_KB (64*1024/4)
`define SRAM_KB (32*1024/4)

//BPU/BTB 相关（全相联，2-entry LRU）
`define BTB_ENTRIES      2   //BTB条目数
`define BTB_TAG_PC_HIGH  31  //tag取PC的高位边界
`define BTB_TAG_PC_LOW   2   //tag取PC的低位边界（[1:0]为字节偏移）
// 派生宽度（文本替换展开为合法表达式，无需额外逻辑）
`define BTB_TAG_WIDTH    (`BTB_TAG_PC_HIGH - `BTB_TAG_PC_LOW + 1) //tag位宽=17
`define BTB_TARGET_WIDTH (`INST_ADDR_WIDTH - 2)                   //目标字地址位宽=30
`define BTB_ENTRY_WIDTH  (1 + `BTB_TAG_WIDTH + `BTB_TARGET_WIDTH) //条目总位宽=48
// 条目字段布局（高位→低位）：
//   [BTB_ENTRY_WIDTH-1]                    : 预测位 taken(1)/not-taken(0)
//   [BTB_ENTRY_WIDTH-2 : BTB_TARGET_WIDTH] : tag = PC[BTB_TAG_PC_HIGH:BTB_TAG_PC_LOW]
//   [BTB_TARGET_WIDTH-1 : 0]               : 目标字地址（字节地址需左移2位拼接）

//编译相关
//`define USE_RAM_IPcore
`define USE_RV32M //乘除法扩展指令集
`define PC_RSTVAL 16'h0000 //PC复位时的启动地址
//`define PROG_FPGA //FPGA编译下载
`define IRAM_BOOT_PATH "../sim/boot.dat"
`define SRAM_BOOT_PATH ""

//外设相关
//-----------------------------------------------------------------
//                          Timer
//-----------------------------------------------------------------

`define TIMER_CTRL0    8'h8

    `define TIMER_CTRL0_INTERRUPT      1
    `define TIMER_CTRL0_INTERRUPT_DEFAULT    0
    `define TIMER_CTRL0_INTERRUPT_B          1
    `define TIMER_CTRL0_INTERRUPT_T          1
    `define TIMER_CTRL0_INTERRUPT_W          1
    `define TIMER_CTRL0_INTERRUPT_R          1:1

    `define TIMER_CTRL0_ENABLE      2
    `define TIMER_CTRL0_ENABLE_DEFAULT    0
    `define TIMER_CTRL0_ENABLE_B          2
    `define TIMER_CTRL0_ENABLE_T          2
    `define TIMER_CTRL0_ENABLE_W          1
    `define TIMER_CTRL0_ENABLE_R          2:2

`define TIMER_CMP0    8'hc

    `define TIMER_CMP0_VALUE_DEFAULT    0
    `define TIMER_CMP0_VALUE_B          0
    `define TIMER_CMP0_VALUE_T          31
    `define TIMER_CMP0_VALUE_W          32
    `define TIMER_CMP0_VALUE_R          31:0

`define TIMER_VAL0    8'h10

    `define TIMER_VAL0_CURRENT_DEFAULT    0
    `define TIMER_VAL0_CURRENT_B          0
    `define TIMER_VAL0_CURRENT_T          31
    `define TIMER_VAL0_CURRENT_W          32
    `define TIMER_VAL0_CURRENT_R          31:0

`define TIMER_CTRL1    8'h14

    `define TIMER_CTRL1_INTERRUPT      1
    `define TIMER_CTRL1_INTERRUPT_DEFAULT    0
    `define TIMER_CTRL1_INTERRUPT_B          1
    `define TIMER_CTRL1_INTERRUPT_T          1
    `define TIMER_CTRL1_INTERRUPT_W          1
    `define TIMER_CTRL1_INTERRUPT_R          1:1

    `define TIMER_CTRL1_ENABLE      2
    `define TIMER_CTRL1_ENABLE_DEFAULT    0
    `define TIMER_CTRL1_ENABLE_B          2
    `define TIMER_CTRL1_ENABLE_T          2
    `define TIMER_CTRL1_ENABLE_W          1
    `define TIMER_CTRL1_ENABLE_R          2:2

`define TIMER_CMP1    8'h18

    `define TIMER_CMP1_VALUE_DEFAULT    0
    `define TIMER_CMP1_VALUE_B          0
    `define TIMER_CMP1_VALUE_T          31
    `define TIMER_CMP1_VALUE_W          32
    `define TIMER_CMP1_VALUE_R          31:0

`define TIMER_VAL1    8'h1c

    `define TIMER_VAL1_CURRENT_DEFAULT    0
    `define TIMER_VAL1_CURRENT_B          0
    `define TIMER_VAL1_CURRENT_T          31
    `define TIMER_VAL1_CURRENT_W          32
    `define TIMER_VAL1_CURRENT_R          31:0


`endif