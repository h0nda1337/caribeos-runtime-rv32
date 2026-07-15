/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>

static volatile uint32_t UART_BASE = 0x10000000u; /* fallback */

void uart_init(uint32_t base){
    UART_BASE = base;
    /* FCR: enable FIFO y limpiar RX/TX */
    *(volatile uint8_t*)(uintptr_t)(UART_BASE + 0x02) = 0x07;
}

/* LSR bits */
#define LSR_DR   0x01  /* Data Ready */
#define LSR_THRE 0x20  /* THR Empty */

/* IER bits */
#define IER_RDA  0x01  /* Received Data Available */
#define IER_THRE 0x02  /* THR Empty Interrupt Enable */

static inline void outb(uint32_t a, uint8_t v){ *(volatile uint8_t*)(uintptr_t)a = v; }
static inline uint8_t inb(uint32_t a){ return *(volatile uint8_t*)(uintptr_t)a; }

/* Offsets 16550A */
static inline uint32_t rbr(void){ return UART_BASE + 0x00; } /* read */
static inline uint32_t thr(void){ return UART_BASE + 0x00; } /* write */
static inline uint32_t ier(void){ return UART_BASE + 0x01; }
static inline uint32_t iir(void){ return UART_BASE + 0x02; } /* read */
static inline uint32_t lsr(void){ return UART_BASE + 0x05; }

static inline uint8_t ier_read(void){ return inb(ier()); }
static inline void    ier_write(uint8_t v){ outb(ier(), v); }

/* TX (polling) */
void uart_putc(char c){
    while(!(inb(lsr()) & LSR_THRE)){}
    outb(thr(), (uint8_t)c);
}
void uart_puts(const char *s){ while(*s) uart_putc(*s++); }

/* IRQ enable/disable */
void uart_irq_enable_thre(void){ ier_write((uint8_t)(ier_read() | IER_THRE)); }
void uart_irq_disable_all(void){  ier_write(0); }
void uart_irq_disable_thre(void){
    uint8_t v = ier_read();
    v = (uint8_t)(v & (uint8_t)~IER_THRE);
    ier_write(v);
}
void uart_irq_enable_rx(void){ ier_write((uint8_t)(ier_read() | IER_RDA)); }

/* RX helpers */
int uart_getc_nonblock(void){
    if(inb(lsr()) & LSR_DR){
        return (int)inb(rbr());
    }
    return -1;
}
uint8_t uart_iir_read(void){ return inb(iir()); }
uint8_t uart_lsr_read(void){ return inb(lsr()); }

/* (Opcional) Forzar transición 0->1 de THRE (no se usa) */
void uart_irq_kick_thre(void){
    outb(thr(), 0x55);   /* emitiría 'U' en consola */
}
