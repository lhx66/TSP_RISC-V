/*
 * Minimal stdio.h for Dhrystone
 */

#ifndef STDIO_H
#define STDIO_H

#include <stdarg.h>

// Printf declarations - implementations in dhrystone_portme.c
extern int printf(const char *format, ...);
extern int scanf(const char *format, ...);

#endif

