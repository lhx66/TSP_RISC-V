#include <stdint.h>

#include "bsp_uart.h"

int main(void)
{
    volatile uint32_t checksum = 0;
    uint32_t i;

    for (i = 1; i <= 16; ++i) {
        checksum = (checksum << 1) ^ (i * 0x13579bdu);
    }

    uart_putc(checksum == 0x71578046u ? 'P' : 'F');
    uart_putc('\n');

    for (;;) {
    }
}
