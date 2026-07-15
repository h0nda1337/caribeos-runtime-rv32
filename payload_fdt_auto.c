#include <stdint.h>

#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){ while((UART_LSR & LSR_THRE)==0){} UART_THR=(uint8_t)c; }
static void puts(const char* s){ while(*s) putc(*s++); }
static void puthex32(uint32_t v){ const char* D="0123456789abcdef"; for(int i=7;i>=0;i--) putc(D[(v>>(i*4))&0xF]); }

static inline uint32_t be32(uint32_t x){
  return ((x&0xFFu)<<24)|((x&0xFF00u)<<8)|((x&0xFF0000u)>>8)|((x>>24)&0xFFu);
}

typedef struct {
  uint32_t magic, totalsize, off_dt_struct, off_dt_strings, off_mem_rsvmap;
  uint32_t version, last_comp_version, boot_cpuid_phys, size_dt_strings, size_dt_struct;
} fdt_hdr_t;

#define FDT_MAGIC 0xd00dfeedu
#define FDT_BEGIN 1u
#define FDT_END   2u
#define FDT_PROP  3u
#define FDT_NOP   4u
#define FDT_DONE  9u

static inline uint32_t read_a1(void){ uint32_t v; __asm__ volatile("mv %0, a1":"=r"(v)); return v; }

static int s_eq(const char* a, const char* b){ int i=0; for(;a[i]&&b[i];i++) if(a[i]!=b[i]) return 0; return a[i]==0 && b[i]==0; }

void _start(void){
  uint32_t dtb = read_a1();

  puts("\r\n[FDT-AUTO] a1="); puthex32(dtb); puts("\r\n");

  /* Por seguridad: NO toques nada fuera de RAM QEMU (0x8000_0000..0x8FFF_FFFF) */
  if (dtb < 0x80000000u || dtb >= 0x90000000u){
    puts("[FDT-AUTO] a1 fuera de rango esperado; abort.\r\n");
    for(;;){}
  }

  fdt_hdr_t* h = (fdt_hdr_t*)(uintptr_t)dtb;

  /* Estas lecturas asumen que el booter mapeó el DTB correctamente.
     Si no, habrá fault: por eso preferimos a1 y no probamos 'candidatos'. */
  if (be32(h->magic) != FDT_MAGIC){
    puts("[FDT-AUTO] MAGIC invalido en "); puthex32(dtb); puts(" (no se usa fallback)\r\n");
    for(;;){}
  }

  uint8_t* p = (uint8_t*)(uintptr_t)dtb + be32(h->off_dt_struct);
  uint8_t* strings = (uint8_t*)(uintptr_t)dtb + be32(h->off_dt_strings);

  puts("[FDT-AUTO] totalsize="); puthex32(be32(h->totalsize));
  puts(" off_struct="); puthex32(be32(h->off_dt_struct));
  puts(" off_strings="); puthex32(be32(h->off_dt_strings)); puts("\r\n");

  /* Recorre hasta /chosen y muestra bootargs si existe */
  int depth=0;
  char path[256]; int plen=0; path[0]=0;

  for(;;){
    uint32_t tok = be32(*(uint32_t*)p); p+=4;

    if(tok==FDT_BEGIN){
      char* name=(char*)p;
      while(*p) p++; p++; while(((uintptr_t)p)&3) p++;

      if(depth==0){ path[0]='/'; path[1]=0; plen=1; }
      else{
        if(!(plen==1 && path[0]=='/')) path[plen++]='/';
        for(int i=0; name[i] && plen<255; i++) path[plen++]=name[i];
        path[plen]=0;
      }
      depth++;

    }else if(tok==FDT_END){
      if(depth>0){
        if(depth==1){ path[0]=0; plen=0; }
        else{
          while(plen>0 && path[plen-1]!='/') plen--;
          if(plen>1) plen--;
          path[plen]=0;
        }
        depth--;
      }else break;

    }else if(tok==FDT_PROP){
      uint32_t be_len=*(uint32_t*)p; p+=4;
      uint32_t be_no =*(uint32_t*)p; p+=4;
      uint32_t len=be32(be_len), nameoff=be32(be_no);
      char* pname=(char*)(strings+nameoff);

      if (s_eq(path,"/chosen") && s_eq(pname,"bootargs")){
        puts("bootargs=\"");
        for(uint32_t i=0;i<len;i++){
          char c=((char*)p)[i];
          if(c==0) break;
          putc(c);
        }
        puts("\"\r\n");
      }
      p += ((len+3u)&~3u);

    }else if(tok==FDT_NOP){
      /* no-op */
    }else if(tok==FDT_DONE){
      break;
    }else{
      puts("[FDT-AUTO] token desconocido: 0x"); puthex32(tok); puts("\r\n");
      break;
    }
  }

  for(;;){}
}
