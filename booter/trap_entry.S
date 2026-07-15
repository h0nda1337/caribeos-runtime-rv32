    .section .text,"ax",@progbits
    .globl trap_entry
    .align 2
trap_entry:
    /* Reserva frame y salva todos los temporales/args/saves que podamos usar */
    addi  sp, sp, -128
    sw    ra, 124(sp)
    sw    t0, 120(sp)
    sw    t1, 116(sp)
    sw    t2, 112(sp)
    sw    a0, 108(sp)
    sw    a1, 104(sp)
    sw    a2, 100(sp)
    sw    a3,  96(sp)
    sw    a4,  92(sp)
    sw    a5,  88(sp)
    sw    a6,  84(sp)
    sw    a7,  80(sp)
    sw    s0,  76(sp)
    sw    s1,  72(sp)
    sw    s2,  68(sp)
    sw    s3,  64(sp)
    sw    s4,  60(sp)
    sw    s5,  56(sp)
    sw    s6,  52(sp)
    sw    s7,  48(sp)
    sw    s8,  44(sp)
    sw    s9,  40(sp)
    sw    s10, 36(sp)
    sw    s11, 32(sp)

    /* a0= scause, a1= sepc, a2= stval */
    csrr  a0, scause
    csrr  a1, sepc
    csrr  a2, stval

    /* llama a trap_handle_c(scause,sepc,stval) -> a0 = nuevo sepc */
    call  trap_handle_c

    /* Escribe el sepc que C regresó en a0 */
    csrw  sepc, a0

    /* Restaura registros y vuelve */
    lw    ra, 124(sp)
    lw    t0, 120(sp)
    lw    t1, 116(sp)
    lw    t2, 112(sp)
    lw    a0, 108(sp)
    lw    a1, 104(sp)
    lw    a2, 100(sp)
    lw    a3,  96(sp)
    lw    a4,  92(sp)
    lw    a5,  88(sp)
    lw    a6,  84(sp)
    lw    a7,  80(sp)
    lw    s0,  76(sp)
    lw    s1,  72(sp)
    lw    s2,  68(sp)
    lw    s3,  64(sp)
    lw    s4,  60(sp)
    lw    s5,  56(sp)
    lw    s6,  52(sp)
    lw    s7,  48(sp)
    lw    s8,  44(sp)
    lw    s9,  40(sp)
    lw    s10, 36(sp)
    lw    s11, 32(sp)
    addi  sp, sp, 128

    sret
