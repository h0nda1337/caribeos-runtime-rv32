/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){
  while((UART_LSR & LSR_THRE) == 0) {}
  UART_THR = (uint8_t)c;
}
static void puts(const char* s){
  while(*s){ putc(*s++); }
}

static long sbi(long eid, long fid, long a0, long a1){
  register long a0r __asm__("a0") = a0;
  register long a1r __asm__("a1") = a1;
  register long a6r __asm__("a6") = fid;
  register long a7r __asm__("a7") = eid;
  __asm__ volatile("ecall" : "+r"(a0r), "+r"(a1r) : "r"(a6r), "r"(a7r) : "memory");
  return a0r;
}

void _start(void){
  puts("\r\n[ELF] Hola + SRST!\r\n");
  /* EID_SRST = 'SRST' (0x53525354), FID=0 => poweroff */
  sbi(0x53525354l, 0, 0, 0);
  for(;;){}
}
