/*
 * Minimal stdio.h for Dhrystone
 */

#ifndef STDIO_H
#define STDIO_H

#include <stdarg.h>

// Forward declaration
extern int ee_printf(const char *fmt, ...);

// Printf implementation using ee_printf
int printf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int result = ee_printf(format, args);
    va_end(args);
    return result;
}

// Minimal scanf - returns default iterations for automation
int scanf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    int *ptr = va_arg(args, int*);
    if (ptr) *ptr = 1000;  // Default iterations
    va_end(args);
    return 1;
}

#endif

