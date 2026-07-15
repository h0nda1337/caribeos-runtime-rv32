/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once
#include <stdint.h>

void console_init(void);
void console_rx_char(char c);
void console_on_tick(uint32_t ticks);
/* Permite pasar el uart_base descubierto en booter.c */
void console_set_uart_base(uint32_t base);
