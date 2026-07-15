/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

    .section .text.xnu_stage0_trap_vector, "ax", @progbits
    .globl xnu_stage0_trap_vector
    .type xnu_stage0_trap_vector, @function
    .align 2
xnu_stage0_trap_vector:
    addi sp, sp, -64
    sw   ra, 60(sp)
    sw   a0, 56(sp)
    sw   a1, 52(sp)
    sw   a2, 48(sp)
    sw   a3, 44(sp)
    sw   a4, 40(sp)
    sw   a5, 36(sp)
    sw   t0, 32(sp)
    sw   t1, 28(sp)
    sw   t2, 24(sp)

    csrr a0, scause
    csrr a1, sepc
    csrr a2, stval
    call xnu_stage0_trap_dispatch

    lw   t2, 24(sp)
    lw   t1, 28(sp)
    lw   t0, 32(sp)
    lw   a5, 36(sp)
    lw   a4, 40(sp)
    lw   a3, 44(sp)
    lw   a2, 48(sp)
    lw   a1, 52(sp)
    lw   a0, 56(sp)
    lw   ra, 60(sp)
    addi sp, sp, 64
    sret
    .size xnu_stage0_trap_vector, . - xnu_stage0_trap_vector

    .section .text.xnu_stage0_user_trap_vector, "ax", @progbits
    .globl xnu_stage0_user_trap_vector
    .type xnu_stage0_user_trap_vector, @function
    .align 2
xnu_stage0_user_trap_vector:
    csrrw sp, sscratch, sp
    addi  sp, sp, -96

    sw    ra, 0(sp)
    sw    gp, 4(sp)
    sw    tp, 8(sp)
    sw    t0, 12(sp)
    sw    t1, 16(sp)
    sw    t2, 20(sp)
    sw    s0, 24(sp)
    sw    s1, 28(sp)
    sw    a0, 32(sp)
    sw    a1, 36(sp)
    sw    a2, 40(sp)
    sw    a3, 44(sp)
    sw    a4, 48(sp)
    sw    a5, 52(sp)
    sw    a6, 56(sp)
    sw    a7, 60(sp)
    csrr  t0, sscratch
    sw    t0, 64(sp)
    csrr  t0, sepc
    sw    t0, 68(sp)
    csrr  t0, scause
    sw    t0, 72(sp)
    csrr  t0, stval
    sw    t0, 76(sp)

    mv    a0, sp
    call  xnu_stage0_user_trap_dispatch

    lw    t0, 68(sp)
    csrw  sepc, t0
    lw    t0, 64(sp)
    lw    ra, 0(sp)
    lw    gp, 4(sp)
    lw    tp, 8(sp)
    lw    t1, 16(sp)
    lw    t2, 20(sp)
    lw    s0, 24(sp)
    lw    s1, 28(sp)
    lw    a0, 32(sp)
    lw    a1, 36(sp)
    lw    a2, 40(sp)
    lw    a3, 44(sp)
    lw    a4, 48(sp)
    lw    a5, 52(sp)
    lw    a6, 56(sp)
    lw    a7, 60(sp)
    addi  sp, sp, 96
    csrw  sscratch, sp
    mv    sp, t0
    sret
    .size xnu_stage0_user_trap_vector, . - xnu_stage0_user_trap_vector

    .section .text.xnu_stage0_enter_user, "ax", @progbits
    .globl xnu_stage0_enter_user
    .type xnu_stage0_enter_user, @function
    .align 2
xnu_stage0_enter_user:
    csrw  sepc, a0
    csrw  sscratch, a2
    mv    sp, a1
    csrr  t0, sstatus
    li    t1, 0x00000100
    not   t1, t1
    and   t0, t0, t1
    li    t1, 0x00040020
    or    t0, t0, t1
    csrw  sstatus, t0
    sret
    .size xnu_stage0_enter_user, . - xnu_stage0_enter_user

    .section .rodata.xnu_stage0_umode_payload, "a", @progbits
    .globl xnu_stage0_umode_payload_start
    .globl xnu_stage0_umode_payload_end
    .align 2
xnu_stage0_umode_payload_start:
    addi  sp, sp, -512

    li    a7, 172
    ecall

    li    a7, 173
    ecall

    li    a7, 178
    ecall

    li    a7, 174
    ecall

    li    a7, 175
    ecall

    li    a7, 176
    ecall

    li    a7, 177
    ecall

    addi  a0, sp, 316
    li    a7, 96
    ecall

    addi  a0, sp, 208
    li    a1, 1
    li    a2, 1
    li    a3, 0
    li    a4, 0
    li    a5, 0
    li    a7, 98
    ecall

    li    a0, 2
    li    a1, 0
    addi  a2, sp, 216
    li    a3, 8
    li    a7, 134
    ecall

    li    a0, 0
    li    a1, 0
    addi  a2, sp, 232
    li    a3, 8
    li    a7, 135
    ecall

    li    a0, 0
    li    a1, 4
    addi  a2, sp, 204
    li    a7, 123
    ecall

    li    a0, 0
    li    a1, 4
    addi  a2, sp, 204
    li    a7, 122
    ecall

    addi  a0, sp, 200
    addi  a1, sp, 196
    li    a2, 0
    li    a7, 168
    ecall

    li    a0, 1
    addi  a1, sp, 184
    li    a7, 406
    ecall

    sw    zero, 176(sp)
    sw    zero, 180(sp)
    addi  a0, sp, 176
    li    a1, 0
    li    a7, 101
    ecall

    li    a0, 0
    li    a1, 0
    li    a2, 0
    li    a3, 0
    li    a7, 414
    ecall

    li    a0, 0
    addi  a1, sp, 104
    li    a7, 165
    ecall

    li    a0, 18
    li    a7, 166
    ecall

    li    a0, 0
    li    a7, 214
    ecall

    li    a0, 0
    li    a1, 4096
    li    a2, 3
    li    a3, 0x22
    li    a4, -1
    li    a5, 0
    li    a7, 222
    ecall
    mv    s1, a0

    mv    a0, s1
    li    a1, 4096
    li    a2, 4096
    li    a3, 0
    li    a7, 216
    ecall
    mv    s1, a0

    mv    a0, s1
    li    a1, 4096
    li    a2, 0
    li    a7, 233
    ecall

    mv    a0, s1
    li    a1, 4096
    li    a2, 1
    li    a7, 226
    ecall

    mv    a0, s1
    li    a1, 4096
    li    a7, 215
    ecall

    addi  a0, sp, 0
    li    a7, 160
    ecall

    addi  a0, sp, 448
    li    a1, 64
    li    a7, 17
    ecall

    addi  a0, sp, 256
    li    a7, 179
    ecall

    li    a0, 0
    li    a1, 3
    li    a2, 0
    addi  a3, sp, 240
    li    a7, 261
    ecall

