#pragma once
#include <stdint.h>
#include "include/uapi/bootargs.h"

void trap_init(void (*handler)(uint32_t scause, uint32_t sepc, uint32_t stval));
void timer_init(uint32_t aclint_base, uint32_t hartid);
