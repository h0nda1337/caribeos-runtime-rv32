/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original public Syllable lifecycle/time adapters to real XNU operations.
 * Controller-only creation/control; worker libc allocation is not enabled.
 */
#include "thread_runtime.h"
#include "tcb_bootstrap.h"
#include <atheos/time.h>
#include <uapi/caribe_thread.h>
#include <errno.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#define THREAD_STACK 32768U
#define THREAD_CHUNK (THREAD_STACK+4096U)
typedef int32 (*entry_fn)(void *);
static struct {
    thread_id id;
    entry_fn entry;
    void *argument;
    int joining;
} slots[CARIBE_THREAD_MAX];
static unsigned char *pool;
static uint32_t controller,owner;

static struct caribe_thread_request request(uint32_t operation)
{
    struct caribe_thread_request r={0}; r.abi=CARIBE_THREAD_ABI; r.operation=operation; return r;
}
static int call(struct caribe_thread_request *r)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)r;
    register uintptr_t a7 __asm__("a7")=CARIBE_THREAD_ECALL;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    if ((int32_t)a0<0) { errno=-(int32_t)a0; return -1; }
    return 0;
}
static int unsupported(void) { errno=ENOTSUP; return -1; }
static int is_controller(void)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    if (call(&r)) return -1;
    if (r.id!=controller || r.owner!=owner || r.cpu) { errno=ENOTSUP; return -1; }
    return 0;
}
int caribe_syllable_threads_init(void)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    if (pool) return is_controller();
    if (call(&r)) return -1;
    if (!r.id || r.id!=r.owner || r.cpu) return unsupported();
    pool=mmap(NULL,CARIBE_THREAD_MAX*THREAD_CHUNK,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    if (pool==MAP_FAILED) { pool=NULL; return -1; }
    controller=r.id; owner=r.owner;
    return 0;
}
static int find_slot(thread_id id)
{
    unsigned i;
    for (i=0;i<CARIBE_THREAD_MAX;i++) if (id>0 && slots[i].id==id) return (int)i;
    errno=EINVAL; return -1;
}
int caribe_syllable_threads_shutdown(void)
{
    unsigned i;
    if (!pool) return 0;
    if (is_controller()) return -1;
    for (i=0;i<CARIBE_THREAD_MAX;i++) if (slots[i].id) { errno=EBUSY; return -1; }
    if (munmap(pool,CARIBE_THREAD_MAX*THREAD_CHUNK)) return -1;
    pool=NULL; controller=owner=0;
    return 0;
}
int exit_thread(int status)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_EXIT); r.status=(uint32_t)status;
    (void)call(&r);
    for (;;) __asm__ volatile("nop");
}
static void enter(uint32_t index,uint32_t id) __attribute__((noreturn));
static void enter(uint32_t index,uint32_t id)
{
    if (index>=CARIBE_THREAD_MAX || (uint32_t)slots[index].id!=id) exit_thread(EINVAL);
    (void)exit_thread(slots[index].entry(slots[index].argument));
    for (;;) __asm__ volatile("nop");
}
thread_id spawn_thread(const char *name,void *entry,int priority,int stack_size,void *argument)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_CREATE);
    uintptr_t tp;
    unsigned index;
    if (!name || !*name || strlen(name)>=OS_NAME_LENGTH || !entry || stack_size<0) { errno=EINVAL; return -1; }
    if (priority!=NORMAL_PRIORITY || (stack_size && (stack_size<16384 || stack_size>(int)THREAD_STACK))) return unsupported();
    if (caribe_syllable_threads_init()) return -1;
    for (index=0;index<CARIBE_THREAD_MAX && slots[index].id;index++);
    if (index==CARIBE_THREAD_MAX) { errno=EAGAIN; return -1; }
    if (caribe_musl_raw_tcb_prepare(pool+index*THREAD_CHUNK+THREAD_STACK,4096,&tp)) return -1;
    r.entry=(uint32_t)(uintptr_t)enter; r.argument=index;
    r.stack_base=(uint32_t)(uintptr_t)(pool+index*THREAD_CHUNK);
    r.stack_size=THREAD_STACK; r.tp=(uint32_t)tp;
    if (call(&r)) return -1;
    slots[index].entry=(entry_fn)entry; slots[index].argument=argument;
    slots[index].joining=0; slots[index].id=(thread_id)r.id;
    return (thread_id)r.id;
}
status_t resume_thread(thread_id id)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_START);
    if (is_controller() || find_slot(id)<0) return -1;
    r.id=(uint32_t)id; return call(&r);
}
int caribe_syllable_thread_join(thread_id id,int *status)
{
    struct caribe_thread_request r;
    int slot,result;
    if (!status) { errno=EINVAL; return -1; }
    if (is_controller() || (slot=find_slot(id))<0) return -1;
    if (slots[slot].joining) { errno=EBUSY; return -1; }
    slots[slot].joining=1;
    do {
        r=request(CARIBE_THREAD_JOIN); r.id=(uint32_t)id; r.timeout_us=60000000U;
        result=call(&r);
    } while (result<0 && (errno==EINTR || errno==ETIMEDOUT));
    if (result<0 || r.state!=CARIBE_THREAD_EXITED) { slots[slot].joining=0; return -1; }
    *status=(int32_t)r.status;
    memset(&slots[slot],0,sizeof(slots[slot]));
    return 0;
}
int wait_for_thread(thread_id id)
{
    int status;
    return caribe_syllable_thread_join(id,&status)?-1:status;
}
int caribe_syllable_thread_terminate(thread_id id)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_CANCEL);
    int status;
    if (is_controller() || find_slot(id)<0) return -1;
    r.id=(uint32_t)id;
    return call(&r)?-1:caribe_syllable_thread_join(id,&status);
}
proc_id get_thread_proc(thread_id id)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_INFO); r.id=(uint32_t)id;
    return call(&r)?-1:(proc_id)r.owner;
}
proc_id get_process_id(const char *name)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_SELF);
    if (name) return unsupported();
    return call(&r)?-1:(proc_id)r.owner;
}
bigtime_t get_system_time(void)
{
    struct caribe_thread_request r=request(CARIBE_THREAD_CLOCK);
    uint64_t ns;
    if (call(&r)) return -1;
    ns=(uint64_t)r.reserved[CARIBE_THREAD_TIME_LOW] | ((uint64_t)r.reserved[CARIBE_THREAD_TIME_HIGH]<<32);
    return (bigtime_t)(ns/1000U);
}
status_t snooze(bigtime_t timeout)
{
    struct caribe_thread_request self=request(CARIBE_THREAD_SELF);
    if (timeout<0) { errno=EINVAL; return -1; }
    if (call(&self)) return -1;
    if (self.id==self.owner) {
        struct timespec t={(time_t)(timeout/1000000), (long)(timeout%1000000)*1000};
        return nanosleep(&t,NULL);
    }
    do {
        struct caribe_thread_request r=request(CARIBE_THREAD_SLEEP);
        r.timeout_us=(uint32_t)(timeout>60000000?60000000:timeout);
        if (call(&r)) return -1;
        timeout-=r.timeout_us;
    } while (timeout>0);
    return 0;
}
status_t suspend_thread(thread_id id) { (void)id; return unsupported(); }
int set_thread_priority(thread_id id,int priority) { (void)id; (void)priority; return unsupported(); }
status_t get_thread_info(thread_id id,thread_info *info) { (void)id; (void)info; return unsupported(); }
