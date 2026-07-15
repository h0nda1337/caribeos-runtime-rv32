	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_EXECVE, 221

	.section .rodata, "a"
start_msg:
	.ascii	"[stage1-init] CaribeOS userspace handoff\n"
	.equ	start_msg_len, . - start_msg
exec_msg:
	.ascii	"[stage1-init] exec /sbin/init\n"
	.equ	exec_msg_len, . - exec_msg
interactive_exec_msg:
	.ascii	"[stage1-init] exec /sbin/interactive-init\n"
	.equ	interactive_exec_msg_len, . - interactive_exec_msg
fail_msg:
	.ascii	"[stage1-init] exec failed\n"
	.equ	fail_msg_len, . - fail_msg
init_path:
	.asciz	"/sbin/init"
init_arg1:
	.asciz	"--system"
interactive_arg:
	.asciz	"--interactive"
interactive_path:
	.asciz	"/sbin/interactive-init"
env0:
	.asciz	"HOME=/"
env1:
	.asciz	"PATH=/sbin:/bin"
env2:
	.asciz	"CARIBE_STAGE=stage1"
env3:
	.asciz	"CBX_CHAIN=OpenSBI-CaribeBootX-XNU"
	.balign	4
init_argv:
	.word	init_path
	.word	init_arg1
	.word	0
interactive_argv:
	.word	interactive_path
	.word	0
init_envp:
	.word	env0
	.word	env1
	.word	env2
	.word	env3
	.word	0

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	mv	s0, sp
	li	s1, 0
	lw	t0, 0(s0)
	li	t1, 2
	bltu	t0, t1, 1f
	lw	a0, 8(s0)
	la	a1, interactive_arg
	call	streq
	mv	s1, a0
1:
	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout
	bnez	s1, interactive_exec

	la	a1, exec_msg
	li	a2, exec_msg_len
	call	write_stdout

	la	a0, init_path
	la	a1, init_argv
	la	a2, init_envp
	li	a7, SYS_EXECVE
	ecall
	j	exec_failed

interactive_exec:
	la	a1, interactive_exec_msg
	li	a2, interactive_exec_msg_len
	call	write_stdout

	la	a0, interactive_path
	la	a1, interactive_argv
	la	a2, init_envp
	li	a7, SYS_EXECVE
	ecall

exec_failed:
	la	a1, fail_msg
	li	a2, fail_msg_len
	call	write_stdout
	li	a0, 1
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
	ret

streq:
	beqz	a0, 2f
1:
	lbu	t0, 0(a0)
	lbu	t1, 0(a1)
	bne	t0, t1, 2f
	beqz	t0, 3f
	addi	a0, a0, 1
	addi	a1, a1, 1
	j	1b
2:
	li	a0, 0
	ret
3:
	li	a0, 1
	ret
