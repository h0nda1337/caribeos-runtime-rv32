    .section .bss,"aw",@nobits
    .balign 16
__s_stack_area:
    .space 16384
__s_stack_top:

    .section .text.entry,"ax",@progbits
    .globl _start
_start:
    /* a0 = hartid, a1 = dtb (conservados) */
    la  sp, __s_stack_top
    la  t0, s_mode_entry
    jr  t0
