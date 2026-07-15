	.equ	SYS_EXIT_GROUP, 94

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall
1:
	j	1b
