/*
// ==========================================
// RISC-V SoC 综合测试程序 (Bare-Metal)
// ==========================================

// 根据你的 AXI_Interconnect 分配，UART 基地址为 0x40000000
#define UART_TX_ADDR 0x40000000

// ---------------------------------------------------------
// 内存段验证用全局变量
// ---------------------------------------------------------
// 1. 存放在 .data 段 (初始值在 IRAM，运行在 SRAM)
int global_init_var = 2026;

// 2. 存放在 .bss 段 (无初始值，由 start.S 清零)
int global_bss_array[5];

// 3. 存放在 .rodata 段 (字符串常量，直接留在 IRAM 中读取)
const char* welcome_msg = "\r\n=== RISC-V SoC Complex Test Start ===\r\n";

// ---------------------------------------------------------
// 简易驱动与打印库 (替代 libc 的 printf)
// ---------------------------------------------------------
// 发送单个字符到 UART
void uart_putc(char c) {
    volatile unsigned int *uart = (volatile unsigned int *)UART_TX_ADDR;
    *uart = c; // 通过 AXI 总线触发 UART 写入

    // 简单的软件延时，防止连续快速发送导致 FPGA 串口内部 FIFO 溢出
    // (如果你的 UART IP 带 Busy 标志位，这里最好改成轮询 Busy 位)
    //for(volatile int i = 0; i < 2000; i++);
}

// 打印字符串
void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

// 打印整数 (这一步重度依赖你刚写的 Simple_Divider_32 模块！)
void uart_print_int(int num) {
    if (num == 0) {
        uart_putc('0');
        return;
    }
    if (num < 0) {
        uart_putc('-');
        num = -num;
    }
    char buf[12];
    int i = 0;
    while (num > 0) {
        buf[i++] = (num % 10) + '0'; // 测试 REM 汇编指令
        num /= 10;                   // 测试 DIV 汇编指令
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

// ---------------------------------------------------------
// 测试 1：矩阵乘法 (测试乘法器、多维数组多重访存)
// ---------------------------------------------------------
void test_matrix_mul() {
    uart_puts("Test 1: Matrix Multiplication (Testing MUL)...\r\n");
    
    int A[3][3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
    int B[3][3] = {{9, 8, 7}, {6, 5, 4}, {3, 2, 1}};
    int C[3][3] = {0};

    // 执行矩阵乘法
    for(int i = 0; i < 3; i++) {
        for(int j = 0; j < 3; j++) {
            for(int k = 0; k < 3; k++) {
                C[i][j] += A[i][k] * B[k][j]; // 测试 MUL 指令及连续 Load/Store
            }
        }
    }

    // 打印结果矩阵
    for(int i = 0; i < 3; i++) {
        uart_puts("  [ ");
        for(int j = 0; j < 3; j++) {
            uart_print_int(C[i][j]);
            uart_puts(" ");
        }
        uart_puts("]\r\n");
    }
}

// ---------------------------------------------------------
// 测试 2：寻找素数 (测试除法器的复杂状态机、分支跳转)
// ---------------------------------------------------------
void test_primes() {
    uart_puts("Test 2: Prime Numbers 2 to 50 (Testing DIV/REM)...\r\n  ");
    int count = 0;
    for (int n = 2; n <= 50; n++) {
        int is_prime = 1;
        for (int i = 2; i * i <= n; i++) { // 测试乘法
            if (n % i == 0) {              // 测试求模
                is_prime = 0;
                break;
            }
        }
        if (is_prime) {
            uart_print_int(n);
            uart_puts(" ");
            count++;
        }
    }
    uart_puts("\r\n  Total primes found: ");
    uart_print_int(count);
    uart_puts("\r\n");
}

// ---------------------------------------------------------
// 主函数
// ---------------------------------------------------------
int main() {
    // 1. 打印开机信息
    uart_puts(welcome_msg);

    // 2. 验证内存布局
    uart_puts("Checking memory init...\r\n");

    uart_puts("  global_init_var (Should be 2026): ");
    uart_print_int(global_init_var);
    uart_puts("\r\n");

    uart_puts("  global_bss_array[0] (Should be 0): ");
    uart_print_int(global_bss_array[0]);
    uart_puts("\r\n");

    // 修改 SRAM 中的变量验证其可写性
    global_init_var += 4;
    uart_puts("  global_init_var modified (Should be 2030): ");
    uart_print_int(global_init_var);
    uart_puts("\r\n\r\n");

    // 3. 运行算法测试
    test_matrix_mul();
    uart_puts("\r\n");

    test_primes();
    uart_puts("\r\n");

    // 4. 结束
    uart_puts("=== Test Finished! Halting CPU. ===\r\n");

    return 0; // 返回 start.S 将进入死循环挂起 CPU
}
*/
