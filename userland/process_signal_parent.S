	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_NANOSLEEP, 101
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_RT_SIGPROCMASK, 135
	.equ	SYS_RT_SIGPENDING, 136
	.equ	SYS_RT_SIGRETURN, 139
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17
	.equ	SIG_BLOCK, 0
	.equ	SIG_UNBLOCK, 1
	.equ	SA_SIGINFO, 0x00000004
	.equ	SA_RESTORER, 0x04000000
	.equ	CLD_EXITED, 1
	.equ	PARENT_MAGIC, 0x51a6c8e2
	.equ	CHILD_STATUS, 42
	.equ	SIGSET_SIZE, 8
	.equ	RT_FRAME_UCONTEXT, 128
	.equ	UC_MCONTEXT, 160
	.equ	MC_PC, 0
	.equ	MC_SP, 8
	.equ	MC_A0, 40

	.section .rodata, "a"
start_msg:
	.ascii	"[process-gate-8] userspace installing real SIGCHLD action\n"
	.equ	start_msg_len, . - start_msg
pending_msg:
	.ascii	"[process-gate-8] blocked SIGCHLD visible through rt_sigpending PASS\n"
	.equ	pending_msg_len, . - pending_msg
handler_msg:
	.ascii	"[process-gate-8] SIGCHLD handler entered with siginfo/ucontext PASS\n"
	.equ	handler_msg_len, . - handler_msg
return_msg:
	.ascii	"[process-gate-8] rt_sigreturn restored PC/SP/registers/mask PASS\n"
	.equ	return_msg_len, . - return_msg
wait_msg:
	.ascii	"[process-gate-8] child wait status=42 after handler PASS\n"
	.equ	wait_msg_len, . - wait_msg
fail_msg:
	.ascii	"[process-gate-8] userspace signal-frame scenario FAIL\n"
	.equ	fail_msg_len, . - fail_msg

	.section .data, "aw"
	.align	2
sigchld_action:
	.word	sigchld_handler
	.word	SA_SIGINFO | SA_RESTORER
	.word	sigreturn_restorer
	.word	0
	.word	0
sigchld_set:
	.word	0x00010000
	.word	0

	.section .bss, "aw", @nobits
	.align	2
pending_set:
	.space	8
wait_status:
	.space	4
sleep_req:
	.space	8
parent_pid:
	.space	4
child_pid:
	.space	4
parent_sp:
	.space	4
handler_count:
	.space	4
handler_ok:
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
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	/* Install Linux RV32 k_sigaction: handler, flags, restorer, mask[8]. */
	li	a0, SIGCHLD
	la	a1, sigchld_action
	li	a2, 0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, parent_fail

	/* Hold SIGCHLD until the child has exited and pending state is visible. */
	li	a0, SIG_BLOCK
	la	a1, sigchld_set
	li	a2, 0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGPROCMASK
	ecall
	bnez	a0, parent_fail

	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	beqz	a0, child_main
	bltz	a0, parent_fail
	la	t0, child_pid
	sw	a0, 0(t0)

	li	a0, 80
	call	sleep_msec
	bnez	a0, parent_fail
	la	a0, pending_set
	li	a1, SIGSET_SIZE
	li	a7, SYS_RT_SIGPENDING
	ecall
	bnez	a0, parent_fail
	la	t0, pending_set
	lw	t1, 0(t0)
	li	t2, 0x00010000
	bne	t1, t2, parent_fail
	lw	t1, 4(t0)
	bnez	t1, parent_fail
	la	a1, pending_msg
	li	a2, pending_msg_len
	call	write_stdout

	/* Trap return from this syscall must enter sigchld_handler first. */
	li	a0, SIG_UNBLOCK
	la	a1, sigchld_set
	li	a2, 0
	li	a3, SIGSET_SIZE
	li	a7, SYS_RT_SIGPROCMASK
	ecall
after_unblock:
	bnez	a0, parent_fail
	li	t0, PARENT_MAGIC
	bne	s0, t0, parent_fail
	la	t0, handler_count
	lw	t1, 0(t0)
	li	t2, 1
	bne	t1, t2, parent_fail
	la	t0, handler_ok
	lw	t1, 0(t0)
	bne	t1, t2, parent_fail
	la	t0, parent_sp
	lw	t1, 0(t0)
	bne	sp, t1, parent_fail
	la	a1, handler_msg
	li	a2, handler_msg_len
	call	write_stdout
	la	a1, return_msg
	li	a2, return_msg_len
	call	write_stdout

	/* SIGCHLD was consumed and the handler mask was restored to unblocked. */
	la	t0, pending_set
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	mv	a0, t0
	li	a1, SIGSET_SIZE
	li	a7, SYS_RT_SIGPENDING
	ecall
	bnez	a0, parent_fail
	la	t0, pending_set
	lw	t1, 0(t0)
	bnez	t1, parent_fail
	lw	t1, 4(t0)
	bnez	t1, parent_fail

	la	t0, child_pid
	lw	a0, 0(t0)
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	la	t0, child_pid
	lw	t1, 0(t0)
	bne	a0, t1, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	li	t2, CHILD_STATUS << 8
	bne	t1, t2, parent_fail
	la	a1, wait_msg
	li	a2, wait_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	parent_fail

child_main:
	li	a0, 25
	call	sleep_msec
	bnez	a0, child_fail
	li	a0, CHILD_STATUS
	li	a7, SYS_EXIT_GROUP
	ecall
	j	child_fail

	/* a0=signal, a1=siginfo_t *, a2=ucontext_t *. */
sigchld_handler:
	li	t0, SIGCHLD
	bne	a0, t0, handler_fail
	lw	t1, 0(a1)
	bne	t1, t0, handler_fail
	lw	t1, 8(a1)
	li	t2, CLD_EXITED
	bne	t1, t2, handler_fail
	lw	t1, 12(a1)
	la	t2, child_pid
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, 20(a1)
	li	t2, CHILD_STATUS
	bne	t1, t2, handler_fail

	/* Verify Linux RISC-V ucontext: PC, x2/SP and x10/a0. */
	lw	t1, UC_MCONTEXT + MC_PC(a2)
	la	t2, after_unblock
	bne	t1, t2, handler_fail
	lw	t1, UC_MCONTEXT + MC_SP(a2)
	la	t2, parent_sp
	lw	t2, 0(t2)
	bne	t1, t2, handler_fail
	lw	t1, UC_MCONTEXT + MC_A0(a2)
	bnez	t1, handler_fail

	la	t0, handler_count
	lw	t1, 0(t0)
	addi	t1, t1, 1
	sw	t1, 0(t0)
	la	t0, handler_ok
	li	t1, 1
	sw	t1, 0(t0)
	li	s0, 0
	ret

handler_fail:
	la	t0, handler_ok
	li	t1, -1
	sw	t1, 0(t0)
	li	s0, 0
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
