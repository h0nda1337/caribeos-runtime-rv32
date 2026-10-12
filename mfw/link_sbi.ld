/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

ENTRY(_start)
SECTIONS
{
  . = 0x80200000;
  __caribebootx_start = .;

  .text : {
    *(.text.entry)
    *(.text .text.*)
    *(.rodata .rodata.*)
  }

  .data : {
    *(.sdata .sdata.*)
    *(.data .data.*)
  }

  .bss (NOLOAD) : {
    *(.sbss .sbss.*)
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
