ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  __caribebootx_start = .;

  .text : {
    *(.text.entry)
    *(.text .text.*)
    *(.rodata .rodata.*)
  }

  .data : {
    *(.data .data.*)
  }

  .bss (NOLOAD) : {
    *(.bss .bss.*)
    *(COMMON)
  }
  __caribebootx_end = .;

  /DISCARD/ : {
    *(.comment*)
    *(.note*)
    *(.eh_frame*)
  }
}
