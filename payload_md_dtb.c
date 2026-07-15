#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static void puthex8(unsigned v){ const char* D="0123456789abcdef"; putc(D[(v>>4)&0xF]); putc(D[v&0xF]); }
static void puthex32(unsigned v){ const char* D="0123456789abcdef"; for(int i=7;i>=0;i--) putc(D[(v>>(i*4))&0xF]); }

typedef struct {
  uint32_t magic, totalsize, off_dt_struct, off_dt_strings, off_mem_rsvmap;
  uint32_t version, last_comp_version, boot_cpuid_phys, size_dt_strings, size_dt_struct;
} fdt_hdr_t;

static uint32_t bswap32(uint32_t x){
  return ((x&0xFFu)<<24)|((x&0xFF00u)<<8)|((x&0xFF0000u)>>8)|((x>>24)&0xFFu);
}
static uint32_t be32(uint32_t x){ return bswap32(x); }

#ifndef DTB_ADDR
#define DTB_ADDR 0x8fe00000u
#endif

static void hexdump(const void* vp, unsigned addr, unsigned len){
  const unsigned char* p = (const unsigned char*)vp;
  for(unsigned i=0;i<len;i+=16){
    puts("  "); puthex32(addr+i); puts(": ");
    for(unsigned j=0;j<16 && i+j<len;j++){ puthex8(p[i+j]); putc(' '); }
    puts("\r\n");
  }
}

void _start(void){
  volatile unsigned char* base = (volatile unsigned char*)(uintptr_t)DTB_ADDR;
  fdt_hdr_t* h=(fdt_hdr_t*)base;

  puts("\r\n[MD] DTB @ "); puthex32(DTB_ADDR); puts("\r\n");
  hexdump((const void*)base,            DTB_ADDR,     64); // header
  unsigned offS = be32(h->off_dt_struct);
  unsigned offT = be32(h->off_dt_strings);
  unsigned szS  = be32(h->size_dt_struct);
  unsigned szT  = be32(h->size_dt_strings);

  puts("off_struct="); puthex32(offS); puts(" size_struct="); puthex32(szS); puts("\r\n");
  puts("off_strings="); puthex32(offT); puts(" size_strings="); puthex32(szT); puts("\r\n");

  // dump inicial del bloque struct (primeros 256 bytes o menos)
  unsigned dump_len = szS < 256 ? szS : 256;
  hexdump((const void*)((uintptr_t)base+offS), DTB_ADDR+offS, dump_len);

  for(;;){}
}
