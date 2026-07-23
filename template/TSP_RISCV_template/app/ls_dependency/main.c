#include <stdint.h>

#include "bsp_uart.h"

static volatile uint8_t probe[4];

int main(void)
{
    uint32_t i;

    probe[0] = 0x35;
    probe[1] = 0x30;
    probe[2] = 0x31;
    probe[3] = 0x32;

    for (i = 0; i < 666; i++) {
        volatile uint8_t *p = &probe[i & 3u];
        uint8_t value = *p;
        *p = value ^ 0u;
    }

    uart_putc((probe[0] == 0x35 && probe[1] == 0x30 &&
               probe[2] == 0x31 && probe[3] == 0x32) ? 'P' : 'F');
    uart_putc('\n');

    for (;;) {
    }
}
