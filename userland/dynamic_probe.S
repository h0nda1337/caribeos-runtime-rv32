	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	AT_NULL, 0
	.equ	AT_BASE, 7
	.equ	AT_ENTRY, 9
	.equ	DT_NULL, 0
	.equ	DT_NEEDED, 1
	.equ	DT_PLTRELSZ, 2
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
	.equ	DT_VERSYM, 0x6ffffff0
	.equ	DT_VERNEED, 0x6ffffffe
	.equ	DT_VERNEEDNUM, 0x6fffffff
	.equ	R_RISCV_32, 1
	.equ	R_RISCV_RELATIVE, 3
	.equ	R_RISCV_JUMP_SLOT, 5
	.equ	RINFO_RELOC_TARGET_RISCV32, 0x00000101
	.equ	RINFO_CARIBE_PROBE_MAGIC_RISCV32, 0x00000201
	.equ	RINFO_RELOC_TARGET_JUMP_SLOT_RISCV32, 0x00000105
	.equ	RINFO_CARIBE_PROBE_CALL_JUMP_SLOT_RISCV32, 0x00000305
	.equ	RINFO_CARIBE_EXTRA_MAGIC_RISCV32, 0x00000401
	.equ	RINFO_CARIBE_CHAIN_MAGIC_RISCV32, 0x00000501
	.equ	RINFO_CARIBE_BUCKET_C_RISCV32, 0x00000601
	.equ	RINFO_CARIBE_BUCKET_A_RISCV32, 0x00000701
	.equ	RINFO_CARIBE_BUCKET_B_RISCV32, 0x00000801

#ifndef CARIBE_BUCKETS_VERNEED_HASH
#define CARIBE_BUCKETS_VERNEED_HASH 0x05dada80
#endif
#ifndef CARIBE_BUCKETS_VERNEED_OTHER
#define CARIBE_BUCKETS_VERNEED_OTHER 2
#endif
#ifndef CARIBE_MAIN_BUCKETS_VERSYM_INDEX
#define CARIBE_MAIN_BUCKETS_VERSYM_INDEX CARIBE_BUCKETS_VERNEED_OTHER
#endif

	.section .interp, "a"
	.asciz	"/lib/ld-caribe-rv32.so.1"

	.section .caribe.dynstr, "a"
dynstr:
	.byte	0
sym_reloc_target_name:
	.asciz	"reloc_target"
	.equ	sym_reloc_target_name_off, sym_reloc_target_name - dynstr
sym_caribe_probe_magic_name:
	.asciz	"caribe_probe_magic"
	.equ	sym_caribe_probe_magic_name_off, sym_caribe_probe_magic_name - dynstr
sym_caribe_probe_call_name:
	.asciz	"caribe_probe_call"
	.equ	sym_caribe_probe_call_name_off, sym_caribe_probe_call_name - dynstr
sym_caribe_extra_magic_name:
	.asciz	"caribe_extra_magic"
	.equ	sym_caribe_extra_magic_name_off, sym_caribe_extra_magic_name - dynstr
sym_caribe_chain_magic_name:
	.asciz	"caribe_chain_magic"
	.equ	sym_caribe_chain_magic_name_off, sym_caribe_chain_magic_name - dynstr
sym_caribe_bucket_c_name:
	.asciz	"caribe_bucket_c"
	.equ	sym_caribe_bucket_c_name_off, sym_caribe_bucket_c_name - dynstr
sym_caribe_bucket_a_name:
	.asciz	"caribe_bucket_a"
	.equ	sym_caribe_bucket_a_name_off, sym_caribe_bucket_a_name - dynstr
sym_caribe_bucket_b_name:
	.asciz	"caribe_bucket_b"
	.equ	sym_caribe_bucket_b_name_off, sym_caribe_bucket_b_name - dynstr
needed_lib_name:
	.asciz	"libcaribe-probe.so.1"
	.equ	needed_lib_name_off, needed_lib_name - dynstr
