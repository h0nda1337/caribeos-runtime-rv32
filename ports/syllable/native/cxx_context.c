/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Real native identity/futex locks; GNU guard and unwinder algorithms unchanged.
 */
#include "cxx_context.h"
#include "heap_runtime.h"
#include <uapi/caribe_thread.h>
#include <stddef.h>
#include <stdint.h>

static caribe_context_mutex fde_mutex,guard_mutex;
static uint32_t fde_calls,guard_calls,waits;
static int raw(uint32_t number,uintptr_t arg,uintptr_t op,uintptr_t value)
{
    register uintptr_t a0 __asm__("a0")=arg,a1 __asm__("a1")=op,a2 __asm__("a2")=value;
    register uintptr_t a3 __asm__("a3")=0,a4 __asm__("a4")=0,a5 __asm__("a5")=0,a7 __asm__("a7")=number;
    __asm__ volatile("ecall":"+r"(a0),"+r"(a1):"r"(a2),"r"(a3),"r"(a4),"r"(a5),"r"(a7):"memory");
    return (int32_t)a0;
}
static uint32_t identity(void)
{
    struct caribe_thread_request r={0}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_SELF;
    if(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r,0,0) || r.cpu) __builtin_trap();
    return r.id;
}
void caribe_context_lock(caribe_context_mutex *m)
{
    uint32_t id;
    if(caribe_heap_scope_enter()<0) __builtin_trap();
    id=identity();
    if(__atomic_load_n(&m->owner,__ATOMIC_ACQUIRE)==id) { m->depth++; return; }
    {
        uint32_t expected=0;
        if(!__atomic_compare_exchange_n(&m->state,&expected,1U,0,__ATOMIC_ACQUIRE,__ATOMIC_RELAXED)) {
            while(__atomic_exchange_n(&m->state,2U,__ATOMIC_ACQUIRE)!=0U) {
                int result;
                __atomic_add_fetch(&waits,1U,__ATOMIC_SEQ_CST);
                result=raw(98U,(uintptr_t)&m->state,128U,2U);
                if(result && result!=-11 && result!=-4) __builtin_trap();
            }
        }
    }
    m->depth=1U; __atomic_store_n(&m->owner,id,__ATOMIC_RELEASE);
}
void caribe_context_unlock(caribe_context_mutex *m)
{
    if(__atomic_load_n(&m->owner,__ATOMIC_ACQUIRE)!=identity() || !m->depth) __builtin_trap();
    if(--m->depth==0U) {
        __atomic_store_n(&m->owner,0U,__ATOMIC_RELEASE);
        if(__atomic_exchange_n(&m->state,0U,__ATOMIC_RELEASE)==2U)
            if(raw(98U,(uintptr_t)&m->state,129U,1U)<0) __builtin_trap();
    }
    if(caribe_heap_scope_leave()<0) __builtin_trap();
}
void caribe_context_statistics(caribe_context_stats *s)
{
    s->fde_calls=__atomic_load_n(&fde_calls,__ATOMIC_SEQ_CST);
    s->guard_calls=__atomic_load_n(&guard_calls,__ATOMIC_SEQ_CST);
    s->waits=__atomic_load_n(&waits,__ATOMIC_SEQ_CST);
}
extern const void *__real__Unwind_Find_FDE(const void *,void *);
const void *__wrap__Unwind_Find_FDE(const void *pc,void *bases)
{
    const void *result;
    caribe_context_lock(&fde_mutex);
    __atomic_add_fetch(&fde_calls,1U,__ATOMIC_SEQ_CST);
    result=__real__Unwind_Find_FDE(pc,bases);
    caribe_context_unlock(&fde_mutex);
    return result;
}
extern int __real___cxa_guard_acquire(void *);
extern void __real___cxa_guard_release(void *);
extern void __real___cxa_guard_abort(void *);
int __wrap___cxa_guard_acquire(void *guard)
{
    int result;
    caribe_context_lock(&guard_mutex);
    __atomic_add_fetch(&guard_calls,1U,__ATOMIC_SEQ_CST);
    result=__real___cxa_guard_acquire(guard);
    if(!result) caribe_context_unlock(&guard_mutex);
    return result;
}
void __wrap___cxa_guard_release(void *guard)
{
    __real___cxa_guard_release(guard); caribe_context_unlock(&guard_mutex);
}
void __wrap___cxa_guard_abort(void *guard)
{
    __real___cxa_guard_abort(guard); caribe_context_unlock(&guard_mutex);
}
