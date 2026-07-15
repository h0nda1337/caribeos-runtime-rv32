#include <stdint.h>
#include "jump_s.h"

extern struct boot_args g_boot_args;

/* cmd: bootbin <va> */
int cmd_bootbin(uint32_t entry_va)
{
  /* a0=0, a1=DTB (el que muestra tu booter) */
  jump_s(entry_va, 0, g_boot_args.dtb);
  return 0; /* no retorna */
}