needed_extra_lib_name:
	.asciz	"libcaribe-extra.so.1"
	.equ	needed_extra_lib_name_off, needed_extra_lib_name - dynstr
needed_buckets_lib_name:
	.asciz	"libcaribe-buckets.so.1"
	.equ	needed_buckets_lib_name_off, needed_buckets_lib_name - dynstr
needed_buckets_version_name:
	.asciz	"CARIBE_BUCKETS_1.0"
	.equ	needed_buckets_version_name_off, needed_buckets_version_name - dynstr
soname_name:
	.asciz	"dynamic-bias-probe"
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
	.word	sym_reloc_target_name_off
	.word	reloc_target
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_probe_magic_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_probe_call_name_off
	.word	0
	.word	8
	.byte	0x12
	.byte	0
	.half	0
	.word	sym_caribe_extra_magic_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_chain_magic_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_bucket_c_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_bucket_a_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	.word	sym_caribe_bucket_b_name_off
	.word	0
	.word	4
	.byte	0x11
	.byte	0
	.half	0

	.section .caribe.versym, "a"
	.balign	2
dynversym:
	.half	0
	.half	1
	.half	1
	.half	1
	.half	1
	.half	1
	.half	CARIBE_MAIN_BUCKETS_VERSYM_INDEX
	.half	CARIBE_MAIN_BUCKETS_VERSYM_INDEX
	.half	CARIBE_MAIN_BUCKETS_VERSYM_INDEX

	.section .dynamic, "aw"
	.balign	4
	.word	DT_STRTAB
	.word	dynstr
	.word	DT_STRSZ
	.word	dynstr_end - dynstr
	.word	DT_NEEDED
	.word	needed_lib_name_off
	.word	DT_NEEDED
	.word	needed_extra_lib_name_off
	.word	DT_NEEDED
	.word	needed_buckets_lib_name_off
	.word	DT_SONAME
	.word	soname_name_off
	.word	DT_SYMTAB
	.word	dynsym
	.word	DT_SYMENT
	.word	16
	.word	DT_VERSYM
	.word	dynversym
	.word	DT_JMPREL
	.word	rel_plt
	.word	DT_PLTRELSZ
	.word	rel_plt_end - rel_plt
	.word	DT_PLTREL
	.word	DT_REL
	.word	DT_INIT
	.word	probe_init
	.word	DT_INIT_ARRAY
	.word	init_array
	.word	DT_INIT_ARRAYSZ
	.word	init_array_end - init_array
	.word	DT_REL
	.word	rel_dyn
	.word	DT_RELSZ
	.word	rel_dyn_end - rel_dyn
	.word	DT_RELENT
	.word	8
	.word	DT_VERNEED
	.word	verneed
	.word	DT_VERNEEDNUM
	.word	1
	.word	DT_NULL
	.word	0

	.section .caribe.verneed, "a"
	.balign	4
verneed:
	.half	1
	.half	1
	.word	needed_buckets_lib_name_off
	.word	vernaux - verneed
	.word	0
vernaux:
	.word	CARIBE_BUCKETS_VERNEED_HASH
	.half	0
	.half	CARIBE_BUCKETS_VERNEED_OTHER
	.word	needed_buckets_version_name_off
	.word	0

	.section .caribe.rel, "a"
	.balign	4
rel_dyn:
	.word	reloc_word
	.word	R_RISCV_RELATIVE
	.word	symbol_reloc_word
	.word	RINFO_RELOC_TARGET_RISCV32
	.word	needed_symbol_word
	.word	RINFO_CARIBE_PROBE_MAGIC_RISCV32
	.word	extra_symbol_word
	.word	RINFO_CARIBE_EXTRA_MAGIC_RISCV32
	.word	chain_symbol_word
	.word	RINFO_CARIBE_CHAIN_MAGIC_RISCV32
	.word	bucket0_symbol_word
	.word	RINFO_CARIBE_BUCKET_C_RISCV32
	.word	bucket1_symbol_word
	.word	RINFO_CARIBE_BUCKET_A_RISCV32
	.word	bucket2_symbol_word
	.word	RINFO_CARIBE_BUCKET_B_RISCV32
	.word	init_array
	.word	R_RISCV_RELATIVE
	.word	init_array + 4
	.word	R_RISCV_RELATIVE
