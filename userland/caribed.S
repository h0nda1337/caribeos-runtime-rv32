/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	AT_FDCWD, -100
	.equ	AT_EMPTY_PATH, 0x1000
	.equ	O_RDONLY, 0
	.equ	O_WRONLY, 1
	.equ	O_RDWR, 2
	.equ	O_NONBLOCK, 0x800
	.equ	O_CLOEXEC, 0x80000
	.equ	FD_CLOEXEC, 1
	.equ	F_DUPFD_CLOEXEC, 1030
	.equ	F_GETFD, 1
	.equ	F_SETFD, 2
	.equ	F_GETFL, 3
	.equ	F_SETFL, 4
	.equ	SEEK_SET, 0
	.equ	SEEK_CUR, 1
	.equ	SYS_GETCWD, 17
	.equ	SYS_DUP, 23
	.equ	SYS_DUP3, 24
	.equ	SYS_FCNTL, 25
	.equ	SYS_STATFS64, 43
	.equ	SYS_FSTATFS64, 44
	.equ	SYS_FACCESSAT, 48
	.equ	SYS_OPENAT, 56
	.equ	SYS_CLOSE, 57
	.equ	SYS_PIPE2, 59
	.equ	SYS_GETDENTS64, 61
	.equ	SYS_LLSEEK, 62
	.equ	SYS_READ, 63
	.equ	SYS_WRITE, 64
	.equ	SYS_READV, 65
	.equ	SYS_WRITEV, 66
	.equ	SYS_PREAD64, 67
	.equ	SYS_PPOLL, 73
	.equ	SYS_READLINKAT, 78
	.equ	SYS_IOCTL, 29
	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_WAITID, 95
	.equ	SYS_NANOSLEEP, 101
	.equ	SYS_CLOCK_GETTIME, 113
	.equ	SYS_CLOCK_GETRES, 114
	.equ	SYS_CLOCK_NANOSLEEP, 115
	.equ	SYS_SCHED_YIELD, 124
	.equ	SYS_KILL, 129
	.equ	SYS_SIGALTSTACK, 132
	.equ	SYS_RT_SIGACTION, 134
	.equ	SYS_RT_SIGPROCMASK, 135
	.equ	SYS_RT_SIGPENDING, 136
	.equ	SYS_TIMES, 153
	.equ	SYS_UNAME, 160
	.equ	SYS_GETRUSAGE, 165
	.equ	SYS_UMASK, 166
	.equ	SYS_GETTIMEOFDAY, 169
	.equ	SYS_SETPGID, 154
	.equ	SYS_GETPGID, 155
	.equ	SYS_GETSID, 156
	.equ	SYS_GETPID, 172
	.equ	SYS_BRK, 214
	.equ	SYS_CHDIR, 49
	.equ	SYS_MUNMAP, 215
	.equ	SYS_CLONE, 220
	.equ	SYS_EXECVE, 221
	.equ	SYS_MMAP, 222
	.equ	SYS_MPROTECT, 226
	.equ	SYS_MINCORE, 232
	.equ	SYS_WAIT4, 260
	.equ	SYS_PRLIMIT64, 261
	.equ	SYS_EXECVEAT, 281
	.equ	RLIMIT_NOFILE, 7
	.equ	RUSAGE_SELF, 0
	.equ	CLOCK_REALTIME, 0
	.equ	CLOCK_MONOTONIC, 1
	.equ	SIGCHLD, 17
	.equ	PROT_READ, 1
	.equ	PROT_WRITE, 2
	.equ	MAP_PRIVATE, 2
	.equ	MAP_ANONYMOUS, 32
	.equ	TCGETS, 0x5401
	.equ	TIOCGPGRP, 0x540f
	.equ	TIOCGWINSZ, 0x5413
	.equ	POLLIN, 0x0001
	.equ	P_ALL, 0
	.equ	P_PID, 1
	.equ	WEXITED, 4
	.equ	WNOWAIT, 0x01000000
	.equ	CLD_EXITED, 1
	.equ	SIG_BLOCK, 0
	.equ	SIG_SETMASK, 2
	.equ	SIG_IGN, 1

	.section .rodata, "a"
start_msg:
	.ascii	"[stage1-caribed] CaribeOS init started\n"
	.equ	start_msg_len, . - start_msg
pid_msg:
	.ascii	"[stage1-caribed] pid ready\n"
	.equ	pid_msg_len, . - pid_msg
argv0_msg:
	.ascii	"[stage1-caribed] argv0: "
	.equ	argv0_msg_len, . - argv0_msg
argv1_msg:
	.ascii	"[stage1-caribed] argv1: "
	.equ	argv1_msg_len, . - argv1_msg
env0_msg:
	.ascii	"[stage1-caribed] env0: "
	.equ	env0_msg_len, . - env0_msg
env1_msg:
	.ascii	"[stage1-caribed] env1: "
	.equ	env1_msg_len, . - env1_msg
heap_msg:
	.ascii	"[stage1-caribed] heap online\n"
	.equ	heap_msg_len, . - heap_msg
tty_abi_msg:
	.ascii	"[stage1-caribed] tty/null ABI ok for bash bring-up\n"
	.equ	tty_abi_msg_len, . - tty_abi_msg
cwd_abi_msg:
	.ascii	"[stage1-caribed] chdir/getcwd ABI ok for shell cd\n"
	.equ	cwd_abi_msg_len, . - cwd_abi_msg
pipe_abi_msg:
	.ascii	"[stage1-caribed] pipe/read/writev/ppoll ABI ok for shell pipelines\n"
	.equ	pipe_abi_msg_len, . - pipe_abi_msg
seek_readv_abi_msg:
	.ascii	"[stage1-caribed] llseek/readv/pread64 ABI ok for shell file reads\n"
	.equ	seek_readv_abi_msg_len, . - seek_readv_abi_msg
fdlink_abi_msg:
	.ascii	"[stage1-caribed] fd-links/relative path ABI ok for shell redirs\n"
	.equ	fdlink_abi_msg_len, . - fdlink_abi_msg
fdflag_abi_msg:
	.ascii	"[stage1-caribed] dup/dup3/fcntl ABI ok for shell fd control\n"
	.equ	fdflag_abi_msg_len, . - fdflag_abi_msg
fsproc_abi_msg:
	.ascii	"[stage1-caribed] uname/statfs/prlimit/umask ABI ok for shell env\n"
	.equ	fsproc_abi_msg_len, . - fsproc_abi_msg
time_abi_msg:
	.ascii	"[stage1-caribed] clock/times/sleep ABI ok for shell time\n"
	.equ	time_abi_msg_len, . - time_abi_msg
sbin_dents_msg:
	.ascii	"[stage1-caribed] /sbin enumerated\n"
	.equ	sbin_dents_msg_len, . - sbin_dents_msg
usr_dents_msg:
	.ascii	"[stage1-caribed] /usr enumerated\n"
	.equ	usr_dents_msg_len, . - usr_dents_msg
