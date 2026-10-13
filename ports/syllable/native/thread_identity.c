/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original native XNU identity adapter, not a complete Syllable thread API.
 */
#include <atheos/threads.h>
#include <uapi/caribe_thread.h>
#include <errno.h>
thread_id get_thread_id(const char *name)
{
    struct caribe_thread_request r={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_SELF};
    register uintptr_t a0 __asm__("a0")=(uintptr_t)&r;
    register uintptr_t a7 __asm__("a7")=CARIBE_THREAD_ECALL;
    if (name) { errno=ENOTSUP; return -1; }
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    if ((int32_t)a0<0) { errno=-(int32_t)a0; return -1; }
    return (thread_id)r.id;
}
