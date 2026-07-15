/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>

#define UART ((volatile uint8_t*)0x10000000u)
static void putc(char c){ *UART = (uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }

static void puthex32(uint32_t v){
  static const char* H="0123456789ABCDEF";
  for(int i=7;i>=0;--i) putc(H[(v>>(i*4))&0xF]);
}

static uint32_t bswap32(uint32_t x){
  return (x>>24) | ((x>>8)&0xFF00) | ((x<<8)&0xFF0000) | (x<<24);
}

/* Firma tipo OS: el booter ya pone a0=hart, a1=dtb y salta con jalr */
void entry(uintptr_t hart, uintptr_t dtb){
  puts("entry C; hart="); puthex32((uint32_t)hart);
  puts(" dtb="); puthex32((uint32_t)dtb); puts("\r\n");

  /* Comprobar cabecera FDT: 0xD00DFEED (big-endian en memoria) */
  uint32_t magic = *(volatile uint32_t*)dtb;
  if (bswap32(magic) == 0xD00DFEED) puts("DTB OK\r\n");
  else                               puts("DTB BAD\r\n");

  /* Haz lo que quieras aquí… */

  /* Y regresamos al booter para ver "retorno de entry()" */
}
