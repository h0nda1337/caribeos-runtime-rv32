/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include <stddef.h>
static int bootx_handle_command(const char* s);
static int is_cmd_go_line(const char* s, const char** out_p);
#include "booter/sbi.h"

/* UART primitives (ya existen) */
void uart_puts(const char*);
void uart_putc(char);
void uart_putdec(uintptr_t);
void uart_puthex32(uint32_t);

/* tick period global (definido en trap.c) */
extern volatile uint32_t g_tick_every;

/* ===== Línea / edición ===== */
static char line[128];
static uint32_t len = 0;

/* Historial (ring buffer) */
#define HIST_N 8
static char hist[HIST_N][128];
static uint32_t hist_count = 0;
static uint32_t hist_widx  = 0;
static int32_t  hist_pos   = -1;

static uint32_t last_drawn_len = 0;

/* Estado ESC para flechas */
static uint8_t esc_state = 0;  /* 0=normal, 1=ESC, 2=ESC[ */

/* uart_base guardado localmente en la consola (sin símbolo global) */
static uint32_t s_uart_base_rt = 0;
void console_set_uart_base(uint32_t base){ s_uart_base_rt = base; }

/* Fallback para QEMU virt si aún no se ha seteado por booter.c */
#ifndef UART_MMIO_DEFAULT
#define UART_MMIO_DEFAULT 0x10000000u
#endif
static inline uint32_t uart_base_effective(void){
  return s_uart_base_rt ? s_uart_base_rt : UART_MMIO_DEFAULT;
}

/* ==== Utils ==== */
static void put_hex_nibble(uint8_t n){ n&=0xF; uart_putc((char)(n<10?('0'+n):('A'+(n-10)))); }
static void put_hex8(uint8_t b){ put_hex_nibble((uint8_t)(b>>4)); put_hex_nibble((uint8_t)(b&0xF)); }

static int streq(const char* a, const char* b){ while(*a&&*b){ if(*a++!=*b++) return 0; } return *a==0 && *b==0; }
static int starts_with(const char* s, const char* p){ while(*p){ if(*p++!=*s++) return 0; } return 1; }

/* decimal o 0xHEX */
static int parse_uint_auto(const char* s, uint32_t* out){
  uint32_t v=0; int any=0; while(*s==' '||*s=='\t') s++;
  if(s[0]=='0' && (s[1]=='x'||s[1]=='X')){ s+=2;
    while(1){ char c=*s; uint8_t d;
      if(c>='0'&&c<='9') d=(uint8_t)(c-'0');
      else if(c>='a'&&c<='f') d=(uint8_t)(c-'a'+10);
      else if(c>='A'&&c<='F') d=(uint8_t)(c-'A'+10);
      else break;
      v=(v<<4)|d; any=1; s++;
    }
  } else { while(*s>='0'&&*s<='9'){ v=v*10+(uint32_t)(*s-'0'); any=1; s++; } }
  if(!any) return 0; *out=v; return 1;
}

/* ==== Rango prohibido desde S-mode (virt/OpenSBI/ACLINT) ==== */
static int is_forbidden_addr(uint32_t a){
  /* OpenSBI firmware (virt): 0x80000000..0x8005FFFF (aprox) */
  if(a>=0x80000000u && a<0x80060000u) return 1;
  /* ACLINT/CLINT (virt): 0x02000000..0x0200FFFF */
  if(a>=0x02000000u && a<0x02010000u) return 1;
  return 0;
}

/* ==== Línea y prompt ==== */
static void prompt(void){ uart_puts("> "); }
static void redraw_line(void){
  uart_puts("\r"); prompt();
  for(uint32_t i=0;i<len;i++) uart_putc(line[i]);
  if(last_drawn_len>len){ uint32_t diff=last_drawn_len-len; for(uint32_t i=0;i<diff;i++) uart_putc(' '); }
  last_drawn_len=len;
}

