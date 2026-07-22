ENTRY(_start)

MEMORY
{
  IRAM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 32K
}

SECTIONS
{
  /* 1. 指令段：存放在 IRAM */
  .text : {
    . = ALIGN(4);
    PROVIDE(_text_start = .);
    *(.init)
    *(.text .text.*)
    . = ALIGN(4);
    PROVIDE(_text_end = .);
  } > IRAM

  /* 2. 只读数据段：因为现在 IRAM 可被 LSU 读取，
        所以直接将只读常量留在 IRAM 即可，节约 SRAM 空间！ */
  /* 3. 初始化数据段 (比如 int a = 1)
        存放(LMA)在 IRAM 掉电不丢失，运行(VMA)在 SRAM 允许读写 */
  .data : {
    . = ALIGN(4);
    PROVIDE(_data_start = .);
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
    *(.sdata .sdata.*)
    *(.data .data.*)
    . = ALIGN(4);
    PROVIDE(_data_end = .);
  } > SRAM AT > IRAM
  
  /* 记录 .data 段在 IRAM 中的确切起始地址，供汇编启动代码搬运使用 */
  PROVIDE(_data_lma = LOADADDR(.data));

  /* 4. 未初始化数据段 (比如 int b;)：仅分配 SRAM 空间 */
  .bss : {
    . = ALIGN(4);
    PROVIDE(_bss_start = .);
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    PROVIDE(_bss_end = .);
    PROVIDE(end = .);
    PROVIDE(_end = .);
  } > SRAM

  /* 5. 栈顶指针指向 SRAM 最高地址 */
  PROVIDE(_sp = ORIGIN(SRAM) + LENGTH(SRAM)); 
}
