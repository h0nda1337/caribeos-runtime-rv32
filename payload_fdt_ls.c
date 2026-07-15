#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static void puthex32(uint32_t v){ const char* D="0123456789abcdef"; for(int i=7;i>=0;i--) putc(D[(v>>(i*4))&0xF]); }

typedef struct {
  uint32_t magic, totalsize, off_dt_struct, off_dt_strings, off_mem_rsvmap;
  uint32_t version, last_comp_version, boot_cpuid_phys, size_dt_strings, size_dt_struct;
} fdt_hdr_t;

static uint32_t bswap32(uint32_t x){
  return ((x&0xFFu)<<24)|((x&0xFF00u)<<8)|((x&0xFF0000u)>>8)|((x>>24)&0xFFu);
}
static uint32_t be32(uint32_t x){ return bswap32(x); }

#define FDT_MAGIC 0xd00dfeedu
#define FDT_BEGIN 1u
#define FDT_END   2u
#define FDT_PROP  3u
#define FDT_NOP   4u
#define FDT_DONE  9u

#ifndef DTB_ADDR
#define DTB_ADDR 0x8fe00000u
#endif

void _start(void){
  volatile uint8_t* base = (volatile uint8_t*)(uintptr_t)DTB_ADDR;
  fdt_hdr_t* h = (fdt_hdr_t*)base;
  if (be32(h->magic) != FDT_MAGIC){
    puts("\r\n[FDT] MAGIC invalido en "); puthex32(DTB_ADDR); puts("\r\n");
    for(;;){}
  }
  puts("\r\n[FDT] OK. totalsize="); puthex32(be32(h->totalsize));
  puts(" off_struct="); puthex32(be32(h->off_dt_struct));
  puts(" off_strings="); puthex32(be32(h->off_dt_strings)); puts("\r\n");

  uint8_t* p = (uint8_t*)base + be32(h->off_dt_struct);
  uint8_t* strings = (uint8_t*)base + be32(h->off_dt_strings);
  char path[256]; int depth=0; path[0] = 0;

  int have_chosen=0, have_bootargs=0;

  for(;;){
    uint32_t tok = be32(*(uint32_t*)p); p+=4;
    if(tok==FDT_BEGIN){
      char* name=(char*)p; // nombre del nodo
      // avanzar p al siguiente alineado
      while(*p) p++;
      p++; while(((uintptr_t)p)&3) p++;

      // actualizar path
      char* q=path; int n=0; while(*q) { q++; n++; }
      if(n==0){ // root
        path[0]='/'; path[1]=0;
      }else{
        if(n<255) path[n++]='/';
        int i=0; while(name[i] && n<255){ path[n++]=name[i++]; }
        path[n]=0;
      }
      depth++;
      puts("[NODE] "); puts(path); puts("\r\n");
      if (path[0]=='/' && path[1]=='c' && path[2]=='h' && path[3]=='o' && path[4]=='s' && path[5]=='e' && path[6]=='n' && (path[7]==0)) have_chosen=1;

    }else if(tok==FDT_END){
      // recortar path al padre
      if(depth>0){
        // quitar el ultimo "/name"
        int n=0; while(path[n]) n++;
        while(n>0 && path[n-1]!='/') n--;
        if(n>1) n--; // quitar la '/' final salvo root
        path[n]=0; if(n==0){ path[0]='/'; path[1]=0; }
      }
      if(--depth<0) break;

    }else if(tok==FDT_PROP){
      uint32_t be_len=*(uint32_t*)p; p+=4;
      uint32_t be_no =*(uint32_t*)p; p+=4;
      uint32_t len=be32(be_len), nameoff=be32(be_no);
      char* pname=(char*)(strings+nameoff);

      puts("  - "); puts(pname); puts(" [len="); puthex32(len); puts("]\r\n");
      if (have_chosen && path[0]=='/' && path[1]=='c' && path[2]=='h' && path[3]=='o' && path[4]=='s' && path[5]=='e' && path[6]=='n' && path[7]==0){
        // estamos dentro de /chosen
        const char* want="bootargs"; int i=0; while(want[i] && pname[i] && want[i]==pname[i]) i++;
        if(want[i]==0 && pname[i]==0) have_bootargs=1;
      }
      p += ((len+3u)&~3u);

    }else if(tok==FDT_NOP){
      // nada
    }else if(tok==FDT_DONE){
      break;
    }else{
      puts("[FDT] token desconocido=0x"); puthex32(tok); puts("\r\n");
      break;
    }
  }

  puts("\r\nResumen: /chosen="); puts(have_chosen?"si":"no");
  puts("  bootargs="); puts(have_bootargs?"si":"no"); puts("\r\n");

  for(;;){}
}
