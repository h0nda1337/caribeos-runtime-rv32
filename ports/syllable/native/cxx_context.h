/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Serialization around genuine GNU FDE lookup and static guard operations.
 */
#ifndef CARIBE_CXX_CONTEXT_H
#define CARIBE_CXX_CONTEXT_H
#include <stdint.h>
typedef struct { uint32_t state,owner,depth; } caribe_context_mutex;
typedef struct { uint32_t fde_calls,guard_calls,waits; } caribe_context_stats;
#ifdef __cplusplus
extern "C" {
#endif
void caribe_context_lock(caribe_context_mutex *);
void caribe_context_unlock(caribe_context_mutex *);
void caribe_context_statistics(caribe_context_stats *);
#ifdef __cplusplus
}
#endif
#endif
