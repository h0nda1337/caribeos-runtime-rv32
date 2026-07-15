/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_CLONE, 220
	.equ	SYS_EXECVE, 221
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17

	.section .rodata, "a"
worker_path:
	.asciz	"/bin/gate14-worker"
worker_arg:
	.asciz	"--cycle"
start_msg:
	.ascii	"[gate14-stress-driver] CPU0 supervisor starting fork-exec-wait\n"
	.equ	start_msg_len, . - start_msg
done_msg:
	.ascii	"[gate14-stress-driver] fork-exec-exit-wait complete PASS\n"
	.equ	done_msg_len, . - done_msg
fail_msg:
	.ascii	"[gate14-stress-driver] FAIL\n"
	.equ	fail_msg_len, . - fail_msg

	.section .data, "aw"
	.align	2
worker_argv:
	.word	worker_path, worker_arg, 0
worker_envp:
	.word	0

	.section .bss, "aw", @nobits
	.align	2
wait_status:
	.space	4

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	/* Parse the single decimal cycle count without pulling in libc. */
	lw	t0, 0(sp)
	li	t1, 2
	bne	t0, t1, driver_fail
	lw	t0, 8(sp)
	li	s0, 0
parse_rounds:
	lbu	t1, 0(t0)
	beqz	t1, parsed_rounds
	addi	t1, t1, -48
	li	t2, 9
	bltu	t2, t1, driver_fail
	li	t2, 10
	mul	s0, s0, t2
	add	s0, s0, t1
	addi	t0, t0, 1
	j	parse_rounds
parsed_rounds:
	beqz	s0, driver_fail
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout
	li	s1, 0

fork_loop:
	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	beqz	a0, child_exec
	bltz	a0, driver_fail
	mv	s2, a0

	mv	a0, s2
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s2, driver_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	bnez	t1, driver_fail
	addi	s1, s1, 1
	blt	s1, s0, fork_loop

	la	a1, done_msg
	li	a2, done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	driver_fail

child_exec:
	la	a0, worker_path
	la	a1, worker_argv
	la	a2, worker_envp
	li	a7, SYS_EXECVE
	ecall
	li	a0, 92
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

driver_fail:
	la	a1, fail_msg
	li	a2, fail_msg_len
	call	write_stdout
	li	a0, 91
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
