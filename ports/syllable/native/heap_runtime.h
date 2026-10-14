/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Scope integration for the genuine musl allocator, not a replacement heap.
 */
#ifndef CARIBE_HEAP_RUNTIME_H
#define CARIBE_HEAP_RUNTIME_H
#ifdef __cplusplus
extern "C" {
#endif
int caribe_heap_init(void);
int caribe_heap_shutdown(void);
int caribe_heap_scope_enter(void);
int caribe_heap_scope_leave(void);
unsigned caribe_heap_cancelled_results(void);
#ifdef __cplusplus
}
#endif
#endif
