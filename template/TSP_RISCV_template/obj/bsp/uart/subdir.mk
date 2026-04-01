################################################################################
# MRS Version: 1.9.2
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../bsp/uart/bsp_uart.c 

O_SRCS += \
../bsp/uart/bsp_uart.o 

OBJS += \
./bsp/uart/bsp_uart.o 

C_DEPS += \
./bsp/uart/bsp_uart.d 


# Each subdirectory must supply rules for building sources it contributes
bsp/uart/%.o: ../bsp/uart/%.c
	@	@	riscv-none-embed-gcc -march=rv32im -mabi=ilp32 -msmall-data-limit=8 -mstrict-align -mno-save-restore -O3 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -Wunused -Wuninitialized  -g -DITERATIONS=2000 -std=gnu99 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -c -o "$@" "$<"
	@	@

