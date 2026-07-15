#include <stdint.h>
void uart_puts(const char *);

static const char HEX[] = "0123456789abcdef";

void uart_puthex32(uint32_t v){
    char s[11]; s[0]='0'; s[1]='x';
    for(int i=0;i<8;i++){
        s[9-i]=HEX[v & 0xF];
        v >>= 4;
    }
    s[10]=0;
    uart_puts(s);
}

void uart_putdec(uintptr_t v){
    char b[32]; int i=31; b[i--]=0;
    if(!v){ b[i--]='0'; uart_puts(&b[i+1]); return; }
    while(v){ b[i--]='0'+(v%10); v/=10; }
    uart_puts(&b[i+1]);
}
