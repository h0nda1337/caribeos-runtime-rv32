/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Native ELF TLS, independent of the compiler's GNU emutls configuration.
 */
    .option norelax
    .section .tdata,"awT",@progbits
    .balign 16
    .type caribe_tcb_initialized,@object
caribe_tcb_initialized:
    .word 0x13579bdf
    .size caribe_tcb_initialized,4
    .section .tbss,"awT",@nobits
    .balign 16
    .type caribe_tcb_zero,@object
caribe_tcb_zero:
    .zero 4
    .size caribe_tcb_zero,4
    .text
    .balign 2
    .globl caribe_tcb_initialized_address
    .type caribe_tcb_initialized_address,@function
caribe_tcb_initialized_address:
    lui a0,%tprel_hi(caribe_tcb_initialized)
    add a0,a0,tp,%tprel_add(caribe_tcb_initialized)
    addi a0,a0,%tprel_lo(caribe_tcb_initialized)
    ret
    .size caribe_tcb_initialized_address,.-caribe_tcb_initialized_address
    .globl caribe_tcb_zero_address
    .type caribe_tcb_zero_address,@function
caribe_tcb_zero_address:
    lui a0,%tprel_hi(caribe_tcb_zero)
    add a0,a0,tp,%tprel_add(caribe_tcb_zero)
    addi a0,a0,%tprel_lo(caribe_tcb_zero)
    ret
    .size caribe_tcb_zero_address,.-caribe_tcb_zero_address
    .section .note.GNU-stack,"",@progbits