/* ==== Historial ==== */
static void hist_store(const char* s){
  if(len==0) return;
  if(hist_count>0){
    uint32_t last=(hist_widx+HIST_N-1)%HIST_N;
    const char* a=s; const char* b=hist[last]; int same=1;
    while(*a||*b){ if(*a!=*b){ same=0; break; } if(*a) a++; if(*b) b++; }
    if(same) return;
  }
  uint32_t i=0; while(s[i] && i<sizeof(hist[0])-1){ hist[hist_widx][i]=s[i]; i++; }
  hist[hist_widx][i]=0; hist_widx=(hist_widx+1)%HIST_N; if(hist_count<HIST_N) hist_count++;
}
static void hist_recall_index(uint32_t idx){
  uint32_t base=(hist_count<HIST_N)?0:(hist_widx%HIST_N);
  uint32_t pos=(base+idx)%HIST_N;
  len=0; for(uint32_t i=0; hist[pos][i] && i<sizeof(line)-1; i++){ line[i]=hist[pos][i]; len++; }
  line[len]=0; redraw_line();
}
static void hist_prev(void){ if(hist_count==0) return; if(hist_pos<0) hist_pos=(int32_t)hist_count-1; else if(hist_pos>0) hist_pos--; hist_recall_index((uint32_t)hist_pos); }
static void hist_next(void){
  if(hist_count==0) return; if(hist_pos<0) return;
  if(hist_pos<(int32_t)hist_count-1){ hist_pos++; hist_recall_index((uint32_t)hist_pos); }
  else { hist_pos=-1; len=0; line[0]=0; redraw_line(); }
}

/* ==== Comandos ==== */
static void cmd_help(void){
  uart_puts("Comandos:\r\n");
  uart_puts("  help            - esta ayuda\r\n");
  uart_puts("  ticks on/off    - habilita/deshabilita log de ticks\r\n");
  uart_puts("  tick N          - log cada N ticks (p.ej., 2000)\r\n");
  uart_puts("  uptime          - muestra ticks y ms aproximados\r\n");
  uart_puts("  mem rd A L      - lee L bytes desde A (dec o 0xHEX)\r\n");
  uart_puts("  mem wr A B      - escribe byte B en A\r\n");
  uart_puts("  csr rd NAME     - lee CSR (sstatus,sie,sip,stvec,sscratch,sepc,scause,stval,satp,time)\r\n");
  uart_puts("  reboot|poweroff - reinicia / apaga vía OpenSBI\r\n");
  uart_puts("  clear           - limpia pantalla (ESC[2J; ESC[H)\r\n");
  uart_puts("  uartbase        - muestra base UART (set y efectiva)\r\n");
  uart_puts("  uartbase set A  - fija base UART a A (dec o 0xHEX)\r\n");
  uart_puts("  go A            - salta a dirección A (S-mode)\r\n");
  uart_puts("\r\nHistorial: ↑/↓ o Ctrl-P/Ctrl-N\r\n");
}

static void cmd_uptime(uint32_t ticks){
  uint32_t ms=ticks*10u, s=ms/1000u, rem=ms%1000u;
  uart_puts("ticks="); uart_putdec(ticks);
  uart_puts("  approx="); uart_putdec(s); uart_puts("s "); uart_putdec(rem); uart_puts("ms\r\n");
}

static void cmd_mem_rd(uint32_t addr, uint32_t lenb){
  if(lenb==0) return;

  /* Bloquea zonas de M-mode para evitar fault */
  uint32_t end = addr + lenb;
  for(uint32_t a=addr; a<end; a++){
    if(is_forbidden_addr(a)){
      uart_puts("forbidden: M-mode/firmware/CLINT desde S-mode\r\n");
      return;
    }
  }

  /* Evita cruzar fuera de los 8 registros del 16550A */
  {
    uint32_t ub = uart_base_effective();
    uint32_t ub_end = ub + 8u; /* offsets 0..7 */
    int clamped = 0;
    if(addr < ub_end && end > ub){
      if(addr >= ub){
        uint32_t maxlen = ub_end - addr;
        if(lenb > maxlen){ lenb = maxlen; clamped = 1; }
        end = addr + lenb;
      } else {
        lenb = (ub > addr) ? (ub - addr) : 0;
        if(lenb) clamped = 1;
        end = addr + lenb;
      }
    }
    if(clamped){
      uart_puts("(recortado por zona UART)\r\n");
    }
  }

  if(lenb==0){ uart_puts("nada que leer (recortado)\r\n"); return; }

  uint8_t* p=(uint8_t*)(uintptr_t)addr;
  uart_puts("dump "); uart_puthex32(addr); uart_puts(" +"); uart_putdec(lenb); uart_puts(":\r\n");
  for(uint32_t i=0;i<lenb;i++){
    if((i&0x0F)==0){ uart_puthex32(addr+i); uart_puts(": "); }
    put_hex8(p[i]); uart_putc(' ');
    if((i&0x0F)==0x0F) uart_puts("\r\n");
  }
  if((lenb&0x0F)!=0) uart_puts("\r\n");
}

