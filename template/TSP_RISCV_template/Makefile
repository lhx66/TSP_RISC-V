# RISC-V bare-metal applications for the TSP RV32IM SoC.

CROSS_COMPILE ?= riscv-none-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

APP ?= coremark
TARGET = $(APP)
ARCH_FLAGS = -march=rv32im -mabi=ilp32
COREMARK_OPT_LEVEL ?= -O3
NONCORE_OPT_LEVEL ?= -O2
LAYOUT_FLAGS ?= -fno-align-functions -fno-align-labels -fno-align-loops
EXTRA_CFLAGS ?=
ifneq (,$(filter coremark state_machine state_bench,$(APP)))
OPT_LEVEL ?= $(COREMARK_OPT_LEVEL)
else
OPT_LEVEL ?= $(NONCORE_OPT_LEVEL)
endif
CFLAGS = $(ARCH_FLAGS) $(OPT_LEVEL) -g -Wall -ffunction-sections -fdata-sections \
         -fno-builtin -fno-common -mstrict-align $(LAYOUT_FLAGS) -mno-relax $(EXTRA_CFLAGS) \
         -I./bsp/timer -I./bsp/uart -I./bsp
LDFLAGS = $(ARCH_FLAGS) -T linker.lds -nostartfiles -Wl,--gc-sections \
          -Wl,-Map=$(TARGET).map

ifeq ($(APP),coremark)
COREMARK_ITERATIONS ?= 0
COREMARK_STATE_INIT_DIAG ?= 0
COREMARK_HEAP_ALIGN ?= 8
COREMARK_SIM_QUIET ?= 0
COREMARK_COMPILER_FLAGS ?= $(OPT_LEVEL)
CFLAGS += -DITERATIONS=$(COREMARK_ITERATIONS) -DCOREMARK_STATE_INIT_DIAG=$(COREMARK_STATE_INIT_DIAG) -DCOREMARK_HEAP_ALIGN=$(COREMARK_HEAP_ALIGN) -DCOREMARK_SIM_QUIET=$(COREMARK_SIM_QUIET) -DCOMPILER_FLAGS=\"$(COREMARK_COMPILER_FLAGS)\" -I./app/coremark
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
else ifeq ($(APP),mul_dependency)
CFLAGS += -I./app/mul_dependency
C_SRCS = app/mul_dependency/main.c bsp/uart/bsp_uart.c
else ifeq ($(APP),ls_dependency)
CFLAGS += -I./app/ls_dependency
C_SRCS = app/ls_dependency/main.c bsp/uart/bsp_uart.c
else ifeq ($(APP),unaligned_access)
CFLAGS += -I./app/unaligned_access
C_SRCS = app/unaligned_access/main.c bsp/uart/bsp_uart.c
else ifeq ($(APP),state_machine)
CFLAGS += -I./app/coremark -I./app/state_machine
C_SRCS = app/state_machine/main.c app/coremark/core_state.c bsp/uart/bsp_uart.c
else ifeq ($(APP),sram_walk)
CFLAGS += -I./app/sram_walk
C_SRCS = app/sram_walk/main.c bsp/uart/bsp_uart.c
else
$(error Unsupported APP '$(APP)'. Supported applications: coremark sim_smoke mul_dependency ls_dependency unaligned_access state_machine sram_walk)
endif

ASM_SRCS = lib/startup/startup.S
OBJS = $(C_SRCS:.c=.o) $(ASM_SRCS:.S=.o)

ifeq ($(APP),coremark)
BUILD_ARTIFACTS = $(TARGET).elf $(TARGET).dump
else
BUILD_ARTIFACTS = $(TARGET).elf $(TARGET).bin $(TARGET).dump
endif

all: $(BUILD_ARTIFACTS)

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
