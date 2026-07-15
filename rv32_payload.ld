/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

ENTRY(_start)
PHDRS { text PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
  . = 0x80410000;
  .text : ALIGN(4) { *(.text._start) *(.text*) *(.rodata*) } :text
  .data : ALIGN(4) { *(.data*) } :data
  .bss (NOLOAD) : ALIGN(4) { *(.bss*) *(COMMON) } :data
  /DISCARD/ : { *(.comment*) *(.note*) }
}
