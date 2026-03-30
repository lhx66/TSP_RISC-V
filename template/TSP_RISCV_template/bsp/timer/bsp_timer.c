#include "bsp_timer.h"

#include "../bsp_map.h"

// 初始化 Timer0
// cmp_value: 定时器比较阈值 (达到该值触发中断)
// enable_interrupt: 是否开启硬件中断信号
void timer0_init(uint32_t cmp_value, bool enable_interrupt) {
    // 1. 先关闭定时器，防止配置时乱跑
    TIMER_CTRL0 = 0;

    // 2. 清零当前计数值
    TIMER_VAL0 = 0;

    // 3. 设置比较值
    TIMER_CMP0 = cmp_value;

    // 4. 配置中断
    if (enable_interrupt) {
        TIMER_CTRL0 |= TIMER_CTRL_INT_EN;
    }
}

// 启动 Timer0
void timer0_start(void) {
    TIMER_CTRL0 |= TIMER_CTRL_EN;
}

// 停止 Timer0
void timer0_stop(void) {
    TIMER_CTRL0 &= ~TIMER_CTRL_EN;
}

// 强制修改当前计数值
void timer0_set_value(uint32_t val) {
    TIMER_VAL0 = val;
}

// 获取当前计数值 (可用于精确定时或测距)
uint32_t timer0_get_value(void) {
    return TIMER_VAL0;
}

// 清除中断 (通常在 trap_handler 中调用)
// 根据该 IP 的特性，通常清零当前计数值或重新设置状态即可清除中断标志
void timer0_clear_interrupt(void) {
    TIMER_VAL0 = 0;
}
