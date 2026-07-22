/*
 * strcpy/strcmp 性能测试
 * 用于验证字符串函数优化的实际效果
 */

#include "dhry.h"
#include "../../bsp/timer/bsp_timer.h"
#include "../../bsp/uart/bsp_uart.h"

// 简单的printf实现
extern int ee_printf(const char *format, ...);

#define TEST_ITERATIONS 10000
#define STR_LEN 30

// 测试用的字符串
extern char *strcpy(char *dest, const char *src);
extern int strcmp(const char *s1, const char *s2);

int main(void) {
    char dest1[STR_LEN];
    char dest2[STR_LEN];
    const char *src = "DHRYSTONE PROGRAM, TEST STRING";
    const char *str1 = "DHRYSTONE PROGRAM, 1'ST STRING";
    const char *str2 = "DHRYSTONE PROGRAM, 2'ND STRING";

    uint32_t start_time, end_time, elapsed_cycles;

    // 初始化计时器
    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    ee_printf("String Function Performance Test\n");
    ee_printf("==================================\n\n");

    // 测试 strcpy 性能
    ee_printf("Testing strcpy (%d iterations)...\n", TEST_ITERATIONS);

    start_time = timer0_get_value();
    for (int i = 0; i < TEST_ITERATIONS; i++) {
        strcpy(dest1, src);
        strcpy(dest2, str1);
    }
    end_time = timer0_get_value();

    elapsed_cycles = end_time - start_time;
    ee_printf("strcpy: %u cycles for %d iterations\n", elapsed_cycles, TEST_ITERATIONS);
    ee_printf("Average: %u cycles per call\n", elapsed_cycles / (TEST_ITERATIONS * 2));

    // 验证结果正确性
    ee_printf("\nVerification:\n");
    ee_printf("dest1 = %s\n", dest1);
    ee_printf("dest2 = %s\n", dest2);

    // 测试 strcmp 性能
    ee_printf("\n\nTesting strcmp (%d iterations)...\n", TEST_ITERATIONS);

    start_time = timer0_get_value();
    for (int i = 0; i < TEST_ITERATIONS; i++) {
        strcmp(str1, str2);
        strcmp(str1, str1);
    }
    end_time = timer0_get_value();

    elapsed_cycles = end_time - start_time;
    ee_printf("strcmp: %u cycles for %d iterations\n", elapsed_cycles, TEST_ITERATIONS);
    ee_printf("Average: %u cycles per call\n", elapsed_cycles / (TEST_ITERATIONS * 2));

    // 测试混合性能
    ee_printf("\n\nTesting mixed operations (%d iterations)...\n", TEST_ITERATIONS);

    start_time = timer0_get_value();
    for (int i = 0; i < TEST_ITERATIONS; i++) {
        strcpy(dest1, str1);
        strcpy(dest2, str2);
        strcmp(dest1, dest2);
    }
    end_time = timer0_get_value();

    elapsed_cycles = end_time - start_time;
    ee_printf("Mixed: %u cycles for %d iterations\n", elapsed_cycles, TEST_ITERATIONS);
    ee_printf("Average: %u cycles per iteration\n", elapsed_cycles / TEST_ITERATIONS);

    ee_printf("\n\nTest complete!\n");

    // 停止计时器
    timer0_stop();

    while(1) {
        // Idle
    }

    return 0;
}
