/*
 * Dhrystone I/O Functions
 * Separate file to avoid multiple definition conflicts
 */

#include <stdarg.h>
#include "../../bsp/uart/bsp_uart.h"

// Simple number-to-string conversion
static void print_num(int num, int base) {
    char buf[16];
    int i = 14;
    int negative = 0;

    if (num < 0 && base == 10) {
        negative = 1;
        num = -num;
    }

    buf[15] = '\0';
    do {
        int digit = num % base;
        buf[i--] = (digit > 9) ? 'a' + digit - 10 : '0' + digit;
        num /= base;
    } while (num > 0);

    if (negative) {
        uart_putc('-');
    }

    for (i++; i < 15; i++) {
        uart_putc(buf[i]);
    }
}

// Minimal printf implementation
int printf(const char *format, ...) {
    va_list args;
    const char *p;
    int chars_printed = 0;

    va_start(args, format);

    for (p = format; *p != '\0'; p++) {
        if (*p != '%') {
            uart_putc(*p);
            chars_printed++;
            continue;
        }

        p++; // skip '%'
        switch (*p) {
            case 'd':
            case 'i':
                print_num(va_arg(args, int), 10);
                chars_printed += 5; // rough estimate
                break;
            case 'u':
                print_num(va_arg(args, unsigned int), 10);
                chars_printed += 5;
                break;
            case 'x':
                print_num(va_arg(args, unsigned int), 16);
                chars_printed += 5;
                break;
            case 's':
                {
                    const char *s = va_arg(args, const char*);
                    if (s == 0) {
                        uart_puts("(null)");
                    } else {
                        // Safe string output - check for null terminator
                        int max_len = 100;
                        int len = 0;
                        const char *p = s;
                        while (len < max_len && *p != '\0') {
                            uart_putc(*p);
                            p++;
                            len++;
                        }
                    }
                    chars_printed += 5; // rough estimate
                }
                break;
            case 'c':
                uart_putc(va_arg(args, int));
                chars_printed++;
                break;
            case '%':
                uart_putc('%');
                chars_printed++;
                break;
            case '\0':
                p--;
                break;
            default:
                uart_putc('%');
                uart_putc(*p);
                chars_printed += 2;
                break;
        }
    }

    va_end(args);
    return chars_printed;
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
