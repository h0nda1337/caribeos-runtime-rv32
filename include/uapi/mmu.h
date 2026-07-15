/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once
#include <stdint.h>

#define PTE_V 0x001
#define PTE_R 0x002
#define PTE_W 0x004
#define PTE_X 0x008
#define PTE_U 0x010
#define PTE_G 0x020
#define PTE_A 0x040
#define PTE_D 0x080

static inline uint32_t pte_super(uint32_t pa, uint32_t flags){
  return ((pa >> 12) << 10) | (flags | PTE_V);
}

void mmu_sv32_install_identity(uint32_t ram_start, uint32_t ram_size_mb,
                               uint32_t mmio0, uint32_t mmio1, uint32_t mmio2);
void mmu_sv32_enable(void);
