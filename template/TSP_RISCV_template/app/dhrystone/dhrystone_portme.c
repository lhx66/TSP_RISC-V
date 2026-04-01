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

// Static variable to track first time call
static int first_call = 1;
static uint32_t start_ticks = 0;

// Simple time implementation - returns elapsed time in seconds
long time(long *t) {
    (void)t;
    uint32_t current_ticks = timer0_get_value();

    if (first_call) {
        start_ticks = current_ticks;
        first_call = 0;
        return 0;
    }

    // Calculate elapsed ticks (assuming timer counts up)
    uint32_t elapsed_ticks = current_ticks - start_ticks;

    // Assuming 50MHz clock, convert ticks to seconds
    return (long)(elapsed_ticks / 50000000);
}

/* ==========================================
 * Memory Allocation (Static Pool)
 * ========================================== */

// Dhrystone needs 2 Rec_Type records + overhead
// Rec_Type is approximately 68 bytes, so we need at least 200 bytes
#define MEMORY_POOL_SIZE 512
static unsigned char memory_pool[MEMORY_POOL_SIZE];
static int pool_offset = 0;

void *malloc(unsigned int size) {
    // Check bounds first
    if (pool_offset + size > MEMORY_POOL_SIZE) {
        // Return NULL if out of memory
        return (void *)0;
    }

    void *ptr = &memory_pool[pool_offset];
    pool_offset += size;

    // Clear allocated memory to prevent garbage data
    // Use volatile to prevent compiler optimization
    volatile unsigned char *p = (volatile unsigned char *)ptr;
    for (unsigned int i = 0; i < size; i++) {
        p[i] = 0;
    }

    return ptr;
}

void free(void *ptr) {
    (void)ptr;
    // Do nothing - static pool doesn't free
}

/* ==========================================
 * String Functions
 * ========================================== */

char *strcpy(char *dest, const char *src) {
    // Safe copy with explicit length limit
    int max_len = 100;  // Safety limit
    int i = 0;
    while (i < max_len) {
        char c = src[i];
        dest[i] = c;
        if (c == '\0') {
            break;
        }
        i++;
    }
    // Ensure null termination
    if (i >= max_len) {
        dest[max_len-1] = '\0';
    }
    return dest;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(const unsigned char *)s1 - *(const unsigned char *)s2;
}

/* ==========================================
 * Printf Interface
 * ========================================== */

// Note: We use the project's ee_printf, so printf is already defined
// in syscalls.c. If you encounter issues, check that implementation.

/* ==========================================
 * Main Entry Point
 * ========================================== */

// Forward declaration of real Dhrystone main
extern int dhrystone_main(void);

int main(void) {
    // Initialize timer (for time() function)
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // Call the real Dhrystone main (compiled with WITH_MAIN)
    dhrystone_main();

    // Stop timer
    timer0_stop();

    // Halt
    while(1) {
        // Idle
    }

    return 0;
}
