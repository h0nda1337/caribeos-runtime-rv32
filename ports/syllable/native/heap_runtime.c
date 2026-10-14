/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original integration: genuine musl locks and protected allocator scopes.
 */
#include "heap_runtime.h"
#include <uapi/caribe_thread.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include "libc.h"

static int ready,previous_locks;
static unsigned cancelled_results;
static int raw(struct caribe_thread_request *r)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)r;
    register uintptr_t a7 __asm__("a7")=CARIBE_THREAD_ECALL;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1","memory");
    return (int32_t)a0;
}
static struct caribe_thread_request request(unsigned operation)
{
    struct caribe_thread_request r={0}; r.abi=CARIBE_THREAD_ABI; r.operation=operation; return r;
}
static int scope(unsigned operation,unsigned acknowledge)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    int result;
    if (!ready) return 0;
    result=raw(&r);
    if (result<0) return result;
    if (r.id==r.owner) return 0;
    r=request(operation); r.status=acknowledge; return raw(&r);
}
int caribe_heap_scope_enter(void) { return scope(CARIBE_THREAD_HEAP_ENTER,0); }
int caribe_heap_scope_leave(void) { return scope(CARIBE_THREAD_HEAP_LEAVE,CARIBE_THREAD_HEAP_CANCEL_ACK); }
unsigned caribe_heap_cancelled_results(void) { return __atomic_load_n(&cancelled_results,__ATOMIC_SEQ_CST); }
int caribe_heap_init(void)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    int result=raw(&r);
    if (result<0) { errno=-result; return -1; }
    if (r.id!=r.owner || r.cpu) { errno=EPERM; return -1; }
    r=request(CARIBE_THREAD_STATS); result=raw(&r);
    if (result<0) { errno=-result; return -1; }
    if (r.live) { errno=EBUSY; return -1; }
    if (!(r.reserved[CARIBE_THREAD_HEAP_FEATURE]&CARIBE_THREAD_HEAP_ENABLED)) { errno=ENOTSUP; return -1; }
    if (!ready) { previous_locks=libc.need_locks; __atomic_store_n(&libc.need_locks,1,__ATOMIC_SEQ_CST); ready=1; }
    return 0;
}
int caribe_heap_shutdown(void)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    int result=raw(&r);
    if (result<0) { errno=-result; return -1; }
    if (r.id!=r.owner || r.cpu) { errno=EPERM; return -1; }
    r=request(CARIBE_THREAD_STATS); result=raw(&r);
    if (result<0) { errno=-result; return -1; }
    if (r.live) { errno=EBUSY; return -1; }
    if (ready) { ready=0; __atomic_store_n(&libc.need_locks,previous_locks,__ATOMIC_SEQ_CST); }
    return 0;
}
extern void *__real_malloc(size_t);
extern void *__real_calloc(size_t,size_t);
extern void *__real_realloc(void *,size_t);
extern void __real_free(void *);
extern int __real_posix_memalign(void **,size_t,size_t);
extern void *__real_aligned_alloc(size_t,size_t);
#define BEGIN() do { int e=caribe_heap_scope_enter(); if(e<0) { errno=-e; return NULL; } } while(0)
#define END() do { int saved=errno; (void)caribe_heap_scope_leave(); errno=saved; } while(0)
static void finish_result(void *p)
{
    int saved=errno;
    if (scope(CARIBE_THREAD_HEAP_LEAVE,0)==-(int)CARIBE_THREAD_CANCELLED) {
        __real_free(p);
        __atomic_add_fetch(&cancelled_results,1U,__ATOMIC_SEQ_CST);
        (void)caribe_heap_scope_leave();
    }
    errno=saved;
}
void *__wrap_malloc(size_t n) { void *p; BEGIN(); p=__real_malloc(n); finish_result(p); return p; }
void *__wrap_calloc(size_t n,size_t size) { void *p; BEGIN(); p=__real_calloc(n,size); finish_result(p); return p; }
void *__wrap_realloc(void *old,size_t n) { void *p; BEGIN(); p=__real_realloc(old,n); finish_result(p); return p; }
void *__wrap_aligned_alloc(size_t align,size_t n) { void *p; BEGIN(); p=__real_aligned_alloc(align,n); finish_result(p); return p; }
void __wrap_free(void *p) { if(caribe_heap_scope_enter()<0) return; __real_free(p); END(); }
int __wrap_posix_memalign(void **p,size_t align,size_t n)
{
    int e=caribe_heap_scope_enter(),result;
    if(e<0) return -e;
    result=__real_posix_memalign(p,align,n); finish_result(result?NULL:*p); return result;
}
