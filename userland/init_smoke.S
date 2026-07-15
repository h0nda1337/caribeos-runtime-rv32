/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	AT_FDCWD, -100
	.equ	O_RDONLY, 0
	.equ	F_OK, 0
	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_GETDENTS64, 61
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_FACCESSAT, 48
	.equ	SYS_READLINKAT, 78
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_UNAME, 160
	.equ	SYS_GETPID, 172
	.equ	SYS_EXECVE, 221
	.equ	SYS_STATX, 291
	.equ	STATX_BASIC_STATS, 0x000007ff

	.section .rodata, "a"
init_msg:
	.ascii	"[stage1-init] CaribeOS stage1 seed under XNU-CaribeOS\n"
	.equ	init_msg_len, . - init_msg
getpid_msg:
	.ascii	"[initrd-init] getpid ok\n"
	.equ	getpid_msg_len, . - getpid_msg
uname_msg:
	.ascii	"[initrd-init] uname ok\n"
	.equ	uname_msg_len, . - uname_msg
proc_version_msg:
	.ascii	"[initrd-init] /proc/version: "
	.equ	proc_version_msg_len, . - proc_version_msg
proc_cpuinfo_msg:
	.ascii	"[initrd-init] /proc/cpuinfo:\n"
	.equ	proc_cpuinfo_msg_len, . - proc_cpuinfo_msg
proc_meminfo_msg:
	.ascii	"[initrd-init] /proc/meminfo:\n"
	.equ	proc_meminfo_msg_len, . - proc_meminfo_msg
proc_caribeos_msg:
	.ascii	"[initrd-init] /proc/caribeos:\n"
	.equ	proc_caribeos_msg_len, . - proc_caribeos_msg
proc_mounts_msg:
	.ascii	"[stage1-init] /proc/mounts:\n"
	.equ	proc_mounts_msg_len, . - proc_mounts_msg
proc_filesystems_msg:
	.ascii	"[stage1-init] /proc/filesystems:\n"
	.equ	proc_filesystems_msg_len, . - proc_filesystems_msg
getdents_msg:
	.ascii	"[initrd-init] getdents64(/proc) ok\n"
	.equ	getdents_msg_len, . - getdents_msg
readlink_msg:
	.ascii	"[initrd-init] readlink(/proc/self/exe): "
	.equ	readlink_msg_len, . - readlink_msg
stage1_msg:
	.ascii	"[stage1-init] initrd VFS online\n"
	.equ	stage1_msg_len, . - stage1_msg
etc_os_release_msg:
	.ascii	"[stage1-init] /etc/os-release:\n"
	.equ	etc_os_release_msg_len, . - etc_os_release_msg
etc_caribe_release_msg:
	.ascii	"[stage1-init] /etc/caribe-release:\n"
	.equ	etc_caribe_release_msg_len, . - etc_caribe_release_msg
manifest_msg:
	.ascii	"[stage1-init] /caribe/stage1.manifest:\n"
	.equ	manifest_msg_len, . - manifest_msg
root_dents_msg:
	.ascii	"[stage1-init] getdents64(/) ok\n"
	.equ	root_dents_msg_len, . - root_dents_msg
etc_dents_msg:
	.ascii	"[stage1-init] getdents64(/etc) ok\n"
	.equ	etc_dents_msg_len, . - etc_dents_msg
caribe_dents_msg:
	.ascii	"[stage1-init] getdents64(/caribe) ok\n"
	.equ	caribe_dents_msg_len, . - caribe_dents_msg
bin_dents_msg:
	.ascii	"[stage1-init] getdents64(/bin) ok\n"
	.equ	bin_dents_msg_len, . - bin_dents_msg
faccess_msg:
	.ascii	"[stage1-init] faccessat(/caribe/stage1.manifest) ok\n"
	.equ	faccess_msg_len, . - faccess_msg
statx_msg:
	.ascii	"[stage1-init] statx(/etc/os-release) ok\n"
	.equ	statx_msg_len, . - statx_msg