usr_lib_dents_msg:
	.ascii	"[stage1-caribed] /usr/lib enumerated\n"
	.equ	usr_lib_dents_msg_len, . - usr_lib_dents_msg
note_msg:
	.ascii	"[stage1-caribed] /usr/lib/caribe.note:\n"
	.equ	note_msg_len, . - note_msg
proc_mounts_msg:
	.ascii	"[stage1-caribed] /proc/mounts:\n"
	.equ	proc_mounts_msg_len, . - proc_mounts_msg
proc_filesystems_msg:
	.ascii	"[stage1-caribed] /proc/filesystems:\n"
	.equ	proc_filesystems_msg_len, . - proc_filesystems_msg
proc_version_msg:
	.ascii	"[stage1-caribed] /proc/version:\n"
	.equ	proc_version_msg_len, . - proc_version_msg
proc_cpuinfo_msg:
	.ascii	"[stage1-caribed] /proc/cpuinfo:\n"
	.equ	proc_cpuinfo_msg_len, . - proc_cpuinfo_msg
proc_meminfo_msg:
	.ascii	"[stage1-caribed] /proc/meminfo:\n"
	.equ	proc_meminfo_msg_len, . - proc_meminfo_msg
proc_uptime_msg:
	.ascii	"[stage1-caribed] /proc/uptime:\n"
	.equ	proc_uptime_msg_len, . - proc_uptime_msg
proc_stat_msg:
	.ascii	"[stage1-caribed] /proc/stat:\n"
	.equ	proc_stat_msg_len, . - proc_stat_msg
proc_caribeos_msg:
	.ascii	"[stage1-caribed] /proc/caribeos:\n"
	.equ	proc_caribeos_msg_len, . - proc_caribeos_msg
proc_bootlog_msg:
	.ascii	"[stage1-caribed] /proc/bootlog:\n"
	.equ	proc_bootlog_msg_len, . - proc_bootlog_msg
proc_iokit_msg:
	.ascii	"[stage1-caribed] /proc/iokit:\n"
	.equ	proc_iokit_msg_len, . - proc_iokit_msg
proc_sbi_msg:
	.ascii	"[stage1-caribed] /proc/caribe/sbi:\n"
	.equ	proc_sbi_msg_len, . - proc_sbi_msg
proc_devices_msg:
	.ascii	"[stage1-caribed] /proc/caribe/devices:\n"
	.equ	proc_devices_msg_len, . - proc_devices_msg
proc_memmap_msg:
	.ascii	"[stage1-caribed] /proc/caribe/memmap:\n"
	.equ	proc_memmap_msg_len, . - proc_memmap_msg
proc_dents_msg:
	.ascii	"[stage1-caribed] /proc enumerated\n"
	.equ	proc_dents_msg_len, . - proc_dents_msg
proc_caribe_dents_msg:
	.ascii	"[stage1-caribed] /proc/caribe enumerated\n"
	.equ	proc_caribe_dents_msg_len, . - proc_caribe_dents_msg
proc_self_fd_dents_msg:
	.ascii	"[stage1-caribed] /proc/self/fd enumerated\n"
	.equ	proc_self_fd_dents_msg_len, . - proc_self_fd_dents_msg
proc_self_fdinfo_msg:
	.ascii	"[stage1-caribed] /proc/self/fdinfo/1:\n"
	.equ	proc_self_fdinfo_msg_len, . - proc_self_fdinfo_msg
proc_self_fdinfo_dents_msg:
	.ascii	"[stage1-caribed] /proc/self/fdinfo enumerated\n"
	.equ	proc_self_fdinfo_dents_msg_len, . - proc_self_fdinfo_dents_msg
mmap_msg:
	.ascii	"[stage1-caribed] mmap anon/file-backed lifecycle ok\n"
	.equ	mmap_msg_len, . - mmap_msg
proc_maps_msg:
	.ascii	"[stage1-caribed] /proc/self/maps:\n"
	.equ	proc_maps_msg_len, . - proc_maps_msg
proc_status_msg:
	.ascii	"[stage1-caribed] /proc/self/status:\n"
	.equ	proc_status_msg_len, . - proc_status_msg
proc_auxv_msg:
	.ascii	"[stage1-caribed] /proc/self/auxv:\n"
	.equ	proc_auxv_msg_len, . - proc_auxv_msg
proc_cmdline_msg:
	.ascii	"[stage1-caribed] /proc/self/cmdline:\n"
	.equ	proc_cmdline_msg_len, . - proc_cmdline_msg
proc_environ_msg:
	.ascii	"[stage1-caribed] /proc/self/environ:\n"
	.equ	proc_environ_msg_len, . - proc_environ_msg
auxv_at_null_msg:
	.ascii	"AT_NULL\t"
	.equ	auxv_at_null_msg_len, . - auxv_at_null_msg
auxv_at_phdr_msg:
	.ascii	"AT_PHDR\t"
	.equ	auxv_at_phdr_msg_len, . - auxv_at_phdr_msg
auxv_at_phent_msg:
	.ascii	"AT_PHENT\t"
	.equ	auxv_at_phent_msg_len, . - auxv_at_phent_msg
auxv_at_phnum_msg:
	.ascii	"AT_PHNUM\t"
	.equ	auxv_at_phnum_msg_len, . - auxv_at_phnum_msg
auxv_at_pagesz_msg:
	.ascii	"AT_PAGESZ\t"
	.equ	auxv_at_pagesz_msg_len, . - auxv_at_pagesz_msg
auxv_at_base_msg:
	.ascii	"AT_BASE\t"
	.equ	auxv_at_base_msg_len, . - auxv_at_base_msg
auxv_at_flags_msg:
	.ascii	"AT_FLAGS\t"
	.equ	auxv_at_flags_msg_len, . - auxv_at_flags_msg
auxv_at_entry_msg:
	.ascii	"AT_ENTRY\t"
	.equ	auxv_at_entry_msg_len, . - auxv_at_entry_msg
auxv_at_uid_msg:
	.ascii	"AT_UID\t"
	.equ	auxv_at_uid_msg_len, . - auxv_at_uid_msg
auxv_at_euid_msg:
	.ascii	"AT_EUID\t"
	.equ	auxv_at_euid_msg_len, . - auxv_at_euid_msg
auxv_at_gid_msg:
	.ascii	"AT_GID\t"
	.equ	auxv_at_gid_msg_len, . - auxv_at_gid_msg
auxv_at_egid_msg:
	.ascii	"AT_EGID\t"
	.equ	auxv_at_egid_msg_len, . - auxv_at_egid_msg
auxv_at_platform_msg:
	.ascii	"AT_PLATFORM\t"
	.equ	auxv_at_platform_msg_len, . - auxv_at_platform_msg
auxv_at_hwcap_msg:
	.ascii	"AT_HWCAP\t"
	.equ	auxv_at_hwcap_msg_len, . - auxv_at_hwcap_msg
