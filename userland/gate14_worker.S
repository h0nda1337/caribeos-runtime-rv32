	.equ	SYS_EXIT_GROUP, 94
	.equ	SYS_GETCPU, 168
	.equ	SYS_MUNMAP, 215
	.equ	SYS_MMAP, 222
	.equ	SYS_MPROTECT, 226
	.equ	PROT_READ, 1
	.equ	PROT_WRITE, 2
	.equ	MAP_PRIVATE, 2
	.equ	MAP_ANONYMOUS, 0x20
	.equ	PAGE_SIZE, 4096

	.section .bss, "aw", @nobits
	.align	2
cpu_slot:
	.space	4
node_slot:
	.space	4

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	la	a0, cpu_slot
	la	a1, node_slot
	li	a2, 0
	li	a7, SYS_GETCPU
	ecall
	bnez	a0, worker_fail
	la	t0, cpu_slot
	lw	t1, 0(t0)
	li	t2, 1
	bne	t1, t2, worker_fail
	la	t0, node_slot
	lw	t1, 0(t0)
	bnez	t1, worker_fail

	li	a0, 0
	li	a1, PAGE_SIZE
	li	a2, PROT_READ | PROT_WRITE
	li	a3, MAP_PRIVATE | MAP_ANONYMOUS
	li	a4, -1
	li	a5, 0
	li	a7, SYS_MMAP
	ecall
	bltz	a0, worker_fail
	mv	s0, a0
	li	t0, 0x14c0ffee
	sw	t0, 0(s0)
	li	t1, PAGE_SIZE - 4
	add	t1, s0, t1
	not	t2, t0
	sw	t2, 0(t1)

	mv	a0, s0
	li	a1, PAGE_SIZE
	li	a2, PROT_READ
	li	a7, SYS_MPROTECT
	ecall
	bnez	a0, worker_fail
	lw	t1, 0(s0)
	bne	t1, t0, worker_fail
	li	t1, PAGE_SIZE - 4
	add	t1, s0, t1
	lw	t1, 0(t1)
	bne	t1, t2, worker_fail

	mv	a0, s0
	li	a1, PAGE_SIZE
	li	a7, SYS_MUNMAP
	ecall
	bnez	a0, worker_fail
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b

worker_fail:
	li	a0, 90
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b
