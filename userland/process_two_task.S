	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17

	.section .rodata, "a"
parent_before_msg:
	.ascii	"[process-gate-3] parent U-mode pid=2 before clone(SIGCHLD)\n"
	.equ	parent_before_msg_len, . - parent_before_msg
parent_wait_msg:
	.ascii	"[process-gate-3] parent clone returned pid=3; entering real wait4\n"
	.equ	parent_wait_msg_len, . - parent_wait_msg
child_msg:
	.ascii	"[process-gate-3] child U-mode pid=3 ppid=2 calling exit_group(9)\n"
	.equ	child_msg_len, . - child_msg
parent_resumed_msg:
	.ascii	"[process-gate-3] parent resumed after child status=9 and continues PASS\n"
	.equ	parent_resumed_msg_len, . - parent_resumed_msg
bad_parent_msg:
	.ascii	"[process-gate-3] parent identity/clone/wait status mismatch FAIL\n"
	.equ	bad_parent_msg_len, . - bad_parent_msg
bad_child_msg:
	.ascii	"[process-gate-3] child identity mismatch FAIL\n"
	.equ	bad_child_msg_len, . - bad_child_msg
returned_msg:
	.ascii	"[process-gate-3] exit_group returned FAIL\n"
	.equ	returned_msg_len, . - returned_msg

	.section .text, "ax"
	.globl	_start
	.type	_start, @function

_start:
	li	a7, SYS_GETPID
	ecall
	li	t0, 2
	bne	a0, t0, bad_parent
	li	a7, SYS_GETPPID
	ecall
	li	t0, 1
	bne	a0, t0, bad_parent

	la	a1, parent_before_msg
	li	a2, parent_before_msg_len
	call	write_stdout

	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	beqz	a0, child_path
	li	t0, 3
	bne	a0, t0, bad_parent
	mv	s0, a0

	la	a1, parent_wait_msg
	li	a2, parent_wait_msg_len
	call	write_stdout
	addi	sp, sp, -16
	sw	zero, 0(sp)
	mv	a0, s0
	mv	a1, sp
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s0, bad_parent_stack
	lw	t0, 0(sp)
	li	t1, 2304
	bne	t0, t1, bad_parent_stack
	addi	sp, sp, 16

	la	a1, parent_resumed_msg
	li	a2, parent_resumed_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

child_path:
	li	a7, SYS_GETPID
	ecall
	li	t0, 3
	bne	a0, t0, bad_child
	li	a7, SYS_GETPPID
	ecall
	li	t0, 2
	bne	a0, t0, bad_child
	la	a1, child_msg
	li	a2, child_msg_len
	call	write_stdout
	li	a0, 9
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

bad_parent_stack:
	addi	sp, sp, 16
bad_parent:
	la	a1, bad_parent_msg
	li	a2, bad_parent_msg_len
	call	write_stdout
	li	a0, 97
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

bad_child:
	la	a1, bad_child_msg
	li	a2, bad_child_msg_len
	call	write_stdout
	li	a0, 96
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
