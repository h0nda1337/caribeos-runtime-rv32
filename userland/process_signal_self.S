/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_NANOSLEEP, 101
	.equ	SYS_KILL, 129
	.equ	SYS_SIGALTSTACK, 132
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_RT_SIGPROCMASK, 135
	.equ	SYS_RT_SIGRETURN, 139
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGUSR1, 10
	.equ	SIGCHLD, 17
	.equ	SA_SIGINFO, 0x00000004
	.equ	SA_RESTORER, 0x04000000
	.equ	SA_ONSTACK, 0x08000000
	.equ	SIG_SETMASK, 2
	.equ	EINTR, 4
	.equ	SIGSET_SIZE, 8
	.equ	PARENT_MAGIC, 0x6a19c4e3
	.equ	RT_FRAME_SIZE, 944
	.equ	RT_FRAME_UCONTEXT, 128
	.equ	UC_SIGMASK, 20
	.equ	UC_MCONTEXT, 160
	.equ	MC_PC, 0
	.equ	MC_SP, 8
	.equ	MC_A0, 40

	.section .rodata, "a"
start_msg:
	.ascii	"[process-gate-9] userspace installed SIGUSR1 SA_SIGINFO/SA_ONSTACK\n"
	.equ	start_msg_len, . - start_msg
self_msg:
	.ascii	"[process-gate-9] kill(self) delivered handler after syscall PASS\n"
	.equ	self_msg_len, . - self_msg
sleep_msg:
	.ascii	"[process-gate-9] SIGUSR1 interrupted XNU deadline sleep with EINTR PASS\n"
	.equ	sleep_msg_len, . - sleep_msg
wait_intr_msg:
	.ascii	"[process-gate-9] SIGUSR1 woke blocked wait4 with EINTR PASS\n"
	.equ	wait_intr_msg_len, . - wait_intr_msg
wait_done_msg:
	.ascii	"[process-gate-9] wait4 retry reaped real sender child status=52 PASS\n"
	.equ	wait_done_msg_len, . - wait_done_msg
context_msg:
	.ascii	"[process-gate-9] altstack/siginfo/ucontext/handler-mask restored x3 PASS\n"
	.equ	context_msg_len, . - context_msg
fail_msg:
	.ascii	"[process-gate-9] userspace directed-signal scenario FAIL\n"
	.equ	fail_msg_len, . - fail_msg

	.section .data, "aw"
	.align	2
sigusr1_action:
	.word	sigusr1_handler
	.word	SA_SIGINFO | SA_RESTORER | SA_ONSTACK
	.word	sigreturn_restorer
	.word	0
	.word	0

	.section .bss, "aw", @nobits
	.align	4
signal_altstack:
	.space	4096
	.align	2
altstack_desc:
	.space	12
handler_mask:
	.space	8
wait_status:
	.space	4
sleep_req:
	.space	8
parent_pid:
	.space	4
parent_sp:
	.space	4
child_pid:
	.space	4
child_mode:
	.space	4
expected_pc:
	.space	4
expected_a0:
	.space	4
expected_sender:
	.space	4
handler_count:
	.space	4
handler_ok:
	.space	4
handler_ra:
	.space	4

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	li	a7, SYS_GETPID
	ecall
	li	t0, 2
	bne	a0, t0, parent_fail
	la	t0, parent_pid
	sw	a0, 0(t0)
	li	a7, SYS_GETPPID
	ecall
	li	t0, 1
	bne	a0, t0, parent_fail
	la	t0, parent_sp
	sw	sp, 0(t0)
	li	s0, PARENT_MAGIC

	la	t0, altstack_desc
	la	t1, signal_altstack
	sw	t1, 0(t0)
	sw	zero, 4(t0)
	li	t1, 4096
	sw	t1, 8(t0)
	mv	a0, t0
	li	a1, 0
	li	a7, SYS_SIGALTSTACK
	ecall
	bnez	a0, parent_fail
	li	a0, SIGUSR1
	la	a1, sigusr1_action
	li	a2, 0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, parent_fail
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	/* Delivery point 1: the return path from kill(self, SIGUSR1). */
	la	t0, expected_pc
	la	t1, after_self_kill
	sw	t1, 0(t0)
	la	t0, expected_a0
	sw	zero, 0(t0)
	la	t0, expected_sender
	la	t1, parent_pid
	lw	t1, 0(t1)
	sw	t1, 0(t0)
	mv	a0, t1
	li	a1, SIGUSR1
	li	a7, SYS_KILL
	ecall
