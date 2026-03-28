.section .init, "ax"
.global _start
.type _start, @function

_start:
    /* 1. 初始化栈指针 */
    la sp, _sp

    /* [硬核调试 1]：向串口发送字符 'S' (Start)，如果看到 S，说明 CPU 正常开机 */
    li t0, 0x40000000
    li t1, 83        /* 'S' 的 ASCII 码 */
    sw t1, 0(t0)

    /* 2. 搬运 .data 段 (此时要通过 AXI 读 IRAM) */
    la a0, _data_lma
    la a1, _data_start
    la a2, _data_end
    bge a1, a2, end_init_data
loop_init_data:
    lw a3, 0(a0)         /* <--- 之前 CPU 就是卡死在这一句！ */
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    blt a1, a2, loop_init_data
end_init_data:

    /* [硬核调试 2]：向串口发送字符 'D' (Data done)，如果看到 D，说明成功越过了 AXI 读 IRAM 的难关！ */
    li t1, 68        /* 'D' 的 ASCII 码 */
    sw t1, 0(t0)

    /* 3. 清零 .bss 段 */
    la a0, _bss_start
    la a1, _bss_end
    bge a0, a1, end_init_bss
loop_init_bss:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, loop_init_bss
end_init_bss:

    /* [硬核调试 3]：向串口发送字符 'B' (BSS done) */
    li t1, 66        /* 'B' 的 ASCII 码 */
    sw t1, 0(t0)

    /* 4. 跳转到 main 函数 */
    call main

1:  j 1b
