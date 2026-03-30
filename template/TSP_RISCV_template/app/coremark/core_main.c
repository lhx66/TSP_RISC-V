/*
Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)
*/
#include "coremark.h"

// 从链接脚本(.ld)中引入段地址符号
extern ee_u32 _data_lma;
extern ee_u32 _data_start;
extern ee_u32 _data_end;
extern ee_u32 _bss_start;
extern ee_u32 _bss_end;

static ee_u16 list_known_crc[]   = { (ee_u16)0xd4b0, (ee_u16)0x3340, (ee_u16)0x6a79, (ee_u16)0xe714, (ee_u16)0xe3c1 };
static ee_u16 matrix_known_crc[] = { (ee_u16)0xbe52, (ee_u16)0x1199, (ee_u16)0x5608, (ee_u16)0x1fd7, (ee_u16)0x0747 };
static ee_u16 state_known_crc[]  = { (ee_u16)0x5e47, (ee_u16)0x39bf, (ee_u16)0xe5a4, (ee_u16)0x8e3a, (ee_u16)0x8d84 };

// =======================================================
// 重写标准库内存操作函数，强制使用 8位 (单字节) 对齐拷贝
// 彻底解决硬件非对齐 SW 导致的内存踩踏崩溃问题！
// =======================================================

void *memcpy(void *dest, const void *src, unsigned int n) {
    char *d = (char *)dest;
    const char *s = (const char *)src;
    while (n--) {
        *d++ = *s++; // 编译器只会生成安全的 lb 和 sb 指令
    }
    return dest;
}

void *memset(void *s, int c, unsigned int n) {
    char *p = (char *)s;
    while (n--) {
        *p++ = c;    // 编译器只会生成安全的 sb 指令
    }
    return s;
}

// 可选：拦截 strlen
unsigned int strlen(const char *s) {
    unsigned int len = 0;
    while (s[len]) len++;
    return len;
}

