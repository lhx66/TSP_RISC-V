ENTRY(_start)

MEMORY
{
  IRAM (rx) : ORIGIN = 0x00000000, LENGTH = 64K
  SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 32K
}

SECTIONS
{
  .text : {
    . = ALIGN(4);
    PROVIDE(_text_start = .);
    *(.init)
    *(.text .text.*)
    
    . = ALIGN(4);
    PROVIDE(_text_end = .);
  } > IRAM

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
  
  PROVIDE(_data_lma = LOADADDR(.data));

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

  PROVIDE(_sp = ORIGIN(SRAM) + LENGTH(SRAM)); 
}