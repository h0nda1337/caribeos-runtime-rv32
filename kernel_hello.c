/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#define UART_BASE 0x10000000u
#define THR (*(volatile uint8_t*)(UART_BASE+0))
#define LSR (*(volatile uint8_t*)(UART_BASE+5))
#define THRE 0x20
static void putc(char c){ while((LSR&THRE)==0){} THR=(uint8_t)c; }
static void puts(const char*s){ while(*s) putc(*s++); }
void _start(void){ puts("\r\n[Kernel demo] Hola desde kernel.elf (RV32)\r\n"); for(;;){} }