static void cmd_mem_wr(uint32_t addr, uint32_t bytev){
  if(is_forbidden_addr(addr)){ uart_puts("forbidden: M-mode/firmware/CLINT\r\n"); return; }
  {
    uint32_t ub = uart_base_effective();
    if(addr>=ub && addr<ub+8){
      /* permitido escribir dentro de los 8 regs; afuera no */
    } else if(addr>=ub && addr<ub+0x1000){
      uart_puts("uart: fuera de los 8 registros válidos\r\n"); return;
    }
  }
  volatile uint8_t* p=(volatile uint8_t*)(uintptr_t)addr;
  *p=(uint8_t)(bytev&0xFFu);
  uart_puts("write "); uart_puthex32(addr); uart_puts(" = 0x"); put_hex8((uint8_t)bytev); uart_puts("\r\n");
}

/* CSR por nombre */
static int csr_rd_by_name(const char* n, uint32_t* out){
  uint32_t v;
  if(streq(n,"sstatus")) { __asm__ volatile("csrr %0, sstatus":"=r"(v)); *out=v; return 1; }
  if(streq(n,"sie"))     { __asm__ volatile("csrr %0, sie":"=r"(v));     *out=v; return 1; }
  if(streq(n,"sip"))     { __asm__ volatile("csrr %0, sip":"=r"(v));     *out=v; return 1; }
  if(streq(n,"stvec"))   { __asm__ volatile("csrr %0, stvec":"=r"(v));   *out=v; return 1; }
  if(streq(n,"sscratch")){ __asm__ volatile("csrr %0, sscratch":"=r"(v));*out=v; return 1; }
  if(streq(n,"sepc"))    { __asm__ volatile("csrr %0, sepc":"=r"(v));    *out=v; return 1; }
  if(streq(n,"scause"))  { __asm__ volatile("csrr %0, scause":"=r"(v));  *out=v; return 1; }
  if(streq(n,"stval"))   { __asm__ volatile("csrr %0, stval":"=r"(v));   *out=v; return 1; }
  if(streq(n,"satp"))    { __asm__ volatile("csrr %0, satp":"=r"(v));    *out=v; return 1; }
  if(streq(n,"time"))    { __asm__ volatile("csrr %0, time":"=r"(v));    *out=v; return 1; }
  return 0;
}

/* Trim finales en la línea actual */
static void rtrim_current_line(void){
  int end=(int)len; while(end>0&&(line[end-1]==' '||line[end-1]=='\t')) end--;
  line[end]=0; len=(uint32_t)end;
}

/* Limpia pantalla y reposiciona cursor al home */
static void term_clear(void){ uart_puts("\x1b[2J\x1b[H"); }