auxv_at_clktck_msg:
	.ascii	"AT_CLKTCK\t"
	.equ	auxv_at_clktck_msg_len, . - auxv_at_clktck_msg
auxv_at_random_msg:
	.ascii	"AT_RANDOM\t"
	.equ	auxv_at_random_msg_len, . - auxv_at_random_msg
auxv_at_execfn_msg:
	.ascii	"AT_EXECFN\t"
	.equ	auxv_at_execfn_msg_len, . - auxv_at_execfn_msg
auxv_at_unknown_msg:
	.ascii	"AT_UNKNOWN\t"
	.equ	auxv_at_unknown_msg_len, . - auxv_at_unknown_msg
hex_digits:
	.ascii	"0123456789abcdef"
process_msg:
	.ascii	"[stage1-caribed] process table wait4/waitid ABI ok\n"
	.equ	process_msg_len, . - process_msg
signal_jobctl_msg:
	.ascii	"[stage1-caribed] signal/jobctl ABI ok for bash probes\n"
	.equ	signal_jobctl_msg_len, . - signal_jobctl_msg
syscall_register_msg:
	.ascii	"[stage1-caribed] Linux/RISC-V syscall register ABI preserves a1-a7\n"
	.equ	syscall_register_msg_len, . - syscall_register_msg
manifest_msg:
	.ascii	"[stage1-caribed] /caribe/stage1.manifest:\n"
	.equ	manifest_msg_len, . - manifest_msg
ready_msg:
	.ascii	"[stage1-caribed] system ready\n"
	.equ	ready_msg_len, . - ready_msg
shebang_exec_msg:
	.ascii	"[stage1-caribed] execveat AT_EMPTY_PATH /usr/bin/dynamic-script via shebang -> PT_INTERP+ET_DYN bias\n"
	.equ	shebang_exec_msg_len, . - shebang_exec_msg
musl_exec_msg:
	.ascii	"[stage1-caribed] exec /bin/musl-probe (real musl libc RV32)\n"
	.equ	musl_exec_msg_len, . - musl_exec_msg
fail_msg:
	.ascii	"[stage1-caribed] init failed\n"
	.equ	fail_msg_len, . - fail_msg
newline:
	.ascii	"\n"
	.equ	newline_len, . - newline
manifest_path:
	.asciz	"/caribe/stage1.manifest"
proc_mounts_path:
	.asciz	"/proc/mounts"
proc_filesystems_path:
	.asciz	"/proc/filesystems"
proc_version_path:
	.asciz	"/proc/version"
proc_cpuinfo_path:
	.asciz	"/proc/cpuinfo"
proc_meminfo_path:
	.asciz	"/proc/meminfo"
proc_uptime_path:
	.asciz	"/proc/uptime"
proc_stat_path:
	.asciz	"/proc/stat"
proc_caribeos_path:
	.asciz	"/proc/caribeos"
proc_bootlog_path:
	.asciz	"/proc/bootlog"
proc_iokit_path:
	.asciz	"/proc/iokit"
proc_sbi_path:
	.asciz	"/proc/caribe/sbi"
proc_devices_path:
	.asciz	"/proc/caribe/devices"
proc_memmap_path:
	.asciz	"/proc/caribe/memmap"
proc_path:
	.asciz	"/proc"
proc_caribe_path:
	.asciz	"/proc/caribe"
proc_self_fd_path:
	.asciz	"/proc/self/fd"
proc_self_fd1_path:
	.asciz	"/proc/self/fd/1"
proc_self_fdinfo_path:
	.asciz	"/proc/self/fdinfo"
proc_self_fdinfo1_path:
	.asciz	"/proc/self/fdinfo/1"
proc_maps_path:
	.asciz	"/proc/self/maps"
proc_status_path:
	.asciz	"/proc/self/status"
proc_auxv_path:
	.asciz	"/proc/self/auxv"
proc_cmdline_path:
	.asciz	"/proc/self/cmdline"
proc_environ_path:
	.asciz	"/proc/self/environ"
dev_tty_path:
	.asciz	"/dev/tty"
dev_fd1_path:
	.asciz	"/dev/fd/1"
dev_null_path:
	.asciz	"/dev/null"
null_probe_byte:
	.ascii	"N"
pipe_payload:
	.ascii	"pipe:ok\n"
	.equ	pipe_payload_len, . - pipe_payload
pipe_writev_a:
	.ascii	"wv:"
	.equ	pipe_writev_a_len, . - pipe_writev_a
pipe_writev_b:
	.ascii	"ok\n"
	.equ	pipe_writev_b_len, . - pipe_writev_b
pipe_writev_expected:
	.ascii	"wv:ok\n"
	.equ	pipe_writev_expected_len, . - pipe_writev_expected
usr_dir_path:
	.asciz	"/usr"
root_dir_path:
	.asciz	"/"
relative_note_path:
	.asciz	"lib/caribe.note"
cwd_relative_note_path:
	.asciz	"usr/lib/caribe.note"
sbin_path:
	.asciz	"/sbin"
usr_path:
	.asciz	"/usr"
usr_lib_path:
	.asciz	"/usr/lib"
usr_lib_note_path:
	.asciz	"/usr/lib/caribe.note"
interp_probe_path:
	.asciz	"/bin/dynamic-bias-probe"
interp_probe_arg1:
	.asciz	"--pt-dynamic-bias"
dynamic_script_path:
	.asciz	"/usr/bin/dynamic-script"
dynamic_script_empty_path:
	.asciz	""
dynamic_script_arg1:
	.asciz	"--stage1-shebang"
musl_probe_path:
	.asciz	"/bin/musl-probe"
musl_probe_arg1:
	.asciz	"--stage1"
interp_probe_env0:
	.asciz	"HOME=/"
interp_probe_env1:
	.asciz	"PATH=/sbin:/bin"
interp_probe_env2:
	.asciz	"LD_TRACE=caribe"
	.balign	4
dynamic_script_argv:
	.word	dynamic_script_path
	.word	dynamic_script_arg1
	.word	0
musl_probe_argv:
	.word	musl_probe_path
	.word	musl_probe_arg1
	.word	0
