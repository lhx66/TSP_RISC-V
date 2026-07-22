/*
 * Dhrystone Porting Layer for RISC-V Bare Metal
 * ==========================================
 * This file provides OS glue functions for Dhrystone
 */

#include "dhry.h"
#include "../../bsp/timer/bsp_timer.h"
#include "../../bsp/uart/bsp_uart.h"

// Forward declarations
extern int do_dhrystone(void);

/* ==========================================
 * Time Measurement (using TIMER)
 * ========================================== */

// Simple time implementation - returns seconds
long time(long *t) {
    (void)t;
    // Assuming 50MHz clock, convert ticks to seconds
    // For better accuracy, you might want to use the full timer value
    return (long)(timer0_get_value() / 50000000);
}

/* ==========================================
 * Memory Allocation (Static Pool)
 * ========================================== */

// Dhrystone only allocates 2 records, so static pool is fine
static unsigned char memory_pool[64];
static int pool_offset = 0;

void *malloc(unsigned int size) {
    void *ptr = &memory_pool[pool_offset];
    pool_offset += size;
    // Simple bounds check
    if (pool_offset > (int)sizeof(memory_pool)) {
        // Return NULL if out of memory
        return (void *)0;
    }
    return ptr;
}

void free(void *ptr) {
    (void)ptr;
    // Do nothing - static pool doesn't free
}

/* ==========================================
 * Printf Interface
 * ========================================== */

// Note: We use the project's ee_printf, so printf is already defined
// in syscalls.c. If you encounter issues, check that implementation.

/* ==========================================
 * Main Entry Point
 * ========================================== */

int main(void) {
    // Initialize timer
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // Print banner
    uart_puts("\r\n");
    uart_puts("Dhrystone Benchmark for RISC-V RV32IM\r\n");
    uart_puts("Version 2.1 (Language: C)\r\n");
    uart_puts("\r\n");
    uart_puts("Execution starts...\r\n");
    uart_puts("\r\n");

    // Run Dhrystone
    do_dhrystone();

    // Print completion
    uart_puts("\r\n");
    uart_puts("Dhrystone completed!\r\n");
    uart_puts("\r\n");

    // Stop
    timer0_stop();

    // Halt
    while(1) {
        // Idle
    }

    return 0;
}
