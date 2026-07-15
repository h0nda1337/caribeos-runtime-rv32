#include <stdint.h>
#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20
static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static long sbi(long eid,long fid,long a0,long a1){
  register long A0 __asm__("a0")=a0, A1 __asm__("a1")=a1, F __asm__("a6")=fid, E __asm__("a7")=eid;
  __asm__ volatile("ecall":"+r"(A0),"+r"(A1):"r"(F),"r"(E):"memory"); return A0;
}
void _start(void){
  puts("\r\n[ELF] Hola + SRST (reboot)!\r\n");
  sbi(0x53525354l, 0, 1, 0); /* EID='SRST', FID=0, type=1=cold reboot */
  for(;;){}
}
