#include "coremark.h"
#include "core_portme.h"
#include "../bsp/timer/bsp_timer.h"   // 【关键新增】引入你手写的 AXI 定时器驱动

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

/* ==========================================
   绑定你的硬件定时器
   ========================================== */
CORETIMETYPE barebones_clock() {
    // 直接返回 AXI Timer 外设里的当前计数值
    return (CORETIMETYPE)timer0_get_value();
}

#define GETMYTIME(_t)              (*_t = barebones_clock())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1

static CORETIMETYPE start_time_val, stop_time_val;

void start_time(void) {
    GETMYTIME(&start_time_val);
}

void stop_time(void) {
    GETMYTIME(&stop_time_val);
}

CORE_TICKS get_time(void) {
    // 利用无符号整数减法的特性，即使定时器溢出翻转（Wrap-around），只要不超过一圈，差值依然是绝对正确的！
    CORE_TICKS elapsed = (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
    return elapsed;
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    // EE_TICKS_PER_SEC 必须在 core_portme.h 中定义为你的 FPGA 时钟频率（如 50000000）
    secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return retval;
}

ee_u32 default_num_contexts = 1;

/* ==========================================
   硬件初始化钩子
   ========================================== */
void portable_init(core_portable *p, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;

    // 如果你有 UART 串口初始化函数，必须在这里调用它！
    // 比如：uart_init(115200); 

    // 👇 【植入心跳包】确保串口能叫出声！
    ee_printf("\r\n==================================\r\n");
    ee_printf("[DEBUG] C Environment Ready!\r\n");
    ee_printf("[DEBUG] CPU Survived Startup!\r\n");
    ee_printf("==================================\r\n");

    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
        ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
    }
    if (sizeof(ee_u32) != 4) {
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    }
    p->portable_id = 1;
}

void portable_fini(core_portable *p) {
    timer0_stop();
    p->portable_id = 0;
}

/* =======================================================
   硬件救星：强制重写标准库的内存操作函数！
   由于官方代码会隐式调用 memcpy 进行结构体赋值，
   这里的重写强制编译器只使用单字节（lb/sb）指令，
   完美免疫标准库中 unaligned lw/sw 带来的静默数据损坏！
   ======================================================= */

void *memcpy(void *dest, const void *src, unsigned int n) {
    char *d = (char *)dest;
    const char *s = (const char *)src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

void *memset(void *s, int c, unsigned int n) {
    char *p = (char *)s;
    while (n--) {
        *p++ = c;
    }
    return s;
}

unsigned int strlen(const char *s) {
    unsigned int len = 0;
    while (s[len]) len++;
    return len;
}