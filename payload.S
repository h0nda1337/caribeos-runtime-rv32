/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

    .option norvc
    .section .text
    .globl _start
_start:
    # UART 8250 @ 0x10000000
    lui     t0, 0x10000            # t0 = 0x10000000

    # t1 = &msg (la → auipc+addi bajo el capó)
    la      t1, msg

1:  lbu     t2, 0(t1)
    beqz    t2, 2f
    sb      t2, 0(t0)
    addi    t1, t1, 1
    j       1b
2:  ret

    .section .rodata
msg:
    .asciz "PAYLOAD!\r\n"