interp_probe_envp:
	.word	interp_probe_env0
	.word	interp_probe_env1
	.word	interp_probe_env2
	.word	0

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	mv	s2, sp

	la	a1, start_msg
	li	a2, start_msg_len
	call	write_stdout

	li	a1, 0x11223344
	li	a2, 0x22334455
	li	a3, 0x33445566
	li	a4, 0x44556677
	li	a5, 0x55667788
	li	a6, 0x66778899
	li	a7, SYS_GETPID
	ecall
	bltz	a0, fail
	li	t0, 0x11223344
	bne	a1, t0, fail
	li	t0, 0x22334455
	bne	a2, t0, fail
	li	t0, 0x33445566
	bne	a3, t0, fail
	li	t0, 0x44556677
	bne	a4, t0, fail
	li	t0, 0x55667788
	bne	a5, t0, fail
	li	t0, 0x66778899
	bne	a6, t0, fail
	li	t0, SYS_GETPID
	bne	a7, t0, fail
	la	a1, syscall_register_msg
	li	a2, syscall_register_msg_len
	call	write_stdout
	la	a1, pid_msg
	li	a2, pid_msg_len
	call	write_stdout

	call	tty_abi_probe
	call	cwd_abi_probe
	call	pipe_abi_probe
	call	seek_readv_probe
	call	fdlink_abi_probe
	call	fdflag_probe
	call	fsproc_abi_probe
	call	time_abi_probe

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

	la	a0, proc_version_path
	la	a1, proc_version_msg
	li	a2, proc_version_msg_len
	call	read_path_to_stdout

	la	a0, proc_cpuinfo_path
	la	a1, proc_cpuinfo_msg
	li	a2, proc_cpuinfo_msg_len
	call	read_path_to_stdout

	la	a0, proc_meminfo_path
	la	a1, proc_meminfo_msg
	li	a2, proc_meminfo_msg_len
	call	read_path_to_stdout

	la	a0, proc_uptime_path
	la	a1, proc_uptime_msg
	li	a2, proc_uptime_msg_len
	call	read_path_to_stdout

	la	a0, proc_stat_path
	la	a1, proc_stat_msg
	li	a2, proc_stat_msg_len
	call	read_path_to_stdout

	la	a0, proc_caribeos_path
	la	a1, proc_caribeos_msg
	li	a2, proc_caribeos_msg_len
	call	read_path_to_stdout

	la	a0, proc_bootlog_path
	la	a1, proc_bootlog_msg
	li	a2, proc_bootlog_msg_len
	call	read_path_to_stdout

	la	a0, proc_iokit_path
	la	a1, proc_iokit_msg
	li	a2, proc_iokit_msg_len
	call	read_path_to_stdout

	la	a0, proc_sbi_path
	la	a1, proc_sbi_msg
	li	a2, proc_sbi_msg_len
	call	read_path_to_stdout

	la	a0, proc_devices_path
	la	a1, proc_devices_msg
	li	a2, proc_devices_msg_len
	call	read_path_to_stdout

	la	a0, proc_memmap_path
	la	a1, proc_memmap_msg
	li	a2, proc_memmap_msg_len
	call	read_path_to_stdout

	la	a0, proc_path
	la	a1, proc_dents_msg
	li	a2, proc_dents_msg_len
	call	getdents_path

	la	a0, proc_caribe_path
	la	a1, proc_caribe_dents_msg
	li	a2, proc_caribe_dents_msg_len
	call	getdents_path

	la	a0, proc_mounts_path
	la	a1, proc_mounts_msg
	li	a2, proc_mounts_msg_len
	call	read_path_to_stdout

	la	a0, proc_filesystems_path
	la	a1, proc_filesystems_msg
	li	a2, proc_filesystems_msg_len
	call	read_path_to_stdout

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
	la	a1, heap_msg
	li	a2, heap_msg_len
	call	write_stdout

	li	a0, 0
	li	a1, 8192
	li	a2, PROT_READ | PROT_WRITE
	li	a3, MAP_PRIVATE | MAP_ANONYMOUS
	li	a4, -1
	li	a5, 0
	li	a7, SYS_MMAP
	ecall
	bltz	a0, fail
	mv	s8, a0
	li	t2, 0x4d
	sb	t2, 0(s8)
	li	t0, 4096
	add	t1, s8, t0
	li	t2, 0x4e
	sb	t2, 0(t1)
	mv	a0, s8
	li	a1, 4096
	li	a2, PROT_READ
	li	a7, SYS_MPROTECT
	ecall
	bnez	a0, fail
	mv	a0, s8
	li	a1, 8192
	la	a2, mincore_vec
	li	a7, SYS_MINCORE
	ecall
	bnez	a0, fail
	la	t3, mincore_vec
	lbu	t0, 0(t3)
	andi	t0, t0, 1
	beqz	t0, fail
	lbu	t1, 1(t3)
	andi	t1, t1, 1
	beqz	t1, fail

	li	a0, AT_FDCWD
	la	a1, usr_lib_note_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s9, a0
	li	a0, 0
	li	a1, 4096
	li	a2, PROT_READ
	li	a3, MAP_PRIVATE
	mv	a4, s9
	li	a5, 0
	li	a7, SYS_MMAP
	ecall
	bltz	a0, fail
	mv	s10, a0
	lbu	t0, 0(s10)
	beqz	t0, fail
	mv	a0, s9
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a0, proc_maps_path
	la	a1, proc_maps_msg
	li	a2, proc_maps_msg_len
	call	read_path_to_stdout

	la	a0, proc_status_path
	la	a1, proc_status_msg
	li	a2, proc_status_msg_len
	call	read_path_to_stdout

	la	a0, proc_auxv_path
	la	a1, proc_auxv_msg
	li	a2, proc_auxv_msg_len
	call	read_auxv_path_to_stdout

	la	a0, proc_cmdline_path
	la	a1, proc_cmdline_msg
	li	a2, proc_cmdline_msg_len
	li	a3, 0x20
	call	read_nul_path_to_stdout

	la	a0, proc_environ_path
	la	a1, proc_environ_msg
	li	a2, proc_environ_msg_len
	li	a3, 0x0a
	call	read_nul_path_to_stdout

	mv	a0, s10
	li	a1, 4096
	li	a7, SYS_MUNMAP
	ecall
	bnez	a0, fail
	mv	a0, s8
	li	a1, 8192
	li	a7, SYS_MUNMAP
	ecall
	bnez	a0, fail
	la	a1, mmap_msg
	li	a2, mmap_msg_len
	call	write_stdout

	la	a0, sbin_path
	la	a1, sbin_dents_msg
	li	a2, sbin_dents_msg_len
	call	getdents_path

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
	mv	s8, a0

	li	a0, P_PID
	mv	a1, s7
	la	a2, wait_siginfo
	li	a3, WEXITED
	li	t0, WNOWAIT
	or	a3, a3, t0
	li	a4, 0
	li	a7, SYS_WAITID
	ecall
	bnez	a0, fail
	la	t0, wait_siginfo
	lw	t1, 0(t0)
	li	t2, SIGCHLD
	bne	t1, t2, fail
	lw	t1, 8(t0)
	li	t2, CLD_EXITED
	bne	t1, t2, fail
	lw	t1, 12(t0)
	bne	t1, s7, fail
	lw	t1, 20(t0)
	bnez	t1, fail

	mv	a0, s7
	la	a1, wait_status
	li	a2, 0
	li	a3, 0
	li	a7, SYS_WAIT4
	ecall
	bne	a0, s7, fail
	lw	t0, wait_status
	bnez	t0, fail

	li	a0, P_ALL
	li	a1, 0
	la	a2, wait_siginfo
	li	a3, WEXITED
	li	a4, 0
	li	a7, SYS_WAITID
	ecall
	bnez	a0, fail
	la	t0, wait_siginfo
	lw	t1, 0(t0)
	li	t2, SIGCHLD
	bne	t1, t2, fail
	lw	t1, 8(t0)
	li	t2, CLD_EXITED
	bne	t1, t2, fail
	lw	t1, 12(t0)
	bne	t1, s8, fail
	lw	t1, 20(t0)
	bnez	t1, fail

	la	a1, process_msg
	li	a2, process_msg_len
	call	write_stdout
	call	signal_jobctl_probe

	la	a0, manifest_path
	la	a1, manifest_msg
	li	a2, manifest_msg_len
	call	read_path_to_stdout

	la	a1, ready_msg
	li	a2, ready_msg_len
	call	write_stdout

	la	a1, musl_exec_msg
	li	a2, musl_exec_msg_len
	call	write_stdout
	la	a0, musl_probe_path
	la	a1, musl_probe_argv
	la	a2, interp_probe_envp
	li	a7, SYS_EXECVE
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

