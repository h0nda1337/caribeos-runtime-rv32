/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Native controller-owned thread integration, not pthread lifecycle.
 */
#ifndef CARIBE_SYLLABLE_THREAD_RUNTIME_H
#define CARIBE_SYLLABLE_THREAD_RUNTIME_H
#include <atheos/threads.h>
#ifdef __cplusplus
extern "C" {
#endif
int caribe_syllable_threads_init(void);
int caribe_syllable_threads_shutdown(void);
int caribe_syllable_thread_join(thread_id id,int *status);
int caribe_syllable_thread_terminate(thread_id id);
#ifdef __cplusplus
}
#endif
#endif
