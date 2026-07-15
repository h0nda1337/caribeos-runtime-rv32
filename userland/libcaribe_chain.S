	.equ	DT_NULL, 0
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
sym_chain_magic_name:
	.asciz	"caribe_chain_magic"
	.equ	sym_chain_magic_name_off, sym_chain_magic_name - dynstr
soname_name:
	.asciz	"libcaribe-chain.so.1"
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
	.word	sym_chain_magic_name_off
	.word	caribe_chain_magic
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
	.word	0x80002000
	.word	1
	.word	0xe17843ed

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
	.word	lib_chain_init
	.word	DT_NULL
	.word	0

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	ret

lib_chain_init:
	la	t0, caribe_chain_magic
	li	t1, 0x43484e31
	sw	t1, 0(t0)
	ret

	.section .data, "aw"
	.globl	caribe_chain_magic
	.type	caribe_chain_magic, @object
caribe_chain_magic:
	.word	0