after_self_kill:
	bnez	a0, parent_fail
	li	a0, 1
	call	validate_parent_after_handler
	bnez	a0, parent_fail
	la	a1, self_msg
	li	a2, self_msg_len
	call	write_stdout

	/* Delivery point 2: a child interrupts a real XNU deadline sleep. */
	la	t0, child_mode
	li	t1, 1
	sw	t1, 0(t0)
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	la	t0, child_pid
	sw	a0, 0(t0)
	la	t0, expected_sender
	sw	a0, 0(t0)
	la	t0, expected_pc
	la	t1, after_interrupted_sleep
	sw	t1, 0(t0)
	la	t0, expected_a0
	li	t1, -EINTR
	sw	t1, 0(t0)
	la	t1, sleep_req
	sw	zero, 0(t1)
	li	t0, 500000000
	sw	t0, 4(t1)
	mv	a0, t1
	li	a1, 0
	li	a7, SYS_NANOSLEEP
	ecall
after_interrupted_sleep:
	li	t0, -EINTR
	bne	a0, t0, parent_fail
	li	a0, 2
	call	validate_parent_after_handler
	bnez	a0, parent_fail
	la	a1, sleep_msg
	li	a2, sleep_msg_len
	call	write_stdout
	li	a0, 51
	call	wait_child_status
	bnez	a0, parent_fail

	/* Delivery point 3: wake a wait4 while its child is still alive. */
	la	t0, child_mode
	li	t1, 2
	sw	t1, 0(t0)
	call	fork_one
	beqz	a0, child_dispatch
	bltz	a0, parent_fail
	la	t0, child_pid
	sw	a0, 0(t0)
	la	t0, expected_sender
	sw	a0, 0(t0)
	la	t0, expected_pc
	la	t1, after_interrupted_wait
	sw	t1, 0(t0)
	la	t0, expected_a0
	li	t1, -EINTR
	sw	t1, 0(t0)
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
after_interrupted_wait:
	li	t0, -EINTR
	bne	a0, t0, parent_fail
	li	a0, 3
	call	validate_parent_after_handler
	bnez	a0, parent_fail
	la	a1, wait_intr_msg
	li	a2, wait_intr_msg_len
	call	write_stdout
	li	a0, 52
	call	wait_child_status
	bnez	a0, parent_fail
	la	a1, wait_done_msg
	li	a2, wait_done_msg_len
	call	write_stdout

	/* Handler-time mask was temporary; SIGUSR1 must now be unblocked. */
	la	t0, handler_mask
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	li	a0, SIG_SETMASK
	li	a1, 0
	mv	a2, t0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGPROCMASK
	ecall
	bnez	a0, parent_fail
	la	t0, handler_mask
	lw	t1, 0(t0)
	andi	t1, t1, 0x200
	bnez	t1, parent_fail
	la	a1, context_msg
	li	a2, context_msg_len
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
	la	t0, child_mode
	lw	t0, 0(t0)
	li	t1, 1
	beq	t0, t1, child_interrupt_sleep
	li	t1, 2
	beq	t0, t1, child_interrupt_wait
	j	child_fail

child_interrupt_sleep:
	li	a0, 25
	call	sleep_msec
	bnez	a0, child_fail
	call	signal_parent
	bnez	a0, child_fail
	li	a0, 51
	j	child_exit