rel_dyn_end:

	.section .caribe.jmprel, "a"
	.balign	4
rel_plt:
	.word	jump_slot_word
	.word	RINFO_RELOC_TARGET_JUMP_SLOT_RISCV32
	.word	needed_call_slot
	.word	RINFO_CARIBE_PROBE_CALL_JUMP_SLOT_RISCV32
rel_plt_end:

	.section .init_array, "aw"
	.balign	4
init_array:
	.word	probe_init_array0
	.word	probe_init_array1
init_array_end:

	.section .rodata, "a"
unexpected_msg:
	.ascii	"[dynamic-probe] unexpected direct entry\n"
	.equ	unexpected_msg_len, . - unexpected_msg
main_msg:
	.ascii	"[dynamic-probe] main entry reached via ld-caribe\n"
	.equ	main_msg_len, . - main_msg
base_msg:
	.ascii	"[dynamic-probe] AT_BASE loader="
	.equ	base_msg_len, . - base_msg
entry_msg:
	.ascii	"[dynamic-probe] AT_ENTRY self="
	.equ	entry_msg_len, . - entry_msg
reloc_msg:
	.ascii	"[dynamic-probe] relocated word="
	.equ	reloc_msg_len, . - reloc_msg
symbol_msg:
	.ascii	"[dynamic-probe] symbol word="
	.equ	symbol_msg_len, . - symbol_msg
needed_symbol_msg:
	.ascii	"[dynamic-probe] needed symbol word="
	.equ	needed_symbol_msg_len, . - needed_symbol_msg
needed_symbol_value_msg:
	.ascii	"[dynamic-probe] needed symbol value="
	.equ	needed_symbol_value_msg_len, . - needed_symbol_value_msg
extra_symbol_msg:
	.ascii	"[dynamic-probe] extra symbol word="
	.equ	extra_symbol_msg_len, . - extra_symbol_msg
extra_symbol_value_msg:
	.ascii	"[dynamic-probe] extra symbol value="
	.equ	extra_symbol_value_msg_len, . - extra_symbol_value_msg
chain_symbol_msg:
	.ascii	"[dynamic-probe] chain symbol word="
	.equ	chain_symbol_msg_len, . - chain_symbol_msg
chain_symbol_value_msg:
	.ascii	"[dynamic-probe] chain symbol value="
	.equ	chain_symbol_value_msg_len, . - chain_symbol_value_msg
bucket0_symbol_msg:
	.ascii	"[dynamic-probe] gnu bucket0 symbol word="
	.equ	bucket0_symbol_msg_len, . - bucket0_symbol_msg
bucket0_symbol_value_msg:
	.ascii	"[dynamic-probe] gnu bucket0 symbol value="
	.equ	bucket0_symbol_value_msg_len, . - bucket0_symbol_value_msg
bucket1_symbol_msg:
	.ascii	"[dynamic-probe] gnu bucket1 symbol word="
	.equ	bucket1_symbol_msg_len, . - bucket1_symbol_msg
bucket1_symbol_value_msg:
	.ascii	"[dynamic-probe] gnu bucket1 symbol value="
	.equ	bucket1_symbol_value_msg_len, . - bucket1_symbol_value_msg
bucket2_symbol_msg:
	.ascii	"[dynamic-probe] gnu bucket2 symbol word="
	.equ	bucket2_symbol_msg_len, . - bucket2_symbol_msg
