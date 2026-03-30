.section .init, "ax"
.global _start
.type _start, @function

_start:
    /* 1. 初始化栈指针 */
    la sp, _sp

    /* 2. 直接跳入 C 语言，剩下的全交给 C 语言处理！ */
    call main

1:  j 1b
