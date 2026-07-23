#include "coremark.h"

#include "bsp_uart.h"

enum CORE_STATE core_state_transition(ee_u8 **instr, ee_u32 *transition_count);

static volatile ee_u8 int_token[6] __attribute__((aligned(4)));
static volatile ee_u8 float_token[10] __attribute__((aligned(4)));
static volatile ee_u8 sci_token[10] __attribute__((aligned(4)));
static volatile ee_u8 bad_token[10] __attribute__((aligned(4)));

static void init_tokens(void)
{
    int_token[0] = '5'; int_token[1] = '0'; int_token[2] = '1';
    int_token[3] = '2'; int_token[4] = ','; int_token[5] = 0;

    float_token[0] = '3'; float_token[1] = '5'; float_token[2] = '.';
    float_token[3] = '5'; float_token[4] = '4'; float_token[5] = '4';
    float_token[6] = '0'; float_token[7] = '0'; float_token[8] = ',';
    float_token[9] = 0;

    sci_token[0] = '5'; sci_token[1] = '.'; sci_token[2] = '5';
    sci_token[3] = '0'; sci_token[4] = '0'; sci_token[5] = 'e';
    sci_token[6] = '+'; sci_token[7] = '3'; sci_token[8] = ',';
    sci_token[9] = 0;

    bad_token[0] = 'T'; bad_token[1] = '0'; bad_token[2] = '.';
    bad_token[3] = '3'; bad_token[4] = 'e'; bad_token[5] = '-';
    bad_token[6] = '1'; bad_token[7] = 'F'; bad_token[8] = ',';
    bad_token[9] = 0;
}

static int check_token(ee_u8 *token, enum CORE_STATE expected_state,
                       ee_u32 expected_start, ee_u32 expected_int,
                       ee_u32 expected_float, ee_u32 expected_s2,
                       ee_u32 expected_exp, ee_u32 expected_invalid)
{
    ee_u8 *cursor = token;
    ee_u32 count[NUM_CORE_STATES] = {0};
    enum CORE_STATE result = core_state_transition(&cursor, count);

    return result != expected_state ||
           count[CORE_START] != expected_start ||
           count[CORE_INT] != expected_int ||
           count[CORE_FLOAT] != expected_float ||
           count[CORE_S2] != expected_s2 ||
           count[CORE_EXPONENT] != expected_exp ||
           count[CORE_INVALID] != expected_invalid;
}

int main(void)
{
    ee_u32 i;
    int failed = 0;

    init_tokens();
    for (i = 0; i < 16; i++) {
        if (check_token((ee_u8 *)int_token, CORE_INT, 1, 0, 0, 0, 0, 0))
            failed |= 1;
        if (check_token((ee_u8 *)float_token, CORE_FLOAT, 1, 1, 0, 0, 0, 0))
            failed |= 2;
        if (check_token((ee_u8 *)sci_token, CORE_SCIENTIFIC, 1, 1, 1, 1, 1, 0))
            failed |= 4;
        if (check_token((ee_u8 *)bad_token, CORE_INVALID, 1, 0, 0, 0, 0, 1))
            failed |= 8;
    }

    uart_putc(failed ? ('0' + failed) : 'P');
    uart_putc('\n');
    for (;;) { }
}
