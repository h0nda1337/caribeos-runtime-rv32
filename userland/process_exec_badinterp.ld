/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

ENTRY(_start)

PHDRS
{
	interp PT_INTERP FLAGS(4);
	text PT_LOAD FLAGS(5);
}

SECTIONS
{
	. = 0x2a000;
	.interp : { *(.interp) } :interp :text
	.text : { *(.text*) *(.rodata*) } :text
}
