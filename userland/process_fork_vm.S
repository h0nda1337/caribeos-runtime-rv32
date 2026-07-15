/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17
	.equ	FORK_ROUNDS, 1000

	.section .data, "aw"
	.align	2
private_value:
	.word	10

	.section .rodata, "a"
parent_begin_msg:
	.ascii	"[process-gate-4] parent value=10 starting 1000 eager forks\n"
	.equ	parent_begin_msg_len, . - parent_begin_msg
child_first_msg:
	.ascii	"[process-gate-4] first child private value=20 exit=12\n"
	.equ	child_first_msg_len, . - child_first_msg
parent_first_msg:
	.ascii	"[process-gate-4] parent retained private value=10 status=12 PASS\n"
	.equ	parent_first_msg_len, . - parent_first_msg
parent_done_msg:
	.ascii	"[process-gate-4] user loop completed forks=1000 value=10 status=12 PASS\n"
	.equ	parent_done_msg_len, . - parent_done_msg
parent_fail_msg:
	.ascii	"[process-gate-4] parent fork/private-memory/wait mismatch FAIL\n"
	.equ	parent_fail_msg_len, . - parent_fail_msg
child_fail_msg:
	.ascii	"[process-gate-4] child private-memory mismatch FAIL\n"
	.equ	child_fail_msg_len, . - child_fail_msg
returned_msg:
	.ascii	"[process-gate-4] exit_group returned FAIL\n"
	.equ	returned_msg_len, . - returned_msg

	.section .text, "ax"
	.globl	_start
	.type	_start, @function

_start:
	li	a7, SYS_GETPID
	ecall
	li	t0, 2
	bne	a0, t0, parent_fail
	li	a7, SYS_GETPPID
	ecall
	li	t0, 1
	bne	a0, t0, parent_fail
	la	t0, private_value
	li	t1, 10
	sw	t1, 0(t0)
	li	s0, 0
	la	a1, parent_begin_msg
	li	a2, parent_begin_msg_len
	call	write_stdout

fork_loop:
	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	beqz	a0, child_path
	bltz	a0, parent_fail
	mv	s2, a0
	addi	sp, sp, -16
	sw	zero, 0(sp)
	mv	a0, s2
	mv	a1, sp
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s2, parent_fail_stack
	lw	t0, 0(sp)
	li	t1, 3072
	bne	t0, t1, parent_fail_stack
	addi	sp, sp, 16
	la	t0, private_value
	lw	t1, 0(t0)
	li	t2, 10
	bne	t1, t2, parent_fail
	bnez	s0, parent_first_done
	la	a1, parent_first_msg
	li	a2, parent_first_msg_len
	call	write_stdout
parent_first_done:
	addi	s0, s0, 1
	li	t0, FORK_ROUNDS
	blt	s0, t0, fork_loop

	la	a1, parent_done_msg
	li	a2, parent_done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

child_path:
	la	t0, private_value
	li	t1, 20
	sw	t1, 0(t0)
	lw	t2, 0(t0)
	bne	t1, t2, child_fail
	bnez	s0, child_no_print
	la	a1, child_first_msg
	li	a2, child_first_msg_len
	call	write_stdout
child_no_print:
	li	a0, 12
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

parent_fail_stack:
	addi	sp, sp, 16
parent_fail:
	la	a1, parent_fail_msg
	li	a2, parent_fail_msg_len
	call	write_stdout
	li	a0, 95
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

child_fail:
	la	a1, child_fail_msg
	li	a2, child_fail_msg_len
	call	write_stdout
	li	a0, 94
	li	a7, SYS_EXIT_GROUP
	ecall

exit_returned:
	la	a1, returned_msg
	li	a2, returned_msg_len
	call	write_stdout
1:
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
