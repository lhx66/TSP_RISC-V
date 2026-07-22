/*
 * Test stack variable initialization
 */

#include "../../bsp/uart/bsp_uart.h"
#include "../../bsp/timer/bsp_timer.h"

// Safe strcpy
char *strcpy(char *dest, const char *src) {
    char *d = dest;
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

// Simple print
static void print_str(const char *s) {
    uart_puts(s);
}

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

int test_stack_vars(void) {
    uart_puts("=== Test Stack Variables ===\r\n");

    // Test 1: Large stack arrays
    char str1[31];
    char str2[31];
    int num1, num2, num3;

    uart_puts("Test 1: Declare stack variables\r\n");
    uart_puts("str1 address: ");
    print_num((unsigned int)str1);
    uart_puts("\r\n");

    uart_puts("Test 2: Before strcpy\r\n");
    uart_puts("str1[0] = ");
    print_num(str1[0]);
    uart_puts("\r\n");

    uart_puts("Test 3: Copy to str1\r\n");
    strcpy(str1, "Hello World");
    uart_puts("After strcpy, str1 = ");
    print_str(str1);
    uart_puts("\r\n");

    uart_puts("Test 4: Copy to str2\r\n");
    strcpy(str2, "DHRYSTONE PROGRAM, 1'ST STRING");
    uart_puts("After strcpy, str2 = ");
    print_str(str2);
    uart_puts("\r\n");

    uart_puts("Test 5: Check str2 content\r\n");
    for (int i = 0; i < 10; i++) {
        uart_putc(str2[i]);
    }
    uart_puts("\r\n");

    uart_puts("Test 6: Numeric variables\r\n");
    num1 = 123;
    num2 = 456;
    num3 = 789;
    uart_puts("num1 = ");
    print_num(num1);
    uart_puts("\r\n");
    uart_puts("num2 = ");
    print_num(num2);
    uart_puts("\r\n");
    uart_puts("num3 = ");
    print_num(num3);
    uart_puts("\r\n");

    uart_puts("=== Stack Test Complete ===\r\n");

    return 0;
}

int main(void) {
    uart_puts("\r\n*** Stack Variable Test ***\r\n");

    // Initialize timer
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // Call test function
    test_stack_vars();

    timer0_stop();
    while(1);

    return 0;
}
