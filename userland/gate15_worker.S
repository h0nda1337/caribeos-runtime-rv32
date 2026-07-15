/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

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
