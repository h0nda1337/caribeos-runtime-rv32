/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Test access to genuine musl's allocator lock, not a replacement lock.
 */
#include "heap_runtime.h"
#include "lock.h"
extern volatile int __malloc_lock[1];
int caribe_heap_test_hold(void)
{
    int error=caribe_heap_scope_enter();
    if(error) return error;
    __lock(__malloc_lock); return 0;
}
void caribe_heap_test_release(void)
{
    __unlock(__malloc_lock);
    (void)caribe_heap_scope_leave();
}
