#pragma once
#include <stdint.h>

int fdt_find_reg_base(const void *dtb, const char *compat, uint32_t *out_base);
int fdt_get_chosen_bootargs(const void *dtb, char *out, uint32_t out_cap);
uint32_t fdt_count_cpus(const void *dtb);

/* Helpers públicos por si los necesitas luego */
static inline uint32_t fdt_be32(const void *p){
    const uint8_t *b=(const uint8_t*)p;
    return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|((uint32_t)b[3]);
}
