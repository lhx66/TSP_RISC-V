# RISC-V bare-metal applications for the TSP RV32IM SoC.

CROSS_COMPILE ?= riscv-none-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

APP ?= coremark
TARGET = $(APP)
ARCH_FLAGS = -march=rv32im -mabi=ilp32
CFLAGS = $(ARCH_FLAGS) -O2 -g -Wall -ffunction-sections -fdata-sections \
         -fno-builtin -fno-common -mstrict-align -fno-align-functions \
         -fno-align-labels -fno-align-loops -mno-relax \
         -I./bsp/timer -I./bsp/uart -I./bsp
LDFLAGS = $(ARCH_FLAGS) -T linker.lds -nostartfiles -Wl,--gc-sections \
          -Wl,-Map=$(TARGET).map

ifeq ($(APP),coremark)
CFLAGS += -DITERATIONS=1000 -DCOMPILER_FLAGS=\"GCC_RV32IM\" -I./app/coremark
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
else ifeq ($(APP),sim_smoke)
CFLAGS += -I./app/sim_smoke
C_SRCS = app/sim_smoke/main.c bsp/uart/bsp_uart.c
else
$(error Unsupported APP '$(APP)'. Supported applications: coremark sim_smoke)
endif

ASM_SRCS = lib/startup/startup.S
OBJS = $(C_SRCS:.c=.o) $(ASM_SRCS:.S=.o)

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
	-del /S /Q *.o
	-del /Q $(TARGET).elf $(TARGET).bin $(TARGET).dump $(TARGET).map

.PHONY: all clean
