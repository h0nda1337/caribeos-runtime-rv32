    .option norvc
    .section .text
    .globl _start
_start:
    lui     t0, 0x10000        # UART 0x10000000
    la      t1, msg
1:  lbu     t2, 0(t1)
    beqz    t2, 2f
    sb      t2, 0(t0)
    addi    t1, t1, 1
    j       1b
2:  ret
    .section .rodata
msg:
    .asciz "ELF says hi!\r\n"
