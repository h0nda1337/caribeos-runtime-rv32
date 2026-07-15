#pragma once
#include <stdint.h>

void console_init(void);
void console_rx_char(char c);
void console_on_tick(uint32_t ticks);
/* Permite pasar el uart_base descubierto en booter.c */
void console_set_uart_base(uint32_t base);
