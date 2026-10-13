/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Exercises genuine LGPL Syllable Locker on native XNU threads, not Looper.
 */
#include <util/locker.h>
#include <uapi/caribe_thread.h>
#include <uapi/caribe_sync.h>
#include "tcb_bootstrap.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#define CHUNK 36864U
#define STACK 32768U
#define ROUNDS 10000U
extern "C" uint32_t *caribe_tcb_initialized_address(void);
extern "C" uint32_t *caribe_tcb_zero_address(void);
static unsigned char *pool;
static os::Locker *mutex;
static volatile uint32_t failure,done,active;
static uint32_t value;
static pthread_t selves[16],main_self;
static uintptr_t pointers[16];
static int *main_errno;

static int raw(uint32_t number,void *arg)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)arg;
    register uintptr_t a7 __asm__("a7")=number;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    return (int32_t)a0;
}
static void require(bool good,const char *label)
{
    if(!good) { fprintf(stderr,"[native-locker] FAIL %s code=%u\n",label,failure); exit(1); }
}
static void yield()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_YIELD;
    (void)raw(CARIBE_THREAD_ECALL,&r);
}
static void finish(uint32_t status) __attribute__((noreturn));
static void finish(uint32_t status)
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_EXIT; r.status=status;
    (void)raw(CARIBE_THREAD_ECALL,&r);
    for(;;) __asm__ volatile("nop");
}
static void worker_require(bool good,uint32_t code)
{
    if(!good) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); finish(code); }
}
static caribe_thread_request stats()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_STATS;
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"thread stats"); return r;
}
static caribe_sync_request sync_stats()
{
    caribe_sync_request r={}; r.abi=CARIBE_SYNC_ABI; r.operation=CARIBE_SYNC_STATS;
    require(raw(CARIBE_THREAD_SYNC_ECALL,&r)==0,"sync stats"); return r;
}
static uint64_t nanos()
{
    timespec t;
    require(clock_gettime(CLOCK_MONOTONIC,&t)==0,"main clock");
    return (uint64_t)t.tv_sec*1000000000ULL+(uint64_t)t.tv_nsec;
}
static void worker(uint32_t slot,uint32_t id)
{
    caribe_thread_request info={}; info.abi=CARIBE_THREAD_ABI; info.operation=CARIBE_THREAD_SELF;
    worker_require(slot<16 && raw(CARIBE_THREAD_ECALL,&info)==0 && info.id==id && info.cpu==0 && info.tp==pointers[slot],1);
    selves[slot]=pthread_self();
    worker_require(selves[slot]!=main_self && __errno_location()!=main_errno && errno==0,2);
    uint32_t *initialized=caribe_tcb_initialized_address(),*zero=caribe_tcb_zero_address();
    worker_require(*initialized==0x13579bdfU && *zero==0,3);
    *initialized=id; *zero=id^0xa5a5a5a5U; errno=(int)(slot+100U);
    for(uint32_t i=0;i<ROUNDS;i++) {
        worker_require(mutex->Lock()==0 && mutex->GetOwner()==(thread_id)id && mutex->GetLockCount()==1,4);
        worker_require(__atomic_add_fetch(&active,1U,__ATOMIC_SEQ_CST)==1,5);
        worker_require(mutex->Lock()==0 && mutex->GetLockCount()==2 && mutex->IsLocked(),6);
        uint32_t saved=value;
        if(!(i&31U)) yield(); /* Force real contenders while the original Locker is held. */
        worker_require(value==saved && active==1 && pthread_self()==selves[slot] &&
            errno==(int)(slot+100U) && *initialized==id && *zero==(id^0xa5a5a5a5U),7);
        value=saved+1;
        worker_require(mutex->Unlock()==0 && mutex->GetLockCount()==1,8);
        worker_require(__atomic_sub_fetch(&active,1U,__ATOMIC_SEQ_CST)==0 && mutex->Unlock()==0,9);
    }
    __atomic_add_fetch(&done,1U,__ATOMIC_SEQ_CST); finish(0);
}
static void try_worker(uint32_t slot,uint32_t id)
{
    (void)id;
    worker_require(slot==0 && pthread_self()!=main_self && errno==0,10);
    worker_require(mutex->Lock(0)==-1 && errno==EAGAIN && !mutex->IsLocked(),11);
    finish(0);
}
static caribe_thread_request create(unsigned slot,bool attempt)
{
    require(caribe_musl_raw_tcb_prepare(pool+slot*CHUNK+STACK,4096,&pointers[slot])==0,"genuine TCB preparation");
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_CREATE;
    r.entry=(uint32_t)(uintptr_t)(attempt?try_worker:worker); r.argument=slot;
    r.stack_base=(uint32_t)(uintptr_t)(pool+slot*CHUNK); r.stack_size=STACK; r.tp=pointers[slot];
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"create"); return r;
}
static void operate(caribe_thread_request *r,uint32_t operation)
{
    r->operation=operation; r->timeout_us=60000000U;
    require(raw(CARIBE_THREAD_ECALL,r)==0,"start/join");
    if(operation==CARIBE_THREAD_JOIN) require(r->status==0,"worker exit/reaper");
}
static void gate_a()
{
    atomic_t a=ATOMIC_INIT(0);
    require(atomic_inc_and_read(&a)==0 && atomic_read(&a)==1 && atomic_dec_and_test(&a),"old-value atomic contract");
    require(atomic_cmp_and_set(&a.counter,0,7)==1 && atomic_cmp_and_set(&a.counter,0,8)==0 &&
        atomic_swap(&a.counter,0)==7,"CAS/exchange");
    os::Locker lock("genuine-locker-A");
    require(lock.GetOwner()==-1 && lock.GetLockCount()==0 && !lock.IsLocked(),"initialized owner");
    thread_id me=get_thread_id(NULL);
    require(me>0 && lock.Lock()==0 && lock.GetOwner()==me && lock.Lock()==0 && lock.GetLockCount()==2,"original recursive fast path");
    require(lock.Unlock()==0 && lock.GetLockCount()==1 && lock.Unlock()==0 && !lock.IsLocked(),"recursive unlock");
    puts("[native-locker-gate-A] genuine os::Locker owner/recursion; RV32A old-value/CAS/exchange contract PASS");
}
static void gate_b()
{
    caribe_thread_request threads[16]; caribe_sync_request before=sync_stats();
    {
        os::Locker lock("genuine-locker-B"); mutex=&lock;
        for(unsigned i=0;i<16;i++) threads[i]=create(i,false);
        errno=123;
        for(unsigned i=0;i<16;i++) operate(&threads[i],CARIBE_THREAD_START);
        uint64_t end=nanos()+120000000000ULL;
        while(__atomic_load_n(&done,__ATOMIC_SEQ_CST)<16) { require(!failure && nanos()<end,"mutex progress"); yield(); }
        for(unsigned i=0;i<16;i++) operate(&threads[i],CARIBE_THREAD_JOIN);
        require(value==160000 && active==0 && failure==0 && errno==123 && pthread_self()==main_self,"exact protected state/main TCB");
        for(unsigned i=0;i<16;i++) for(unsigned j=0;j<i;j++) require(selves[i]!=selves[j],"independent worker TCB");
        require(lock.GetLockCount()==0 && lock.GetOwner()==-1,"unlocked after all workers");
    }
    caribe_sync_request after=sync_stats();
    require(after.live==before.live && after.waits>before.waits,"real scheduler waits and semaphore retirement");
    printf("[native-locker-gate-B] workers=16 rounds=160000 recursive acquisitions=320000 overlaps=0 cpu=0 scheduler-waits=%u PASS\n",after.waits-before.waits);
}
static void gate_c()
{
    os::Locker lock("genuine-locker-C"); mutex=&lock;
    thread_id me=get_thread_id(NULL);
    require(lock.Lock()==0,"main holds locker");
    for(unsigned i=0;i<64;i++) {
        caribe_thread_request thread=create(0,true);
        errno=123; operate(&thread,CARIBE_THREAD_START); operate(&thread,CARIBE_THREAD_JOIN);
        require(!failure && errno==123 && lock.GetOwner()==me && lock.GetLockCount()==1,"try-lock leaves main owner unchanged");
    }
    require(lock.Unlock()==0,"final owner unlock");
    puts("[native-locker-gate-C] immediate timeout EAGAIN cycles=64; genuine errno isolation; owner preserved; generic reaping PASS");
}
int main(int argc,char **argv)
{
    char gate='C';
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0];
    else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    caribe_thread_request before=stats(); caribe_sync_request sync_before=sync_stats();
    require(before.live==0 && sync_before.live==0,"baseline resources");
    main_self=pthread_self(); main_errno=__errno_location();
    gate_a();
    if(gate>='B') {
        pool=(unsigned char *)mmap(NULL,16*CHUNK,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
        require(pool!=MAP_FAILED,"bounded stack/TCB pool");
        gate_b(); if(gate>='C') gate_c();
        require(munmap(pool,16*CHUNK)==0,"pool release after reaper");
    }
    caribe_thread_request after=stats();
    uint32_t expected=gate>='C'?80:gate>='B'?16:0;
    require(after.live==0 && after.created-before.created==expected && after.exited-before.exited==expected &&
        after.reaped-before.reaped==expected && sync_stats().live==0,"exact final resources");
    printf("[native-locker] created=reaped=%u live=0 semaphores=0 all slots retired PASS\n",expected);
    printf("[native-locker] gates A-%c PASS; genuine Syllable Locker with native XNU threads, not Looper/AppServer or pthread lifecycle\n",gate);
    return 0;
}