execve_msg:
	.ascii	"[stage1-init] execve(/bin/caribectl)\n"
	.equ	execve_msg_len, . - execve_msg
done_msg:
	.ascii	"[stage1-init] stage1 smoke complete\n"
	.equ	done_msg_len, . - done_msg
fail_msg:
	.ascii	"[stage1-init] stage1 smoke failed\n"
	.equ	fail_msg_len, . - fail_msg
newline:
	.ascii	"\n"
	.equ	newline_len, . - newline
root_path:
	.asciz	"/"
bin_path:
	.asciz	"/bin"
etc_path:
	.asciz	"/etc"
caribe_path:
	.asciz	"/caribe"
proc_version_path:
	.asciz	"/proc/version"
proc_cpuinfo_path:
	.asciz	"/proc/cpuinfo"
proc_meminfo_path:
	.asciz	"/proc/meminfo"
proc_caribeos_path:
	.asciz	"/proc/caribeos"
proc_mounts_path:
	.asciz	"/proc/mounts"
proc_filesystems_path:
	.asciz	"/proc/filesystems"
proc_path:
	.asciz	"/proc"
proc_self_exe_path:
	.asciz	"/proc/self/exe"
etc_os_release_path:
	.asciz	"/etc/os-release"
etc_caribe_release_path:
	.asciz	"/etc/caribe-release"
caribe_stage1_manifest_path:
	.asciz	"/caribe/stage1.manifest"
bin_caribectl_path:
	.asciz	"/bin/caribectl"
exec_arg1:
	.asciz	"--from-init"
exec_env0:
	.asciz	"CARIBE_STAGE=stage1"
exec_env1:
	.asciz	"CBX_CHAIN=OpenSBI-CaribeBootX-XNU"
	.balign	4
exec_argv:
	.word	bin_caribectl_path
	.word	exec_arg1
	.word	0
