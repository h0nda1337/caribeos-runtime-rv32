	.equ	SYS_FCNTL, 25
	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_PIPE2, 59
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_CLONE, 220
	.equ	SYS_EXECVE, 221
	.equ	SYS_WAIT4, 260
	.equ	AT_FDCWD, -100
	.equ	O_RDONLY, 0
	.equ	O_CLOEXEC, 0x80000
	.equ	SIGCHLD, 17

	.section .rodata, "a"
fixture_path:
	.asciz	"/usr/lib/process-fd-fixture"
exec_path:
	.asciz	"/bin/process-fd-exec"
pipe_payload:
	.ascii	"PIPE"
parent_open_msg:
	.ascii	"[process-gate-5] parent opened fd3 CLOEXEC and read ABCD offset=4 PASS\n"
	.equ	parent_open_msg_len, . - parent_open_msg
child_read_msg:
	.ascii	"[process-gate-5] child read EFGH through shared OFD and closed fd5 PASS\n"
	.equ	child_read_msg_len, . - child_read_msg
parent_offset_msg:
	.ascii	"[process-gate-5] parent observed shared offset and read IJKL after status=21 PASS\n"
	.equ	parent_offset_msg_len, . - parent_offset_msg
parent_done_msg:
	.ascii	"[process-gate-5] parent close remained independent; user fd scenario PASS\n"
	.equ	parent_done_msg_len, . - parent_done_msg
parent_fail_msg:
	.ascii	"[process-gate-5] parent fd/OFD scenario FAIL\n"
	.equ	parent_fail_msg_len, . - parent_fail_msg
child_fail_msg:
	.ascii	"[process-gate-5] child fd/OFD scenario FAIL\n"
	.equ	child_fail_msg_len, . - child_fail_msg
returned_msg:
	.ascii	"[process-gate-5] exit_group returned FAIL\n"
	.equ	returned_msg_len, . - returned_msg

	.section .data, "aw"
	.align	2
exec_argv:
	.word	exec_path
	.word	0
exec_envp:
	.word	0

	.section .bss, "aw", @nobits
	.align	2
parent_buffer:
	.space	8
child_buffer:
	.space	8
pipe_fds:
	.space	8
wait_status:
	.space	4

	.section .text, "ax"
	.globl	_start
	.type	_start, @function

_start:
	li	a0, AT_FDCWD
	la	a1, fixture_path
	li	a2, O_RDONLY | O_CLOEXEC
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	li	t0, 3
	bne	a0, t0, parent_fail
	mv	s1, a0

	mv	a0, s1
	la	a1, parent_buffer
	li	a2, 4
	li	a7, SYS_READ
	ecall
	li	t0, 4
	bne	a0, t0, parent_fail
	la	t0, parent_buffer
	lw	t1, 0(t0)
	li	t2, 0x44434241
	bne	t1, t2, parent_fail
	la	a1, parent_open_msg
	li	a2, parent_open_msg_len
	call	write_stdout

	la	a0, pipe_fds
	li	a1, 0
	li	a7, SYS_PIPE2
	ecall
	bnez	a0, parent_fail
	la	t0, pipe_fds
	lw	s3, 0(t0)
	lw	s4, 4(t0)
	li	t1, 4
	bne	s3, t1, parent_fail
	li	t1, 5
	bne	s4, t1, parent_fail
	mv	a0, s4
	la	a1, pipe_payload
	li	a2, 4
	li	a7, SYS_WRITE
	ecall
	li	t0, 4
	bne	a0, t0, parent_fail

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

	mv	a0, s3
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, parent_fail
	mv	a0, s4
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, parent_fail

	mv	a0, s2
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s2, parent_fail
	la	t0, wait_status
	lw	t1, 0(t0)
	li	t2, 5376
	bne	t1, t2, parent_fail

	mv	a0, s1
	la	a1, parent_buffer
	li	a2, 4
	li	a7, SYS_READ
	ecall
	li	t0, 4
	bne	a0, t0, parent_fail
	la	t0, parent_buffer
	lw	t1, 0(t0)
	li	t2, 0x4c4b4a49
	bne	t1, t2, parent_fail
	la	a1, parent_offset_msg
	li	a2, parent_offset_msg_len
	call	write_stdout

	mv	a0, s1
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, parent_fail
	la	a1, parent_done_msg
	li	a2, parent_done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

child_path:
	mv	a0, s1
	la	a1, child_buffer
	li	a2, 4
	li	a7, SYS_READ
	ecall
	li	t0, 4
	bne	a0, t0, child_fail
	la	t0, child_buffer
	lw	t1, 0(t0)
	li	t2, 0x48474645
	bne	t1, t2, child_fail
	mv	a0, s4
	li	a7, SYS_CLOSE
	ecall
	bnez	a0, child_fail
	la	a1, child_read_msg
	li	a2, child_read_msg_len
	call	write_stdout
	la	a0, exec_path
	la	a1, exec_argv
	la	a2, exec_envp
	li	a7, SYS_EXECVE
	ecall
	j	child_fail

parent_fail:
	la	a1, parent_fail_msg
	li	a2, parent_fail_msg_len
	call	write_stdout
	li	a0, 93
	li	a7, SYS_EXIT_GROUP
	ecall
	j	exit_returned

child_fail:
	la	a1, child_fail_msg
	li	a2, child_fail_msg_len
	call	write_stdout
	li	a0, 92
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