tty_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)

	li	a0, AT_FDCWD
	la	a1, dev_tty_path
	li	a2, O_RDWR
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0

	mv	a0, s0
	li	a1, TCGETS
	la	a2, tty_termios
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a1, TIOCGWINSZ
	la	a2, tty_winsize
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a1, TIOCGPGRP
	la	a2, tty_pgrp
	li	a7, SYS_IOCTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, AT_FDCWD
	la	a1, dev_null_path
	li	a2, O_RDWR
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0

	mv	a0, s0
	la	a1, null_probe_byte
	li	a2, 1
	li	a7, SYS_WRITE
	ecall
	li	t0, 1
	bne	a0, t0, fail

	mv	a0, s0
	la	a1, io_buf
	li	a2, 1
	li	a7, SYS_READ
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a1, tty_abi_msg
	li	a2, tty_abi_msg_len
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

cwd_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)

	la	a0, usr_dir_path
	li	a7, SYS_CHDIR
	ecall
	bnez	a0, fail

	la	a0, cwd_buf
	li	a1, 128
	li	a7, SYS_GETCWD
	ecall
	blez	a0, fail
	la	t0, cwd_buf
	lbu	t1, 0(t0)
	li	t2, 0x2f
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 0x75
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 0x73
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 0x72
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	bnez	t1, fail

	la	a0, root_dir_path
	li	a7, SYS_CHDIR
	ecall
	bnez	a0, fail

	la	a1, cwd_abi_msg
	li	a2, cwd_abi_msg_len
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

pipe_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	sw	s0, 8(sp)
	sw	s1, 4(sp)

	la	a0, pipe_fds
	li	a1, 0
	li	a7, SYS_PIPE2
	ecall
	bnez	a0, fail
	la	t0, pipe_fds
	lw	s0, 0(t0)
	lw	s1, 4(t0)

	mv	a0, s1
	la	a1, pipe_payload
	li	a2, pipe_payload_len
	li	a7, SYS_WRITE
	ecall
	li	t0, pipe_payload_len
	bne	a0, t0, fail

	la	t0, pipe_pollfd
	sw	s0, 0(t0)
	li	t1, POLLIN
	sh	t1, 4(t0)
	sh	zero, 6(t0)
	la	a0, pipe_pollfd
	li	a1, 1
	li	a2, 0
	li	a3, 0
	li	a4, 0
	li	a7, SYS_PPOLL
	ecall
	li	t0, 1
	bne	a0, t0, fail
	la	t0, pipe_pollfd
	lhu	t1, 6(t0)
	andi	t1, t1, POLLIN
	beqz	t1, fail

	mv	a0, s0
	la	a1, pipe_read_buf
	li	a2, pipe_payload_len
	li	a7, SYS_READ
	ecall
	li	t0, pipe_payload_len
	bne	a0, t0, fail
	la	t0, pipe_read_buf
	la	t1, pipe_payload
	li	t2, pipe_payload_len
1:
	beqz	t2, 2f
	lbu	t3, 0(t0)
	lbu	t4, 0(t1)
	bne	t3, t4, fail
	addi	t0, t0, 1
	addi	t1, t1, 1
	addi	t2, t2, -1
	j	1b
2:
	la	t0, pipe_iov
	la	t1, pipe_writev_a
	sw	t1, 0(t0)
	li	t1, pipe_writev_a_len
	sw	t1, 4(t0)
	la	t1, pipe_writev_b
	sw	t1, 8(t0)
	li	t1, pipe_writev_b_len
	sw	t1, 12(t0)

	mv	a0, s1
	la	a1, pipe_iov
	li	a2, 2
	li	a7, SYS_WRITEV
	ecall
	li	t0, pipe_writev_expected_len
	bne	a0, t0, fail

	mv	a0, s0
	la	a1, pipe_read_buf
	li	a2, pipe_writev_expected_len
	li	a7, SYS_READ
	ecall
	li	t0, pipe_writev_expected_len
	bne	a0, t0, fail
	la	t0, pipe_read_buf
	la	t1, pipe_writev_expected
	li	t2, pipe_writev_expected_len
3:
	beqz	t2, 4f
	lbu	t3, 0(t0)
	lbu	t4, 0(t1)
	bne	t3, t4, fail
	addi	t0, t0, 1
	addi	t1, t1, 1
	addi	t2, t2, -1
	j	3b
4:
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	mv	a0, s1
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a1, pipe_abi_msg
	li	a2, pipe_abi_msg_len
	call	write_stdout
	lw	s1, 4(sp)
	lw	s0, 8(sp)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

fdlink_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	sw	s0, 8(sp)
	sw	s1, 4(sp)

	li	a0, AT_FDCWD
	la	a1, usr_dir_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0

	mv	a0, s0
	la	a1, relative_note_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s1, a0
	mv	a0, s1
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, AT_FDCWD
	la	a1, cwd_relative_note_path
	li	a2, 0
	li	a3, 0
	li	a7, SYS_FACCESSAT
	ecall
	bnez	a0, fail

	li	a0, AT_FDCWD
	la	a1, proc_self_fd1_path
	la	a2, fdlink_buf
	li	a3, 128
	li	a7, SYS_READLINKAT
	ecall
	blez	a0, fail
	la	t0, fdlink_buf
	lbu	t1, 0(t0)
	li	t2, 0x2f
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 0x64
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 0x65
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 0x76
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	li	t2, 0x2f
	bne	t1, t2, fail
	lbu	t1, 5(t0)
	li	t2, 0x74
	bne	t1, t2, fail
	lbu	t1, 6(t0)
	li	t2, 0x74
	bne	t1, t2, fail
	lbu	t1, 7(t0)
	li	t2, 0x79
	bne	t1, t2, fail

	li	a0, AT_FDCWD
	la	a1, dev_fd1_path
	li	a2, O_WRONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a0, proc_self_fdinfo1_path
	la	a1, proc_self_fdinfo_msg
	li	a2, proc_self_fdinfo_msg_len
	call	read_path_to_stdout

	la	a0, proc_self_fd_path
	la	a1, proc_self_fd_dents_msg
	li	a2, proc_self_fd_dents_msg_len
	call	getdents_path

	la	a0, proc_self_fdinfo_path
	la	a1, proc_self_fdinfo_dents_msg
	li	a2, proc_self_fdinfo_dents_msg_len
	call	getdents_path

	la	a1, fdlink_abi_msg
	li	a2, fdlink_abi_msg_len
	call	write_stdout
	lw	s1, 4(sp)
	lw	s0, 8(sp)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

