/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	AT_FDCWD, -100
	.equ	O_RDONLY, 0
	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_GETDENTS64, 61
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_GETPID, 172
	.equ	SYS_BRK, 214
	.equ	SYS_CLONE, 220
	.equ	SYS_WAIT4, 260
	.equ	SIGCHLD, 17

	.section .rodata, "a"
hello_msg:
	.ascii	"[stage1-caribectl] execve target reached\n"
	.equ	hello_msg_len, . - hello_msg
pid_msg:
	.ascii	"[stage1-caribectl] getpid ok\n"
	.equ	pid_msg_len, . - pid_msg
argv0_msg:
	.ascii	"[stage1-caribectl] argv0: "
	.equ	argv0_msg_len, . - argv0_msg
argv1_msg:
	.ascii	"[stage1-caribectl] argv1: "
	.equ	argv1_msg_len, . - argv1_msg
env0_msg:
	.ascii	"[stage1-caribectl] env0: "
	.equ	env0_msg_len, . - env0_msg
env1_msg:
	.ascii	"[stage1-caribectl] env1: "
	.equ	env1_msg_len, . - env1_msg
brk_msg:
	.ascii	"[stage1-caribectl] brk heap ok\n"
	.equ	brk_msg_len, . - brk_msg
usr_dents_msg:
	.ascii	"[stage1-caribectl] getdents64(/usr) ok\n"
	.equ	usr_dents_msg_len, . - usr_dents_msg
usr_lib_dents_msg:
	.ascii	"[stage1-caribectl] getdents64(/usr/lib) ok\n"
	.equ	usr_lib_dents_msg_len, . - usr_lib_dents_msg
note_msg:
	.ascii	"[stage1-caribectl] /usr/lib/caribe.note:\n"
	.equ	note_msg_len, . - note_msg
clone_wait_msg:
	.ascii	"[stage1-caribectl] clone/wait4 real child task ok\n"
	.equ	clone_wait_msg_len, . - clone_wait_msg
manifest_msg:
	.ascii	"[stage1-caribectl] manifest after exec:\n"
	.equ	manifest_msg_len, . - manifest_msg
done_msg:
	.ascii	"[stage1-caribectl] done\n"
	.equ	done_msg_len, . - done_msg
fail_msg:
	.ascii	"[stage1-caribectl] failed\n"
	.equ	fail_msg_len, . - fail_msg
newline:
	.ascii	"\n"
	.equ	newline_len, . - newline
manifest_path:
	.asciz	"/caribe/stage1.manifest"
usr_path:
	.asciz	"/usr"
usr_lib_path:
	.asciz	"/usr/lib"
usr_lib_note_path:
	.asciz	"/usr/lib/caribe.note"

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	mv	s2, sp

	la	a1, hello_msg
	li	a2, hello_msg_len
	call	write_stdout

	li	a7, SYS_GETPID
	ecall
	bltz	a0, fail
	la	a1, pid_msg
	li	a2, pid_msg_len
	call	write_stdout

	la	a1, argv0_msg
	li	a2, argv0_msg_len
	call	write_stdout
	lw	a1, 4(s2)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, argv1_msg
	li	a2, argv1_msg_len
	call	write_stdout
	lw	a1, 8(s2)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, env0_msg
	li	a2, env0_msg_len
	call	write_stdout
	lw	a1, 16(s2)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, env1_msg
	li	a2, env1_msg_len
	call	write_stdout
	lw	a1, 20(s2)
	call	write_cstr_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	li	a0, 0
	li	a7, SYS_BRK
	ecall
	beqz	a0, fail
	mv	s3, a0
	li	t0, 4096
	add	a0, s3, t0
	li	a7, SYS_BRK
	ecall
	add	t1, s3, t0
	bne	a0, t1, fail
	li	t2, 0x43
	sb	t2, 0(s3)
	la	a1, brk_msg
	li	a2, brk_msg_len
	call	write_stdout

	la	a0, usr_path
	la	a1, usr_dents_msg
	li	a2, usr_dents_msg_len
	call	getdents_path

	la	a0, usr_lib_path
	la	a1, usr_lib_dents_msg
	li	a2, usr_lib_dents_msg_len
	call	getdents_path

	la	a0, usr_lib_note_path
	la	a1, note_msg
	li	a2, note_msg_len
	call	read_path_to_stdout

	li	a0, SIGCHLD
	li	a1, 0
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_CLONE
	ecall
	bnez	a0, 1f
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
	j	fail
1:
	bltz	a0, fail
	mv	s7, a0
	mv	a0, s7
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s7, fail
	lw	t0, wait_status
	bnez	t0, fail
	la	a1, clone_wait_msg
	li	a2, clone_wait_msg_len
	call	write_stdout

	la	a1, manifest_msg
	li	a2, manifest_msg_len
	call	write_stdout

	li	a0, AT_FDCWD
	la	a1, manifest_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a1, done_msg
	li	a2, done_msg_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall

fail:
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

write_cstr_stdout:
	beqz	a1, 2f
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	t0, a1
	li	t1, 0
1:
	lbu	t2, 0(t0)
	beqz	t2, 3f
	addi	t0, t0, 1
	addi	t1, t1, 1
	j	1b
3:
	li	a0, 1
	mv	a2, t1
	li	a7, SYS_WRITE
	ecall
	lw	ra, 12(sp)
	addi	sp, sp, 16
2:
	ret

read_fd_to_stdout:
	addi	sp, sp, -16
	sw	ra, 12(sp)
2:
	mv	a0, s0
	la	a1, io_buf
	li	a2, 512
	li	a7, SYS_READ
	ecall
	bltz	a0, fail
	beqz	a0, 3f
	mv	s1, a0
	li	a0, 1
	la	a1, io_buf
	mv	a2, s1
	li	a7, SYS_WRITE
	ecall
	bltz	a0, fail
	j	2b
3:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_path_to_stdout:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s4, a0
	mv	s5, a1
	mv	s6, a2
	mv	a1, s5
	mv	a2, s6
	call	write_stdout
	li	a0, AT_FDCWD
	mv	a1, s4
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

getdents_path:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s4, a0
	mv	s5, a1
	mv	s6, a2
	li	a0, AT_FDCWD
	mv	a1, s4
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	mv	a0, s0
	la	a1, dents_buf
	li	a2, 512
	li	a7, SYS_GETDENTS64
	ecall
	bge	zero, a0, fail
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	mv	a1, s5
	mv	a2, s6
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

	.section .bss, "aw", @nobits
	.balign	16
io_buf:
	.skip	512
dents_buf:
	.skip	512
wait_status:
	.skip	4
