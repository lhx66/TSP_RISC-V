#include <stdint.h>

#include "bsp_uart.h"

static inline uint32_t rv_mul(uint32_t a, uint32_t b)
{
    uint32_t value;
    __asm__ volatile ("mul %0, %1, %2" : "=r"(value) : "r"(a), "r"(b));
    return value;
}

static inline uint32_t rv_mulh(uint32_t a, uint32_t b)
{
    uint32_t value;
    __asm__ volatile ("mulh %0, %1, %2" : "=r"(value) : "r"(a), "r"(b));
    return value;
}

static inline uint32_t rv_mulhsu(uint32_t a, uint32_t b)
{
    uint32_t value;
    __asm__ volatile ("mulhsu %0, %1, %2" : "=r"(value) : "r"(a), "r"(b));
    return value;
}

static inline uint32_t rv_mulhu(uint32_t a, uint32_t b)
{
    uint32_t value;
    __asm__ volatile ("mulhu %0, %1, %2" : "=r"(value) : "r"(a), "r"(b));
    return value;
}

int main(void)
{
    uint32_t failed = 0;

    failed |= rv_mul(0xfffffffdu, 7u) != 0xffffffebu;
    failed |= rv_mulh(0x80000000u, 2u) != 0xffffffffu;
    failed |= rv_mulhsu(0xfffffffeu, 0xffffffffu) != 0xfffffffeu;
    failed |= rv_mulhu(0xffffffffu, 0xffffffffu) != 0xfffffffeu;

    uart_putc(failed ? 'F' : 'P');
    uart_putc('\n');
    for (;;) { }
}
