/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	SYS_FCNTL, 25
	.equ	SYS_IOCTL, 29
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_NANOSLEEP, 101
	.equ	SYS_KILL, 129
	.equ	SYS_SIGALTSTACK, 132
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_RT_SIGRETURN, 139
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	F_GETFL, 3
	.equ	F_SETFL, 4
	.equ	O_NONBLOCK, 0x800
	.equ	TCGETS, 0x5401
	.equ	TCSETS, 0x5402
	.equ	TCSETSF, 0x5404
	.equ	FIONREAD, 0x541b
	.equ	ICANON, 0x00000002
	.equ	ECHO, 0x00000008
	.equ	CC_VTIME, 22
	.equ	CC_VMIN, 23
	.equ	SIGUSR1, 10
	.equ	SIGCHLD, 17
	.equ	SA_SIGINFO, 0x00000004
	.equ	SA_RESTORER, 0x04000000
	.equ	SA_ONSTACK, 0x08000000
	.equ	SIGSET_SIZE, 8
	.equ	EINTR, 4
	.equ	EAGAIN, 11
	.equ	PARENT_MAGIC, 0x71c0a55a
	.equ	RT_FRAME_UCONTEXT, 128
	.equ	UC_MCONTEXT, 160
	.equ	MC_PC, 0
	.equ	MC_SP, 8
	.equ	MC_A0, 40

	.section .rodata, "a"
nonblock_msg:
	.ascii	"[process-gate-10] empty O_NONBLOCK read returned EAGAIN PASS\n"
	.equ	nonblock_msg_len, . - nonblock_msg
type_prompt:
	.ascii	"[process-gate-10] type: "
	.equ	type_prompt_len, . - type_prompt
canonical_msg:
	.ascii	"[process-gate-10] canonical echo/backspace partial reads FIONREAD PASS\n"
	.equ	canonical_msg_len, . - canonical_msg
raw_prompt:
	.ascii	"[process-gate-10] raw VMIN=2: "
	.equ	raw_prompt_len, . - raw_prompt
raw_msg:
	.ascii	"[process-gate-10] noncanonical VMIN=2 read returned XY PASS\n"
	.equ	raw_msg_len, . - raw_msg
vtime_msg:
	.ascii	"[process-gate-10] noncanonical VMIN=0 VTIME=1 timeout returned 0 PASS\n"
	.equ	vtime_msg_len, . - vtime_msg
signal_prompt:
	.ascii	"[process-gate-10] signal-read: blocking without UART input\n"
	.equ	signal_prompt_len, . - signal_prompt
signal_msg:
	.ascii	"[process-gate-10] SIGUSR1 interrupted blocking read with EINTR PASS\n"
	.equ	signal_msg_len, . - signal_msg
done_msg:
	.ascii	"[process-gate-10] userspace UART/TTY scenario complete PASS\n"
	.equ	done_msg_len, . - done_msg
fail_msg:
	.ascii	"[process-gate-10] userspace UART/TTY scenario FAIL\n"
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
termios_original:
	.space	36
termios_work:
	.space	36
read_buffer:
	.space	32
