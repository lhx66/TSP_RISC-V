#ifndef BSP_MAP_H
#define BSP_MAP_H

#include <stdint.h>

// ==========================================
// 物理内存映射映射表 (对应 AXI Interconnect)
// ==========================================
#define IRAM_BASE   0x00000000  // 指令 RAM (64KB)
#define SRAM_BASE   0x20000000  // 数据 SRAM (32KB)
#define UART_BASE   0x40000000  // UART 外设基地址
#define TIMER_BASE  0x60000000  // Timer 外设基地址

// 宏定义：用于裸机下的指针强转，实现对硬件寄存器的读写
#define REG32(addr) (*(volatile uint32_t *)(addr))

#endif // BSP_MAP_H