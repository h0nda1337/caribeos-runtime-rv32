/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

ENTRY(_start)

/* Cargaremos el payload en 0x80400000 (fuera del rango del booter) */
SECTIONS {
  . = 0x80400000;

  /* Código de arranque primero */
  .text : {
    *(.text.boot)
    *(.text*)
  }

  .rodata : {
    *(.rodata*)
  }

  .data : {
    *(.data*)
  }

  /* BSS sin carga */
  .bss (NOLOAD) : {
    __bss_start = .;
    *(.bss*)
    *(COMMON)
    __bss_end = .;
  }

  /* Reserva de pila simple (16 KiB) y símbolo de tope */
  . = ALIGN(16);
  . += 16K;
  __stack_top = .;
}
