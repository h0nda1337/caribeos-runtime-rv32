/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Uses unmodified musl internal headers and __copy_tls, not pthread_create.
 */
#include <uapi/caribe_thread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "pthread_impl.h"

#define SLOTS 16U
#define CHUNK 36864U
#define STACK_SIZE 32768U
#define ROUNDS 10000U
#define INITIAL 0x13579bdfU
extern uint32_t *caribe_tcb_initialized_address(void);
extern uint32_t *caribe_tcb_zero_address(void);
static unsigned char *pool;
static pthread_t tcbs[SLOTS];
static volatile uint32_t ready, checks, failure;
static uint32_t release_word;
static pthread_t main_tcb;
static int *main_errno;
static uint32_t *main_initialized, *main_zero;

static int call(uint32_t number, uint32_t a, uint32_t b, uint32_t c)
{
    register uint32_t a0 __asm__("a0")=a, a1 __asm__("a1")=b;
    register uint32_t a2 __asm__("a2")=c, a3 __asm__("a3")=0;
    register uint32_t a7 __asm__("a7")=number;
    __asm__ volatile("ecall" : "+r"(a0), "+r"(a1) : "r"(a2), "r"(a3), "r"(a7) : "memory");
    return (int)a0;
}
static int request(struct caribe_thread_request *r)
{
    return call(CARIBE_THREAD_ECALL,(uint32_t)(uintptr_t)r,0,0);
}
static int futex(uint32_t op,uint32_t count)
{
    return call(422,(uint32_t)(uintptr_t)&release_word,op,count);
}
static void yield(void)
{
    struct caribe_thread_request r={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_YIELD};
    (void)request(&r);
}
static void finish(uint32_t status)
{
    struct caribe_thread_request r={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_EXIT,.status=status};
    (void)request(&r);
    for(;;) __asm__ volatile("nop");
}
static void worker_require(int good,uint32_t code)
{
    if(!good) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); finish(code); }
}
static void worker(uint32_t slot,uint32_t id)
{
    pthread_t self=pthread_self();
    uint32_t *initialized=caribe_tcb_initialized_address(), *zero=caribe_tcb_zero_address();
    int *mine=__errno_location();
    struct caribe_thread_request info={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_SELF};
    uint32_t i;
    worker_require(slot<SLOTS && self==tcbs[slot] && self->self==self,1);
    worker_require(request(&info)==0 && info.id==id && info.cpu==0 && info.tp==(uintptr_t)TP_ADJ(self),2);
    worker_require(mine==&self->errno_val && mine!=main_errno && *mine==0,3);
    worker_require(*initialized==INITIAL && *zero==0 && initialized!=main_initialized && zero!=main_zero,4);
    for(i=0;i<SLOTS;i++) if(i!=slot && tcbs[i]) worker_require(mine!=&tcbs[i]->errno_val,5);
    *initialized=INITIAL^id; *zero=id;
    for(i=0;i<ROUNDS;i++) {
        errno=(int)(slot+100);
        worker_require(close(-1)==-1 && errno==95,6); /* Real musl error translation; syscall remains denied. */
        errno=(int)(slot+200);
        if(!(i&31U)) yield();
        worker_require(pthread_self()==self && __errno_location()==mine && errno==(int)(slot+200) &&
            *initialized==(INITIAL^id) && *zero==id,7);
        __atomic_add_fetch(&checks,1U,__ATOMIC_SEQ_CST);
    }
    __atomic_add_fetch(&ready,1U,__ATOMIC_SEQ_CST);
    worker_require(futex(128,42)==0,8);
    worker_require(errno==(int)(slot+200) && *initialized==(INITIAL^id) && *zero==id,9);
    finish(0);
}
static void require(int good,const char *label)
{
    if(!good) { fprintf(stderr,"[native-tcb] FAIL %s code=%u\n",label,failure); exit(1); }
}
static uint64_t nanos(void)
{
    struct timespec t;
    require(clock_gettime(CLOCK_MONOTONIC,&t)==0,"clock");
    return (uint64_t)t.tv_sec*1000000000ULL+(uint64_t)t.tv_nsec;
}
static void verify_main(void)
{
    require(pthread_self()==main_tcb && __errno_location()==main_errno && errno==123 &&
        *main_initialized==0x2468ace0U && *main_zero==0x10203040U,"main TCB/TLS unchanged");
}
static void prepare(unsigned slot)
{
    unsigned char *mem=pool+slot*CHUNK+STACK_SIZE;
    uintptr_t base, end;
    memset(mem,0,CHUNK-STACK_SIZE);
    tcbs[slot]=__copy_tls(mem);
    base=(uintptr_t)tcbs[slot]; end=(uintptr_t)mem+CHUNK-STACK_SIZE;
    require(base>=(uintptr_t)mem && (uintptr_t)TP_ADJ(tcbs[slot])+libc.tls_head->size<=end &&
        ((uintptr_t)TP_ADJ(tcbs[slot])&15U)==0,"genuine musl TCB bounds/alignment");
    /* This isolated raw-thread TCB is NOT inserted into musl's pthread list. */
    tcbs[slot]->self=tcbs[slot];
    tcbs[slot]->locale=&libc.global_locale;
    tcbs[slot]->canary=main_tcb->canary;
    tcbs[slot]->robust_list.head=&tcbs[slot]->robust_list.head;
    tcbs[slot]->sysinfo=main_tcb->sysinfo;
    require(tcbs[slot]->dtv[0]==1 && tcbs[slot]->dtv[1]-DTP_OFFSET==(uintptr_t)TP_ADJ(tcbs[slot]) &&
        *(uint32_t *)TP_ADJ(tcbs[slot])==INITIAL,"original __copy_tls image/DTV");
}
static struct caribe_thread_request create(unsigned slot)
{
    struct caribe_thread_request r={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_CREATE,
        .entry=(uint32_t)(uintptr_t)worker,.argument=slot,
        .stack_base=(uint32_t)(uintptr_t)(pool+slot*CHUNK),.stack_size=STACK_SIZE,
        .tp=(uint32_t)(uintptr_t)TP_ADJ(tcbs[slot])};
    require(request(&r)==0,"create with real TCB");
    return r;
}
static void operate(struct caribe_thread_request *r,uint32_t op,uint32_t status)
{
    r->operation=op; r->timeout_us=60000000U;
    require(request(r)==0,"thread operation");
    if(op==CARIBE_THREAD_JOIN) require(r->status==status,"join/reaper");
}
static void await_ready(uint32_t count)
{
    uint64_t end=nanos()+60000000000ULL;
    while(__atomic_load_n(&ready,__ATOMIC_SEQ_CST)<count) {
        require(!failure && nanos()<end,"worker progress"); yield();
    }
    verify_main();
}
static void run(unsigned count,int cancel)
{
    struct caribe_thread_request threads[SLOTS]; unsigned i; uint32_t wakes=0;
    uint64_t end;
    ready=checks=failure=0; release_word=42;
    memset(tcbs,0,sizeof tcbs);
    for(i=0;i<count;i++) { prepare(i); threads[i]=create(i); }
    for(i=0;i<count;i++) operate(&threads[i],CARIBE_THREAD_START,0);
    await_ready(count);
    require(checks==count*ROUNDS,"exact TLS/errno checks");
    if(cancel) {
        for(i=0;i<count;i++) operate(&threads[i],CARIBE_THREAD_CANCEL,0);
    } else {
        end=nanos()+30000000000ULL;
        while(wakes<count) {
            int n=futex(129,count-wakes);
            require(n>=0 && (uint32_t)n<=count-wakes && nanos()<end,"real bounded futex wake");
            wakes+=(uint32_t)n; if(wakes<count) yield();
        }
    }
    for(i=0;i<count;i++) operate(&threads[i],CARIBE_THREAD_JOIN,cancel?CARIBE_THREAD_CANCELLED:0);
    require(!failure && futex(129,INT_MAX)==0,"empty futex queue after reaper");
    verify_main();
}
int main(int argc,char **argv)
{
    char gate='C'; unsigned i; uint32_t expected;
    struct caribe_thread_request before={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_STATS},after=before;
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0];
    else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    main_tcb=pthread_self(); main_errno=__errno_location();
    main_initialized=caribe_tcb_initialized_address(); main_zero=caribe_tcb_zero_address();
    require(main_tcb==__pthread_self() && main_tcb->self==main_tcb && main_errno==&main_tcb->errno_val &&
        *main_initialized==INITIAL && *main_zero==0,"boot musl TCB and native ELF TLS");
    require(libc.tls_cnt==1 && libc.tls_head && libc.tls_align==16 && libc.tls_size<=4096,"real PT_TLS module");
    pool=mmap(0,SLOTS*CHUNK,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    require(pool!=MAP_FAILED,"bounded TCB/stack pool");
    require(request(&before)==0 && before.live==0,"baseline resources");
    for(i=0;i<SLOTS;i++) { prepare(i); require(tcbs[i]!=main_tcb && &tcbs[i]->errno_val!=main_errno,"independent TCB"); }
    *main_initialized=0x2468ace0U; *main_zero=0x10203040U; errno=123;
    puts("[native-tcb-gate-A] genuine musl __copy_tls TCB/DTV=16; native PT_TLS initialized/zero image; main pthread_self/errno PASS");
    if(gate>='B') {
        run(SLOTS,0);
        puts("[native-tcb-gate-B] workers=16 checks=160000; private pthread_self/errno/native TLS; futex resumes=16 cpu=0 PASS");
    }
    if(gate>='C') {
        for(i=0;i<64;i++) run(1,0);
        run(SLOTS,1);
        puts("[native-tcb-gate-C] reuse cycles=64 cancellation requests=16; fresh TLS/errno; main unchanged; zero waiter leaks PASS");
    }
    expected=gate>='C'?96U:gate>='B'?16U:0U;
    require(request(&after)==0 && after.live==0 && after.created-before.created==expected &&
        after.exited-before.exited==expected && after.reaped-before.reaped==expected,"exact final resources");
    printf("[native-tcb] created=reaped=%u live=0 all slots retired PASS\n",expected);
    printf("[native-tcb] gates A-%c PASS; musl TCB/native ELF TLS only, not pthread lifecycle or threaded libc\n",gate);
    require(munmap(pool,SLOTS*CHUNK)==0,"pool release after reaper");
    return 0;
}
