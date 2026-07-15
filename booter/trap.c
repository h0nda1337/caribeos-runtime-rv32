/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include "include/uapi/trap.h"
#include "booter/plic_min.h"
#include "booter/console.h"

void uart_puts(const char*);
void uart_putc(char);
void uart_putdec(uintptr_t);
void uart_irq_disable_thre(void);
uint8_t uart_iir_read(void);
uint8_t uart_lsr_read(void);
int uart_getc_nonblock(void);

extern void trap_entry(void);

/* Habilita interrupciones de timer y externas en S-mode */
void trap_init(void (*handler)(uint32_t, uint32_t, uint32_t)){
  (void)handler; /* handler real es trap_handle_c() */
  uintptr_t te = (uintptr_t)trap_entry;
  __asm__ volatile("csrw stvec, %0" :: "r"(te));

  const uint32_t SSTATUS_SIE = (1u<<1);
  const uint32_t SIE_STIE    = (1u<<5);
  const uint32_t SIE_SEIE    = (1u<<9);
  __asm__ volatile("csrs sstatus, %0" :: "r"(SSTATUS_SIE));
  __asm__ volatile("csrs sie, %0"     :: "r"(SIE_STIE | SIE_SEIE));
}

/* === Timer vía sstc (no ACLINT en S-mode) === */
static volatile uint32_t g_hart   = 0;
static volatile uint32_t g_ticks  = 0;
/* tick period configurable desde console.c */
volatile uint32_t g_tick_every = 1000;

static inline uint64_t rdtime64(void){
  uint32_t hi1, lo, hi2;
  do {
    __asm__ volatile("csrr %0, timeh" : "=r"(hi1));
    __asm__ volatile("csrr %0, time"  : "=r"(lo));
    __asm__ volatile("csrr %0, timeh" : "=r"(hi2));
  } while(hi1 != hi2);
  return ((uint64_t)hi2 << 32) | lo;
}
static inline void wr_stimecmp(uint64_t val){
  uint32_t lo = (uint32_t)(val & 0xFFFFFFFFu);
  uint32_t hi = (uint32_t)(val >> 32);
  __asm__ volatile("csrw stimecmph, %0" :: "r"(0xFFFFFFFFu) : "memory");
  __asm__ volatile("csrw stimecmp,  %0" :: "r"(lo) : "memory");
  __asm__ volatile("csrw stimecmph, %0" :: "r"(hi) : "memory");
}

void timer_init(uint32_t aclint_base_unused, uint32_t hartid){
  (void)aclint_base_unused;
  g_hart = hartid;
  uint64_t now = rdtime64();
  wr_stimecmp(now + 100000ULL); /* ~10ms a 10MHz */
}

/* Pretty names (excepciones) */
static const char* exc_name(uint32_t code){
  switch(code){
    case 0: return "insn_addr_misaligned";
    case 1: return "insn_access_fault";
    case 2: return "illegal_insn";
    case 3: return "breakpoint";
    case 4: return "load_addr_misaligned";
    case 5: return "load_access_fault";
    case 6: return "store_addr_misaligned";
    case 7: return "store_access_fault";
    case 8: return "ecall_u";
    case 9: return "ecall_s";
    case 11:return "ecall_m";
    default:return "exception";
  }
}

/* Hook principal llamado desde trap_entry.S */
uint32_t trap_handle_c(uint32_t scause, uint32_t sepc, uint32_t stval){
  (void)stval;
  const uint32_t INTR = 0x80000000u;
  if(scause & INTR){
    uint32_t code = (scause & 0x7FFFFFFF);
    if(code == 5){ /* S-timer */
      g_ticks++;
      /* delega la impresión y re-prompt en console */
      console_on_tick(g_ticks);
      uint64_t now = rdtime64();
      wr_stimecmp(now + 100000ULL);

    } else if(code == 9){ /* S-external (PLIC: uart8250 id=10) */
      uint32_t ctxS = (uint32_t)(g_hart*2u + 2u);
      uint32_t id = plic_claim(ctxS);
      if(id){
        if(id == 10){
          /* Despacha causas por IIR mientras haya IRQs pendientes (bit0==1 => no pending) */
          for(;;){
            uint8_t iirv = uart_iir_read();
            if(iirv & 0x01) break; /* no pending */
            uint8_t iid = (uint8_t)(iirv & 0x0F);

            switch(iid){
              case 0x02: /* THR Empty */
                /* apaga sólo THRE para no afectar RX */
                uart_irq_disable_thre();
                break;

              case 0x04: /* Received Data Available */
              case 0x0C: /* RX Timeout (FIFO) */
              {
                for(;;){
                  int ch = uart_getc_nonblock();
                  if(ch < 0) break;
                  console_rx_char((char)ch);
                }
                break;
              }

              case 0x06: /* Receiver Line Status */
                (void)uart_lsr_read(); /* limpia estatus de línea */
                break;

              case 0x00: /* Modem Status: ignoramos */
              default:
                break;
            }
          }
        }
        plic_complete(ctxS, id);
      }
    }
    return sepc;
  }

  /* Excepciones (log útil) */
  uart_puts("\r\n[trap] "); uart_puts(exc_name(scause));
  uart_puts(" code="); uart_putdec(scause);
  uart_puts(" sepc="); uart_putdec(sepc);
  uart_puts(" stval="); uart_putdec(stval);
  return sepc;
}