bucket2_symbol_value_msg:
	.ascii	"[dynamic-probe] gnu bucket2 symbol value="
	.equ	bucket2_symbol_value_msg_len, . - bucket2_symbol_value_msg
jump_slot_msg:
	.ascii	"[dynamic-probe] jump slot word="
	.equ	jump_slot_msg_len, . - jump_slot_msg
needed_call_slot_msg:
	.ascii	"[dynamic-probe] needed call slot="
	.equ	needed_call_slot_msg_len, . - needed_call_slot_msg
needed_call_value_msg:
	.ascii	"[dynamic-probe] needed call value="
	.equ	needed_call_value_msg_len, . - needed_call_value_msg
init_msg:
	.ascii	"[dynamic-probe] init word="
	.equ	init_msg_len, . - init_msg
init_array0_msg:
	.ascii	"[dynamic-probe] init array0 word="
	.equ	init_array0_msg_len, . - init_array0_msg
init_array1_msg:
	.ascii	"[dynamic-probe] init array1 word="
	.equ	init_array1_msg_len, . - init_array1_msg
newline:
	.ascii	"\n"
	.equ	newline_len, . - newline
hex_digits:
	.ascii	"0123456789abcdef"

	.section .text, "ax"
	.globl _start
	.type _start, @function

_start:
	mv	s0, sp
	li	s1, 0
	li	s2, 0

	lw	t0, 0(s0)
	addi	t1, s0, 4
	slli	t2, t0, 2
	add	t1, t1, t2
	addi	t1, t1, 4
1:
	lw	t2, 0(t1)
	addi	t1, t1, 4
	bnez	t2, 1b
2:
	lw	t2, 0(t1)
	lw	t3, 4(t1)
	li	t4, AT_NULL
	beq	t2, t4, 3f
	li	t4, AT_BASE
	bne	t2, t4, 4f
	mv	s1, t3
	j	5f
4:
	li	t4, AT_ENTRY
	bne	t2, t4, 5f
	mv	s2, t3
5:
	addi	t1, t1, 8
	j	2b
3:
	beqz	s1, direct_entry

	la	a1, main_msg
	li	a2, main_msg_len
	call	write_stdout
	la	a1, base_msg
	li	a2, base_msg_len
	call	write_stdout
	mv	a0, s1
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, entry_msg
	li	a2, entry_msg_len
	call	write_stdout
	mv	a0, s2
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, reloc_msg
	li	a2, reloc_msg_len
	call	write_stdout
	la	t0, reloc_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, symbol_msg
	li	a2, symbol_msg_len
	call	write_stdout
	la	t0, symbol_reloc_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_symbol_msg
	li	a2, needed_symbol_msg_len
	call	write_stdout
	la	t0, needed_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_symbol_value_msg
	li	a2, needed_symbol_value_msg_len
	call	write_stdout
	la	t0, needed_symbol_word
	lw	t0, 0(t0)
	beqz	t0, 8f
	lw	a0, 0(t0)
	j	9f
8:
	li	a0, 0
9:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, extra_symbol_msg
	li	a2, extra_symbol_msg_len
	call	write_stdout
	la	t0, extra_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, extra_symbol_value_msg
	li	a2, extra_symbol_value_msg_len
	call	write_stdout
	la	t0, extra_symbol_word
	lw	t0, 0(t0)
	beqz	t0, 10f
	lw	a0, 0(t0)
	j	11f
10:
	li	a0, 0
11:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, chain_symbol_msg
	li	a2, chain_symbol_msg_len
	call	write_stdout
	la	t0, chain_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, chain_symbol_value_msg
	li	a2, chain_symbol_value_msg_len
	call	write_stdout
	la	t0, chain_symbol_word
	lw	t0, 0(t0)
	beqz	t0, 12f
	lw	a0, 0(t0)
	j	13f
12:
	li	a0, 0
13:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket0_symbol_msg
	li	a2, bucket0_symbol_msg_len
	call	write_stdout
	la	t0, bucket0_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket0_symbol_value_msg
	li	a2, bucket0_symbol_value_msg_len
	call	write_stdout
	la	t0, bucket0_symbol_word
	lw	t0, 0(t0)
	beqz	t0, bucket0_missing
	lw	a0, 0(t0)
	j	bucket0_done
bucket0_missing:
	li	a0, 0
bucket0_done:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket1_symbol_msg
	li	a2, bucket1_symbol_msg_len
	call	write_stdout
	la	t0, bucket1_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket1_symbol_value_msg
	li	a2, bucket1_symbol_value_msg_len
	call	write_stdout
	la	t0, bucket1_symbol_word
	lw	t0, 0(t0)
	beqz	t0, bucket1_missing
	lw	a0, 0(t0)
	j	bucket1_done
bucket1_missing:
	li	a0, 0
bucket1_done:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket2_symbol_msg
	li	a2, bucket2_symbol_msg_len
	call	write_stdout
	la	t0, bucket2_symbol_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, bucket2_symbol_value_msg
	li	a2, bucket2_symbol_value_msg_len
	call	write_stdout
	la	t0, bucket2_symbol_word
	lw	t0, 0(t0)
	beqz	t0, bucket2_missing
	lw	a0, 0(t0)
	j	bucket2_done
bucket2_missing:
	li	a0, 0
bucket2_done:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, jump_slot_msg
	li	a2, jump_slot_msg_len
	call	write_stdout
	la	t0, jump_slot_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_call_slot_msg
	li	a2, needed_call_slot_msg_len
	call	write_stdout
	la	t0, needed_call_slot
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, needed_call_value_msg
	li	a2, needed_call_value_msg_len
	call	write_stdout
	la	t0, needed_call_slot
	lw	t0, 0(t0)
	beqz	t0, needed_call_missing
	jalr	ra, t0, 0
	j	needed_call_done
needed_call_missing:
	li	a0, 0
needed_call_done:
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, init_msg
	li	a2, init_msg_len
	call	write_stdout
	la	t0, init_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, init_array0_msg
	li	a2, init_array0_msg_len
	call	write_stdout
	la	t0, init_array0_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	la	a1, init_array1_msg
	li	a2, init_array1_msg_len
	call	write_stdout
	la	t0, init_array1_word
	lw	a0, 0(t0)
	call	write_hex32_stdout
	la	a1, newline
	li	a2, newline_len
	call	write_stdout
	li	a0, 0
	li	a7, SYS_EXIT_GROUP
	ecall

direct_entry:
	la	a1, unexpected_msg
	li	a2, unexpected_msg_len
	call	write_stdout
	li	a0, 88
	li	a7, SYS_EXIT_GROUP
	ecall
6:
	j	6b

probe_init:
	la	t0, init_word
	li	t1, 0x494e4954
	sw	t1, 0(t0)
	ret

probe_init_array0:
	la	t0, init_array0_word
	li	t1, 0x41525230
	sw	t1, 0(t0)
	ret

probe_init_array1:
	la	t0, init_array1_word
	li	t1, 0x41525231
	sw	t1, 0(t0)
	ret

write_stdout:
	li	a0, 1
	li	a7, SYS_WRITE
	ecall
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
	ret

	.section .bss, "aw", @nobits
	.balign	16
hex_buf:
	.skip	10

	.section .data, "aw"
	.balign	4
reloc_word:
	.word	reloc_target
reloc_target:
	.word	0x52454c31
symbol_reloc_word:
	.word	0
needed_symbol_word:
	.word	0
extra_symbol_word:
	.word	0
chain_symbol_word:
	.word	0
bucket0_symbol_word:
	.word	0
bucket1_symbol_word:
	.word	0
bucket2_symbol_word:
	.word	0
jump_slot_word:
	.word	0
needed_call_slot:
	.word	0
init_word:
	.word	0
init_array0_word:
	.word	0
init_array1_word:
	.word	0
