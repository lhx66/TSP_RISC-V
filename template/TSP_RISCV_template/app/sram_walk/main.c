#include <stdint.h>

#include "bsp_uart.h"

#define WALK_BYTES 4096U

static volatile uint8_t walk_mem[WALK_BYTES] __attribute__((aligned(4)));

static uint8_t byte_pattern(uint32_t index)
{
    return (uint8_t)((index * 73U) ^ (index >> 3) ^ 0xa5U);
}

int main(void)
{
    volatile uint32_t *word_mem = (volatile uint32_t *)walk_mem;
    uint32_t i;

    for (i = 0; i < WALK_BYTES; i++)
        walk_mem[i] = byte_pattern(i);
    for (i = 0; i < WALK_BYTES; i++) {
        if (walk_mem[i] != byte_pattern(i)) {
            uart_putc('B');
            uart_putc('F');
            for (;;) { }
        }
    }

    for (i = 0; i < WALK_BYTES / sizeof(uint32_t); i++)
        word_mem[i] = 0xa5a50000U ^ (i * 0x1021U);
    for (i = 0; i < WALK_BYTES / sizeof(uint32_t); i++) {
        if (word_mem[i] != (0xa5a50000U ^ (i * 0x1021U))) {
            uart_putc('W');
            uart_putc('F');
            for (;;) { }
        }
    }

    uart_putc('P');
    for (;;) { }
}
