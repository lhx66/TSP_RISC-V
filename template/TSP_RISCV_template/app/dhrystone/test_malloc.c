/*
 * Simple malloc test to verify memory allocation
 */

#include "../../bsp/uart/bsp_uart.h"
#include "../../bsp/timer/bsp_timer.h"

// Simple number print
static void print_num(unsigned int num) {
    char buf[16];
    int i = 14;
    buf[15] = '\0';
    do {
        int digit = num % 10;
        buf[i--] = '0' + digit;
        num /= 10;
    } while (num > 0);
    for (i++; i < 15; i++) {
        uart_putc(buf[i]);
    }
}

// Malloc implementation (same as dhrystone_portme.c)
#define MEMORY_POOL_SIZE 512
static unsigned char memory_pool[MEMORY_POOL_SIZE];
static int pool_offset = 0;

void *malloc(unsigned int size) {
    if (pool_offset + size > MEMORY_POOL_SIZE) {
        return (void *)0;
    }

    void *ptr = &memory_pool[pool_offset];
    pool_offset += size;

    // Clear allocated memory - use volatile to prevent optimization
    volatile unsigned char *p = (volatile unsigned char *)ptr;
    for (unsigned int i = 0; i < size; i++) {
        p[i] = 0;
    }

    return ptr;
}

// Test structure
typedef struct {
    int a;
    int b;
    char c[16];
} test_struct;

int main(void) {
    uart_puts("\r\n=== Malloc Test ===\r\n");

    // Initialize timer
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // Test malloc
    uart_puts("Allocating test_struct...\r\n");
    test_struct *ptr = (test_struct *)malloc(sizeof(test_struct));

    if (ptr == 0) {
        uart_puts("ERROR: malloc returned NULL!\r\n");
        while(1);
    }

    // Check if memory is zeroed
    uart_puts("Checking if memory is zeroed...\r\n");
    int all_zero = 1;
    unsigned char *bytes = (unsigned char *)ptr;
    for (unsigned int i = 0; i < sizeof(test_struct); i++) {
        if (bytes[i] != 0) {
            all_zero = 0;
            break;
        }
    }

    if (all_zero) {
        uart_puts("SUCCESS: Memory is properly zeroed!\r\n");
    } else {
        uart_puts("ERROR: Memory contains garbage data!\r\n");
    }

    // Write test data
    uart_puts("Writing test data...\r\n");
    ptr->a = 12345;
    ptr->b = 67890;
    for (int i = 0; i < 15; i++) {
        ptr->c[i] = 'A' + i;
    }
    ptr->c[15] = '\0';

    // Verify
    uart_puts("Verifying data...\r\n");
    uart_puts("ptr->a = ");
    print_num(ptr->a);
    uart_puts("\r\n");

    uart_puts("ptr->b = ");
    print_num(ptr->b);
    uart_puts("\r\n");

    uart_puts("ptr->c = ");
    for (int i = 0; i < 15; i++) {
        uart_putc(ptr->c[i]);
    }
    uart_puts("\r\n");

    uart_puts("=== Test Complete ===\r\n");

    timer0_stop();
    while(1) {
        // Idle
    }

    return 0;
}
