#ifndef BSP_UART_H
#define BSP_UART_H

#include <stdint.h>

// 假设你的 UART 寄存器映射如下 (请根据你的 UART IP 手册调整偏移量)
#define UART_TX_DATA REG32(UART_BASE + 0x00) // 发送寄存器
#define UART_RX_DATA REG32(UART_BASE + 0x04) // 接收寄存器
#define UART_STATUS  REG32(UART_BASE + 0x08) // 状态寄存器

// 状态寄存器位定义 (假设)
#define UART_TX_FULL  (1 << 0)  // TX FIFO 满标志
#define UART_RX_EMPTY (1 << 1)  // RX FIFO 空标志

// API 函数声明
void uart_putc(char c);
void uart_puts(const char *str);
char uart_getc(void);

#endif // BSP_UART_H
