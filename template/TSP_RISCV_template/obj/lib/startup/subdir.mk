################################################################################
# MRS Version: 1.9.2
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
S_UPPER_SRCS += \
../lib/startup/startup.S 

O_SRCS += \
../lib/startup/startup.o 

OBJS += \
./lib/startup/startup.o 

S_UPPER_DEPS += \
./lib/startup/startup.d 


# Each subdirectory must supply rules for building sources it contributes
lib/startup/%.o: ../lib/startup/%.S
	@	@	riscv-none-embed-gcc -march=rv32im -mabi=ilp32 -msmall-data-limit=8 -mstrict-align -mno-save-restore -O3 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -Wunused -Wuninitialized  -g -x assembler -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -c -o "$@" "$<"
	@	@

