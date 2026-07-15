	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_GETPID, 172

	.section .rodata, "a"
entry_msg:
	.ascii	"[process-gate-2] child U-mode pid=2 calling exit_group(7)\n"
	.equ	entry_msg_len, . - entry_msg
bad_pid_msg:
	.ascii	"[process-gate-2] child getpid mismatch FAIL\n"
	.equ	bad_pid_msg_len, . - bad_pid_msg
returned_msg:
	.ascii	"[process-gate-2] exit_group returned FAIL\n"
	.equ	returned_msg_len, . - returned_msg

	.section .text, "ax"
	.globl	_start
	.type	_start, @function

_start:
	li	a7, SYS_GETPID
	ecall
	li	t0, 2
	bne	a0, t0, bad_pid

	la	a1, entry_msg
	li	a2, entry_msg_len
	call	write_stdout
	li	a0, 7
	li	a7, SYS_EXIT_GROUP
	ecall

	la	a1, returned_msg
	li	a2, returned_msg_len
	call	write_stdout
	li	a0, 99
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

bad_pid:
	la	a1, bad_pid_msg
	li	a2, bad_pid_msg_len
	call	write_stdout
	li	a0, 98
	li	a7, SYS_EXIT_GROUP
	ecall
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
