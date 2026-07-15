	.equ	SYS_FCNTL, 25
	.equ	SYS_GETCWD, 17
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_GETPGID, 155
	.equ	SYS_GETSID, 156
	.equ	SYS_UMASK, 166
	.equ	SYS_GETPID, 172
	.equ	SYS_GETPPID, 173
	.equ	SYS_GETUID, 174
	.equ	SYS_GETEUID, 175
	.equ	SYS_GETGID, 176
	.equ	SYS_GETEGID, 177
	.equ	F_GETFD, 1
	.equ	EBADF, 9
	.equ	SIGUSR1, 10
	.equ	SIGUSR2, 12

	.section .rodata, "a"
expected_path:
	.asciz	"/bin/process-exec-child"
expected_arg:
	.asciz	"first"
expected_env:
	.asciz	"GATE6=transactional"
first_msg:
	.ascii	"[process-gate-6] exec image verified identity/argv/env/cwd/umask/credentials/signals/CLOEXEC PASS\n"
	.equ	first_msg_len, . - first_msg
fail_msg:
	.ascii	"[process-gate-6] exec image invariant FAIL\n"
	.equ	fail_msg_len, . - fail_msg

	.section .bss, "aw", @nobits
	.align	2
cwd_buffer:
	.space	64
old_custom:
	.space	24
old_ignored:
	.space	24

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	lw	s0, 0(sp)
	li	t0, 1
	beq	s0, t0, argc_ok
	li	t0, 2
	bne	s0, t0, fail
argc_ok:
	lw	a0, 4(sp)
	la	a1, expected_path
	call	streq
	beqz	a0, fail
	li	t0, 2
	bne	s0, t0, argv_done
	lw	a0, 8(sp)
	la	a1, expected_arg
	call	streq
	beqz	a0, fail
argv_done:
	addi	t0, s0, 2
	slli	t0, t0, 2
	add	t0, sp, t0
	lw	a0, 0(t0)
	la	a1, expected_env
	call	streq
	beqz	a0, fail
	lw	t1, 4(t0)
	bnez	t1, fail

	li	a7, SYS_GETPID
	ecall
	li	t0, 2
	ble	a0, t0, fail
	li	a7, SYS_GETPPID
	ecall
	li	t0, 2
	bne	a0, t0, fail
	la	a0, cwd_buffer
	li	a1, 64
	li	a7, SYS_GETCWD
	ecall
	li	t0, 5
	bne	a0, t0, fail
	la	t0, cwd_buffer
	lbu	t1, 0(t0)
	li	t2, '/'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'u'
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 's'
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 'r'
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	bnez	t1, fail

	li	a0, 027
	li	a7, SYS_UMASK
	ecall
	li	t0, 027
	bne	a0, t0, fail
	li	a7, SYS_GETUID
	ecall
	bnez	a0, fail
	li	a7, SYS_GETEUID
	ecall
	bnez	a0, fail
	li	a7, SYS_GETGID
	ecall
	bnez	a0, fail
	li	a7, SYS_GETEGID
	ecall
	bnez	a0, fail
	li	a0, 0
	li	a7, SYS_GETPGID
	ecall
	li	t0, 2
	bne	a0, t0, fail
	li	a0, 0
	li	a7, SYS_GETSID
	ecall
	li	t0, 2
	bne	a0, t0, fail

	li	a0, SIGUSR1
	li	a1, 0
	la	a2, old_custom
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, fail
	la	t0, old_custom
	lw	t1, 0(t0)
	bnez	t1, fail
	li	a0, SIGUSR2
	li	a1, 0
	la	a2, old_ignored
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, fail
	la	t0, old_ignored
	lw	t1, 0(t0)
	li	t2, 1
	bne	t1, t2, fail

	li	a0, 3
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, -EBADF
	bne	a0, t0, fail
	li	t0, 2
	bne	s0, t0, exit_ok
	la	a1, first_msg
	li	a2, first_msg_len
	call	write_stdout
exit_ok:
	li	a0, 23
	li	a7, SYS_EXIT_GROUP
	ecall
	j	fail

fail:
	la	a1, fail_msg
	li	a2, fail_msg_len
	call	write_stdout
	li	a0, 91
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

streq:
1:
	lbu	t3, 0(a0)
	lbu	t4, 0(a1)
	bne	t3, t4, 2f
	beqz	t3, 3f
	addi	a0, a0, 1
	addi	a1, a1, 1
	j	1b
2:
	li	a0, 0
	ret
3:
	li	a0, 1
	ret

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret
