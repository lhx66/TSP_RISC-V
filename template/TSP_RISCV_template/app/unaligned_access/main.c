#include <stdint.h>

#include "bsp_uart.h"

static volatile uint8_t data[12] __attribute__((aligned(4)));

static inline void store_u32(uint8_t *addr, uint32_t value)
{
    __asm__ volatile ("sw %1, 0(%0)" : : "r"(addr), "r"(value) : "memory");
}

static inline uint32_t load_u32(const uint8_t *addr)
{
    uint32_t value;
    __asm__ volatile ("lw %0, 0(%1)" : "=r"(value) : "r"(addr) : "memory");
    return value;
}

static inline void store_u16(uint8_t *addr, uint16_t value)
{
    __asm__ volatile ("sh %1, 0(%0)" : : "r"(addr), "r"(value) : "memory");
}

static inline uint32_t load_u16(const uint8_t *addr)
{
    uint32_t value;
    __asm__ volatile ("lhu %0, 0(%1)" : "=r"(value) : "r"(addr) : "memory");
    return value;
}

static inline int32_t load_s16(const uint8_t *addr)
{
    int32_t value;
    __asm__ volatile ("lh %0, 0(%1)" : "=r"(value) : "r"(addr) : "memory");
    return value;
}

int main(void)
{
    uint8_t *const p = (uint8_t *)data;
    uint32_t failed = 0;

    store_u32(p + 0, 0x11223344u);
    store_u32(p + 4, 0x55667788u);
    store_u32(p + 1, 0xaabbccddu);
    if (load_u32(p + 1) != 0xaabbccddu)
        failed = 1;
    if (p[0] != 0x44u || p[1] != 0xddu || p[2] != 0xccu || p[3] != 0xbbu ||
        p[4] != 0xaau || p[5] != 0x77u || p[6] != 0x66u || p[7] != 0x55u)
        failed = 1;

    store_u32(p + 0, 0x11223344u);
    store_u32(p + 4, 0x55667788u);
    store_u16(p + 3, 0xcafeu);
    if (load_u16(p + 3) != 0xcafeu || load_s16(p + 3) != (int32_t)0xffffcafeu)
        failed = 1;
    if (p[0] != 0x44u || p[1] != 0x33u || p[2] != 0x22u || p[3] != 0xfeu ||
        p[4] != 0xcau || p[5] != 0x77u || p[6] != 0x66u || p[7] != 0x55u)
        failed = 1;

    uart_putc(failed ? 'F' : 'P');
    uart_putc('\n');
    for (;;) { }
}
