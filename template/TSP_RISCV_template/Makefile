# ====================================================================
# RISC-V Bare-Metal Makefile for CoreMark (Strict RV32IM)
# ====================================================================

# 1. 配置你的工具链前缀
# Windows xPack 用户通常是 riscv-none-elf-
# Linux APT 用户通常是 riscv64-unknown-elf-
CROSS_COMPILE ?= riscv-none-elf-

CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

# 2. 核心架构参数：绝对纯净的 RV32IM，没有任何 C 扩展！
# ilp32 表示 32位整形指针软浮点 ABI
# 强制编译器生成严格对齐的内存访问指令，保护我们的 LSU！
ARCH_FLAGS = -march=rv32im -mabi=ilp32 -mstrict-align

# 3. 编译选项：优化等级 O2，独立段以便链接器回收垃圾代码，增加 CoreMark 必需的宏定义
CFLAGS = $(ARCH_FLAGS) -O2 -g -Wall -mcmodel=medany \
         -ffunction-sections -fdata-sections \
         -DITERATIONS=10 -DCOMPILER_FLAGS=\"GCC_RV32IM\" \
         -I./app/coremark -I./bsp/timer -I./bsp/uart -I./bsp

# 4. 链接选项：使用你自己的 linker.lds，不使用系统启动代码，开启垃圾回收
LDFLAGS = $(ARCH_FLAGS) -T linker.lds -nostartfiles -Wl,--gc-sections \
          -Wl,-Map=coremark.map

# 5. 源文件清单
# 注意：跑 CoreMark 时，必须排除你之前的 src/main.c，因为 core_main.c 里已经有 main 函数了！
C_SRCS = \
    app/coremark/core_list_join.c \
    app/coremark/core_main.c \
    app/coremark/core_matrix.c \
    app/coremark/core_portme.c \
    app/coremark/core_state.c \
    app/coremark/core_util.c \
    app/coremark/cvt.c \
    app/coremark/ee_printf.c \
    bsp/timer/bsp_timer.c \
    bsp/uart/bsp_uart.c \
    bsp/syscalls.c

# 启动汇编文件
ASM_SRCS = lib/startup/startup.S

# 将 .c 和 .S 替换为 .o 目标文件
OBJS = $(C_SRCS:.c=.o) $(ASM_SRCS:.S=.o)

# 输出目标名
TARGET = coremark

# ====================================================================
# 编译规则
# ====================================================================

all: $(TARGET).elf $(TARGET).bin $(TARGET).dump

$(TARGET).elf: $(OBJS)
	@echo "Linking $@"
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.c
	@echo "Compiling $<"
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	@echo "Assembling $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).bin: $(TARGET).elf
	@echo "Generating Binary $@"
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	@echo "Generating Disassembly $@"
	$(OBJDUMP) -D $< > $@

clean:
	del /S /Q *.o
	del /Q $(TARGET).elf $(TARGET).bin $(TARGET).dump coremark.map

.PHONY: all clean