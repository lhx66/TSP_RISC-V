.section .init, "ax"
.global _start
.type _start, @function

_start:
    /* Data and read-only data are initialized directly in SRAM by Pango IP. */
    li sp, 0x20008000

    /* Clear only uninitialized SRAM. */
    la a0, _bss_start
    la a1, _bss_end
    bgeu a0, a1, 2f
1:
    sb zero, 0(a0)
    addi a0, a0, 1
    bltu a0, a1, 1b
2:
    call main

3:
    j 3b
