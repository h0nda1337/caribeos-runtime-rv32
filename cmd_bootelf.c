#include <stdint.h>
#include "jump_s.h"

/* Asume que en algún header tienes algo como: */
struct boot_args {
  uint32_t dtb;         /* dirección del DTB vigente (la que imprime tu booter) */
  /* ... otros campos ... */
};
extern struct boot_args g_boot_args;

extern int elf_load_to_va(uint32_t elf_src, uint32_t *entry_va_out); /* tu loader */

/* cmd: bootelf <addr> */
int cmd_bootelf(uint32_t elf_addr)
{
  uint32_t entry_va = 0;
  if (elf_load_to_va(elf_addr, &entry_va) != 0){
    /* print/log error... */
    return -1;
  }

  /* aquí solías hacer: jr entry;  Ahora pasa a1 = g_boot_args.dtb */
  /* a0 = 0 (libre), a1 = DTB */
  jump_s(entry_va, 0, g_boot_args.dtb);

  return 0; /* no retorna */
}
