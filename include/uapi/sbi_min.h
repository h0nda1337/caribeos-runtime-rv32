/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once
#include <stdint.h>

/* ecall genérico (SBI v0.2: a7=EID, a6=FID) */
static inline long sbi_ecall(long eid, long fid, long a0, long a1, long a2, long a3) {
  register long _a0 asm("a0") = a0;
  register long _a1 asm("a1") = a1;
  register long _a2 asm("a2") = a2;
  register long _a3 asm("a3") = a3;
  register long _a6 asm("a6") = fid;
  register long _a7 asm("a7") = eid;
  asm volatile ("ecall"
                : "+r"(_a0), "+r"(_a1)
                : "r"(_a2), "r"(_a3), "r"(_a6), "r"(_a7)
                : "memory");
  return _a0; /* error code en a0; valor en a1 si aplica */
}

/* SBI TIME */
#define SBI_EID_TIME      0x54494D45L /* 'TIME' */
#define SBI_FID_SET_TIMER 0

/* RV32: el 64-bit va en a0(lo), a1(hi) */
static inline void sbi_set_timer_u64(uint64_t next) {
#if __riscv_xlen == 32
  (void)sbi_ecall(SBI_EID_TIME, SBI_FID_SET_TIMER,
                  (long)(uint32_t)(next & 0xFFFFFFFFu),
                  (long)(uint32_t)(next >> 32),
                  0, 0);
#else
  (void)sbi_ecall(SBI_EID_TIME, SBI_FID_SET_TIMER, (long)next, 0, 0, 0);
#endif
}

/* Leer tiempo 64-bit desde CSRs time/timeh */
static inline uint64_t rdtime64(void){
  uint32_t hi0, lo, hi1;
  do {
    asm volatile ("csrr %0, timeh" : "=r"(hi0));
    asm volatile ("csrr %0, time"  : "=r"(lo));
    asm volatile ("csrr %0, timeh" : "=r"(hi1));
  } while(hi0 != hi1);
  return ((uint64_t)hi1 << 32) | lo;
}
