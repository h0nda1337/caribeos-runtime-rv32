	.equ	SYS_WRITE, 64
	.equ	SYS_EXIT_GROUP, 94
	.equ	AT_NULL, 0
	.equ	AT_BASE, 7
	.equ	AT_ENTRY, 9

	.section .interp, "a"
	.asciz	"/lib/ld-caribe-rv32.so.1"

	.section .rodata, "a"
unexpected_msg:
	.ascii	"[interp-probe] unexpected direct entry\n"
	.equ	unexpected_msg_len, . - unexpected_msg
main_msg:
	.ascii	"[interp-probe] main entry reached via ld-caribe\n"
	.equ	main_msg_len, . - main_msg
base_msg:
	.ascii	"[interp-probe] AT_BASE loader="
	.equ	base_msg_len, . - base_msg
entry_msg:
	.ascii	"[interp-probe] AT_ENTRY self="
	.equ	entry_msg_len, . - entry_msg
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
