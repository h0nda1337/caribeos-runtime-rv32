/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static void puthex32(unsigned long v){
  const char* D="0123456789abcdef"; for(int i=7;i>=0;i--) putc(D[(v>>(i*4))&0xF]);
}

struct sret { long err; long val; };
static struct sret sbi2(long eid,long fid,long a0,long a1){
  register long A0 __asm__("a0")=a0;
  register long A1 __asm__("a1")=a1;
  register long F  __asm__("a6")=fid;
  register long E  __asm__("a7")=eid;
  __asm__ volatile("ecall":"+r"(A0),"+r"(A1):"r"(F),"r"(E):"memory");
  struct sret r={A0,A1}; return r;
}

void _start(void){
  puts("\r\n[SBI-INFO]\r\n");
  // EID Base = 0x10 (SBI v2)
  struct sret v  = sbi2(0x10, 0, 0, 0); // spec version
  struct sret id = sbi2(0x10, 1, 0, 0); // impl id
  struct sret iv = sbi2(0x10, 2, 0, 0); // impl version
  struct sret mv = sbi2(0x10, 4, 0, 0); // mvendorid
  struct sret ma = sbi2(0x10, 5, 0, 0); // marchid
  struct sret mi = sbi2(0x10, 6, 0, 0); // mimpid

  puts("spec      = 0x"); puthex32((unsigned long)v.val);  puts(" err=0x"); puthex32((unsigned long)v.err);  puts("\r\n");
  puts("impl_id   = 0x"); puthex32((unsigned long)id.val); puts(" err=0x"); puthex32((unsigned long)id.err); puts("\r\n");
  puts("impl_ver  = 0x"); puthex32((unsigned long)iv.val); puts(" err=0x"); puthex32((unsigned long)iv.err); puts("\r\n");
  puts("mvendorid = 0x"); puthex32((unsigned long)mv.val); puts(" err=0x"); puthex32((unsigned long)mv.err); puts("\r\n");
  puts("marchid   = 0x"); puthex32((unsigned long)ma.val); puts(" err=0x"); puthex32((unsigned long)ma.err); puts("\r\n");
  puts("mimpid    = 0x"); puthex32((unsigned long)mi.val); puts(" err=0x"); puthex32((unsigned long)mi.err); puts("\r\n");

  // ¿está SRST?
  struct sret sr = sbi2(0x10, 3, 0x53525354l, 0); // probe_extension('SRST')
  puts("probe SRST= 0x"); puthex32((unsigned long)sr.val); puts(" err=0x"); puthex32((unsigned long)sr.err); puts("\r\n");
  for(;;){}
}
