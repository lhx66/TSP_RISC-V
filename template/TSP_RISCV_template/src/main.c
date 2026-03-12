#include <stdint.h>

#define UART_TX_REG (*(volatile uint32_t *)0x40000000)

// 汇编级延时函数
void delay(uint32_t loops) {
    __asm__ volatile (
        "1: \n"
        "addi %0, %0, -1 \n"
        "bnez %0, 1b \n"
        : "+r" (loops)
    );
}

// 手写取余 (x % 10)，彻底避开硬件除法器和库函数
uint32_t mod10(uint32_t val) {
    while (val >= 10) {
        val -= 10;
    }
    return val;
}

// 打印单个数字，测试 if-else
void print_digit(uint32_t d) {
    if (d <= 9) {
        UART_TX_REG = '0' + d;
    } else {
        UART_TX_REG = 'E'; // 理论上永远不会执行到这里，除非 ALU 算错
    }
}

int main(void) {
    uint32_t cycle = 0;
    
    while(1) {
        // 打印前缀 "CYC:" (纯寄存器操作，不查表)
        UART_TX_REG = 'C';
        UART_TX_REG = 'Y';
        UART_TX_REG = 'C';
        UART_TX_REG = ':';

        // 打印循环次数的个位数 (测试函数多层嵌套和栈指针 sp)
        print_digit(mod10(cycle));
        UART_TX_REG = ' ';
        UART_TX_REG = '[';

        // 打印动态加载进度条动画 (测试 FOR 循环与复杂 IF-ELSE)
        uint32_t len = cycle & 7; // 等价于 cycle % 8
        for (uint32_t i = 0; i <= 7; i++) {
            if (i < len) {
                UART_TX_REG = '='; // 已走过的进度
            } else if (i == len) {
                UART_TX_REG = 'O'; // 当前的球
            } else {
                UART_TX_REG = '-'; // 未走过的轨道
            }
        }

        // 打印后缀和回车
        UART_TX_REG = ']';
        UART_TX_REG = '\r';
        UART_TX_REG = '\n';

        cycle++;
        delay(2000000); // 控制动画播放速度
    }
    return 0;
}
