#ifndef BSP_TIMER_H
#define BSP_TIMER_H

#include <stdint.h>
#include <stdbool.h>

// Timer 寄存器地址映射
#define TIMER_CTRL0 REG32(TIMER_BASE + 0x08)
#define TIMER_CMP0  REG32(TIMER_BASE + 0x0C)
#define TIMER_VAL0  REG32(TIMER_BASE + 0x10)

#define TIMER_CTRL1 REG32(TIMER_BASE + 0x14)
#define TIMER_CMP1  REG32(TIMER_BASE + 0x18)
#define TIMER_VAL1  REG32(TIMER_BASE + 0x1C)

// 控制位宏定义
#define TIMER_CTRL_INT_EN (1 << 1) // 中断使能位
#define TIMER_CTRL_EN     (1 << 2) // 定时器开启位

// API 函数声明
void timer0_init(uint32_t cmp_value, bool enable_interrupt);
void timer0_start(void);
void timer0_stop(void);
void timer0_set_value(uint32_t val);
uint32_t timer0_get_value(void);
void timer0_clear_interrupt(void);

#endif // BSP_TIMER_H
