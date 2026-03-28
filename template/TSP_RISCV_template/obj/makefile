################################################################################
# MRS Version: 1.9.2
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/subdir.mk
-include lib/startup/subdir.mk
-include app/coremark/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(ASM_UPPER_DEPS)),)
-include $(ASM_UPPER_DEPS)
endif
ifneq ($(strip $(ASM_DEPS)),)
-include $(ASM_DEPS)
endif
ifneq ($(strip $(S_DEPS)),)
-include $(S_DEPS)
endif
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 
SECONDARY_FLASH += \
TSP_RISCV_template.hexAndbin \

SECONDARY_LIST += \
TSP_RISCV_template.lst \

SECONDARY_SIZE += \
TSP_RISCV_template.siz \


# All Target
all: TSP_RISCV_template.elf secondary-outputs

# Tool invocations
TSP_RISCV_template.elf: $(OBJS) $(USER_OBJS)
	@	@	riscv-none-embed-gcc -march=rv32im -mabi=ilp32 -msmall-data-limit=8 -mno-save-restore -O0 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -Wunused -Wuninitialized  -g -T "E:\FPGA\TSP_RVmaster\template\TSP_RISCV_template\linker.lds" -nostartfiles -Xlinker --gc-sections -L"../" -Wl,-Map,"TSP_RISCV_template.map" --specs=nano.specs --specs=nosys.specs -o "TSP_RISCV_template.elf" $(OBJS) $(USER_OBJS) $(LIBS)
	@	@
TSP_RISCV_template.hexAndbin: TSP_RISCV_template.elf
	@	riscv-none-embed-objcopy -O ihex "TSP_RISCV_template.elf"  "TSP_RISCV_template.hex" && riscv-none-embed-objcopy -O binary "TSP_RISCV_template.elf"  "TSP_RISCV_template.bin"
	@	@
TSP_RISCV_template.lst: TSP_RISCV_template.elf
	@	riscv-none-embed-objdump --source --all-headers --demangle --line-numbers --wide "TSP_RISCV_template.elf" > "TSP_RISCV_template.lst"
	@	@
TSP_RISCV_template.siz: TSP_RISCV_template.elf
	@	riscv-none-embed-size --format=berkeley "TSP_RISCV_template.elf"
	@	@
	$(MAKE) --no-print-directory post-build

# Other Targets
clean:
	-$(RM) $(ASM_UPPER_DEPS)$(OBJS)$(SECONDARY_FLASH)$(SECONDARY_LIST)$(SECONDARY_SIZE)$(ASM_DEPS)$(S_DEPS)$(S_UPPER_DEPS)$(C_DEPS) TSP_RISCV_template.elf
	-@
post-build:
	-riscv-none-embed-objcopy -O ihex "TSP_RISCV_template.elf" "TSP_RISCV_template.hex" && riscv-none-embed-objcopy -O binary "TSP_RISCV_template.elf" "TSP_RISCV_template.bin"
	-@
secondary-outputs: $(SECONDARY_FLASH) $(SECONDARY_LIST) $(SECONDARY_SIZE)

.PHONY: all clean dependents post-build

-include ../makefile.targets