exec_envp:
	.word	exec_env0
	.word	exec_env1
	.word	0

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	la	a1, init_msg
	li	a2, init_msg_len
	call	write_stdout

	li	a7, SYS_GETPID
	ecall
	bltz	a0, fail
	la	a1, getpid_msg
	li	a2, getpid_msg_len
	call	write_stdout

	la	a0, uts_buf
	li	a7, SYS_UNAME
	ecall
	bnez	a0, fail
	la	a1, uname_msg
	li	a2, uname_msg_len
	call	write_stdout

	li	a0, AT_FDCWD
	la	a1, proc_version_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0

	la	a1, proc_version_msg
	li	a2, proc_version_msg_len
	call	write_stdout

	mv	a0, s0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, AT_FDCWD
	la	a1, proc_cpuinfo_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	la	a1, proc_cpuinfo_msg
	li	a2, proc_cpuinfo_msg_len
	call	write_stdout
	mv	a0, s0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, AT_FDCWD
	la	a1, proc_meminfo_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	la	a1, proc_meminfo_msg
	li	a2, proc_meminfo_msg_len
	call	write_stdout
	mv	a0, s0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, AT_FDCWD
	la	a1, proc_caribeos_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	la	a1, proc_caribeos_msg
	li	a2, proc_caribeos_msg_len
	call	write_stdout
	mv	a0, s0
	call	read_fd_to_stdout
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a0, proc_mounts_path
	la	a1, proc_mounts_msg
	li	a2, proc_mounts_msg_len
	call	read_path_to_stdout

	la	a0, proc_filesystems_path
	la	a1, proc_filesystems_msg
	li	a2, proc_filesystems_msg_len
	call	read_path_to_stdout

	li	a0, AT_FDCWD
	la	a1, proc_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	mv	a0, s0
	la	a1, dents_buf
	li	a2, 256
	li	a7, SYS_GETDENTS64
	ecall
	bge	zero, a0, fail
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	la	a1, getdents_msg
	li	a2, getdents_msg_len
	call	write_stdout

	li	a0, AT_FDCWD
	la	a1, proc_self_exe_path
	la	a2, io_buf
	li	a3, 160
	li	a7, SYS_READLINKAT
	ecall
	bge	zero, a0, fail
	mv	s1, a0
	la	a1, readlink_msg
	li	a2, readlink_msg_len
	call	write_stdout
	li	a0, 1
	la	a1, io_buf
	mv	a2, s1
	li	a7, SYS_WRITE
	ecall
	la	a1, newline
	li	a2, newline_len
	call	write_stdout

	la	a1, stage1_msg
	li	a2, stage1_msg_len
	call	write_stdout

	la	a0, etc_os_release_path
	la	a1, etc_os_release_msg
	li	a2, etc_os_release_msg_len
	call	read_path_to_stdout

	la	a0, etc_caribe_release_path
	la	a1, etc_caribe_release_msg
	li	a2, etc_caribe_release_msg_len
	call	read_path_to_stdout

	la	a0, caribe_stage1_manifest_path
	la	a1, manifest_msg
	li	a2, manifest_msg_len
	call	read_path_to_stdout

	la	a0, root_path
	la	a1, root_dents_msg
	li	a2, root_dents_msg_len
	call	getdents_path

	la	a0, etc_path
	la	a1, etc_dents_msg
	li	a2, etc_dents_msg_len
	call	getdents_path

	la	a0, caribe_path
	la	a1, caribe_dents_msg
	li	a2, caribe_dents_msg_len
	call	getdents_path

	la	a0, bin_path
	la	a1, bin_dents_msg
	li	a2, bin_dents_msg_len
	call	getdents_path

	la	a0, caribe_stage1_manifest_path
	la	a1, faccess_msg
	li	a2, faccess_msg_len
	call	faccess_path

	la	a0, etc_os_release_path
	la	a1, statx_msg
	li	a2, statx_msg_len
	call	statx_path

	la	a1, execve_msg
	li	a2, execve_msg_len
	call	write_stdout

	la	a0, bin_caribectl_path
	la	a1, exec_argv
	la	a2, exec_envp
	li	a7, SYS_EXECVE
	ecall
	j	fail

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

read_fd_to_stdout:
	mv	a0, s0
	la	a1, io_buf
	li	a2, 512
	li	a7, SYS_READ
	ecall
	bltz	a0, fail
	beqz	a0, 2f
	mv	s1, a0
	li	a0, 1
	la	a1, io_buf
	mv	a2, s1
	li	a7, SYS_WRITE
	ecall
	bltz	a0, fail
	j	read_fd_to_stdout
2:
	ret

read_path_to_stdout:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s2, a0
	mv	s3, a1
	mv	s4, a2
	mv	a1, s3
	mv	a2, s4
	call	write_stdout
	li	a0, AT_FDCWD
	mv	a1, s2
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
	mv	s2, a0
	mv	s3, a1
	mv	s4, a2
	li	a0, AT_FDCWD
	mv	a1, s2
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
	mv	a1, s3
	mv	a2, s4
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

faccess_path:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s2, a0
	mv	s3, a1
	mv	s4, a2
	li	a0, AT_FDCWD
	mv	a1, s2
	li	a2, F_OK
	li	a3, 0
	li	a7, SYS_FACCESSAT
	ecall
	bltz	a0, fail
	mv	a1, s3
	mv	a2, s4
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

statx_path:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s2, a0
	mv	s3, a1
	mv	s4, a2
	li	a0, AT_FDCWD
	mv	a1, s2
	li	a2, 0
	li	a3, STATX_BASIC_STATS
	la	a4, statx_buf
	li	a7, SYS_STATX
	ecall
	bltz	a0, fail
	mv	a1, s3
	mv	a2, s4
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

	.section .bss, "aw", @nobits
	.balign	16
uts_buf:
	.skip	390
io_buf:
	.skip	512
dents_buf:
	.skip	512
statx_buf:
	.skip	256
