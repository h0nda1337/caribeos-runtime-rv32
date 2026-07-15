    .section .text.boot
    .globl _start
    .type _start, @function

_start:
    /* Preparar pila */
    la      sp, __stack_top

    /* Zeroear .bss */
    la      t0, __bss_start
    la      t1, __bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    /* a0 = hart, a1 = dtb ya vienen del booter; no los toquemos */
    la      t0, entry
    jalr    ra, t0, 0     /* entra a entry(a0,a1); si retorna, volvemos al booter */
    ret
