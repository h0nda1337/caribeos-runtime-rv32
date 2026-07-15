	.equ	SYS_FCNTL, 25
	.equ	SYS_CLOSE, 57
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	F_GETFD, 1
	.equ	EBADF, 9

	.section .rodata, "a"
cloexec_msg:
	.ascii	"[process-gate-5] exec kept process identity and removed CLOEXEC fd3 PASS\n"
	.equ	cloexec_msg_len, . - cloexec_msg
pipe_msg:
	.ascii	"[process-gate-5] exec image read PIPE from inherited fd4 PASS\n"
	.equ	pipe_msg_len, . - pipe_msg
fail_msg:
	.ascii	"[process-gate-5] exec image descriptor verification FAIL\n"
	.equ	fail_msg_len, . - fail_msg
returned_msg:
	.ascii	"[process-gate-5] exec image exit_group returned FAIL\n"
	.equ	returned_msg_len, . - returned_msg

	.section .bss, "aw", @nobits
	.align	2
pipe_buffer:
	.space	8

	.section .text, "ax"
	.globl	_start
	.type	_start, @function

_start:
	li	a0, 3
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, -EBADF
	bne	a0, t0, fail
	li	a0, 5
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, -EBADF
	bne	a0, t0, fail
	la	a1, cloexec_msg
	li	a2, cloexec_msg_len
	call	write_stdout

	li	a0, 4
	la	a1, pipe_buffer
	li	a2, 4
	li	a7, SYS_READ
	ecall
	li	t0, 4
	bne	a0, t0, fail
	la	t0, pipe_buffer
	lw	t1, 0(t0)
	li	t2, 0x45504950
	bne	t1, t2, fail
	la	a1, pipe_msg
	li	a2, pipe_msg_len
	call	write_stdout
	li	a0, 4
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, fail
	li	a0, 21
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

fail:
	la	a1, fail_msg
	li	a2, fail_msg_len
	call	write_stdout
	li	a0, 91
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