fsproc_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	sw	s0, 8(sp)

	la	a0, uname_buf
	li	a7, SYS_UNAME
	ecall
	bnez	a0, fail
	la	t0, uname_buf
	lbu	t1, 0(t0)
	li	t2, 'L'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	addi	t0, t0, 260
	lbu	t1, 0(t0)
	li	t2, 'r'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'i'
	bne	t1, t2, fail

	la	a0, usr_lib_note_path
	la	a1, statfs_buf
	li	a7, SYS_STATFS64
	ecall
	bnez	a0, fail
	la	t0, statfs_buf
	lw	t1, 0(t0)
	li	t2, 0x482b
	bne	t1, t2, fail
	lw	t1, 4(t0)
	li	t2, 4096
	bne	t1, t2, fail

	li	a0, AT_FDCWD
	la	a1, usr_lib_note_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0
	mv	a0, s0
	la	a1, statfs_buf
	li	a7, SYS_FSTATFS64
	ecall
	bnez	a0, fail
	la	t0, statfs_buf
	lw	t1, 0(t0)
	li	t2, 0x482b
	bne	t1, t2, fail
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	li	a0, 0
	li	a1, RLIMIT_NOFILE
	li	a2, 0
	la	a3, rlimit_buf
	li	a7, SYS_PRLIMIT64
	ecall
	bnez	a0, fail
	la	t0, rlimit_buf
	lw	t1, 0(t0)
	li	t2, 19
	bne	t1, t2, fail
	lw	t1, 4(t0)
	bnez	t1, fail
	lw	t1, 8(t0)
	li	t2, 19
	bne	t1, t2, fail
	lw	t1, 12(t0)
	bnez	t1, fail

	li	a0, 63
	li	a7, SYS_UMASK
	ecall
	li	t0, 18
	bne	a0, t0, fail
	li	a0, 18
	li	a7, SYS_UMASK
	ecall
	li	t0, 63
	bne	a0, t0, fail

	la	a1, fsproc_abi_msg
	li	a2, fsproc_abi_msg_len
	call	write_stdout

	lw	s0, 8(sp)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

time_abi_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)

	li	a0, CLOCK_MONOTONIC
	la	a1, time_ts_buf
	li	a7, SYS_CLOCK_GETTIME
	ecall
	bnez	a0, fail
	la	t0, time_ts_buf
	lw	t1, 4(t0)
	li	t2, 1000000000
	bgeu	t1, t2, fail

	li	a0, CLOCK_MONOTONIC
	la	a1, time_res_buf
	li	a7, SYS_CLOCK_GETRES
	ecall
	bnez	a0, fail
	la	t0, time_res_buf
	lw	t1, 0(t0)
	bnez	t1, fail
	lw	t1, 4(t0)
	li	t2, 1
	bne	t1, t2, fail

	la	t0, time_req_buf
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	la	t0, time_rem_buf
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	la	a0, time_req_buf
	la	a1, time_rem_buf
	li	a7, SYS_NANOSLEEP
	ecall
	bnez	a0, fail

	la	t0, time_req_buf
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	li	a0, CLOCK_MONOTONIC
	li	a1, 0
	la	a2, time_req_buf
	la	a3, time_rem_buf
	li	a7, SYS_CLOCK_NANOSLEEP
	ecall
	bnez	a0, fail

	la	a0, time_tv_buf
	li	a1, 0
	li	a7, SYS_GETTIMEOFDAY
	ecall
	bnez	a0, fail
	la	t0, time_tv_buf
	lw	t1, 4(t0)
	li	t2, 1000000
	bgeu	t1, t2, fail

	li	a0, RUSAGE_SELF
	la	a1, rusage_buf
	li	a7, SYS_GETRUSAGE
	ecall
	bnez	a0, fail

	li	a7, SYS_SCHED_YIELD
	ecall
	bnez	a0, fail

	la	a0, tms_buf
	li	a7, SYS_TIMES
	ecall
	bltz	a0, fail
	la	t0, tms_buf
	lw	t1, 0(t0)
	bnez	t1, fail
	lw	t1, 4(t0)
	bnez	t1, fail
	lw	t1, 8(t0)
	bnez	t1, fail
	lw	t1, 12(t0)
	bnez	t1, fail

	la	a1, time_abi_msg
	li	a2, time_abi_msg_len
	call	write_stdout

	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

