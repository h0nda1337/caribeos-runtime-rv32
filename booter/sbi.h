#pragma once
#include <stdint.h>

struct sbi_ret { long error; long value; };

static inline struct sbi_ret sbi_call(long eid, long fid,
                                      long a0, long a1, long a2, long a3){
  register long a0r __asm__("a0") = a0;
  register long a1r __asm__("a1") = a1;
  register long a2r __asm__("a2") = a2;
  register long a3r __asm__("a3") = a3;
  register long a6r __asm__("a6") = fid;
  register long a7r __asm__("a7") = eid;
  __asm__ volatile("ecall" : "+r"(a0r), "+r"(a1r)
                           : "r"(a2r), "r"(a3r), "r"(a6r), "r"(a7r)
                           : "memory");
  struct sbi_ret r = { a0r, a1r };
  return r;
}

/* System reset (SRST) */
#define SBI_EID_SRST 0x53525354L /* 'SRST' */
#define SBI_SRST_RESET_TYPE_SHUTDOWN     0
#define SBI_SRST_RESET_TYPE_COLD_REBOOT  1
#define SBI_SRST_RESET_TYPE_WARM_REBOOT  2

static inline void sbi_system_reset(uint32_t type, uint32_t reason){
  (void)sbi_call(SBI_EID_SRST, 0, type, reason, 0, 0);
  for(;;) __asm__ volatile("wfi");
}
