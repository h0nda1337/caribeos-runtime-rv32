#include <stdint.h>

#define UART_BASE   0x10000000u
#define UART_THR    (*(volatile uint8_t*)(UART_BASE + 0))  // transmit holding
#define UART_LSR    (*(volatile uint8_t*)(UART_BASE + 5))  // line status
#define LSR_THRE    0x20                                    // Transmit-Hold-Register Empty

static void putc(char c){
  while((UART_LSR & LSR_THRE)==0) { }
  UART_THR = (uint8_t)c;
}
static void puts(const char* s){
  while(*s){ putc(*s++); }
}

void _start(void){
  puts("\r\n[ELF] Hola desde payload ELF rv32!\r\n");
  // bucle infinito para observar salida; si prefieres volver, podrías ecall SRST aquí.
  for(;;){}
}
