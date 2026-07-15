    .section .text
    .globl _start
_start:
    /* A la entrada: a0 = hartid, a1 = dtb (QEMU virt) */
    /* Delegar interrupciones de Supervisor a S-mode: SSIP(1), STIP(5), SEIP(9) */
    li      t0, (1 << 1) | (1 << 5) | (1 << 9)
    csrs    mideleg, t0

    /* (opcional) Delegar excepciones comunes a S-mode (illegal, ecall, etc.) */
    /* li   t1, 0xFFFF    */
    /* csrs medeleg, t1   */

    /* Cambiar MPP = S para hacer mret a S-mode */
    csrr    t1, mstatus
    li      t2, ~(3 << 11)         /* limpiar MPP */
    and     t1, t1, t2
    li      t2, (1 << 11)          /* MPP = S */
    or      t1, t1, t2
    csrw    mstatus, t1

    /* Saltar a s_mode_entry(hartid=a0, dtb=a1) en S-mode */
    la      t0, s_mode_entry
    csrw    mepc, t0
    mret