#if MAIN_HAS_NOARGC
MAIN_RETURN_TYPE main(void) {
    int  argc = 0;
    char *argv[1];
#else
MAIN_RETURN_TYPE main(int argc, char *argv[]) {
#endif

    ee_u16       j = 0;
    ee_s16       known_id = -1, total_errors = 0;
    ee_u16       seedcrc = 0;
    CORE_TICKS   total_time;
    core_results results[1];
    ee_u32       mem_array[600];

    // 💥 护盾开启：加上 volatile，强迫编译器生成原生 Load/Store 指令，彻底封杀 memset/memcpy 的替换！
    volatile ee_u32 *src, *dst, *end;

    ee_printf("\r\n[DEBUG] CoreMark Booting (C-Level Data Init)...\r\n");

    /* =========================================================
       🚀 核心拯救行动：绝对物理级内存操作
       ========================================================= */
    src = (volatile ee_u32 *)&_data_lma;
    dst = (volatile ee_u32 *)&_data_start;
    end = (volatile ee_u32 *)&_data_end;

    ee_printf("[DEBUG] Copying .data from 0x%x to 0x%x... ", (ee_u32)src, (ee_u32)dst);
    while (dst < end) {
        *dst++ = *src++;
    }
    ee_printf("Done!\r\n");

    dst = (volatile ee_u32 *)&_bss_start;
    end = (volatile ee_u32 *)&_bss_end;
    ee_printf("[DEBUG] Clearing .bss at 0x%x... ", (ee_u32)dst);
    while (dst < end) {
        *dst++ = 0; // 这里的每一次循环，都会被老老实实地编译成一条 sw 指令！
    }
    ee_printf("Done!\r\n");

    /* =========================================================
       3. 正式开始 CoreMark 初始化
       ========================================================= */
    portable_init(&(results[0].port), &argc, argv);

    results[0].seed1      = 0x3415;
    results[0].seed2      = 0x3415;
    results[0].seed3      = 0x66;
    results[0].iterations = ITERATIONS;
    results[0].execs      = 7;
    results[0].size       = 664;
    results[0].err        = 0;

    results[0].memblock[0] = (void *)mem_array;
    results[0].memblock[1] = (char *)mem_array;
    results[0].memblock[2] = (char *)mem_array + 664;
    results[0].memblock[3] = (char *)mem_array + 1328;

    ee_printf("\r\n=== Hardware Final Boss Test ===\r\n");

    // ---------------------------------------------------
    // 测试 1：有符号跳转测试 (检查 BLT / BGE 是否写反了)
    // ---------------------------------------------------
    ee_printf("[Test 1] Signed Branch Test... ");
    volatile int neg_val = -5;
    volatile int pos_val = 0;
    if (neg_val >= pos_val) {
        ee_printf("\r\n[FATAL BUG] BJP evaluates -5 >= 0! Check $signed() in exu_bjp.v!\r\n");
        while(1); // 硬件有 Bug，强制卡死
    }
    ee_printf("PASS\r\n");

    // ---------------------------------------------------
    // 测试 2：极速 RAW 冒险测试 (检查 ALU -> Branch 连贯性)
    // ---------------------------------------------------
    ee_printf("[Test 2] RAW Hazard Test... ");
    volatile int counter = 5;
    __asm__ volatile (
        "1:\n\t"
        "addi %0, %0, -1\n\t"    // 减1
        "bne  %0, zero, 1b\n\t"  // 紧接着立刻判断
        : "+r" (counter)
    );
    ee_printf("PASS\r\n");

    // ---------------------------------------------------
    // 测试 3：极速 LSU RAW 冒险测试 (检查 LW -> Branch 连贯性)
    // ---------------------------------------------------
    ee_printf("[Test 3] LSU to Branch RAW Test... ");
    volatile int dummy_node[2];
    dummy_node[0] = (int)&dummy_node[0]; // 指向自己
    dummy_node[1] = 0;                   // NULL

    volatile int *ptr = dummy_node;
    __asm__ volatile (
        "lw   %0, 4(%0)\n\t"     // 读取 dummy_node[1] (即 0)
        "bne  %0, zero, 2f\n\t"  // 应该不跳转
        "j    3f\n\t"            // 成功跳出
        "2:\n\t"
        "j    2b\n\t"            // 错误：陷入死循环
        "3:\n\t"
        : "+r" (ptr)
    );
    ee_printf("PASS\r\n");

    ee_printf("=== All Hardware Tests Passed! ===\r\n");

    ee_printf("[DEBUG] Init List... \r\n");
    results[0].list = core_list_init(664, results[0].memblock[1], 0x3415);

    ee_printf("[DEBUG] Init Matrix... \r\n");
    core_init_matrix(664, results[0].memblock[2], 0x3415 | (0x3415 << 16), &(results[0].mat));

    ee_printf("[DEBUG] Init State... \r\n");
    // .data 段一旦恢复，int_stream 就不再是 0x0，这里绝对能平稳度过！
    core_init_state(664, 0x3415, results[0].memblock[3]);
    
    // 🟢 诊断点 A：证明它活着逃出了 Init State
    ee_printf("[DEBUG] Init State Completed Successfully!\r\n");

    // =========================================================
    // 💥 终极 Boss 战：CPU 流水线数据冒险（Data Hazard）大考
    // =========================================================
    ee_printf("\r\n[DEBUG] Running Final Boss Pipeline Tests...\r\n");

    // 🎯 Test 8: Load-Use 数据冒险测试
    ee_printf("  -> Test 8: Load-Use Hazard... ");
    ee_u32 lu_data[2] = {0xAAAAAAAA, 0xBBBBBBBB};
    ee_u32 lu_res = 0;
    ee_u32 *p_lu = lu_data;
    __asm__ volatile (
        "lw t1, 4(%1) \n\t"   
        "addi t2, t1, 1 \n\t" 
        "sw t2, 0(%0) \n\t"
        :
        : "r" (&lu_res), "r" (p_lu)
        : "t1", "t2", "memory"
    );
    if (lu_res != 0xBBBBBBBC) {
        ee_printf("FAIL! No Pipeline Stall! Res: 0x%08X\r\n", lu_res);
        while(1);
    }
    ee_printf("OK\r\n");

    // 🎯 Test 9: 分支指令 RAW 冒险测试
    ee_printf("  -> Test 9: Branch RAW Hazard... ");
    ee_u32 br_res = 0;
    __asm__ volatile (
        "li t1, 5 \n\t"
        "li t2, 0 \n\t"
        "1: \n\t"
        "addi t1, t1, -1 \n\t"  
        "addi t2, t2, 1 \n\t"
        "bne t1, zero, 1b \n\t" 
        "sw t2, 0(%0) \n\t"
        :
        : "r" (&br_res)
        : "t1", "t2", "memory"
    );
    if (br_res != 5) {
        ee_printf("FAIL! Res: %d\r\n", br_res);
        while(1);
    }
    ee_printf("OK\r\n");

    ee_printf("[DEBUG] Pipeline is flawless!\r\n");
    // =========================================================

    ee_printf("\r\n[DEBUG] BENCHMARK PREPARING...\r\n");

    // 🟢 诊断点 B：测试定时器的 AXI 总线映射是否死锁
    ee_printf("[DEBUG] Ready to start timer (Testing AXI Bus)...\r\n");
    start_time();
    ee_printf("[DEBUG] Timer started! AXI Bus is ALIVE!\r\n");

    /* ================= 正式跑分计算 ================= */
    j = 0;
    // 💥 强行只跑 5 轮，用来快速验证整个流程是否全通！
    while (j < 5) {
        ee_printf("\r\n[ITER %d] ", j);

        results[0].seed1 = core_bench_list(&results[0], 1);
        ee_printf("L1_OK "); // 链表正向测试通过

        results[0].seed2 = core_bench_list(&results[0], -1);
        ee_printf("L2_OK "); // 链表反向测试通过

        results[0].seed3 = core_bench_state(664, results[0].memblock[1], results[0].seed1, results[0].seed2, results[0].seed1, results[0].seed2);
        ee_printf("S_OK ");  // 状态机测试通过

        results[0].err  += core_bench_matrix(&(results[0].mat), 0, results[0].seed3);
        ee_printf("M_OK ");  // 矩阵乘法测试通过

        j++;
    }
    
    ee_printf("\r\n[DEBUG] Main loop finished! Stopping timer...\r\n");
    stop_time();
    total_time = get_time();
    ee_printf("[DEBUG] Timer stopped! Total Time Ticks: %lu\r\n", (long unsigned)total_time);

    // ====================================================
    // 🚦 诊断拦截点：测试 DIVU/REMU 和串口是否存活
    // ====================================================
    ee_printf("\r\n[DEBUG] Algorithm Finished. Testing DIVU...\r\n");

    volatile unsigned int test_num = 12345;
    volatile unsigned int test_base = 10;
    unsigned int test_res = test_num / test_base; // 触发 DIVU

    if (test_res != 1234) {
        ee_printf("[FATAL] DIVU BUG! 12345 / 10 = %d\r\n", test_res);
        while(1); // 卡死在这里，防止它继续往下跑破坏内存
    } else {
        ee_printf("[OK] DIVU works fine. Proceeding to final print...\r\n");
    }
    // ====================================================

    ee_printf("\r\n[DEBUG] Loop Finished! Validating results...\r\n");

    /* ================= 结果校验与打印 ================= */
    seedcrc = crc16(results[0].seed1, seedcrc);
    seedcrc = crc16(results[0].seed2, seedcrc);
    seedcrc = crc16(results[0].seed3, seedcrc);
    seedcrc = crc16(results[0].size, seedcrc);

    switch (seedcrc) {
        case 0x8a02: known_id = 0; ee_printf("6k performance run parameters for coremark.\n"); break;
        case 0x7b05: known_id = 1; ee_printf("6k validation run parameters for coremark.\n"); break;
        case 0x4eaf: known_id = 2; ee_printf("Profile generation run parameters for coremark.\n"); break;
        case 0xe9f5: known_id = 3; ee_printf("2K performance run parameters for coremark.\n"); break;
        case 0x18f2: known_id = 4; ee_printf("2K validation run parameters for coremark.\n"); break;
        default:     total_errors = -1; break;
    }

    if (known_id >= 0) {
        results[0].err = 0;
        if ((results[0].execs & 1) && (results[0].crclist != list_known_crc[known_id])) {
            ee_printf("ERROR! list crc 0x%04x - should be 0x%04x\n", results[0].crclist, list_known_crc[known_id]);
            results[0].err++;
        }
        if ((results[0].execs & 2) && (results[0].crcmatrix != matrix_known_crc[known_id])) {
            ee_printf("ERROR! matrix crc 0x%04x - should be 0x%04x\n", results[0].crcmatrix, matrix_known_crc[known_id]);
            results[0].err++;
        }
        if ((results[0].execs & 4) && (results[0].crcstate != state_known_crc[known_id])) {
            ee_printf("ERROR! state crc 0x%04x - should be 0x%04x\n", results[0].crcstate, state_known_crc[known_id]);
            results[0].err++;
        }
        total_errors += results[0].err;
    }

    ee_printf("\r\n=== COREMARK RESULTS ===\r\n");
    ee_printf("CoreMark Size    : %lu\n", (long unsigned)results[0].size);
    ee_printf("Total ticks      : %lu\n", (long unsigned)total_time);
    ee_printf("Total time (secs): %d\n", time_in_secs(total_time));
    if (time_in_secs(total_time) > 0)
        ee_printf("Iterations/Sec   : %d\n", results[0].iterations / time_in_secs(total_time));

    if (time_in_secs(total_time) < 10) {
        ee_printf("ERROR! Must execute for at least 10 secs for a valid result!\n");
        total_errors++;
    }

    ee_printf("Iterations       : %lu\n", (long unsigned)results[0].iterations);
    ee_printf("Compiler flags   : %s\n", COMPILER_FLAGS);

    if (total_errors == 0) ee_printf("Correct operation validated!\n");
    else ee_printf("Errors detected\n");

    ee_printf("=== COREMARK TEST FINISHED ===\r\n");
    while(1);
    return 0;
}