static void handle_line(const char* s, uint32_t last_ticks){
  rtrim_current_line(); if(len==0) return;
  hist_store(s); hist_pos=-1;

  if(streq(s,"help")) cmd_help();
  else if(streq(s,"ticks on")){ g_tick_every=1000; uart_puts("ticks=1000\r\n"); }
  else if(streq(s,"ticks off")){ g_tick_every=0; uart_puts("ticks=off\r\n"); }
  else if(starts_with(s,"tick ")){ uint32_t n=0; if(parse_uint_auto(s+5,&n)){ g_tick_every=n; uart_puts("ticks="); uart_putdec(n); uart_puts("\r\n"); } else uart_puts("uso: tick N\r\n"); }
  else if(streq(s,"uptime")) cmd_uptime(last_ticks);
  else if(starts_with(s,"mem rd ")){ uint32_t a=0,l=0; const char* p=s+7;
    if(parse_uint_auto(p,&a)){ while(*p&&*p!=' '&&*p!='\t') p++; while(*p==' '||*p=='\t') p++;
      if(parse_uint_auto(p,&l)) cmd_mem_rd(a,l); else uart_puts("uso: mem rd <addr> <len>\r\n");
    } else uart_puts("uso: mem rd <addr> <len>\r\n");
  }
  else if(starts_with(s,"mem wr ")){ uint32_t a=0,b=0; const char* p=s+7;
    if(parse_uint_auto(p,&a)){ while(*p&&*p!=' '&&*p!='\t') p++; while(*p==' '||*p=='\t') p++;
      if(parse_uint_auto(p,&b)) cmd_mem_wr(a,b); else uart_puts("uso: mem wr <addr> <byte>\r\n");
    } else uart_puts("uso: mem wr <addr> <byte>\r\n");
  }
  else if(starts_with(s,"csr rd ")){ const char* p=s+7; while(*p==' '||*p=='\t') p++; uint32_t v;
    if(csr_rd_by_name(p,&v)){ uart_puts(p); uart_puts(" = "); uart_puthex32(v); uart_puts("\r\n"); }
    else uart_puts("CSR desconocido\r\n");
  }
  else if(streq(s,"reboot")){ uart_puts("SBI: cold reboot...\r\n"); sbi_system_reset(SBI_SRST_RESET_TYPE_COLD_REBOOT,0); }
  else if(streq(s,"poweroff")){ uart_puts("SBI: poweroff...\r\n"); sbi_system_reset(SBI_SRST_RESET_TYPE_SHUTDOWN,0); }
  else if(streq(s,"clear")) term_clear();
  else if(starts_with(s,"uartbase")){
    uart_puts("uart_base (set): "); uart_puthex32(s_uart_base_rt);
    uart_puts("  effective: "); uart_puthex32(uart_base_effective()); uart_puts("\r\n");
  }
  else {
    const char* gp = NULL;
    if (is_cmd_go_line(s, &gp)) {
      char tok[32]; int i = 0;
      while (*gp && *gp!=32 && *gp!=9 && *gp!=13 && *gp!=10 && *gp!=35 && i < (int)sizeof(tok)-1) tok[i++] = *gp++;
      tok[i] = 0;
      if (tok[0]) {
        uint32_t a = 0;
        if (parse_uint_auto(tok, &a)) {
          g_tick_every = 0;
          uart_puts("jump S to "); uart_puthex32(a); uart_puts(" ...\r\n");
          ((void(*)(void))(uintptr_t)a)();
          uart_puts("retorno de entry()\r\n");
        } else { uart_puts("uso: go <addr>\r\n"); }
      } else { uart_puts("uso: go <addr>\r\n"); }
    } else {  if (bootx_handle_command(s)) { return; }
  if (bootx_handle_command(s)) { return; }
  uart_puts("ECHO: "); uart_puts(s); uart_puts("\r\n");
}
  }
}

/* ===== API ===== */
static uint32_t last_ticks_seen=0;

void console_init(void){
  len=0; hist_count=0; hist_widx=0; hist_pos=-1; last_drawn_len=0; esc_state=0;
  uart_puts("\r\nRX listo. 'help' para comandos. Historial: ↑/↓ o Ctrl-P/Ctrl-N\r\n");
  prompt();
}

/* Manejo ESC [ A/B (↑/↓) */
static int handle_esc_seq(char c){
  if(esc_state==0){ if((unsigned char)c==0x1B){ esc_state=1; return 1; } return 0; }
  else if(esc_state==1){ if(c=='['){ esc_state=2; return 1; } esc_state=0; return 1; }
  else { if(c=='A') hist_prev(); else if(c=='B') hist_next(); esc_state=0; return 1; }
}

void console_rx_char(char c){
  if(handle_esc_seq(c)) return;
  if(c==0x10){ hist_prev(); return; } /* ^P */
  if(c==0x0E){ hist_next(); return; } /* ^N */

  if(c=='\r'||c=='\n'){ uart_puts("\r\n"); line[len]=0; handle_line(line,last_ticks_seen); len=0; line[0]=0; last_drawn_len=0; prompt(); return; }
  if(c==0x08||c==0x7F){ if(len>0){ len--; uart_puts("\b \b"); last_drawn_len=(last_drawn_len>0)?last_drawn_len-1:0; } return; }
  if(c>=32&&c<=126&&len<sizeof(line)-1){ line[len++]=c; uart_putc(c); if(last_drawn_len<len) last_drawn_len=len; }
}

