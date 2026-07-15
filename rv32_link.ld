OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
  . = 0;
  .text : { *(.text._start) *(.text*) *(.rodata*) }
  /DISCARD/ : { *(.comment*) *(.eh_frame*) *(.data*) *(.bss*) *(.sdata*) *(.sbss*) }
}
