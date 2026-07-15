/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	DT_NULL, 0
	.equ	DT_NEEDED, 1
	.equ	DT_HASH, 4
	.equ	DT_STRTAB, 5
	.equ	DT_SYMTAB, 6
	.equ	DT_STRSZ, 10
	.equ	DT_SYMENT, 11
	.equ	DT_INIT, 12
	.equ	DT_SONAME, 14
	.equ	DT_GNU_HASH, 0x6ffffef5

	.section .caribe.dynstr, "a"
dynstr:
	.byte	0
sym_probe_magic_name:
	.asciz	"caribe_probe_magic"
	.equ	sym_probe_magic_name_off, sym_probe_magic_name - dynstr
sym_probe_call_name:
	.asciz	"caribe_probe_call"
	.equ	sym_probe_call_name_off, sym_probe_call_name - dynstr
sym_probe_aux1_name:
	.asciz	"caribe_probe_aux1"
	.equ	sym_probe_aux1_name_off, sym_probe_aux1_name - dynstr
sym_probe_aux2_name:
	.asciz	"caribe_probe_aux2"
	.equ	sym_probe_aux2_name_off, sym_probe_aux2_name - dynstr
sym_probe_aux3_name:
	.asciz	"caribe_probe_aux3"
	.equ	sym_probe_aux3_name_off, sym_probe_aux3_name - dynstr
sym_probe_aux4_name:
	.asciz	"caribe_probe_aux4"
	.equ	sym_probe_aux4_name_off, sym_probe_aux4_name - dynstr
sym_probe_aux5_name:
	.asciz	"caribe_probe_aux5"
	.equ	sym_probe_aux5_name_off, sym_probe_aux5_name - dynstr
sym_probe_aux6_name:
	.asciz	"caribe_probe_aux6"
	.equ	sym_probe_aux6_name_off, sym_probe_aux6_name - dynstr
needed_extra_lib_name:
	.asciz	"libcaribe-extra.so.1"
	.equ	needed_extra_lib_name_off, needed_extra_lib_name - dynstr
needed_chain_lib_name:
	.asciz	"libcaribe-chain.so.1"
	.equ	needed_chain_lib_name_off, needed_chain_lib_name - dynstr
soname_name:
	.asciz	"libcaribe-probe.so.1"
	.equ	soname_name_off, soname_name - dynstr
dynstr_end:

	.section .caribe.dynsym, "a"
	.balign	4
dynsym:
	.word	0
	.word	0
	.word	0
	.byte	0
	.byte	0
	.half	0
	.word	sym_probe_magic_name_off
	.word	caribe_probe_magic
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_call_name_off
	.word	caribe_probe_call
	.word	caribe_probe_call_end - caribe_probe_call
	.byte	0x12
	.byte	0
	.half	0
	.word	sym_probe_aux6_name_off
	.word	caribe_probe_aux6_shadow
	.word	4
	.byte	0x01
	.byte	0
	.half	0
	.word	sym_probe_aux1_name_off
	.word	caribe_probe_aux1
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux2_name_off
	.word	caribe_probe_aux2
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux3_name_off
	.word	caribe_probe_aux3
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux4_name_off
	.word	caribe_probe_aux4
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux5_name_off
	.word	caribe_probe_aux5
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux6_name_off
	.word	caribe_probe_aux6
	.word	4
	.byte	0x11
	.byte	0
	.half	0
dynsym_end:

	.section .caribe.hash, "a"
	.balign	4
dynhash:
	.word	1
	.word	(dynsym_end - dynsym) / 16
	.word	0
	.rept	(dynsym_end - dynsym) / 16
	.word	0
	.endr

	.section .caribe.gnu_hash, "a"
	.balign	4
dyngnuhash:
	.word	1
	.word	1
	.word	1
	.word	5
	.word	0x2080023f
	.word	1
	.word	0x03cc5ca2
	.word	0x937cd53c
	.word	0x937c12e4
	.word	0x937c12e0
	.word	0x937c12e0
	.word	0x937c12e2
	.word	0x937c12e2
	.word	0x937c12e4
	.word	0x937c12e5

	.section .dynamic, "aw"
	.balign	4
	.word	DT_STRTAB
	.word	dynstr
	.word	DT_STRSZ
	.word	dynstr_end - dynstr
	.word	DT_HASH
	.word	dynhash
	.word	DT_GNU_HASH
	.word	dyngnuhash
	.word	DT_NEEDED
	.word	needed_extra_lib_name_off
	.word	DT_NEEDED
	.word	needed_chain_lib_name_off
	.word	DT_SONAME
	.word	soname_name_off
	.word	DT_SYMTAB
	.word	dynsym
	.word	DT_SYMENT
	.word	16
	.word	DT_INIT
	.word	lib_probe_init
	.word	DT_NULL
	.word	0

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	ret

	.globl	caribe_probe_call
	.type	caribe_probe_call, @function
	.balign	4
caribe_probe_call:
	li	a0, 0x4342464e
	ret
caribe_probe_call_end:

lib_probe_init:
	la	t0, caribe_probe_magic
	li	t1, 0x43425031
	sw	t1, 0(t0)
	ret

	.section .data, "aw"
	.globl	caribe_probe_magic
	.type	caribe_probe_magic, @object
caribe_probe_magic:
	.word	0
	.globl	caribe_probe_aux1
	.type	caribe_probe_aux1, @object
caribe_probe_aux1:
	.word	0x50524131
	.globl	caribe_probe_aux2
	.type	caribe_probe_aux2, @object
caribe_probe_aux2:
	.word	0x50524132
	.globl	caribe_probe_aux3
	.type	caribe_probe_aux3, @object
caribe_probe_aux3:
	.word	0x50524133
	.globl	caribe_probe_aux4
	.type	caribe_probe_aux4, @object
caribe_probe_aux4:
	.word	0x50524134
	.globl	caribe_probe_aux5
	.type	caribe_probe_aux5, @object
caribe_probe_aux5:
	.word	0x50524135
	.globl	caribe_probe_aux6
	.type	caribe_probe_aux6, @object
caribe_probe_aux6:
	.word	0x50524136
caribe_probe_aux6_shadow:
	.word	0x53584436
