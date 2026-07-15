/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include "include/uapi/bootargs.h"
#include "include/uapi/mmu.h"
#include "include/uapi/trap.h"
#include "booter/plic_min.h"
#include "booter/console.h"
#include "booter/hfsplus_boot.h"

void uart_init(uint32_t base);
void uart_puts(const char *);
void uart_puthex32(uint32_t v);
void uart_putdec(uintptr_t v);
void caribe_pack_boot_args(caribe_boot_args *ba, uintptr_t dtb);
void uart_irq_enable_rx(void);

static void trap_handler(uint32_t scause, uint32_t sepc, uint32_t stval){
  (void)scause; (void)sepc; (void)stval;
}

void __attribute__((noreturn)) s_mode_entry(uintptr_t hartid, void *dtb)
{
    uart_puts("\r\n[CaribeBootX-RV32] S-mode up. hart=");
    uart_putdec(hartid);

    caribe_boot_args ba;
    caribe_pack_boot_args(&ba, (uintptr_t)dtb);
    uart_init((uint32_t)ba.uart_base);
    console_set_uart_base((uint32_t)ba.uart_base);

    uart_puts("\r\nboot_args (desde FDT si aplica):");
    uart_puts("\r\n  dtb        = "); uart_puthex32((uint32_t)ba.dtb);
    uart_puts("\r\n  uart_base  = "); uart_puthex32((uint32_t)ba.uart_base);
    uart_puts("\r\n  plic_base  = "); uart_puthex32((uint32_t)ba.plic_base);
    uart_puts("\r\n  aclint_base= "); uart_puthex32((uint32_t)ba.aclint_base);
    uart_puts("\r\n  mem_mb     = "); uart_putdec(ba.mem_mb);
    uart_puts("\r\n  ncpus      = "); uart_putdec(ba.ncpus);

    mmu_sv32_install_identity(0x80000000u, ba.mem_mb,
                              (uint32_t)ba.uart_base,
                              (uint32_t)ba.plic_base,
                              (uint32_t)ba.aclint_base);
    mmu_sv32_enable();
    uart_puts("\r\nMMU Sv32 activa (identidad).\r\n");

    trap_init(trap_handler);
    timer_init((uint32_t)ba.aclint_base, (uint32_t)hartid);
    uart_puts("Timer armado (~10ms). Esperando ticks...\r\n");

    /* === PLIC (externas) === */
    plic_init((uint32_t)ba.plic_base);
    uint32_t ctxS = (uint32_t)(hartid*2u + 2u); /* S-mode */
    /* En QEMU virt, el ns16550a suele ser ID=10 */
    plic_set_priority(10, 1);
    plic_enable(ctxS, 10);
    plic_set_threshold(ctxS, 0);

    /* Habilita interrupción de RX en el UART */
    uart_irq_enable_rx();

    if (caribe_hfsplus_boot((uint32_t)hartid, (uintptr_t)dtb) != 0) {
        uart_puts("\r\n[CaribeBootX] HFS+ boot no completo; abriendo consola.\r\n");
    }

    /* Arranca la consola (prompt) */
    console_init();

    for(;;) __asm__ volatile("wfi");
}
