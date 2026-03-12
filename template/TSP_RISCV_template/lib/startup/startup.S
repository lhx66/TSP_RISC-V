.section .init, "ax"
.global _start
.type _start, @function

_start:
    /* 1. 初始化栈指针 (C语言局部变量全靠它) */
    la sp, _sp

    /* 2. 搬运 .data 段 (将有初值的全局变量从 IRAM 复制到 SRAM) */
    la a0, _data_lma     /* 源地址 (IRAM) */
    la a1, _data_start   /* 目的地址 (SRAM) */
    la a2, _data_end
    bge a1, a2, end_init_data
loop_init_data:
    lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    blt a1, a2, loop_init_data
end_init_data:

    /* 3. 清零 .bss 段 (将未初始化的全局变量设为 0) */
    la a0, _bss_start
    la a1, _bss_end
    bge a0, a1, end_init_bss
loop_init_bss:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, loop_init_bss
end_init_bss:

    /* 4. 环境准备完毕，优雅地跳转到 C 语言的 main 函数！ */
    call main

    /* 5. 万一 main 函数 return 了，死锁在这里保护 CPU */
1:  j 1b
