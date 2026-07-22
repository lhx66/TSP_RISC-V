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

    // Optimized memory clear: use word-sized access when aligned
    unsigned char *p = (unsigned char *)ptr;
    unsigned int i = 0;

    // Clear leading bytes until 4-byte aligned
    while (i < size && ((uintptr_t)(p + i) & 0x3)) {
        p[i++] = 0;
    }

    // Clear 4 bytes at a time (only if aligned)
    while (i + 4 <= size) {
        // Use byte-wise store to avoid unaligned access
        p[i] = 0;
        p[i+1] = 0;
        p[i+2] = 0;
        p[i+3] = 0;
        i += 4;
    }

    // Clear remaining trailing bytes
    while (i < size) {
        p[i++] = 0;
    }

    return ptr;
}

void free(void *ptr) {
    (void)ptr;
    // Do nothing - static pool doesn't free
}

/* ==========================================
 * Memory Copy Function (for structassign if needed)
 * ========================================== */

void *memcpy(void *dest, const void *src, unsigned int n) {
    // Optimized memcpy for RISC-V with no unaligned access
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    unsigned int i = 0;

    // Handle small copies or unaligned start byte-by-byte
    while (i < n && ((uintptr_t)(d + i) & 0x3) && ((uintptr_t)(s + i) & 0x3)) {
        d[i] = s[i];
        i++;
        if (i >= n) return dest;
    }

    // Copy 4 bytes at a time when both aligned
    // Use byte-wise access to avoid non-aligned access issues
    while (i + 4 <= n) {
        d[i] = s[i];
        d[i+1] = s[i+1];
        d[i+2] = s[i+2];
        d[i+3] = s[i+3];
        i += 4;
    }

    // Copy remaining bytes
    while (i < n) {
        d[i] = s[i];
        i++;
    }

    return dest;
}

/* ==========================================
 * String Functions - Optimized for RISC-V
 * ==========================================
 * Optimizations applied:
 * - No unaligned memory accesses (RISC-V limitation)
 * - Loop unrolling for better throughput
 * - Reduced conditional branches in hot paths
 * - Word-wise copying when aligned (NEW!)
 */

char *strcpy(char *dest, const char *src) {
    // Ultra-optimized strcpy with alignment-aware word copying
    const char *s = src;
    char *d = dest;

    // Check if both source and destination are 4-byte aligned
    int aligned = (((uintptr_t)s & 0x3) == 0) && (((uintptr_t)d & 0x3) == 0);

    if (aligned) {
        // Fast path: Both aligned, use 8-byte loop unrolling with word copying
        // We still use byte access to avoid unaligned access issues,
        // but process 8 bytes at a time for better throughput
        while (1) {
            // Load 8 bytes
            char c0 = s[0], c1 = s[1], c2 = s[2], c3 = s[3];
            char c4 = s[4], c5 = s[5], c6 = s[6], c7 = s[7];

            // Store 8 bytes
            d[0] = c0; d[1] = c1; d[2] = c2; d[3] = c3;
            d[4] = c4; d[5] = c5; d[6] = c6; d[7] = c7;

            // Check for null terminator in first 4 bytes
            if (c0 == '\0') return dest;
            if (c1 == '\0') { d[2] = '\0'; d[3] = '\0'; return dest; }
            if (c2 == '\0') { d[3] = '\0'; return dest; }
            if (c3 == '\0') return dest;

            // Check for null terminator in next 4 bytes
            if (c4 == '\0') { d[5] = '\0'; d[6] = '\0'; d[7] = '\0'; return dest; }
            if (c5 == '\0') { d[6] = '\0'; d[7] = '\0'; return dest; }
            if (c6 == '\0') { d[7] = '\0'; return dest; }
            if (c7 == '\0') return dest;

            s += 8;
            d += 8;
        }
    } else {
        // Slow path: Not aligned, use 4-byte loop unrolling
        while (1) {
            char c0 = s[0];
            char c1 = s[1];
            char c2 = s[2];
            char c3 = s[3];

            d[0] = c0;
            if (c0 == '\0') break;

            d[1] = c1;
            if (c1 == '\0') {
                d[2] = '\0';
                d[3] = '\0';
                break;
            }

            d[2] = c2;
            if (c2 == '\0') {
                d[3] = '\0';
                break;
            }

            d[3] = c3;
            if (c3 == '\0') break;

            s += 4;
            d += 4;
        }
    }

    return dest;
}

int strcmp(const char *s1, const char *s2) {
    // Optimized strcmp with alignment-aware processing
    int aligned = (((uintptr_t)s1 & 0x3) == 0) && (((uintptr_t)s2 & 0x3) == 0);

    if (aligned) {
        // Fast path: Both aligned, use 8-byte loop unrolling
        while (1) {
            // Compare 8 bytes at a time
            unsigned char c0 = s1[0], c1 = s2[0];
            if (c0 != c1 || c0 == '\0') return c0 - c1;

            unsigned char c2 = s1[1], c3 = s2[1];
            if (c2 != c3 || c2 == '\0') return c2 - c3;

            unsigned char c4 = s1[2], c5 = s2[2];
            if (c4 != c5 || c4 == '\0') return c4 - c5;

            unsigned char c6 = s1[3], c7 = s2[3];
            if (c6 != c7 || c6 == '\0') return c6 - c7;

            unsigned char c8 = s1[4], c9 = s2[4];
            if (c8 != c9 || c8 == '\0') return c8 - c9;

            unsigned char c10 = s1[5], c11 = s2[5];
            if (c10 != c11 || c10 == '\0') return c10 - c11;

            unsigned char c12 = s1[6], c13 = s2[6];
            if (c12 != c13 || c12 == '\0') return c12 - c13;

            unsigned char c14 = s1[7], c15 = s2[7];
            if (c14 != c15 || c14 == '\0') return c14 - c15;

            s1 += 8;
            s2 += 8;
        }
    } else {
        // Slow path: Not aligned, use 4-byte loop unrolling
        while (1) {
            unsigned char c0 = s1[0];
            unsigned char c1 = s2[0];
            if (c0 != c1 || c0 == '\0') return c0 - c1;

            unsigned char c2 = s1[1];
            unsigned char c3 = s2[1];
            if (c2 != c3 || c2 == '\0') return c2 - c3;

            unsigned char c4 = s1[2];
            unsigned char c5 = s2[2];
            if (c4 != c5 || c4 == '\0') return c4 - c5;

            unsigned char c6 = s1[3];
            unsigned char c7 = s2[3];
            if (c6 != c7 || c6 == '\0') return c6 - c7;

            s1 += 4;
            s2 += 4;
        }
    }
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
