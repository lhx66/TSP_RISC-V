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

    // 全局启动计数器（检测反复重启）
    static int boot_count = 0;
    boot_count++;

    // 如果启动次数过多，停止程序
    if (boot_count > 3) {
        ee_printf("Too many restarts! Halting.\r\n");
        while(1);
    }

    // 极简调试信息
    ee_printf("Boot %d\r\n", boot_count);
    ee_printf("Init OK\r\n");

    timer0_init(0xFFFFFFFF, 0);
    timer0_start();

    // 👇 加上这几句，测试定时器是不是真的在动！
    ee_printf("[DEBUG] Timer Init Value: %d\r\n", timer0_get_value());
    for(volatile int k=0; k<50000; k++); // 故意让 CPU 拖延一小会儿
    ee_printf("[DEBUG] Timer After Delay: %d\r\n", timer0_get_value());

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

// ==========================================
// 极简静态对齐堆 (供官方代码的 portable_malloc 使用)
// ==========================================
// 强制 8 字节对齐，确保基地址绝对安全
#ifndef COREMARK_HEAP_ALIGN
#define COREMARK_HEAP_ALIGN 8
#endif
__attribute__((aligned(COREMARK_HEAP_ALIGN))) static ee_u8 my_heap[TOTAL_DATA_SIZE * MULTITHREAD + 256];
static int heap_offset = 0;

void *portable_malloc(size_t size) {
    void *ptr = &my_heap[heap_offset];
    heap_offset += size;
    return ptr;
}

void portable_free(void *p) {
    heap_offset = 0; // 极简释放
}

/* =======================================================
   免疫 GCC 优化的安全内存操作护盾
   ======================================================= */
void *memcpy(void *dest, const void *src, unsigned int n) {
    volatile char *d = (volatile char *)dest;
    const volatile char *s = (const volatile char *)src;
    while (n--) *d++ = *s++;
    return dest;
}

void *memset(void *s, int c, unsigned int n) {
    volatile char *p = (volatile char *)s;
    while (n--) *p++ = c;
    return s;
}

unsigned int strlen(const char *s) {
    volatile unsigned int len = 0;
    const volatile char *str = (const volatile char *)s;
    while (str[len]) len++;
    return len;
}
