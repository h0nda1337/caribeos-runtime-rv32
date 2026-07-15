#pragma once
#include <stdint.h>

/* Salta a S-mode entry con a0/a1 preparados.
 * a0: libre (puedes pasar 0)
 * a1: DTB pointer
 */
static inline void jump_s(uint32_t entry, uint32_t a0, uint32_t a1){
  register uint32_t A0 __asm__("a0") = a0;
  register uint32_t A1 __asm__("a1") = a1;
  register uint32_t E  __asm__("t0") = entry; /* evitar literal en jr */

  __asm__ volatile(
    "mv a0,%0\n"
    "mv a1,%1\n"
    "jr %2\n"
    :
    : "r"(A0), "r"(A1), "r"(E)
    : "memory"
  );
  __builtin_unreachable();
}
