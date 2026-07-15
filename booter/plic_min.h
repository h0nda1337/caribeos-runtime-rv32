#pragma once
#include <stdint.h>

/* Inicializa base del PLIC */
void plic_init(uint32_t base);
/* context: S-mode = 2*hart + 2  (hart0 => 2) */
void plic_set_threshold(uint32_t context, uint32_t th);
void plic_set_priority(uint32_t source, uint32_t prio);
void plic_enable(uint32_t context, uint32_t source);
uint32_t plic_claim(uint32_t context);
void plic_complete(uint32_t context, uint32_t id);
