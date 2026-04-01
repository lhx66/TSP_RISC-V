#include "bsp_uart.h"
#include "../bsp_map.h"

// 发送单字符 (轮询发送，确保不丢包)
void uart_putc(char c) {
    // 如果 UART 发送缓冲区满了，就死等 (防止打字太快导致字符被覆盖)
    // 注意：如果你的 UART IP 没有状态寄存器，可以把这个 while 注释掉
    while (UART_STATUS & UART_TX_FULL);

    // 将字符写入数据寄存器
    UART_TX_DATA = (uint32_t)c;
}

// 发送字符串 (之前你在 main.c 里频繁调用的函数就是它)
void uart_puts(const char *str) {
    while (*str != '\0') {
        uart_putc(*str);
        str++;
    }
}

// 接收单字符 (阻塞等待)
char uart_getc(void) {
    while (UART_STATUS & UART_RX_EMPTY);
    return (char)(UART_RX_DATA & 0xFF);
}