0:
    auipc a0, %pcrel_hi(xnu_stage0_root_path)
    addi  a0, a0, %pcrel_lo(0b)
    addi  a1, sp, 224
    li    a7, 43
    ecall

    li    a0, -100
5:
    auipc a1, %pcrel_hi(xnu_stage0_proc_self_exe_path)
    addi  a1, a1, %pcrel_lo(5b)
    li    a2, 0
    li    a3, 0
    li    a7, 48
    ecall

    li    a0, -100
6:
    auipc a1, %pcrel_hi(xnu_stage0_proc_self_exe_path)
    addi  a1, a1, %pcrel_lo(6b)
    addi  a2, sp, 352
    li    a3, 64
    li    a7, 78
    ecall
    mv    a2, a0

    li    a0, 1
    addi  a1, sp, 352
    li    a7, 64
    ecall

    li    a0, 1
7:
    auipc a1, %pcrel_hi(xnu_stage0_umode_newline)
    addi  a1, a1, %pcrel_lo(7b)
    li    a2, 1
    li    a7, 64
    ecall

    li    a0, -100
8:
    auipc a1, %pcrel_hi(xnu_stage0_proc_version_path)
    addi  a1, a1, %pcrel_lo(8b)
    li    a2, 0
    li    a3, 0x7ff
    addi  a4, sp, 64
    li    a7, 291
    ecall

    li    a0, -100
0:
    auipc a1, %pcrel_hi(xnu_stage0_proc_version_path)
    addi  a1, a1, %pcrel_lo(0b)
    addi  a2, sp, 64
    li    a3, 0
    li    a7, 79
    ecall

    li    a0, -100
9:
    auipc a1, %pcrel_hi(xnu_stage0_proc_path)
    addi  a1, a1, %pcrel_lo(9b)
    li    a2, 0
    li    a3, 0
    li    a7, 56
    ecall
    mv    s1, a0

    mv    a0, s1
    addi  a1, sp, 64
    li    a7, 80
    ecall

    mv    a0, s1
    addi  a1, sp, 224
    li    a7, 44
    ecall

    mv    a0, s1
    addi  a1, sp, 128
    li    a2, 160
    li    a7, 61
    ecall

    mv    a0, s1
    li    a7, 57
    ecall

    li    a0, 1
    addi  a1, sp, 336
    li    a7, 403
    ecall

    addi  a0, sp, 328
    li    a1, 0
    li    a7, 169
    ecall

    addi  a0, sp, 320
    li    a1, 8
    li    a2, 0
    li    a7, 278
    ecall

    li    a0, -100
4:
    auipc a1, %pcrel_hi(xnu_stage0_proc_version_path)
    addi  a1, a1, %pcrel_lo(4b)
    li    a2, 0
    li    a3, 0
    li    a7, 56
    ecall
    mv    s0, a0

    addi  a1, sp, 256
    li    a2, 96
    li    a7, 63
    ecall
    mv    a2, a0

    li    a0, 1
    addi  a1, sp, 256
    li    a7, 64
    ecall

    mv    a0, s0
    li    a7, 57
    ecall

    li    a0, 1
1:
    auipc a1, %pcrel_hi(xnu_stage0_umode_msg)
    addi  a1, a1, %pcrel_lo(1b)
    li    a2, 49
    li    a7, 64
    ecall

3:
    auipc t0, %pcrel_hi(xnu_stage0_umode_msg2)
    addi  t0, t0, %pcrel_lo(3b)
    sw    t0, 400(sp)
    li    t1, 43
    sw    t1, 404(sp)
    li    a0, 1
    addi  a1, sp, 400
    li    a2, 1
    li    a7, 66
    ecall

    li    a0, 0
    li    a7, 94
    ecall
2:
    j     2b
xnu_stage0_umode_msg:
    .ascii "[umode] Linux write syscall reached XNU-CaribeOS\n"
xnu_stage0_umode_msg_end:
xnu_stage0_umode_msg2:
    .ascii "[umode] Linux writev vector reached stage0\n"
xnu_stage0_umode_msg2_end:
xnu_stage0_proc_version_path:
    .asciz "/proc/version"
xnu_stage0_proc_self_exe_path:
    .asciz "/proc/self/exe"
xnu_stage0_proc_path:
    .asciz "/proc"
xnu_stage0_root_path:
    .asciz "/"
xnu_stage0_umode_newline:
    .ascii "\n"
xnu_stage0_umode_payload_end:
