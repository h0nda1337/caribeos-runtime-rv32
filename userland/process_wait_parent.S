/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_WAITID, 95
	.equ	SYS_NANOSLEEP, 101
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17
	.equ	CLD_EXITED, 1
	.equ	ECHILD, 10
	.equ	WNOHANG, 1
	.equ	WEXITED, 4
	.equ	WNOWAIT, 0x01000000
	.equ	P_ALL, 0
	.equ	P_PID, 1
	.equ	BATCH_CHILDREN, 10

	.section .rodata, "a"
start_msg:
	.ascii	"[process-gate-7] userspace parent starting real wait race matrix\n"
	.equ	start_msg_len, . - start_msg
wait_before_msg:
	.ascii	"[process-gate-7] parent waited before child exit; SIGCHLD wakeup PASS\n"
	.equ	wait_before_msg_len, . - wait_before_msg
exit_before_msg:
	.ascii	"[process-gate-7] child exited before wait; waitid WNOWAIT preserved zombie PASS\n"
	.equ	exit_before_msg_len, . - exit_before_msg
nohang_msg:
	.ascii	"[process-gate-7] WNOHANG returned 0 for live matching child PASS\n"
	.equ	nohang_msg_len, . - nohang_msg
batch_msg:
	.ascii	"[process-gate-7] ten children exited/reaped in reverse order with no duplicates PASS\n"
	.equ	batch_msg_len, . - batch_msg
empty_msg:
	.ascii	"[process-gate-7] wait4/waitid report ECHILD after final reap PASS\n"
	.equ	empty_msg_len, . - empty_msg
orphan_msg:
	.ascii	"[process-gate-7] parent leaving live child for PID1 reparent test\n"
	.equ	orphan_msg_len, . - orphan_msg
fail_msg:
	.ascii	"[process-gate-7] userspace wait scenario FAIL\n"
	.equ	fail_msg_len, . - fail_msg

	.section .bss, "aw", @nobits
	.align	2
wait_status:
	.space	4
wait_siginfo:
	.space	128
batch_pids:
	.space	40
sleep_req:
	.space	8

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
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	/* Parent reaches wait4 while this child sleeps on an XNU deadline. */
	li	s0, 1
	call	fork_one
	beqz	a0, child_dispatch
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
	li	t2, 7936
	bne	t1, t2, parent_fail
	la	a1, wait_before_msg
	li	a2, wait_before_msg_len
	call	write_stdout

	/* Let the next child become a zombie before observing it with waitid. */
	li	s0, 2
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	mv	s1, a0
	li	a0, 50
	call	sleep_msec
	bnez	a0, parent_fail
	li	a0, P_PID
	mv	a1, s1
	la	a2, wait_siginfo
	li	a3, WEXITED | WNOWAIT
	li	a4, 0
	li	a7, SYS_WAITID
	ecall
	bnez	a0, parent_fail
	la	t0, wait_siginfo
	lw	t1, 0(t0)
	li	t2, SIGCHLD
	bne	t1, t2, parent_fail
	lw	t1, 8(t0)
	li	t2, CLD_EXITED
	bne	t1, t2, parent_fail
	lw	t1, 12(t0)
	bne	t1, s1, parent_fail
	lw	t1, 20(t0)
	li	t2, 32
	bne	t1, t2, parent_fail
	mv	a0, s1
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s1, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	li	t2, 8192
	bne	t1, t2, parent_fail
	la	a1, exit_before_msg
	li	a2, exit_before_msg_len
	call	write_stdout

	/* The live child remains asleep while WNOHANG observes it. */
	li	s0, 3
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	mv	s1, a0
	mv	a0, s1
	la	a1, wait_status
	li	a2, WNOHANG
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bnez	a0, parent_fail
	mv	a0, s1
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s1, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	li	t2, 8448
	bne	t1, t2, parent_fail
	la	a1, nohang_msg
	li	a2, nohang_msg_len
	call	write_stdout

	/* Create ten live tasks before collecting any of them. */
	li	s0, 4
	li	s1, 0
batch_fork_loop:
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	la	t0, batch_pids
	slli	t1, s1, 2
	add	t0, t0, t1
	sw	a0, 0(t0)
	addi	s1, s1, 1
	li	t0, BATCH_CHILDREN
	blt	s1, t0, batch_fork_loop

	/* Observe the first exit without consuming it. */
	li	a0, P_ALL
	li	a1, 0
	la	a2, wait_siginfo
	li	a3, WEXITED | WNOWAIT
	li	a4, 0
	li	a7, SYS_WAITID
	ecall
	bnez	a0, parent_fail
	la	t0, wait_siginfo
	lw	t1, 0(t0)
	li	t2, SIGCHLD
	bne	t1, t2, parent_fail
	lw	t1, 8(t0)
	li	t2, CLD_EXITED
	bne	t1, t2, parent_fail
	lw	s2, 12(t0)
	lw	s3, 20(t0)
	li	t1, 40
	blt	s3, t1, parent_fail
	li	t1, 50
	bge	s3, t1, parent_fail
	la	t0, batch_pids
	lw	t1, 36(t0)
	bne	s2, t1, parent_fail
	mv	a0, s2
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s2, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	slli	t2, s3, 8
	bne	t1, t2, parent_fail
	addi	t0, s3, -40
	li	s6, 1
	sll	s6, s6, t0
	li	s7, 1

batch_wait_loop:
	li	a0, -1
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	blez	a0, parent_fail
	mv	s4, a0
	la	t0, wait_status
	lw	s5, 0(t0)
	srli	s5, s5, 8
	li	t3, 0
	la	t4, batch_pids
batch_pid_scan:
	lw	t5, 0(t4)
	beq	t5, s4, batch_pid_found
	addi	t3, t3, 1
	addi	t4, t4, 4
	li	t6, BATCH_CHILDREN
	blt	t3, t6, batch_pid_scan
	j	parent_fail
batch_pid_found:
	addi	t0, t3, 40
	bne	s5, t0, parent_fail
	li	t1, 1
	sll	t1, t1, t3
	and	t2, s6, t1
	bnez	t2, parent_fail
	or	s6, s6, t1
	addi	s7, s7, 1
	li	t0, BATCH_CHILDREN
	blt	s7, t0, batch_wait_loop
	li	t0, 0x3ff
	bne	s6, t0, parent_fail
	la	a1, batch_msg
	li	a2, batch_msg_len
	call	write_stdout

	li	a0, -1
	la	a1, wait_status
	li	a2, WNOHANG
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	li	t0, -ECHILD
	bne	a0, t0, parent_fail
	li	a0, P_ALL
	li	a1, 0
	la	a2, wait_siginfo
	li	a3, WEXITED | WNOHANG
	li	a4, 0
	li	a7, SYS_WAITID
	ecall
	li	t0, -ECHILD
	bne	a0, t0, parent_fail
	la	a1, empty_msg
	li	a2, empty_msg_len
	call	write_stdout

	/* This sleeping child must still be alive when the parent exits. */
	li	s0, 5
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	la	a1, orphan_msg
	li	a2, orphan_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	parent_fail

fork_one:
	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	ret

child_dispatch:
	li	t0, 1
	beq	s0, t0, child_wait_before
	li	t0, 2
	beq	s0, t0, child_exit_before
	li	t0, 3
	beq	s0, t0, child_nohang
	li	t0, 4
	beq	s0, t0, child_batch
	li	t0, 5
	beq	s0, t0, child_orphan
	j	child_fail

child_wait_before:
	li	a0, 50
	call	sleep_msec
	bnez	a0, child_fail
	li	a0, 31
	j	child_exit

child_exit_before:
	li	a0, 32
	j	child_exit

child_nohang:
	li	a0, 100
	call	sleep_msec
	bnez	a0, child_fail
	li	a0, 33
	j	child_exit

child_batch:
	li	t0, BATCH_CHILDREN
	sub	a0, t0, s1
	li	t0, 50
	mul	a0, a0, t0
	call	sleep_msec
	bnez	a0, child_fail
	addi	a0, s1, 40
	j	child_exit

child_orphan:
	li	a0, 100
	call	sleep_msec
	bnez	a0, child_fail
	li	a0, 55
	j	child_exit

sleep_msec:
	li	t0, 1000000
	mul	t0, a0, t0
	la	t1, sleep_req
	sw	zero, 0(t1)
	sw	t0, 4(t1)
	mv	a0, t1
	li	a1, 0
	li	a7, SYS_NANOSLEEP
	ecall
	ret

child_exit:
	li	a7, SYS_EXIT_GROUP
	ecall

child_fail:
	li	a0, 91
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

parent_fail:
	la	a1, fail_msg
	li	a2, fail_msg_len
	call	write_stdout
	li	a0, 92
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
