/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_FCNTL, 25
	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_WRITE, 64
	.equ	SYS_CHDIR, 49
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_UMASK, 166
	.equ	SYS_GETPPID, 173
	.equ	SYS_GETPID, 172
	.equ	SYS_CLONE, 220
	.equ	SYS_EXECVE, 221
	.equ	SYS_WAIT4, 260
	.equ	AT_FDCWD, -100
	.equ	O_RDONLY, 0
	.equ	O_CLOEXEC, 0x80000
	.equ	F_GETFD, 1
	.equ	FD_CLOEXEC, 1
	.equ	ENOENT, 2
	.equ	SIGUSR1, 10
	.equ	SIGUSR2, 12
	.equ	SIGCHLD, 17
	.equ	ROUNDS, 1000

	.section .rodata, "a"
cwd_path:
	.asciz	"/usr"
fixture_path:
	.asciz	"/usr/lib/process-fd-fixture"
bad_exec_path:
	.asciz	"/bin/process-exec-badinterp"
exec_path:
	.asciz	"/bin/process-exec-child"
first_arg:
	.asciz	"first"
gate_env:
	.asciz	"GATE6=transactional"
start_msg:
	.ascii	"[process-gate-6] parent state prepared; starting fork-exec-wait x1000\n"
	.equ	start_msg_len, . - start_msg
rollback_msg:
	.ascii	"[process-gate-6] failed exec returned ENOENT with registers/data/fd intact PASS\n"
	.equ	rollback_msg_len, . - rollback_msg
done_msg:
	.ascii	"[process-gate-6] userspace parent observed status=23 x1000 and continued PASS\n"
	.equ	done_msg_len, . - done_msg
parent_fail_msg:
	.ascii	"[process-gate-6] parent scenario FAIL\n"
	.equ	parent_fail_msg_len, . - parent_fail_msg
child_fail_msg:
	.ascii	"[process-gate-6] pre-exec child scenario FAIL\n"
	.equ	child_fail_msg_len, . - child_fail_msg

	.section .data, "aw"
	.align	2
custom_action:
	.word	0x12345678, 0, 0, 0, 0, 0
ignored_action:
	.word	1, 0, 0, 0, 0, 0
regular_argv:
	.word	exec_path, 0
first_argv:
	.word	exec_path, first_arg, 0
exec_envp:
	.word	gate_env, 0
bad_argv:
	.word	bad_exec_path, 0
rollback_sentinel:
	.word	0x47583652

	.section .bss, "aw", @nobits
	.align	2
wait_status:
	.space	4

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

	la	a0, cwd_path
	li	a7, SYS_CHDIR
	ecall
	bnez	a0, parent_fail
	li	a0, 027
	li	a7, SYS_UMASK
	ecall
	li	t0, 022
	bne	a0, t0, parent_fail

	li	a0, SIGUSR1
	la	a1, custom_action
	li	a2, 0
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, parent_fail
	li	a0, SIGUSR2
	la	a1, ignored_action
	li	a2, 0
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, parent_fail

	li	a0, AT_FDCWD
	la	a1, fixture_path
	li	a2, O_RDONLY | O_CLOEXEC
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	li	t0, 3
	bne	a0, t0, parent_fail
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	li	s0, 0
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
	mv	s1, a0

	mv	a0, s1
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s1, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	li	t2, 5888
	bne	t1, t2, parent_fail
	addi	s0, s0, 1
	li	t0, ROUNDS
	blt	s0, t0, fork_loop

	li	a0, 3
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, parent_fail
	la	a1, done_msg
	li	a2, done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	parent_fail

child_path:
	bnez	s0, valid_exec
	la	a0, bad_exec_path
	la	a1, bad_argv
	la	a2, exec_envp
	li	a7, SYS_EXECVE
	ecall
	li	t0, -ENOENT
	bne	a0, t0, child_fail
	la	t0, rollback_sentinel
	lw	t1, 0(t0)
	li	t2, 0x47583652
	bne	t1, t2, child_fail
	li	a0, 3
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, FD_CLOEXEC
	bne	a0, t0, child_fail
	la	a1, rollback_msg
	li	a2, rollback_msg_len
	call	write_stdout

valid_exec:
	la	a0, exec_path
	bnez	s0, 1f
	la	a1, first_argv
	j	2f
1:
	la	a1, regular_argv
2:
	la	a2, exec_envp
	li	a7, SYS_EXECVE
	ecall

child_fail:
	la	a1, child_fail_msg
	li	a2, child_fail_msg_len
	call	write_stdout
	li	a0, 92
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

parent_fail:
	la	a1, parent_fail_msg
	li	a2, parent_fail_msg_len
	call	write_stdout
	li	a0, 93
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