child_interrupt_wait:
	li	a0, 25
	call	sleep_msec
	bnez	a0, child_fail
	call	signal_parent
	bnez	a0, child_fail
	li	a0, 150
	call	sleep_msec
	bnez	a0, child_fail
	li	a0, 52
	j	child_exit

signal_parent:
	li	a7, SYS_GETPPID
	ecall
	li	a1, SIGUSR1
	li	a7, SYS_KILL
	ecall
	ret

wait_child_status:
	mv	t3, a0
	la	t0, child_pid
	lw	a0, 0(t0)
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	la	t0, child_pid
	lw	t1, 0(t0)
	bne	a0, t1, wait_child_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	slli	t2, t3, 8
	bne	t1, t2, wait_child_fail
	li	a0, 0
	ret
wait_child_fail:
	li	a0, -1
	ret

validate_parent_after_handler:
	mv	t3, a0
	li	t0, PARENT_MAGIC
	bne	s0, t0, validate_parent_fail
	la	t0, parent_sp
	lw	t1, 0(t0)
	bne	sp, t1, validate_parent_fail
	la	t0, handler_count
	lw	t1, 0(t0)
	bne	t1, t3, validate_parent_fail
	la	t0, handler_ok
	lw	t1, 0(t0)
	li	t2, 1
	bne	t1, t2, validate_parent_fail
	li	a0, 0
	ret
validate_parent_fail:
	li	a0, -1
	ret

	/* a0=SIGUSR1, a1=siginfo_t *, a2=ucontext_t *. */
sigusr1_handler:
	la	t0, handler_ra
	sw	ra, 0(t0)
	li	t0, SIGUSR1
	bne	a0, t0, handler_fail
	bne	sp, a1, handler_fail
	addi	t1, a1, RT_FRAME_UCONTEXT
	bne	a2, t1, handler_fail
	lw	t1, 0(a1)
	bne	t1, t0, handler_fail
	lw	t1, 8(a1)
	bnez	t1, handler_fail
	lw	t1, 12(a1)
	la	t2, expected_sender
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, 16(a1)
	bnez	t1, handler_fail

	la	t0, signal_altstack
	bltu	sp, t0, handler_fail
	addi	t1, sp, RT_FRAME_SIZE
	li	t2, 4096
	add	t2, t0, t2
	bltu	t2, t1, handler_fail
	lw	t1, UC_MCONTEXT + MC_PC(a2)
	la	t2, expected_pc
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, UC_MCONTEXT + MC_SP(a2)
	la	t2, parent_sp
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, UC_MCONTEXT + MC_A0(a2)
	la	t2, expected_a0
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, UC_SIGMASK(a2)
	andi	t1, t1, 0x200
	bnez	t1, handler_fail

	/* The active handler mask must contain SIGUSR1 until rt_sigreturn. */
	la	t0, handler_mask
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	li	a0, SIG_SETMASK
	li	a1, 0
	mv	a2, t0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGPROCMASK
	ecall
	bnez	a0, handler_fail
	la	t0, handler_mask
	lw	t1, 0(t0)
	andi	t1, t1, 0x200
	beqz	t1, handler_fail
	la	t0, handler_count
	lw	t1, 0(t0)
	addi	t1, t1, 1
	sw	t1, 0(t0)
	la	t0, handler_ok
	li	t1, 1
	sw	t1, 0(t0)
	li	s0, 0
	la	t0, handler_ra
	lw	ra, 0(t0)
	ret

handler_fail:
	la	t0, handler_ok
	li	t1, -1
	sw	t1, 0(t0)
	li	s0, 0
	la	t0, handler_ra
	lw	ra, 0(t0)
	ret

sigreturn_restorer:
	li	a7, SYS_RT_SIGRETURN
	ecall
	unimp

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
	li	a0, 90
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

parent_fail:
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
