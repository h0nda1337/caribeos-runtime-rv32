#pragma once
#include <stdint.h>
typedef struct {
  uintptr_t dtb;         /* puntero al FDT */
  uintptr_t uart_base;   /* base MMIO UART (si la resuelves en booter) */
  uintptr_t plic_base;   /* base PLIC */
  uintptr_t aclint_base; /* base ACLINT (mtime/mtimecmp) */
  uint32_t  mem_mb;      /* memoria total en MiB */
  uint32_t  ncpus;       /* harts disponibles */
} caribe_boot_args;
