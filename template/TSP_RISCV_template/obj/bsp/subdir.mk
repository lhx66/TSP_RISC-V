################################################################################
# MRS Version: 1.9.2
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../bsp/syscalls.c 

O_SRCS += \
../bsp/syscalls.o 

OBJS += \
./bsp/syscalls.o 

C_DEPS += \
./bsp/syscalls.d 


# Each subdirectory must supply rules for building sources it contributes
bsp/%.o: ../bsp/%.c
	@	@	riscv-none-embed-gcc -march=rv32im -mabi=ilp32 -msmall-data-limit=8 -mstrict-align -mno-save-restore -O3 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -Wunused -Wuninitialized  -g -DITERATIONS=2000 -std=gnu99 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -c -o "$@" "$<"
	@	@

