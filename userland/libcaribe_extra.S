/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

	.equ	DT_NULL, 0
	.equ	DT_PLTRELSZ, 2
	.equ	DT_HASH, 4
	.equ	DT_STRTAB, 5
	.equ	DT_SYMTAB, 6
	.equ	DT_STRSZ, 10
	.equ	DT_SYMENT, 11
	.equ	DT_INIT, 12
	.equ	DT_SONAME, 14
	.equ	DT_REL, 17
	.equ	DT_RELSZ, 18
	.equ	DT_RELENT, 19
	.equ	DT_PLTREL, 20
	.equ	DT_JMPREL, 23
	.equ	DT_INIT_ARRAY, 25
	.equ	DT_INIT_ARRAYSZ, 27
	.equ	DT_GNU_HASH, 0x6ffffef5
	.equ	R_RISCV_32, 1
	.equ	R_RISCV_RELATIVE, 3
	.equ	R_RISCV_JUMP_SLOT, 5
	.equ	RINFO_CARIBE_PROBE_MAGIC_RISCV32, 0x00000201
	.equ	RINFO_CARIBE_PROBE_CALL_JUMP_SLOT_RISCV32, 0x00000305
	.equ	RINFO_CARIBE_PROBE_AUX1_RISCV32, 0x00000401
	.equ	RINFO_CARIBE_PROBE_AUX2_RISCV32, 0x00000501
	.equ	RINFO_CARIBE_PROBE_AUX3_RISCV32, 0x00000601
	.equ	RINFO_CARIBE_PROBE_AUX4_RISCV32, 0x00000701
	.equ	RINFO_CARIBE_PROBE_AUX5_RISCV32, 0x00000801
	.equ	RINFO_CARIBE_PROBE_AUX6_RISCV32, 0x00000901
	.equ	RINFO_CARIBE_OPTIONAL_MISSING_RISCV32, 0x00000a01

	.section .caribe.dynstr, "a"
dynstr:
	.byte	0
sym_extra_magic_name:
	.asciz	"caribe_extra_magic"
	.equ	sym_extra_magic_name_off, sym_extra_magic_name - dynstr
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
sym_optional_missing_name:
	.asciz	"caribe_optional_missing"
	.equ	sym_optional_missing_name_off, sym_optional_missing_name - dynstr
soname_name:
	.asciz	"libcaribe-extra.so.1"
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
	.word	sym_extra_magic_name_off
	.word	caribe_extra_magic
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_magic_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_call_name_off
	.word	0
	.word	8
	.byte	0x12
	.byte	0
	.half	0
	.word	sym_probe_aux1_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux2_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux3_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux4_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux5_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_probe_aux6_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_optional_missing_name_off
	.word	0
	.word	4
	.byte	0x21
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
	.word	0x6080623f
	.word	1
	.word	0x37b289ae
	.word	0x03cc5ca2
	.word	0x937cd53c
	.word	0x937c12e0
	.word	0x937c12e0
	.word	0x937c12e2
	.word	0x937c12e2
	.word	0x937c12e4
	.word	0x937c12e4
	.word	0xcbe563c9

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
	.word	DT_SONAME
	.word	soname_name_off
	.word	DT_SYMTAB
	.word	dynsym
	.word	DT_SYMENT
	.word	16
	.word	DT_INIT
	.word	lib_extra_init
	.word	DT_INIT_ARRAY
	.word	lib_extra_init_array
	.word	DT_INIT_ARRAYSZ
	.word	lib_extra_init_array_end - lib_extra_init_array
	.word	DT_REL
	.word	lib_extra_rel
	.word	DT_RELSZ
	.word	lib_extra_rel_end - lib_extra_rel
	.word	DT_RELENT
	.word	8
	.word	DT_JMPREL
	.word	lib_extra_jmprel
	.word	DT_PLTRELSZ
	.word	lib_extra_jmprel_end - lib_extra_jmprel
	.word	DT_PLTREL
	.word	DT_REL
	.word	DT_NULL
	.word	0

	.section .caribe.rel, "a"
	.balign	4
lib_extra_rel:
	.word	lib_extra_init_array
	.word	R_RISCV_RELATIVE
	.word	probe_magic_ptr
	.word	RINFO_CARIBE_PROBE_MAGIC_RISCV32
	.word	probe_aux1_ptr
	.word	RINFO_CARIBE_PROBE_AUX1_RISCV32
	.word	probe_aux2_ptr
	.word	RINFO_CARIBE_PROBE_AUX2_RISCV32
	.word	probe_aux3_ptr
	.word	RINFO_CARIBE_PROBE_AUX3_RISCV32
	.word	probe_aux4_ptr
	.word	RINFO_CARIBE_PROBE_AUX4_RISCV32
	.word	probe_aux5_ptr
	.word	RINFO_CARIBE_PROBE_AUX5_RISCV32
	.word	probe_aux6_ptr
	.word	RINFO_CARIBE_PROBE_AUX6_RISCV32
	.word	weak_missing_ptr
	.word	RINFO_CARIBE_OPTIONAL_MISSING_RISCV32
lib_extra_rel_end:

	.section .caribe.jmprel, "a"
	.balign	4
lib_extra_jmprel:
	.word	probe_call_slot
	.word	RINFO_CARIBE_PROBE_CALL_JUMP_SLOT_RISCV32
lib_extra_jmprel_end:

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	ret

lib_extra_init:
	la	t0, caribe_extra_magic
	li	t1, 0x43455831
	sw	t1, 0(t0)
	ret

lib_extra_init_array0:
	addi	sp, sp, -16
	sw	ra, 12(sp)
	la	t0, probe_magic_ptr
	lw	t0, 0(t0)
	beqz	t0, 3f
	la	t0, probe_call_slot
	lw	t0, 0(t0)
	beqz	t0, 2f
	jalr	ra, t0, 0
	li	t0, 0x4342464e
	bne	a0, t0, 2f
	la	t0, probe_aux1_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524131
	bne	t2, t3, 2f
	la	t0, probe_aux2_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524132
	bne	t2, t3, 2f
	la	t0, probe_aux3_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524133
	bne	t2, t3, 2f
	la	t0, probe_aux4_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524134
	bne	t2, t3, 2f
	la	t0, probe_aux5_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524135
	bne	t2, t3, 2f
	la	t0, probe_aux6_ptr
	lw	t0, 0(t0)
	beqz	t0, 2f
	lw	t2, 0(t0)
	li	t3, 0x50524136
	bne	t2, t3, 2f
	la	t0, weak_missing_ptr
	lw	t0, 0(t0)
	bnez	t0, 2f
	li	t1, 0x43455836
	j	4f
2:
	li	t1, 0x43455822
	j	4f
3:
	li	t1, 0x43455821
4:
	la	t0, caribe_extra_magic
	sw	t1, 0(t0)
	lw	ra, 12(sp)
	addi	sp, sp, 16
	ret

	.section .init_array, "aw"
	.balign	4
lib_extra_init_array:
	.word	lib_extra_init_array0
lib_extra_init_array_end:

	.section .data, "aw"
	.globl	caribe_extra_magic
	.type	caribe_extra_magic, @object
caribe_extra_magic:
	.word	0
probe_magic_ptr:
	.word	0
probe_call_slot:
	.word	0
probe_aux1_ptr:
	.word	0
probe_aux2_ptr:
	.word	0
probe_aux3_ptr:
	.word	0
probe_aux4_ptr:
	.word	0
probe_aux5_ptr:
	.word	0
probe_aux6_ptr:
	.word	0
weak_missing_ptr:
	.word	0
