/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.section .interp, "a", @progbits
	.asciz	"/lib/ld-gate6-missing.so.1"

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	li	a0, 95
	li	a7, 94
	ecall
1:
	j	1b
