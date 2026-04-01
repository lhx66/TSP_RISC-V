/*
 * Test strcpy function
 */

#include "../../bsp/uart/bsp_uart.h"
#include "../../bsp/timer/bsp_timer.h"

// strcpy implementation (same as dhrystone_portme.c)
char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++) != '\0');
    return dest;
}

// Simple print
static void print_str(const char *s) {
    uart_puts(s);
}

int main(void) {
    uart_puts("\r\n=== strcpy Test ===\r\n");

    // Initialize timer
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // Test 1: Simple strcpy
    char str1[31];
    uart_puts("Test 1: Simple strcpy...\r\n");
    strcpy(str1, "Hello World");
    print_str("Result: ");
    print_str(str1);
    uart_puts("\r\n");

    // Test 2: Long string
    char str2[31];
    uart_puts("Test 2: Long string...\r\n");
    strcpy(str2, "DHRYSTONE PROGRAM, 1'ST STRING");
    print_str("Result: ");
    print_str(str2);
    uart_puts("\r\n");

    // Test 3: Check content
    uart_puts("Test 3: Character check...\r\n");
    for (int i = 0; i < 10; i++) {
        uart_putc(str2[i]);
    }
    uart_puts("\r\n");

    uart_puts("=== Test Complete ===\r\n");

    timer0_stop();
    while(1);

    return 0;
}
