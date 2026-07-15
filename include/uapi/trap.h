/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#pragma once
#include <stdint.h>
#include "include/uapi/bootargs.h"

void trap_init(void (*handler)(uint32_t scause, uint32_t sepc, uint32_t stval));
void timer_init(uint32_t aclint_base, uint32_t hartid);
