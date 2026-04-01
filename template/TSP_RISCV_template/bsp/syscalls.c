#include <stdio.h>
#include "./uart/bsp_uart.h" // 引入你的 uart_putc 函数

// ============================================================================
// 重定向 GCC 标准库底层写函数
// 当你调用 printf 时，标准库会自动把格式化好的字符串打包传给 ptr，长度传给 len
// ============================================================================
int _write(int file, char *ptr, int len) {
    int i;

    // file == 1 代表 stdout (标准输出), file == 2 代表 stderr (标准错误)
    if (file == 1 || file == 2) {
        for (i = 0; i < len; i++) {
            // 【经典填坑】：将 Linux 风格的换行符 \n 自动转换为 Windows/串口工具识别的 \r\n
            if (ptr[i] == '\n') {
                uart_putc('\r');
            }
            // 调用我们自己写的硬件 UART 发送单字符函数
            uart_putc(ptr[i]);
        }
        return len; // 必须返回成功写入的字节数
    }

    // 如果是写其他文件描述符，返回错误
    return -1;
}
