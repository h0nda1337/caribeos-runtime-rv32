#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static void puthex32(uint32_t v){ const char* D="0123456789abcdef"; for(int i=7;i>=0;i--) putc(D[(v>>(i*4))&0xF]); }

static int s_eq(const char* a, const char* b){ int i=0; for(;a[i]&&b[i];i++) if(a[i]!=b[i]) return 0; return a[i]==0 && b[i]==0; }
static int s_len(const char* a){ int n=0; while(a[n]) n++; return n; }

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

  char path[256]; int depth=0; int plen=0;
  path[0]=0;

  int seen_chosen = 0;
  int seen_bootargs = 0;

  for(;;){
    uint32_t tok = be32(*(uint32_t*)p); p+=4;

    if(tok==FDT_BEGIN){
      char* name=(char*)p;
      while(*p) p++; p++; while(((uintptr_t)p)&3) p++;

      /* actualizar path sin duplicar '/' */
      if(depth==0){
        /* root */
        path[0]='/'; path[1]=0; plen=1;
      }else{
        if(!(plen==1 && path[0]=='/')) path[plen++]='/';
        for(int i=0; name[i] && plen<255; i++) path[plen++]=name[i];
        path[plen]=0;
      }

      depth++;
      puts("[NODE] "); puts(path); puts("\r\n");

      /* chosen es hijo directo de root: depth previo era 1, ahora ya es 2.
         Miramos con el nombre y depth-1 == 1 => hijo de root */
      if(depth==2 && s_eq(name,"chosen")) seen_chosen = 1;

    }else if(tok==FDT_END){
      if(depth>0){
        if(depth==1){
          /* cerrando root */
          path[0]=0; plen=0;
        }else{
          /* recortar al padre */
          while(plen>0 && path[plen-1]!='/') plen--;
          if(plen>1) plen--; /* quitar '/' salvo si padre es root */
          path[plen]=0;
        }
        depth--;
      }else{
        break;
      }

    }else if(tok==FDT_PROP){
      uint32_t be_len=*(uint32_t*)p; p+=4;
      uint32_t be_no =*(uint32_t*)p; p+=4;
      uint32_t len=be32(be_len), nameoff=be32(be_no);
      char* pname=(char*)(strings+nameoff);

      puts("  - "); puts(pname); puts(" [len="); puthex32(len); puts("]\r\n");

      /* estamos exactamente dentro de /chosen ? */
      if (s_eq(path,"/chosen") && s_eq(pname,"bootargs")){
        seen_bootargs = 1;
        /* imprimir bootargs como string (hasta len) */
        puts("    bootargs=\"");
        for(uint32_t i=0;i<len;i++){
          char c=((char*)p)[i];
          if(c==0) break;
          putc(c);
        }
        puts("\"\r\n");
      }

      p += ((len+3u)&~3u);

    }else if(tok==FDT_NOP){
      /* nada */

    }else if(tok==FDT_DONE){
      break;

    }else{
      puts("[FDT] token desconocido=0x"); puthex32(tok); puts("\r\n");
      break;
    }
  }

  puts("\r\nResumen: /chosen="); puts(seen_chosen?"si":"no");
  puts("  bootargs="); puts(seen_bootargs?"si":"no"); puts("\r\n");

  for(;;){}
}
