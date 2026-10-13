/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Minimal raw-thread TCB bootstrap; not a complete pthread lifecycle.
 */
#ifndef CARIBE_MUSL_RAW_TCB_H
#define CARIBE_MUSL_RAW_TCB_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
int caribe_musl_raw_tcb_prepare(void *reserve,size_t bytes,uintptr_t *tp);
#ifdef __cplusplus
}
#endif
#endif
