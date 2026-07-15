	.equ	DT_NULL, 0
	.equ	DT_HASH, 4
	.equ	DT_STRTAB, 5
	.equ	DT_SYMTAB, 6
	.equ	DT_STRSZ, 10
	.equ	DT_SYMENT, 11
	.equ	DT_SONAME, 14
	.equ	DT_GNU_HASH, 0x6ffffef5
	.equ	DT_VERSYM, 0x6ffffff0
	.equ	DT_VERDEF, 0x6ffffffc
	.equ	DT_VERDEFNUM, 0x6ffffffd

#ifndef CARIBE_BUCKETS_VERSYM_INDEX
#define CARIBE_BUCKETS_VERSYM_INDEX 2
#endif

	.section .caribe.dynstr, "a"
dynstr:
	.byte	0
sym_bucket_c_name:
	.asciz	"caribe_bucket_c"
	.equ	sym_bucket_c_name_off, sym_bucket_c_name - dynstr
sym_bucket_a_name:
	.asciz	"caribe_bucket_a"
	.equ	sym_bucket_a_name_off, sym_bucket_a_name - dynstr
sym_bucket_b_name:
	.asciz	"caribe_bucket_b"
	.equ	sym_bucket_b_name_off, sym_bucket_b_name - dynstr
soname_name:
	.asciz	"libcaribe-buckets.so.1"
	.equ	soname_name_off, soname_name - dynstr
version_name:
#ifdef CARIBE_BUCKETS_BAD_VERDEF_NAME
	.asciz	"CARIBE_BUCKETS_2.0"
#else
	.asciz	"CARIBE_BUCKETS_1.0"
#endif
	.equ	version_name_off, version_name - dynstr
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
	/* bucket 0: gnu_hash("caribe_bucket_c") % 3 */
	.word	sym_bucket_c_name_off
	.word	caribe_bucket_c
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	/* bucket 1: gnu_hash("caribe_bucket_a") % 3 */
	.word	sym_bucket_a_name_off
	.word	caribe_bucket_a
	.word	4
	.byte	0x11
	.byte	0
	.half	0
	/* bucket 2: gnu_hash("caribe_bucket_b") % 3 */
	.word	sym_bucket_b_name_off
	.word	caribe_bucket_b
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
	.word	3
	.word	1
	.word	1
	.word	5
	.word	0x00000f00
	.word	1
	.word	2
	.word	3
	.word	0x0b5e296b
	.word	0x0b5e2969
	.word	0x0b5e2969

	.section .caribe.versym, "a"
	.balign	2
dynversym:
	.half	0
	.half	CARIBE_BUCKETS_VERSYM_INDEX
	.half	CARIBE_BUCKETS_VERSYM_INDEX
	.half	CARIBE_BUCKETS_VERSYM_INDEX

	.section .caribe.verdef, "a"
	.balign	4
dynverdef:
	.half	1
	.half	0
	.half	2
	.half	1
	.word	0x05dada80
	.word	dynverdaux - dynverdef
	.word	0
dynverdaux:
	.word	version_name_off
	.word	0

	.section .dynamic, "aw"
	.balign	4
	.word	DT_STRTAB
	.word	dynstr
	.word	DT_STRSZ
	.word	dynstr_end - dynstr
	.word	DT_HASH
	.word	dynhash
#ifndef CARIBE_BUCKETS_NO_GNU_HASH
	.word	DT_GNU_HASH
	.word	dyngnuhash
#endif
#ifndef CARIBE_BUCKETS_NO_VERSYM
	.word	DT_VERSYM
	.word	dynversym
#endif
	.word	DT_VERDEF
	.word	dynverdef
	.word	DT_VERDEFNUM
	.word	1
	.word	DT_SONAME
	.word	soname_name_off
	.word	DT_SYMTAB
	.word	dynsym
	.word	DT_SYMENT
	.word	16
	.word	DT_NULL
	.word	0

	.section .text, "ax"
	.globl	_start
	.type	_start, @function
_start:
	ret

	.section .data, "aw"
	.globl	caribe_bucket_c
	.type	caribe_bucket_c, @object
caribe_bucket_c:
	.word	0x424b5430
	.globl	caribe_bucket_a
	.type	caribe_bucket_a, @object
caribe_bucket_a:
	.word	0x424b5431
	.globl	caribe_bucket_b
	.type	caribe_bucket_b, @object
caribe_bucket_b:
	.word	0x424b5432
