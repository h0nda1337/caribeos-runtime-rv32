/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Real original Syllable Thread/Locker with native XNU lifecycle and clock.
 */
#include <util/thread.h>
#include <util/locker.h>
#include <atheos/time.h>
#include <uapi/caribe_thread.h>
#include <uapi/caribe_sync.h>
#include "thread_runtime.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
extern "C" uint32_t *caribe_tcb_initialized_address(void);
extern "C" uint32_t *caribe_tcb_zero_address(void);
static volatile uint32_t failure,entered,active,done,sleeps;
static uint32_t value;
static os::Locker *mutex;
static pthread_t main_self,selves[16];
static int *main_errno;
static int raw(uint32_t number,void *arg)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)arg;
    register uintptr_t a7 __asm__("a7")=number;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    return (int32_t)a0;
}
static caribe_thread_request req(uint32_t operation)
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=operation; return r;
}
static void require(bool ok,const char *label)
{
    if(!ok) { fprintf(stderr,"[syllable-thread] FAIL %s code=%u errno=%d\n",label,failure,errno); exit(1); }
}
static void check(bool ok,uint32_t code)
{
    if(!ok) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); exit_thread((int)code); }
}
static void yield()
{
    caribe_thread_request r=req(CARIBE_THREAD_YIELD); (void)raw(CARIBE_THREAD_ECALL,&r);
}
static caribe_thread_request stats()
{
    caribe_thread_request r=req(CARIBE_THREAD_STATS);
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"stats"); return r;
}
static caribe_sync_request sync_stats()
{
    caribe_sync_request r={}; r.abi=CARIBE_SYNC_ABI; r.operation=CARIBE_SYNC_STATS;
    require(raw(CARIBE_THREAD_SYNC_ECALL,&r)==0,"sync stats"); return r;
}
static uint64_t main_ns()
{
    timespec t; require(clock_gettime(CLOCK_MONOTONIC,&t)==0,"Linux main clock");
    return (uint64_t)t.tv_sec*1000000000ULL+t.tv_nsec;
}
static void identity(unsigned slot)
{
    caribe_thread_request r=req(CARIBE_THREAD_SELF);
    check(slot<16 && raw(CARIBE_THREAD_ECALL,&r)==0 && r.cpu==0 && r.id>=0x40000000U,1);
    check(get_thread_id(NULL)==(thread_id)r.id && get_process_id(NULL)==(proc_id)r.owner,2);
    selves[slot]=pthread_self();
    check(selves[slot]!=main_self && __errno_location()!=main_errno && errno==0,3);
    check(*caribe_tcb_initialized_address()==0x13579bdfU && *caribe_tcb_zero_address()==0,4);
    *caribe_tcb_initialized_address()=r.id; *caribe_tcb_zero_address()=r.id^0xa5a5a5a5U;
    errno=(int)(100+slot);
}
static int32 c_entry(void *)
{
    identity(0); __atomic_add_fetch(&entered,1U,__ATOMIC_SEQ_CST);
    check(spawn_thread("worker-create",(void *)c_entry,NORMAL_PRIORITY,0,NULL)==-1 && errno==ENOTSUP,5);
    check(close(-1)==-1 && errno==ENOTSUP,6);
    check(snooze(-1)==-1 && errno==EINVAL && snooze(0)==0,7);
    return 0x12345678;
}
class Probe : public os::Thread {
    unsigned mode,slot;
public:
    Probe(unsigned kind,unsigned index=0):Thread("genuine-syllable-thread"),mode(kind),slot(index) {}
    int32 Run() override
    {
        identity(slot); __atomic_add_fetch(&entered,1U,__ATOMIC_SEQ_CST);
        if(mode==0) return 0;
        if(mode==2) {
            bigtime_t before=get_system_time();
            check(before>=0 && mutex->Lock(2000)==-1 && errno==ETIMEDOUT && !mutex->IsLocked(),8);
            check(get_system_time()-before>=2000,9); return 0;
        }
        if(mode==3) { Delay(5000000); check(false,10); return 10; }
        uint32_t id=(uint32_t)get_thread_id(NULL);
        for(unsigned i=0;i<10000;i++) {
            check(mutex->Lock()==0 && mutex->GetOwner()==(thread_id)id,11);
            check(__atomic_add_fetch(&active,1U,__ATOMIC_SEQ_CST)==1 && mutex->Lock()==0 && mutex->GetLockCount()==2,12);
            uint32_t saved=value;
            if(!(i&31U)) yield();
            check(value==saved && errno==(int)(100+slot) && *caribe_tcb_initialized_address()==id &&
                  *caribe_tcb_zero_address()==(id^0xa5a5a5a5U) && pthread_self()==selves[slot],13);
            value=saved+1;
            check(mutex->Unlock()==0 && __atomic_sub_fetch(&active,1U,__ATOMIC_SEQ_CST)==0 && mutex->Unlock()==0,14);
            if(!(i&255U)) {
                bigtime_t before=get_system_time();
                check(before>=0,15); Delay(50);
                check(get_system_time()-before>=50,16);
                __atomic_add_fetch(&sleeps,1U,__ATOMIC_SEQ_CST);
            }
        }
        __atomic_add_fetch(&done,1U,__ATOMIC_SEQ_CST); return 0;
    }
};
static void gate_a()
{
    uint64_t low=main_ns(); caribe_thread_request clock=req(CARIBE_THREAD_CLOCK);
    require(raw(CARIBE_THREAD_ECALL,&clock)==0,"native clock"); uint64_t high=main_ns();
    uint64_t ns=(uint64_t)clock.reserved[CARIBE_THREAD_TIME_LOW] | ((uint64_t)clock.reserved[CARIBE_THREAD_TIME_HIGH]<<32);
    require(ns>=low && ns<=high && clock.reserved[CARIBE_THREAD_TIME_HIGH]!=0,"64-bit monotonic clock bracket");
    clock=req(CARIBE_THREAD_CLOCK); clock.reserved[0]=1;
    require(raw(CARIBE_THREAD_ECALL,&clock)==-EINVAL && raw(CARIBE_THREAD_ECALL,(void *)1)==-EFAULT,"clock input guards");
    caribe_thread_request sleep=req(CARIBE_THREAD_SLEEP);
    require(raw(CARIBE_THREAD_ECALL,&sleep)==-EPERM,"main native sleep rejected");
    require(caribe_syllable_threads_init()==0,"bounded native pool");
    thread_id id=spawn_thread("genuine-C-thread",(void *)c_entry,NORMAL_PRIORITY,0,NULL);
    require(id>=0x40000000 && entered==0,"created suspended");
    caribe_thread_request info=req(CARIBE_THREAD_INFO); info.id=(uint32_t)id;
    require(raw(CARIBE_THREAD_ECALL,&info)==0 && info.state==CARIBE_THREAD_SUSPENDED && info.cpu==0,"real native suspended state");
    yield(); require(entered==0 && caribe_syllable_threads_shutdown()==-1 && errno==EBUSY,"no early entry/no live pool release");
    require(resume_thread(id)==0 && wait_for_thread(id)==0x12345678 && !failure,"C resume/status/generic join");
    require(resume_thread(id)==-1 && errno==EINVAL,"stale ID retired");
    {
        Probe thread(0);
        require(thread.GetProcessId()==get_process_id(NULL),"original Thread owner");
        try { thread.Stop(); require(false,"unsupported Stop succeeded"); }
        catch(const os::ThreadException &e) { require(e.error()==ENOTSUP,"Stop error propagation"); }
        try { (void)thread.GetPriority(); require(false,"unsupported info succeeded"); }
        catch(const os::ThreadException &e) { require(e.error()==ENOTSUP,"info error propagation"); }
        try { thread.SetPriority(); require(false,"unsupported priority succeeded"); }
        catch(const os::ThreadException &e) { require(e.error()==ENOTSUP,"priority error propagation"); }
        thread.Start(); thread.WaitFor(); require(thread.GetThreadId()==-1 && !failure,"original C++ virtual entry/reap");
    }
    puts("[syllable-thread-gate-A] original os::Thread and C lifecycle; suspended/resume/join status=0x12345678; 64-bit native clock; unsupported errors PASS");
}
static void gate_b()
{
    Probe *threads[16]; caribe_thread_request before=stats(); caribe_sync_request sync_before=sync_stats();
    {
        os::Locker lock("genuine-thread-locker-B"); mutex=&lock;
        for(unsigned i=0;i<16;i++) threads[i]=new Probe(1,i);
        errno=123;
        for(unsigned i=0;i<16;i++) threads[i]->Start();
        uint64_t deadline=main_ns()+120000000000ULL;
        while(__atomic_load_n(&done,__ATOMIC_SEQ_CST)<16) { require(!failure && main_ns()<deadline,"worker progress"); yield(); }
        for(unsigned i=0;i<16;i++) { threads[i]->WaitFor(); require(threads[i]->GetThreadId()==-1,"C++ join ID"); }
        require(value==160000 && sleeps==640 && active==0 && errno==123 && pthread_self()==main_self,"exact worker/TLS/main state");
        for(unsigned i=0;i<16;i++) { for(unsigned j=0;j<i;j++) require(selves[i]!=selves[j],"independent TCBs"); delete threads[i]; }
    }
    uint32_t blocks=stats().reserved[CARIBE_THREAD_SLEEP_WAITS]-before.reserved[CARIBE_THREAD_SLEEP_WAITS];
    uint32_t waits=sync_stats().waits-sync_before.waits;
    require(blocks>=640 && waits>0,"real native timer and semaphore waits");
    printf("[syllable-thread-gate-B] workers=16 rounds=160000 recursive acquisitions=320000 overlaps=0 cpu=0 sleeps=640 timer-waits=%u scheduler-waits=%u PASS\n",blocks,waits);
}
static void gate_c()
{
    caribe_sync_request before=sync_stats();
    {
        os::Locker lock("genuine-thread-locker-C"); mutex=&lock;
        require(lock.Lock()==0,"main timed-lock owner");
        Probe thread(2); thread.Start(); thread.WaitFor();
        for(unsigned i=1;i<64;i++) { thread.Initialize("genuine-thread-timeout"); thread.Start(); thread.WaitFor(); }
        require(!failure && lock.GetOwner()==get_thread_id(NULL) && lock.GetLockCount()==1 && lock.Unlock()==0,"timed ownership preservation");
    }
    uint32_t timed=sync_stats().timeouts-before.timeouts;
    require(timed>=64,"actual native timeout calls");
    {
        Probe thread(3);
        for(unsigned i=0;i<64;i++) {
            if(i) thread.Initialize("genuine-thread-cancel");
            uint32_t previous=stats().reserved[CARIBE_THREAD_SLEEP_WAITS];
            thread.Start(); uint64_t deadline=main_ns()+5000000000ULL;
            while(stats().reserved[CARIBE_THREAD_SLEEP_WAITS]==previous) { require(!failure && main_ns()<deadline,"native sleep registration"); yield(); }
            thread.Terminate(); require(thread.GetThreadId()==-1 && !failure,"native cancel/join, not kill(pid)");
        }
    }
    printf("[syllable-thread-gate-C] finite timeout cycles=64 elapsed>=2000us native-timeouts=%u; sleep cancellation cycles=64; original Initialize/Terminate and generic reaping PASS\n",timed);
}
int main(int argc,char **argv)
{
    char gate='C';
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0];
    else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    caribe_thread_request before=stats(); require(before.live==0 && sync_stats().live==0,"baseline resources");
    main_self=pthread_self(); main_errno=__errno_location();
    gate_a(); if(gate>='B') gate_b(); if(gate>='C') gate_c();
    require(caribe_syllable_threads_shutdown()==0,"pool release only after generic reaping");
    caribe_thread_request after=stats(); uint32_t count=gate>='C'?146:gate>='B'?18:2;
    uint32_t cancelled=gate>='C'?64:0;
    require(!failure && after.live==0 && after.created-before.created==count && after.exited-before.exited==count &&
            after.reaped-before.reaped==count && after.cancelled-before.cancelled==cancelled && after.faults==before.faults &&
            sync_stats().live==0,"exact final resource/cancellation counters");
    printf("[syllable-thread] created=reaped=%u cancelled=%u live=0 semaphores=0 pool released PASS\n",count,cancelled);
    printf("[syllable-thread] gates A-%c PASS; genuine Syllable Thread/native clock, not Looper/AppServer or threaded libc\n",gate);
    return 0;
}