fionread_value:
	.space	4
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
saved_open_flags:
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

	li	a0, 0
	li	a1, TCGETS
	la	a2, termios_original
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, parent_fail
	la	t0, termios_original
	lw	t1, 12(t0)
	andi	t2, t1, ICANON | ECHO
	li	t3, ICANON | ECHO
	bne	t2, t3, parent_fail
	lbu	t1, CC_VTIME(t0)
	bnez	t1, parent_fail
	lbu	t1, CC_VMIN(t0)
	li	t2, 1
	bne	t1, t2, parent_fail
	call	check_fionread_zero
	bnez	a0, parent_fail

	li	a0, 0
	li	a1, F_GETFL
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	bltz	a0, parent_fail
	la	t0, saved_open_flags
	sw	a0, 0(t0)
	li	t1, O_NONBLOCK
	or	a2, a0, t1
	li	a0, 0
	li	a1, F_SETFL
	li	a7, SYS_FCNTL
	ecall
	bnez	a0, parent_fail
	li	a0, 0
	la	a1, read_buffer
	li	a2, 8
	li	a7, SYS_READ
	ecall
	li	t0, -EAGAIN
	bne	a0, t0, parent_fail
	la	t0, saved_open_flags
	lw	a2, 0(t0)
	li	a0, 0
	li	a1, F_SETFL
	li	a7, SYS_FCNTL
	ecall
	bnez	a0, parent_fail
	la	a1, nonblock_msg
	li	a2, nonblock_msg_len
	call	write_stdout

	la	a1, type_prompt
	li	a2, type_prompt_len
	call	write_stdout
	li	a0, 0
	la	a1, read_buffer
	li	a2, 3
	li	a7, SYS_READ
	ecall
	li	t0, 3
	bne	a0, t0, parent_fail
	la	t0, read_buffer
	lbu	t1, 0(t0)
	li	t2, 'c'
	bne	t1, t2, parent_fail
	lbu	t1, 1(t0)
	li	t2, 'a'
	bne	t1, t2, parent_fail
	lbu	t1, 2(t0)
	li	t2, 'r'
	bne	t1, t2, parent_fail
	li	a0, 0
	li	a1, FIONREAD
	la	a2, fionread_value
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, parent_fail
	la	t0, fionread_value
	lw	t1, 0(t0)
	li	t2, 4
	bne	t1, t2, parent_fail
	li	a0, 0
	la	a1, read_buffer
	li	a2, 16
	li	a7, SYS_READ
	ecall
	li	t0, 4
	bne	a0, t0, parent_fail
	la	t0, read_buffer
	lbu	t1, 0(t0)
	li	t2, 'i'
	bne	t1, t2, parent_fail
	lbu	t1, 1(t0)
	li	t2, 'b'
	bne	t1, t2, parent_fail
	lbu	t1, 2(t0)
	li	t2, 'e'
	bne	t1, t2, parent_fail
	lbu	t1, 3(t0)
	li	t2, 10
	bne	t1, t2, parent_fail
	call	check_fionread_zero
	bnez	a0, parent_fail
	la	a1, canonical_msg
	li	a2, canonical_msg_len
	call	write_stdout

	call	copy_original_termios
	la	t0, termios_work
	lw	t1, 12(t0)
	li	t2, ~(ICANON | ECHO)
	and	t1, t1, t2
	sw	t1, 12(t0)
	sb	zero, CC_VTIME(t0)
	li	t1, 2
	sb	t1, CC_VMIN(t0)
	li	a0, 0
	li	a1, TCSETSF
	mv	a2, t0
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, parent_fail
	la	a1, raw_prompt
	li	a2, raw_prompt_len
	call	write_stdout
	li	a0, 0
	la	a1, read_buffer
	li	a2, 8
	li	a7, SYS_READ
	ecall
	li	t0, 2
	bne	a0, t0, parent_fail
	la	t0, read_buffer
	lbu	t1, 0(t0)
	li	t2, 'X'
	bne	t1, t2, parent_fail
	lbu	t1, 1(t0)
	li	t2, 'Y'
	bne	t1, t2, parent_fail
	la	a1, raw_msg
	li	a2, raw_msg_len
	call	write_stdout

	la	t0, termios_work
	li	t1, 1
	sb	t1, CC_VTIME(t0)
	sb	zero, CC_VMIN(t0)
	li	a0, 0
	li	a1, TCSETS
	mv	a2, t0
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, parent_fail
	li	a0, 0
	la	a1, read_buffer
	li	a2, 8
	li	a7, SYS_READ
	ecall
	bnez	a0, parent_fail
	la	a1, vtime_msg
	li	a2, vtime_msg_len
	call	write_stdout
	call	restore_original_termios
	bnez	a0, parent_fail

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
	call	fork_one
	beqz	a0, child_signal_read
	bltz	a0, parent_fail
	la	t0, child_pid
	sw	a0, 0(t0)
	la	t0, expected_sender
	sw	a0, 0(t0)
	la	t0, expected_pc
	la	t1, after_signal_read
	sw	t1, 0(t0)
	la	t0, expected_a0
	li	t1, -EINTR
	sw	t1, 0(t0)
	la	a1, signal_prompt
	li	a2, signal_prompt_len
	call	write_stdout
	li	a0, 0
	la	a1, read_buffer
	li	a2, 8
	li	a7, SYS_READ
	ecall
after_signal_read:
	li	t0, -EINTR
	bne	a0, t0, parent_fail
	li	t0, PARENT_MAGIC
	bne	s0, t0, parent_fail
	la	t0, parent_sp
	lw	t1, 0(t0)
	bne	sp, t1, parent_fail
	la	t0, handler_count
	lw	t1, 0(t0)
	li	t2, 1
	bne	t1, t2, parent_fail
	la	t0, handler_ok
	lw	t1, 0(t0)
	bne	t1, t2, parent_fail
	li	a0, 61
	call	wait_child_status
	bnez	a0, parent_fail
	call	check_fionread_zero
	bnez	a0, parent_fail
	la	a1, signal_msg
	li	a2, signal_msg_len
	call	write_stdout
	la	a1, done_msg
	li	a2, done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	parent_fail

child_signal_read:
	li	a0, 25
	call	sleep_msec
	bnez	a0, child_fail
	li	a7, SYS_GETPPID
	ecall
	li	a1, SIGUSR1
	li	a7, SYS_KILL
	ecall
	bnez	a0, child_fail
	li	a0, 61
	li	a7, SYS_EXIT_GROUP
	ecall
	j	child_fail

fork_one:
	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
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

check_fionread_zero:
	li	a0, 0
	li	a1, FIONREAD
	la	a2, fionread_value
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, check_fionread_done
	la	t0, fionread_value
	lw	t1, 0(t0)
	seqz	a0, t1
	xori	a0, a0, 1
check_fionread_done:
	ret

copy_original_termios:
	la	t0, termios_original
	la	t1, termios_work
	li	t2, 9
1:
	lw	t3, 0(t0)
	sw	t3, 0(t1)
	addi	t0, t0, 4
	addi	t1, t1, 4
	addi	t2, t2, -1
	bnez	t2, 1b
	ret

restore_original_termios:
	li	a0, 0
	li	a1, TCSETSF
	la	a2, termios_original
	li	a7, SYS_IOCTL
	ecall
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

child_fail:
	li	a0, 90
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

parent_fail:
	call	restore_original_termios
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
