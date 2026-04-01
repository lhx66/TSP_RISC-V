################################################################################
# MRS Version: 1.9.2
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../app/coremark/core_list_join.c \
../app/coremark/core_main.c \
../app/coremark/core_matrix.c \
../app/coremark/core_portme.c \
../app/coremark/core_state.c \
../app/coremark/core_util.c \
../app/coremark/cvt.c \
../app/coremark/ee_printf.c 

O_SRCS += \
../app/coremark/core_list_join.o \
../app/coremark/core_main.o \
../app/coremark/core_matrix.o \
../app/coremark/core_portme.o \
../app/coremark/core_state.o \
../app/coremark/core_util.o \
../app/coremark/cvt.o \
../app/coremark/ee_printf.o 

OBJS += \
./app/coremark/core_list_join.o \
./app/coremark/core_main.o \
./app/coremark/core_matrix.o \
./app/coremark/core_portme.o \
./app/coremark/core_state.o \
./app/coremark/core_util.o \
./app/coremark/cvt.o \
./app/coremark/ee_printf.o 

C_DEPS += \
./app/coremark/core_list_join.d \
./app/coremark/core_main.d \
./app/coremark/core_matrix.d \
./app/coremark/core_portme.d \
./app/coremark/core_state.d \
./app/coremark/core_util.d \
./app/coremark/cvt.d \
./app/coremark/ee_printf.d 


# Each subdirectory must supply rules for building sources it contributes
app/coremark/%.o: ../app/coremark/%.c
	@	@	riscv-none-embed-gcc -march=rv32im -mabi=ilp32 -msmall-data-limit=8 -mstrict-align -mno-save-restore -O3 -fmessage-length=0 -fsigned-char -ffunction-sections -fdata-sections -Wunused -Wuninitialized  -g -DITERATIONS=2000 -std=gnu99 -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -c -o "$@" "$<"
	@	@

