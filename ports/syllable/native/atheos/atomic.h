/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original RV32A adapter for the public Syllable atomic API; no x86 code.
 */
#ifndef CARIBE_SYLLABLE_ATOMIC_H
#define CARIBE_SYLLABLE_ATOMIC_H
#include <stdint.h>
typedef struct { volatile int32_t counter; } atomic_t;
typedef char caribe_atomic_size[(sizeof(atomic_t)==4)?1:-1];
#define ATOMIC_INIT(i) { (i) }
static inline int atomic_read(const atomic_t *v) { return __atomic_load_n(&v->counter,__ATOMIC_SEQ_CST); }
static inline void atomic_set(atomic_t *v,int i) { __atomic_store_n(&v->counter,i,__ATOMIC_SEQ_CST); }
static inline void atomic_add(atomic_t *v,int i) { (void)__atomic_fetch_add(&v->counter,i,__ATOMIC_SEQ_CST); }
static inline void atomic_sub(atomic_t *v,int i) { (void)__atomic_fetch_sub(&v->counter,i,__ATOMIC_SEQ_CST); }
static inline void atomic_or(atomic_t *v,int i) { (void)__atomic_fetch_or(&v->counter,i,__ATOMIC_SEQ_CST); }
static inline void atomic_and(atomic_t *v,int i) { (void)__atomic_fetch_and(&v->counter,i,__ATOMIC_SEQ_CST); }
static inline void atomic_inc(atomic_t *v) { atomic_add(v,1); }
static inline void atomic_dec(atomic_t *v) { atomic_sub(v,1); }
static inline int atomic_sub_and_test(atomic_t *v,int i) { return __atomic_sub_fetch(&v->counter,i,__ATOMIC_SEQ_CST)==0; }
static inline int atomic_dec_and_test(atomic_t *v) { return atomic_sub_and_test(v,1); }
static inline int atomic_inc_and_test(atomic_t *v) { return __atomic_add_fetch(&v->counter,1,__ATOMIC_SEQ_CST)==0; }
/* The Syllable contract returns the OLD value, essential to Locker's fast path. */
static inline int atomic_inc_and_read(atomic_t *v) { return __atomic_fetch_add(&v->counter,1,__ATOMIC_SEQ_CST); }
static inline int atomic_add_negative(atomic_t *v,int i) { return __atomic_add_fetch(&v->counter,i,__ATOMIC_SEQ_CST)<0; }
static inline int atomic_swap(volatile void *v,int i) { return __atomic_exchange_n((volatile int32_t *)v,i,__ATOMIC_SEQ_CST); }
static inline int atomic_cmp_and_set(volatile void *v,int expected,int value)
{
    return __atomic_compare_exchange_n((volatile int32_t *)v,&expected,value,0,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
}
#endif