void console_on_tick(uint32_t ticks){
  last_ticks_seen=ticks;
  if(g_tick_every && (ticks%g_tick_every)==0){ uart_puts("\r\n[tick] "); uart_putdec(ticks); uart_puts("\r\n"); redraw_line(); }
}
static int is_cmd_go_line(const char* s, const char** out_p){
  if(!s) return 0;
  while(*s==' '||*s=='\t'||*s=='\r'||*s=='\n') s++;
  if ((s[0]=='g'||s[0]=='G') && (s[1]=='o'||s[1]=='O') &&
      (s[2]==0 || s[2]==' ' || s[2]=='\t' || s[2]=='\r' || s[2]=='\n')){
    s += 2;
    while(*s==' '||*s=='\t'||*s=='\r'||*s=='\n') s++;
    if(out_p) *out_p = s;
    return 1;
  }
  return 0;
}
void cmd_go(uint32_t a){
  extern volatile uint32_t g_tick_every;
  uart_puts("jump S to "); uart_puthex32(a); uart_puts(" ...\r\n");
  g_tick_every = 0;
  ((void(*)(void))(uintptr_t)a)();
  uart_puts("retorno de entry()\r\n");
}

/* ========================= BootX-like command block =========================
   Comandos: bootbin, bootelf, set bootargs="...", reboot, poweroff
   Implementados aquí para no tocar el Makefile.
   Dependencias externas: uart_puts, uart_puthex32, cmd_go()
   ========================================================================== */
extern void uart_puts(const char*);
extern void uart_puthex32(uint32_t);
void cmd_go(uint32_t entry);

