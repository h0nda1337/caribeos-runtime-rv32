/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include "booter/plic_min.h"

static volatile uint32_t g_plic = 0;

#define REG32(a) ((volatile uint32_t*)(uintptr_t)(a))

/* En el PLIC de QEMU/SiFive los contextos son 1-based.
   Los bancos de 'enable' y 'threshold/claim' se indexan con (ctx-1). */
static inline uintptr_t plic_prio_addr(uint32_t id){ return (uintptr_t)g_plic + 4u*id; }
static inline uintptr_t plic_enable_addr(uint32_t ctx){ return (uintptr_t)g_plic + 0x2000u   + 0x80u   * (ctx - 1u); }
static inline uintptr_t plic_thresh_addr(uint32_t ctx){ return (uintptr_t)g_plic + 0x200000u + 0x1000u * (ctx - 1u); }
static inline uintptr_t plic_claimc_addr(uint32_t ctx){ return (uintptr_t)g_plic + 0x200004u + 0x1000u * (ctx - 1u); }

void plic_init(uint32_t base){ g_plic = base; }
void plic_set_threshold(uint32_t ctx, uint32_t th){ *REG32(plic_thresh_addr(ctx)) = th; }
void plic_set_priority(uint32_t src, uint32_t prio){ *REG32(plic_prio_addr(src)) = prio; }

void plic_enable(uint32_t ctx, uint32_t src){
  uintptr_t en = plic_enable_addr(ctx);
  uint32_t idx = src / 32u, bit = src % 32u;
  REG32(en)[idx] |= (1u << bit);
}

uint32_t plic_claim(uint32_t ctx){ return *REG32(plic_claimc_addr(ctx)); }
void plic_complete(uint32_t ctx, uint32_t id){ *REG32(plic_claimc_addr(ctx)) = id; }
