# ==========================================
# RISC-V Dhrystone Makefile
# ==========================================

# 工具链配置
CROSS_COMPILE ?= riscv-none-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# 架构参数
ARCH_FLAGS = -march=rv32im -mabi=ilp32

# 编译选项
CFLAGS = $(ARCH_FLAGS) -O1 -g -Wall \
         -ffunction-sections -fdata-sections \
         -fno-builtin -fno-common \
         -mstrict-align \
         -fno-align-functions \
         -fno-align-labels \
         -fno-align-loops \
         -mno-relax \
         -finline-functions \
         -finline-small-functions \
         -DTIME -DNOENUM -DWITH_MAIN \
         -DDHRY_ITERS=100000 \
         -I.

# 链接选项
LDFLAGS = $(ARCH_FLAGS) -T ../../linker.lds -nostartfiles \
          -Wl,--gc-sections

# 源文件
DHRY_SRC = dhry_1.c dhry_2.c dhrystone_portme.c dhrystone_io.c
BSP_SRC = ../../bsp/timer/bsp_timer.c \
         ../../bsp/uart/bsp_uart.c \
         ../../bsp/syscalls.c \
         ../../lib/startup/startup.S

# 目标文件
DHRY_OBJ = $(DHRY_SRC:.c=.o)
DHRY_OBJ := $(DHRY_OBJ:.S=.o)
BSP_OBJ = $(BSP_SRC:.c=.o)
BSP_OBJ := $(BSP_OBJ:.S=.o)
# 不转换BSP路径，使用明确规则编译
OBJS = $(DHRY_OBJ) $(BSP_OBJ)

TARGET = dhrystone

.PHONY: all clean run convert

# 编译规则
%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# BSP文件编译规则（保持原路径）
../../bsp/timer/bsp_timer.o: ../../bsp/timer/bsp_timer.c
	$(CC) $(CFLAGS) -c $< -o $@

../../bsp/uart/bsp_uart.o: ../../bsp/uart/bsp_uart.c
	$(CC) $(CFLAGS) -c $< -o $@

../../bsp/syscalls.o: ../../bsp/syscalls.c
	$(CC) $(CFLAGS) -c $< -o $@

../../lib/startup/startup.o: ../../lib/startup/startup.S
	$(CC) $(CFLAGS) -c $< -o $@

all: $(TARGET).elf $(TARGET).bin

$(TARGET).elf: $(OBJS)
	@echo "Linking $@"
	$(CC) $(LDFLAGS) -o $@ $(OBJS)
	@echo "Dhrystone binary created successfully!"

$(TARGET).bin: $(TARGET).elf
	@echo "Generating binary $@"
	$(OBJCOPY) -O binary $< $@

convert: $(TARGET).bin
	@echo "Converting to FPGA format..."
	@if [ -f ../../../tools/bin2txt.py ]; then \
		cd ../../../tools && python bin2txt.py && echo "Conversion complete!"; \
	else \
		echo "Note: bin2txt.py not found, manual conversion required"; \
	fi

clean:
	rm -f *.o *.elf *.bin *.dump $(TARGET)
	$(MAKE) -C dhrystone-riscv-master clean

run: all
	@echo "================================================"
	@echo "Dhrystone for RISC-V RV32IM"
	@echo "================================================"
	@echo ""
	@echo "Instructions:"
	@echo "1. Synthesize bitstream with $(TARGET).bin"
	@echo "2. Download to FPGA"
	@echo "3. Check UART for Dhrystone score"
	@echo ""
