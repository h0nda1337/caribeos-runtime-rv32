/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Workers intentionally use no libc, pthread or GNU emutls.
 */
#include <uapi/caribe_thread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#define PRIVATE_WAIT 128U
#define PRIVATE_WAKE 129U
#define CHUNK 36864U
#define ROUNDS 10000U
static uint32_t word = 42, other_word = 42;
static volatile uint32_t acknowledgements, ready, failure;
static unsigned char *memory;

static int call(uint32_t number, uint32_t a, uint32_t b, uint32_t c, uint32_t d)
{
    register uint32_t a0 __asm__("a0") = a, a1 __asm__("a1") = b;
    register uint32_t a2 __asm__("a2") = c, a3 __asm__("a3") = d;
    register uint32_t a7 __asm__("a7") = number;
    __asm__ volatile("ecall" : "+r"(a0), "+r"(a1) : "r"(a2), "r"(a3), "r"(a7) : "memory");
    return (int)a0;
}
static int futex(uint32_t *address, uint32_t op, uint32_t value, const void *timeout, int wide)
{
    return call(wide ? 422U : 98U, (uint32_t)(uintptr_t)address, op, value, (uint32_t)(uintptr_t)timeout);
}
static int thread_request(struct caribe_thread_request *request)
{
    return call(CARIBE_THREAD_ECALL, (uint32_t)(uintptr_t)request, 0, 0, 0);
}
static void yield(void)
{
    struct caribe_thread_request request = { .abi=CARIBE_THREAD_ABI, .operation=CARIBE_THREAD_YIELD };
    (void)thread_request(&request);
}
static void worker_exit(uint32_t status)
{
    struct caribe_thread_request request = { .abi=CARIBE_THREAD_ABI, .operation=CARIBE_THREAD_EXIT, .status=status };
    (void)thread_request(&request);
    for (;;) __asm__ volatile("nop");
}
static void worker(uint32_t rounds, uint32_t id)
{
    uint32_t i;
    (void)id;
    __atomic_add_fetch(&ready, 1U, __ATOMIC_SEQ_CST);
    for (i=0; i<rounds; i++) {
        int result = futex(&word, PRIVATE_WAIT, 42, 0, 1);
        if (result) { __atomic_store_n(&failure, (uint32_t)-result, __ATOMIC_SEQ_CST); worker_exit(1); }
        __atomic_add_fetch(&acknowledgements, 1U, __ATOMIC_SEQ_CST);
    }
    worker_exit(0);
}
static void disabled_worker(uint32_t unused, uint32_t id)
{
    (void)unused; (void)id;
    worker_exit(futex(&word, PRIVATE_WAIT, 42, 0, 1) == -95 ? 0 : 1);
}
static void require(int valid, const char *label)
{
    if (!valid) { fprintf(stderr, "[native-futex] FAIL %s\n", label); exit(1); }
}
static uint64_t nanos(void)
{
    struct timespec ts;
    require(clock_gettime(CLOCK_MONOTONIC, &ts)==0, "clock");
    return (uint64_t)ts.tv_sec*1000000000ULL+(uint64_t)ts.tv_nsec;
}
static struct caribe_thread_request create(unsigned slot, uint32_t rounds, int disabled)
{
    struct caribe_thread_request request = { .abi=CARIBE_THREAD_ABI, .operation=CARIBE_THREAD_CREATE,
        .entry=(uint32_t)(uintptr_t)(disabled ? disabled_worker : worker), .argument=rounds,
        .stack_base=(uint32_t)(uintptr_t)(memory+slot*CHUNK), .stack_size=32768,
        .tp=(uint32_t)(uintptr_t)(memory+slot*CHUNK+32768) };
    require(thread_request(&request)==0, "create");
    return request;
}
static void operate(struct caribe_thread_request *request, uint32_t op, uint32_t status)
{
    request->operation=op; request->timeout_us=60000000U;
    require(thread_request(request)==0, "thread operation");
    if(op==CARIBE_THREAD_JOIN) require(request->status==status, "join status/reaper");
}
static void await(volatile uint32_t *counter, uint32_t wanted)
{
    uint64_t end=nanos()+30000000000ULL;
    while(__atomic_load_n(counter, __ATOMIC_SEQ_CST)<wanted) {
        require(!__atomic_load_n(&failure, __ATOMIC_SEQ_CST), "worker futex failure");
        require(nanos()<end, "progress timeout");
        yield();
    }
}
static uint32_t wake_waiters(uint32_t wanted)
{
    uint32_t count=0;
    uint64_t end=nanos()+30000000000ULL;
    while(count<wanted) {
        int result=futex(&word, PRIVATE_WAKE, wanted-count, 0, 1);
        require(result>=0 && (uint32_t)result<=wanted-count, "bounded wake return");
        count+=(uint32_t)result;
        require(nanos()<end, "wake timeout");
        if(count<wanted) yield();
    }
    return count;
}
static void gate_a(void)
{
    int64_t bad[2]={0,1000000000LL}, delay64[2]={0,3000000}, huge[2]={INT64_MAX,0};
    int32_t delay32[2]={0,3000000};
    uint64_t start;
    require(futex(&word,PRIVATE_WAIT,41,0,1)==-11, "mismatch EAGAIN");
    require(futex((uint32_t *)((uintptr_t)&word+1),PRIVATE_WAIT,42,0,1)==-22, "unaligned EINVAL");
    require(futex((uint32_t *)0x1000,PRIVATE_WAIT,42,0,1)==-14, "unmapped EFAULT");
    require(futex(&word,PRIVATE_WAIT,42,(void *)0x1000,1)==-14, "timeout EFAULT");
    require(futex(&word,PRIVATE_WAIT,42,bad,1)==-22, "bad nanoseconds");
    bad[0]=-1; bad[1]=0;
    require(futex(&word,PRIVATE_WAIT,42,bad,1)==-22, "negative seconds");
    require(futex(&word,PRIVATE_WAIT,41,huge,1)==-11, "huge valid timeout no wrap");
    require(futex(&word,0,42,0,1)==-38, "shared futex unsupported");
    require(futex(&word,137,42,0,1)==-38, "bitset unsupported");
    require(futex(&word,PRIVATE_WAKE,UINT32_MAX,0,1)==-22, "negative wake count");
    require(futex(&word,PRIVATE_WAKE,0,0,1)==0, "zero wake");
    start=nanos();
    require(futex(&word,PRIVATE_WAIT,42,delay64,1)==-110 && nanos()-start>=3000000ULL, "time64 timeout");
    start=nanos();
    require(futex(&word,PRIVATE_WAIT,42,delay32,0)==-110 && nanos()-start>=3000000ULL, "time32 timeout");
    puts("[native-futex-gate-A] private WAIT/WAKE ABI negatives and real time32/time64 scheduler timeouts PASS");
}
static void gate_b(void)
{
    struct caribe_thread_request thread=create(0,ROUNDS,0);
    uint32_t i,total=0;
    ready=acknowledgements=failure=0;
    operate(&thread,CARIBE_THREAD_START,0);
    await(&ready,1);
    for(i=1;i<=ROUNDS;i++) { total+=wake_waiters(1); await(&acknowledgements,i); }
    operate(&thread,CARIBE_THREAD_JOIN,0);
    require(total==ROUNDS && acknowledgements==ROUNDS && !failure, "exact 10000 sleeps/wakes");
    require(futex(&word,PRIVATE_WAKE,INT32_MAX,0,1)==0, "empty after join");
    puts("[native-futex-gate-B] rounds=10000 actual waiters woken=10000 acknowledgements=10000 zero lost events PASS");
}
static void gate_c(void)
{
    struct caribe_thread_request threads[16]; uint32_t i;
    ready=acknowledgements=failure=0;
    puts("[native-futex-progress] gate C creating sixteen suspended threads");
    for(i=0;i<16;i++) threads[i]=create(i,1,0);
    puts("[native-futex-progress] gate C starting sixteen threads");
    for(i=0;i<16;i++) operate(&threads[i],CARIBE_THREAD_START,0);
    puts("[native-futex-progress] gate C waiting for ready=16");
    await(&ready,16); yield();
    puts("[native-futex-progress] gate C ready=16; bounded wakes");
    require(futex(&other_word,PRIVATE_WAKE,INT32_MAX,0,1)==0, "address-key isolation");
    require(futex(&word,PRIVATE_WAKE,0,0,1)==0 && acknowledgements==0, "zero wake preserves waiters");
    require(wake_waiters(1)==1, "wake one"); await(&acknowledgements,1);
    require(acknowledgements==1, "only one worker wakes");
    require(wake_waiters(15)==15, "remaining bounded wake"); await(&acknowledgements,16);
    for(i=0;i<16;i++) operate(&threads[i],CARIBE_THREAD_JOIN,0);
    require(!failure && futex(&word,PRIVATE_WAKE,INT32_MAX,0,1)==0, "all slots gone");
    puts("[native-futex-gate-C] sixteen simultaneous waiters; zero/one/fifteen bounded wakes and separate address key PASS");
}
static void gate_d(void)
{
    unsigned i;
    for(i=0;i<64;i++) {
        struct caribe_thread_request thread;
        ready=acknowledgements=failure=0; thread=create(0,1,0);
        operate(&thread,CARIBE_THREAD_START,0); await(&ready,1); yield();
        operate(&thread,CARIBE_THREAD_CANCEL,0); operate(&thread,CARIBE_THREAD_JOIN,CARIBE_THREAD_CANCELLED);
        require(futex(&word,PRIVATE_WAKE,INT32_MAX,0,1)==0, "cancelled waiter leak");
    }
    for(i=0;i<8;i++) {
        int channel[2],ack[2],status; char byte='Q'; pid_t child;
        require(pipe(channel)==0 && pipe(ack)==0, "isolation pipes");
        child=fork(); require(child>=0,"isolation fork");
        if(!child) {
            struct caribe_thread_request thread;
            close(channel[0]); close(ack[1]); ready=acknowledgements=failure=0;
            thread=create(0,2,0); operate(&thread,CARIBE_THREAD_START,0);
            await(&ready,1); wake_waiters(1); await(&acknowledgements,1); yield();
            require(write(channel[1],&byte,1)==1 && read(ack[0],&byte,1)==1,"child handshake");
            _exit(0); /* Owner teardown must cancel and dequeue its waiter. */
        }
        close(channel[1]); close(ack[0]); require(read(channel[0],&byte,1)==1,"child private wait");
        require(futex(&word,PRIVATE_WAKE,INT32_MAX,0,1)==0,"same VA different pmap isolation");
        require(write(ack[1],&byte,1)==1,"release child");
        require(waitpid(child,&status,0)==child && WIFEXITED(status) && WEXITSTATUS(status)==0,"owner exit");
        close(channel[0]); close(ack[1]);
    }
    puts("[native-futex-gate-D] blocked cancellations=64 owner-exit cycles=8; same-VA distinct-pmap isolation; zero waiter leaks PASS");
}
int main(int argc,char **argv)
{
    char gate='D'; int disabled=0;
    struct caribe_thread_request before={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_STATS};
    struct caribe_thread_request after={.abi=CARIBE_THREAD_ABI,.operation=CARIBE_THREAD_STATS};
    uint32_t expected;
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0];
    else if(argc==2 && !strcmp(argv[1],"--profile-off")) disabled=1;
    else if(argc!=1) return 2;
    if(gate<'A'||gate>'D') return 2;
    memory=mmap(0,16*CHUNK,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    require(memory!=MAP_FAILED,"stack pool");
    require(thread_request(&before)==0 && before.live==0,"baseline thread resources");
    if(disabled) {
        struct caribe_thread_request thread=create(0,0,1);
        operate(&thread,CARIBE_THREAD_START,0); operate(&thread,CARIBE_THREAD_JOIN,0);
        puts("[native-futex] disabled profile worker futex=ENOTSUP; conservative raw-thread syscall boundary PASS");
    } else {
        gate_a(); if(gate>='B') gate_b(); if(gate>='C') gate_c(); if(gate>='D') gate_d();
    }
    expected=disabled ? 1U : (gate>='B' ? 1U : 0U)+(gate>='C' ? 16U : 0U)+(gate>='D' ? 72U : 0U);
    require(thread_request(&after)==0 && after.live==0 && after.created-before.created==expected &&
        after.reaped-before.reaped==expected && after.exited-before.exited==expected,"exact final reaper resources");
    printf("[native-futex] created=reaped=%u live=0 all slots retired PASS\n",expected);
    if(!disabled) printf("[native-futex] gates A-%c PASS; private futex scheduler waits, not pthread or threaded libc\n",gate);
    require(munmap(memory,16*CHUNK)==0,"stack pool release after reaper");
    return 0;
}
