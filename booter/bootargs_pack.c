#include <stdint.h>
#include "include/uapi/bootargs.h"
#include "booter/fdt_min.h"

static uint32_t try_compat(const void *dtb, const char *compat, uint32_t def){
    uint32_t base = 0;
    if(fdt_find_reg_base(dtb, compat, &base)==0) return base;
    return def;
}

void caribe_pack_boot_args(caribe_boot_args *ba, uintptr_t dtb)
{
    /* Fallbacks QEMU 'virt' */
    uint32_t def_uart  = 0x10000000u;
    uint32_t def_plic  = 0x0c000000u;
    uint32_t def_aclint= 0x02000000u;

    ba->dtb        = dtb;
    /* UART: ns16550a en QEMU */
    ba->uart_base  = try_compat((const void*)dtb, "ns16550a", def_uart);

    /* PLIC: riscv,plic0 */
    ba->plic_base  = try_compat((const void*)dtb, "riscv,plic0", def_plic);

    /* Timer: puede ser 'riscv,clint0' o 'riscv,aclint-mtimer' */
    uint32_t tmr = try_compat((const void*)dtb, "riscv,aclint-mtimer",
                 try_compat((const void*)dtb, "riscv,clint0", def_aclint));
    ba->aclint_base = tmr;

    ba->mem_mb     = 256;  /* igual que -m 256 */
    ba->ncpus      = fdt_count_cpus((const void*)dtb);
    if (ba->ncpus == 0)
        ba->ncpus = 1;
}