seek_readv_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	sw	s0, 8(sp)

	la	t0, readv_iov
	la	t1, readv_buf0
	sw	t1, 0(t0)
	li	t1, 6
	sw	t1, 4(t0)
	la	t1, readv_buf1
	sw	t1, 8(t0)
	li	t1, 1
	sw	t1, 12(t0)

	li	a0, AT_FDCWD
	la	a1, usr_lib_note_path
	li	a2, O_RDONLY
	li	a3, 0
	li	a7, SYS_OPENAT
	ecall
	bltz	a0, fail
	mv	s0, a0

	mv	a0, s0
	la	a1, readv_iov
	li	a2, 2
	li	a7, SYS_READV
	ecall
	li	t0, 7
	bne	a0, t0, fail
	la	t0, readv_buf0
	lbu	t1, 0(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'n'
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 't'
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	li	t2, 'r'
	bne	t1, t2, fail
	lbu	t1, 5(t0)
	li	t2, 'd'
	bne	t1, t2, fail
	la	t0, readv_buf1
	lbu	t1, 0(t0)
	li	t2, '-'
	bne	t1, t2, fail

	mv	a0, s0
	la	a1, readv_buf0
	li	a2, 6
	li	a3, 0
	li	a4, 0
	li	a7, SYS_PREAD64
	ecall
	li	t0, 6
	bne	a0, t0, fail
	la	t0, readv_buf0
	lbu	t1, 0(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'n'
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 't'
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	li	t2, 'r'
	bne	t1, t2, fail
	lbu	t1, 5(t0)
	li	t2, 'd'
	bne	t1, t2, fail

	mv	a0, s0
	li	a1, 0
	li	a2, 0
	la	a3, llseek_result
	li	a4, SEEK_CUR
	li	a7, SYS_LLSEEK
	ecall
	bnez	a0, fail
	la	t0, llseek_result
	lw	t1, 0(t0)
	li	t2, 7
	bne	t1, t2, fail
	lw	t1, 4(t0)
	bnez	t1, fail

	mv	a0, s0
	la	a1, readv_buf0
	li	a2, 6
	li	a7, SYS_READ
	ecall
	li	t0, 6
	bne	a0, t0, fail
	la	t0, readv_buf0
	lbu	t1, 0(t0)
	li	t2, 'w'
	bne	t1, t2, fail
	lbu	t1, 1(t0)
	li	t2, 'a'
	bne	t1, t2, fail
	lbu	t1, 2(t0)
	li	t2, 'l'
	bne	t1, t2, fail
	lbu	t1, 3(t0)
	li	t2, 'k'
	bne	t1, t2, fail
	lbu	t1, 4(t0)
	li	t2, 'e'
	bne	t1, t2, fail
	lbu	t1, 5(t0)
	li	t2, 'r'
	bne	t1, t2, fail

	mv	a0, s0
	li	a1, 0
	li	a2, 0
	la	a3, llseek_result
	li	a4, SEEK_SET
	li	a7, SYS_LLSEEK
	ecall
	bnez	a0, fail
	la	t0, llseek_result
	lw	t1, 0(t0)
	bnez	t1, fail
	lw	t1, 4(t0)
	bnez	t1, fail

	mv	a0, s0
	la	a1, readv_buf0
	li	a2, 6
	li	a7, SYS_READ
	ecall
	li	t0, 6
	bne	a0, t0, fail
	la	t0, readv_buf0
	lbu	t1, 0(t0)
	li	t2, 'i'
	bne	t1, t2, fail
	lbu	t1, 5(t0)
	li	t2, 'd'
	bne	t1, t2, fail

	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	la	a1, seek_readv_abi_msg
	li	a2, seek_readv_abi_msg_len
	call	write_stdout

	lw	s0, 8(sp)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

fdflag_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	sw	s0, 8(sp)
	sw	s1, 4(sp)

	li	a0, 1
	li	a7, SYS_DUP
	ecall
	bltz	a0, fail
	mv	s0, a0

	mv	a0, s0
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a1, F_SETFD
	li	a2, FD_CLOEXEC
	li	a7, SYS_FCNTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, FD_CLOEXEC
	bne	a0, t0, fail

	mv	a0, s0
	li	a1, F_SETFL
	li	a2, O_NONBLOCK
	li	a7, SYS_FCNTL
	ecall
	bnez	a0, fail

	mv	a0, s0
	li	a1, F_GETFL
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	bltz	a0, fail
	andi	t0, a0, 3
	li	t1, O_WRONLY
	bne	t0, t1, fail
	li	t1, O_NONBLOCK
	and	t0, a0, t1
	beqz	t0, fail

	mv	a0, s0
	li	a1, F_DUPFD_CLOEXEC
	li	a2, 8
	li	a7, SYS_FCNTL
	ecall
	bltz	a0, fail
	mv	s1, a0
	li	t0, 8
	blt	s1, t0, fail

	mv	a0, s1
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, FD_CLOEXEC
	bne	a0, t0, fail

	mv	a0, s0
	li	a1, 9
	li	a2, O_CLOEXEC
	li	a7, SYS_DUP3
	ecall
	li	t0, 9
	bne	a0, t0, fail

	li	a0, 9
	li	a1, F_GETFD
	li	a2, 0
	li	a7, SYS_FCNTL
	ecall
	li	t0, FD_CLOEXEC
	bne	a0, t0, fail

	mv	a0, s0
	mv	a1, s0
	li	a2, 0
	li	a7, SYS_DUP3
	ecall
	bgez	a0, fail

	mv	a0, s0
	la	a1, fdflag_abi_msg
	li	a2, fdflag_abi_msg_len
	li	a7, SYS_WRITE
	ecall
	bltz	a0, fail

	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	mv	a0, s1
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	li	a0, 9
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail

	lw	s1, 4(sp)
	lw	s0, 8(sp)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

signal_jobctl_probe:
	addi	sp, sp, -16
	sw	ra, 12(sp)

	la	t0, sigaction_new
	li	t1, SIG_IGN
	sw	t1, 0(t0)
	sw	zero, 4(t0)
	sw	zero, 8(t0)
	sw	zero, 12(t0)
	sw	zero, 16(t0)
	sw	zero, 20(t0)

	li	a0, SIGCHLD
	la	a1, sigaction_new
	la	a2, sigaction_old
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, fail

	li	a0, SIGCHLD
	li	a1, 0
	la	a2, sigaction_readback
	li	a3, 8
	li	a7, SYS_RT_SIGACTION
	ecall
	bnez	a0, fail
	la	t0, sigaction_readback
	lw	t1, 0(t0)
	li	t2, SIG_IGN
	bne	t1, t2, fail

	la	t0, sigmask_new
	sw	zero, 0(t0)
	sw	zero, 4(t0)
	li	t1, 1
	sb	t1, 2(t0)
	li	a0, SIG_SETMASK
	la	a1, sigmask_new
	la	a2, sigmask_old
	li	a3, 8
	li	a7, SYS_RT_SIGPROCMASK
	ecall
	bnez	a0, fail
	la	t0, sigmask_old
	lw	t1, 0(t0)
	bnez	t1, fail
	lw	t1, 4(t0)
	bnez	t1, fail

	li	a0, SIG_SETMASK
	li	a1, 0
	la	a2, sigmask_readback
	li	a3, 8
	li	a7, SYS_RT_SIGPROCMASK
	ecall
	bnez	a0, fail
	la	t0, sigmask_readback
	lbu	t1, 2(t0)
	andi	t1, t1, 1
	beqz	t1, fail

	la	a0, sigpending_buf
	li	a1, 8
	li	a7, SYS_RT_SIGPENDING
	ecall
	bnez	a0, fail
	la	t0, sigpending_buf
	lw	t1, 0(t0)
	bnez	t1, fail
	lw	t1, 4(t0)
	bnez	t1, fail

	la	t0, sigalt_new
	li	t1, 0x50000
	sw	t1, 0(t0)
	sw	zero, 4(t0)
	li	t1, 4096
	sw	t1, 8(t0)
	la	a0, sigalt_new
	la	a1, sigalt_old
	li	a7, SYS_SIGALTSTACK
	ecall
	bnez	a0, fail
	li	a0, 0
	la	a1, sigalt_readback
	li	a7, SYS_SIGALTSTACK
	ecall
	bnez	a0, fail
	la	t0, sigalt_readback
	lw	t1, 0(t0)
	li	t2, 0x50000
	bne	t1, t2, fail
	lw	t1, 8(t0)
	li	t2, 4096
	bne	t1, t2, fail

	li	a0, 0
	li	a1, 1
	li	a7, SYS_SETPGID
	ecall
	bnez	a0, fail
	li	a0, 0
	li	a7, SYS_GETPGID
	ecall
	li	t0, 1
	bne	a0, t0, fail
	li	a0, 0
	li	a7, SYS_GETSID
	ecall
	li	t0, 1
	bne	a0, t0, fail

	li	a0, 1
	li	a1, 0
	li	a7, SYS_KILL
	ecall
	bnez	a0, fail
	li	a0, 1
	li	a1, SIGCHLD
	li	a7, SYS_KILL
	ecall
	bnez	a0, fail

	la	a1, signal_jobctl_msg
	li	a2, signal_jobctl_msg_len
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

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

read_nul_path_to_stdout:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	mv	s4, a0
	mv	s5, a1
	mv	s6, a2
	mv	s7, a3
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
2:
	mv	a0, s0
	la	a1, io_buf
	li	a2, 512
	li	a7, SYS_READ
	ecall
	bltz	a0, fail
	beqz	a0, 4f
	mv	s1, a0
	la	s4, io_buf
	li	s5, 0
3:
	bge	s5, s1, 5f
	add	t0, s4, s5
	lbu	t1, 0(t0)
	bnez	t1, 6f
	sb	s7, 0(t0)
6:
	addi	s5, s5, 1
	j	3b
5:
	li	a0, 1
	la	a1, io_buf
	mv	a2, s1
	li	a7, SYS_WRITE
	ecall
	bltz	a0, fail
	j	2b
4:
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

read_auxv_path_to_stdout:
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
	mv	a0, s0
	la	a1, io_buf
	li	a2, 512
	li	a7, SYS_READ
	ecall
	blez	a0, fail
	mv	s1, a0
	mv	a0, s0
	li	a7, SYS_CLOSE
	ecall
	bltz	a0, fail
	la	s4, io_buf
	li	s5, 0
7:
	addi	t0, s5, 8
	bgt	t0, s1, 8f
	lw	s6, 0(s4)
	lw	s7, 4(s4)
	mv	a0, s6
	call	write_auxv_name
	mv	a0, s7
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	addi	s4, s4, 8
	addi	s5, s5, 8
	beqz	s6, 8f
	j	7b
8:
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

write_auxv_name:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	li	t0, 0
	beq	a0, t0, 1f
	li	t0, 3
	beq	a0, t0, 2f
	li	t0, 4
	beq	a0, t0, 3f
	li	t0, 5
	beq	a0, t0, 4f
	li	t0, 6
	beq	a0, t0, 5f
	li	t0, 7
	beq	a0, t0, 6f
	li	t0, 8
	beq	a0, t0, 7f
	li	t0, 9
	beq	a0, t0, 8f
	li	t0, 11
	beq	a0, t0, 9f
	li	t0, 12
	beq	a0, t0, 10f
	li	t0, 13
	beq	a0, t0, 11f
	li	t0, 14
	beq	a0, t0, 12f
	li	t0, 15
	beq	a0, t0, 13f
	li	t0, 16
	beq	a0, t0, 14f
	li	t0, 17
	beq	a0, t0, 15f
	li	t0, 25
	beq	a0, t0, 16f
	li	t0, 31
	beq	a0, t0, 17f
	la	a1, auxv_at_unknown_msg
	li	a2, auxv_at_unknown_msg_len
	j	18f
1:
	la	a1, auxv_at_null_msg
	li	a2, auxv_at_null_msg_len
	j	18f
2:
	la	a1, auxv_at_phdr_msg
	li	a2, auxv_at_phdr_msg_len
	j	18f
3:
	la	a1, auxv_at_phent_msg
	li	a2, auxv_at_phent_msg_len
	j	18f
4:
	la	a1, auxv_at_phnum_msg
	li	a2, auxv_at_phnum_msg_len
	j	18f
5:
	la	a1, auxv_at_pagesz_msg
	li	a2, auxv_at_pagesz_msg_len
	j	18f
6:
	la	a1, auxv_at_base_msg
	li	a2, auxv_at_base_msg_len
	j	18f
7:
	la	a1, auxv_at_flags_msg
	li	a2, auxv_at_flags_msg_len
	j	18f
8:
	la	a1, auxv_at_entry_msg
	li	a2, auxv_at_entry_msg_len
	j	18f
9:
	la	a1, auxv_at_uid_msg
	li	a2, auxv_at_uid_msg_len
	j	18f
10:
	la	a1, auxv_at_euid_msg
	li	a2, auxv_at_euid_msg_len
	j	18f
11:
	la	a1, auxv_at_gid_msg
	li	a2, auxv_at_gid_msg_len
	j	18f
12:
	la	a1, auxv_at_egid_msg
	li	a2, auxv_at_egid_msg_len
	j	18f
13:
	la	a1, auxv_at_platform_msg
	li	a2, auxv_at_platform_msg_len
	j	18f
14:
	la	a1, auxv_at_hwcap_msg
	li	a2, auxv_at_hwcap_msg_len
	j	18f
15:
	la	a1, auxv_at_clktck_msg
	li	a2, auxv_at_clktck_msg_len
	j	18f
16:
	la	a1, auxv_at_random_msg
	li	a2, auxv_at_random_msg_len
	j	18f
17:
	la	a1, auxv_at_execfn_msg
	li	a2, auxv_at_execfn_msg_len
18:
	call	write_stdout
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

write_hex32_stdout:
	la	t0, hex_buf
	li	t1, 0x30
	sb	t1, 0(t0)
	li	t1, 0x78
	sb	t1, 1(t0)
	addi	t0, t0, 2
	li	t2, 28
	la	t4, hex_digits
1:
	srl	t3, a0, t2
	andi	t3, t3, 0x0f
	add	t5, t4, t3
	lbu	t6, 0(t5)
	sb	t6, 0(t0)
	addi	t0, t0, 1
	addi	t2, t2, -4
	bgez	t2, 1b
	li	a0, 1
	la	a1, hex_buf
	li	a2, 10
	li	a7, SYS_WRITE
	ecall
	bltz	a0, fail
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
hex_buf:
	.skip	10
dents_buf:
	.skip	512
wait_status:
	.skip	4
wait_siginfo:
	.skip	128
mincore_vec:
	.skip	8
tty_termios:
	.skip	36
tty_winsize:
	.skip	8
tty_pgrp:
	.skip	4
cwd_buf:
	.skip	128
pipe_fds:
	.skip	8
pipe_read_buf:
	.skip	32
pipe_pollfd:
	.skip	8
pipe_iov:
	.skip	16
fdlink_buf:
	.skip	128
readv_iov:
	.skip	16
readv_buf0:
	.skip	16
readv_buf1:
	.skip	8
llseek_result:
	.skip	8
uname_buf:
	.skip	390
statfs_buf:
	.skip	88
rlimit_buf:
	.skip	16
time_ts_buf:
	.skip	16
time_res_buf:
	.skip	16
time_tv_buf:
	.skip	8
time_req_buf:
	.skip	16
time_rem_buf:
	.skip	16
rusage_buf:
	.skip	72
tms_buf:
	.skip	16
sigaction_new:
	.skip	24
sigaction_old:
	.skip	24
sigaction_readback:
	.skip	24
sigmask_new:
	.skip	8
sigmask_old:
	.skip	8
sigmask_readback:
	.skip	8
sigpending_buf:
	.skip	8
sigalt_new:
	.skip	12
sigalt_old:
	.skip	12
sigalt_readback:
	.skip	12