/* --- utils --- */
static int bx_is_space(char c){ return (c==' '||c=='\t'||c=='\r'||c=='\n'); }
static const char* bx_skip_ws(const char* s){ while(s && bx_is_space(*s)) s++; return s; }
static int bx_starts_with(const char* s, const char* p){
  if(!s||!p) return 0; while(*p){ if(*s++!=*p++) return 0; } return 1;
}
static int bx_is_hex(char c){
  return (c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F');
}
static uint32_t bx_hexv(char c){
  if(c>='0'&&c<='9') return (uint32_t)(c-'0');
  if(c>='a'&&c<='f') return 10u+(uint32_t)(c-'a');
  return 10u+(uint32_t)(c-'A');
}
static int bx_parse_uint_auto(const char* s, uint32_t* out){
  if(!s) return 0;
  s = bx_skip_ws(s);
  if(s[0]=='0' && (s[1]=='x'||s[1]=='X')){
    s+=2; uint32_t v=0; int any=0;
    while(bx_is_hex(*s)){ v=(v<<4)|bx_hexv(*s++); any=1; }
    if(!any) return 0; if(out) *out=v; return 1;
  }
  if(*s<'0'||*s>'9') return 0;
  uint32_t v=0;
  while(*s>='0'&&*s<='9'){ v = v*10u + (uint32_t)(*s - '0'); s++; }
  if(out) *out=v; return 1;
}

/* --- SBI reset (SRST) --- */
static long bx_sbi(long eid, long fid, long a0, long a1){
  register long a0r __asm__("a0") = a0;
  register long a1r __asm__("a1") = a1;
  register long a6r __asm__("a6") = fid;
  register long a7r __asm__("a7") = eid;
  __asm__ volatile("ecall" : "+r"(a0r), "+r"(a1r) : "r"(a6r), "r"(a7r) : "memory");
  return a0r;
}
static void bx_sbi_reset(uint32_t type, uint32_t reason){
  const long EID_SRST = 0x53525354l; /* 'SRST' */
  (void)bx_sbi(EID_SRST, 0, type, reason);
  while(1){}
}

/* --- DTB bootargs overwrite (mínimo) --- */
typedef struct {
  uint32_t magic, totalsize, off_dt_struct, off_dt_strings, off_mem_rsvmap;
  uint32_t version, last_comp_version, boot_cpuid_phys, size_dt_strings, size_dt_struct;
} bx_fdt_hdr_t;
static inline uint32_t bx_bswap32(uint32_t x){
  return ((x&0xFFu)<<24)|((x&0xFF00u)<<8)|((x&0xFF0000u)>>8)|((x>>24)&0xFFu);
}
static inline uint32_t bx_be32(uint32_t x){ return bx_bswap32(x); }
#define BX_FDT_MAGIC 0xd00dfeedu
#define BX_FDT_BEGIN 1u
#define BX_FDT_END   2u
#define BX_FDT_PROP  3u
#define BX_FDT_NOP   4u
#define BX_FDT_DONE  9u
#ifndef DTB_FIXED_ADDR
#define DTB_FIXED_ADDR 0x8fe00000u
#endif
static int bx_fdt_overwrite_bootargs(void* dtb, const char* s){
  if(!dtb||!s) return -3;
  bx_fdt_hdr_t* h=(bx_fdt_hdr_t*)dtb;
  if(bx_be32(h->magic)!=BX_FDT_MAGIC) return -3;
  uint8_t* base=(uint8_t*)dtb;
  uint8_t* p = base + bx_be32(h->off_dt_struct);
  uint8_t* strings = base + bx_be32(h->off_dt_strings);
  int depth=0, in_chosen=0;
  uint32_t newlen=0; while(s[newlen]) newlen++;
  for(;;){
    uint32_t tok = bx_be32(*(uint32_t*)p); p+=4;
    if(tok==BX_FDT_BEGIN){
      char* name=(char*)p; size_t l=0; while(name[l]) l++;
      p=(uint8_t*)(name+l+1); while(((uintptr_t)p)&3) p++;
      depth++;
      if(depth>1){
        const char* cho="chosen"; size_t i=0;
        while(cho[i]&&name[i]&&cho[i]==name[i]) i++;
        in_chosen = (cho[i]==0 && name[i]==0);
      }else in_chosen=0;
    }else if(tok==BX_FDT_END){
      if(in_chosen) in_chosen=0;
      if(--depth<0) return -3;
      if(depth==0) break;
    }else if(tok==BX_FDT_PROP){
      uint32_t be_len=*(uint32_t*)p; p+=4;
      uint32_t be_no =*(uint32_t*)p; p+=4;
      uint32_t len=bx_be32(be_len), nameoff=bx_be32(be_no);
      char* pname=(char*)(strings+nameoff);
      if(in_chosen){
        const char* want="bootargs"; size_t i=0; while(want[i]&&pname[i]&&want[i]==pname[i]) i++;
        if(want[i]==0 && pname[i]==0){
          if(newlen<=len){
            for(uint32_t i2=0;i2<len;i2++){ ((uint8_t*)p)[i2] = (i2<newlen)?(uint8_t)s[i2]:0; }
            return 1;
          }else return -2;
        }
      }
      p += ((len+3u)&~3u);
    }else if(tok==BX_FDT_NOP){
      /* nada */
    }else if(tok==BX_FDT_DONE){
      break;
    }else return -3;
  }
  return 0;
}

/* --- ELF32 loader mínimo --- */
#define BX_EM_RISCV 243
#define BX_PT_LOAD  1
typedef struct {
  unsigned char e_ident[16];
  uint16_t e_type, e_machine;
  uint32_t e_version, e_entry, e_phoff, e_shoff, e_flags;
  uint16_t e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx;
} bx_Elf32_Ehdr;
typedef struct {
  uint32_t p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align;
} bx_Elf32_Phdr;
static void bx_memset(void* d, int v, size_t n){ uint8_t* p=d; while(n--)*p++=(uint8_t)v; }
static void bx_memcpy(void* d, const void* s, size_t n){ uint8_t* dp=d; const uint8_t* sp=s; while(n--)*dp++=*sp++; }
static int bx_elf32_load(uint32_t image, uint32_t* out_entry){
  bx_Elf32_Ehdr* eh=(bx_Elf32_Ehdr*)(uintptr_t)image;
  if(!(eh->e_ident[0]==0x7f&&eh->e_ident[1]=='E'&&eh->e_ident[2]=='L'&&eh->e_ident[3]=='F')) return -1;
  if(eh->e_ident[4]!=1) return -2; /* 32-bit */
  if(eh->e_ident[5]!=1) return -3; /* little */
  if(eh->e_machine!=BX_EM_RISCV) return -4;
  if(eh->e_phnum==0 || eh->e_phentsize!=sizeof(bx_Elf32_Phdr)) return -5;
  bx_Elf32_Phdr* ph=(bx_Elf32_Phdr*)((uintptr_t)eh + eh->e_phoff);
  for(uint16_t i=0;i<eh->e_phnum;i++){
    if(ph[i].p_type!=BX_PT_LOAD) continue;
    void* dst=(void*)(uintptr_t)ph[i].p_vaddr;
    void* src=(void*)((uintptr_t)eh + ph[i].p_offset);
    if(ph[i].p_filesz) bx_memcpy(dst, src, ph[i].p_filesz);
    if(ph[i].p_memsz>ph[i].p_filesz) bx_memset((uint8_t*)dst+ph[i].p_filesz,0,(size_t)(ph[i].p_memsz-ph[i].p_filesz));
  }
  if(out_entry) *out_entry=eh->e_entry;
  return 0;
}

/* --- router --- */
static int bootx_handle_command(const char* s){
  if(!s) return 0;
  s = bx_skip_ws(s);
  /* bootelf <addr> */
  if(bx_starts_with(s,"bootelf")){
    s+=7; s=bx_skip_ws(s);
    uint32_t addr=0, entry=0;
    if(!bx_parse_uint_auto(s,&addr)){ uart_puts("uso: bootelf <addr>\r\n"); return 1; }
    uart_puts("ELF @ "); uart_puthex32(addr); uart_puts(" ...\r\n");
    int rc = bx_elf32_load(addr,&entry);
    if(rc){ uart_puts("elf error "); uart_puthex32((uint32_t)rc); uart_puts("\r\n"); return 1; }
    uart_puts("entry = "); uart_puthex32(entry); uart_puts("\r\n");
    cmd_go(entry);
    return 1;
  }
  /* bootbin <addr> [entry] */
  if(bx_starts_with(s,"bootbin")){
    s+=7; s=bx_skip_ws(s);
    uint32_t addr=0, entry=0;
    if(!bx_parse_uint_auto(s,&addr)){ uart_puts("uso: bootbin <addr> [entry]\r\n"); return 1; }
    while(*s && !bx_is_space(*s)) s++; s=bx_skip_ws(s);
    entry = (*s && bx_parse_uint_auto(s,&entry)) ? entry : addr;
    uart_puts("BIN entry="); uart_puthex32(entry); uart_puts("\r\n");
    cmd_go(entry);
    return 1;
  }
  /* set bootargs="..." */
  if(bx_starts_with(s,"set")){
    s+=3; s=bx_skip_ws(s);
    const char* key="bootargs";
    const char* p=s; size_t i=0; while(key[i]&&p[i]&&key[i]==p[i]) i++;
    if(key[i]==0 && (p[i]==0 || bx_is_space(p[i]) || p[i]=='=')){
      s=p+i; s=bx_skip_ws(s); if(*s=='=') s++; s=bx_skip_ws(s);
      char buf[256]; size_t n=0;
      if(*s=='"'||*s=='\''){ char q=*s++; while(*s&&*s!=q&&n<sizeof(buf)-1) buf[n++]=*s++; }
      else{ while(*s&&!bx_is_space(*s)&&n<sizeof(buf)-1) buf[n++]=*s++; }
      buf[n]=0; if(n==0){ uart_puts("uso: set bootargs=\"...\"\r\n"); return 1; }
      int rc = bx_fdt_overwrite_bootargs((void*)(uintptr_t)DTB_FIXED_ADDR, buf);
      if(rc==1) uart_puts("bootargs OK\r\n");
      else if(rc==0) uart_puts("bootargs: /chosen/bootargs no encontrado\r\n");
      else if(rc==-2) uart_puts("bootargs: cadena demasiado larga para propiedad actual\r\n");
      else uart_puts("bootargs: DTB invalido\r\n");
      return 1;
    }
  }
  /* reboot / poweroff */
  if(bx_starts_with(s,"reboot")){ uart_puts("SBI reboot...\r\n"); bx_sbi_reset(1,0); return 1; }
  if(bx_starts_with(s,"poweroff")||bx_starts_with(s,"shutdown")){ uart_puts("SBI poweroff...\r\n"); bx_sbi_reset(0,0); return 1; }
  return 0;
}
/* ======================= /BootX-like command block ======================== */
