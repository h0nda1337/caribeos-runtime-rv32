/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Native timer wake and bounded diagnostics for original Syllable Looper.
 */
#ifndef CARIBE_LOOPER_RUNTIME_H
#define CARIBE_LOOPER_RUNTIME_H
#include <atheos/types.h>
#define CARIBE_LOOPER_WAKE 0x43425857U
typedef struct { uint32_t malformed,node_rejected,wake_sent,wake_full,debug_lines,debug_dropped; } caribe_looper_stats;
#ifdef __cplusplus
extern "C" {
#endif
void caribe_syllable_debug(const char *,...);
void caribe_looper_wake(port_id);
void caribe_looper_reject(int node);
void caribe_looper_statistics(caribe_looper_stats *);
void caribe_looper_flush_debug(void);
#ifdef __cplusplus
}
#endif
#endif
