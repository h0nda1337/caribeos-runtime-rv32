/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Genuine musl mallocng and original Syllable worker Message/Queue transport.
 */
#include <util/thread.h>
#include <util/message.h>
#include <util/messagequeue.h>
#include <atheos/time.h>
#include <atheos/msgport.h>
#include <uapi/caribe_thread.h>
#include "thread_runtime.h"
#include "heap_runtime.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

extern "C" uint32_t *caribe_tcb_initialized_address(void);
extern "C" uint32_t *caribe_tcb_zero_address(void);
extern "C" int caribe_heap_test_hold(void);
extern "C" void caribe_heap_test_release(void);
extern "C" int caribe_musl_raw_tcb_prepare(void *,size_t,uintptr_t *);
static volatile unsigned failure,done,held;
static volatile uint32_t allocation_cycles,message_cycles;
static pthread_t controller_tcbs,tcbs[16];
static port_id input,output;
static const char *program;
static unsigned char *partial_stack;

static int raw(uint32_t number,uintptr_t a=0,uintptr_t b=0,uintptr_t c=0,uintptr_t d=0,uintptr_t e=0,uintptr_t f=0,uint32_t inner=0)
{
    register uintptr_t a0 __asm__("a0")=a,a1 __asm__("a1")=b,a2 __asm__("a2")=c,a3 __asm__("a3")=d;
    register uintptr_t a4 __asm__("a4")=e,a5 __asm__("a5")=f,a6 __asm__("a6")=inner,a7 __asm__("a7")=number;
    __asm__ volatile("ecall" : "+r"(a0),"+r"(a1) : "r"(a2),"r"(a3),"r"(a4),"r"(a5),"r"(a6),"r"(a7) : "memory");
    return (int32_t)a0;
}
static caribe_thread_request stats()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_STATS;
    if(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)) exit(1);
    return r;
}
static void require(bool ok,const char *what)
{
    if(!ok) { fprintf(stderr,"[native-heap] FAIL %s code=%u errno=%d\n",what,failure,errno); exit(1); }
}
static void check(bool ok,unsigned code)
{
    if(!ok) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); exit_thread((int)code); }
}
static void yield()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_YIELD;
    (void)raw(CARIBE_THREAD_ECALL,(uintptr_t)&r);
}
static void wait_value(volatile unsigned *p,unsigned value,const char *what)
{
    bigtime_t deadline=get_system_time()+5000000;
    while(__atomic_load_n(p,__ATOMIC_SEQ_CST)!=value) { require(!failure && get_system_time()<deadline,what); yield(); }
}
class Worker : public os::Thread {
    unsigned mode,slot;
public:
    Worker(unsigned kind,unsigned index=0):Thread("genuine-musl-heap-worker"),mode(kind),slot(index) {}
    int32 Run() override
    {
        check(pthread_self()!=controller_tcbs && errno==0 && *caribe_tcb_initialized_address()==0x13579bdfU,1);
        tcbs[slot]=pthread_self(); *caribe_tcb_initialized_address()=0xabc00000U+slot;
        *caribe_tcb_zero_address()=slot+1;
        if(mode==4 || mode==5) {
            check(caribe_heap_test_hold()==0,2); __atomic_store_n(&held,1U,__ATOMIC_SEQ_CST);
            Delay(mode==4?200000:5000000); caribe_heap_test_release(); return 0;
        }
        if(mode==6) {
            check(caribe_heap_scope_enter()==0,3);
            *(volatile uint32_t *)1=7; return 0;
        }
        if(mode==7) {
            void *p=malloc(4096); check(p!=NULL,24);
            *(volatile uint32_t *)p=0x13579bdfU;
            free(p); check(false,4); return 4;
        }
        if(mode==3) {
            for(unsigned i=0;i<10000;i++) {
                os::Message message; int32 value=0;
                check(message.ReadPort(input)==0 && message.GetCode()==73 && message.FindInt32("round",&value)==0 && value==(int32)i,5);
                check(send_msg_x(output,i,&value,sizeof(value),-1)==0,6);
            }
            return 0;
        }
        if(mode==0) {
            uintptr_t sp; __asm__ volatile("mv %0, sp":"=r"(sp));
            uintptr_t page=sp&~4095U, tls=(uintptr_t)pthread_self()&~4095U;
            check(raw(CARIBE_THREAD_VM_ECALL,page,4096,0,0,0,0,215)==-EBUSY &&
                  raw(CARIBE_THREAD_VM_ECALL,tls,4096,0,0,0,0,215)==-EBUSY,7);
            check(raw(CARIBE_THREAD_VM_ECALL,page,4096,PROT_READ,0,0,0,226)==-EBUSY,8);
            check(raw(222,0,4096,3,0x22,UINT32_MAX)==-ENOTSUP && close(-1)==-1 && errno==ENOTSUP,9);
            caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_HEAP_LEAVE;
            check(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)==-EINVAL,10);
            void *p=malloc(131072); check(p!=NULL,11); memset(p,0x5a,131072); free(p);
            return 0;
        }
        errno=100+slot;
        os::MessageQueue q;
        for(unsigned i=0;i<10000;i++) {
            size_t size=32+(i&63U); unsigned char *p=(unsigned char *)calloc(1,size);
            check(p!=NULL,12);
            for(size_t j=0;j<size;j++) check(p[j]==0,13);
            memset(p,(int)(slot+1),size);
            unsigned char *next=(unsigned char *)realloc(p,size+128);
            check(next!=NULL,14);
            for(size_t j=0;j<size;j++) check(next[j]==slot+1,15);
            free(next);
            void *aligned=NULL; check(posix_memalign(&aligned,64,192)==0 && ((uintptr_t)aligned&63U)==0,16); free(aligned);
            if(!(i&15U)) {
                os::Message *m=new os::Message(73); unsigned char bytes[256]; int32 value=0;
                check(m->AddInt32("slot",slot)==0 && m->AddString("word","genuine worker Message") ==0,17);
                size_t n=m->GetFlattenedSize(); check(n<=sizeof(bytes) && m->Flatten(bytes,sizeof(bytes))==0,18);
                os::Message decoded; check(decoded.Unflatten(bytes,n)==0 && decoded.FindInt32("slot",&value)==0 && value==(int32)slot,19);
                check(q.Lock(),20); q.AddMessage(m); check(q.NextMessage()==m && q.IsEmpty(),21); q.Unlock(); delete m;
                __atomic_add_fetch(&message_cycles,1U,__ATOMIC_SEQ_CST);
            }
            check(errno==(int)(100+slot) && pthread_self()==tcbs[slot] && *caribe_tcb_initialized_address()==0xabc00000U+slot,22);
            __atomic_add_fetch(&allocation_cycles,1U,__ATOMIC_SEQ_CST);
            if(!(i&31U)) yield();
        }
        __atomic_add_fetch(&done,1U,__ATOMIC_SEQ_CST); return 0;
    }
};
static void partial_entry(void *)
{
    check(raw(CARIBE_THREAD_VM_ECALL,(uintptr_t)partial_stack,1,0,0,0,0,215)==-EBUSY &&
          raw(CARIBE_THREAD_VM_ECALL,(uintptr_t)partial_stack,1,PROT_READ,0,0,0,226)==-EBUSY,23);
    exit_thread(0);
}
static void gate_a()
{
    require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"genuine musl locking and real thread pool");
    require(raw(CARIBE_THREAD_VM_ECALL,0,4096,7,0x22,UINT32_MAX,0,222)==-ENOTSUP &&
            raw(CARIBE_THREAD_VM_ECALL,0,4096,3,2,3,0,222)==-ENOTSUP &&
            raw(CARIBE_THREAD_VM_ECALL,0,4096,0,0x22,UINT32_MAX,0,222)==-ENOTSUP,"execute/file/PROT_NONE rejected honestly");
    require(raw(CARIBE_THREAD_VM_ECALL,0,4096,8192,1,0,0,216)==-ENOSYS,"no fake legacy mremap shrink");
    Worker worker(0); worker.Start(); worker.WaitFor(); require(!failure,"worker real VM and protected stack/TCB");
    partial_stack=(unsigned char *)mmap(NULL,36864,3,0x22,-1,0);
    uintptr_t tp=0; require(partial_stack!=MAP_FAILED && caribe_musl_raw_tcb_prepare(partial_stack+32768,4096,&tp)==0,"partial-page stack fixture");
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_CREATE;
    r.entry=(uint32_t)(uintptr_t)partial_entry; r.stack_base=(uint32_t)(uintptr_t)partial_stack+16;
    r.stack_size=16384; r.tp=(uint32_t)tp;
    require(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)==-EINVAL,"unaligned stack creation rejected");
    r.stack_base-=16;
    require(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)==0,"page-aligned real native stack create"); uint32_t id=r.id;
    r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_START; r.id=id;
    require(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)==0,"partial-page worker start");
    r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_JOIN; r.id=id; r.timeout_us=5000000;
    require(raw(CARIBE_THREAD_ECALL,(uintptr_t)&r)==0 && r.status==0 && !failure && munmap(partial_stack,36864)==0,"rounded-page protection and generic reap");
    puts("[native-heap-gate-A] genuine musl VM; anonymous RW only; execute/file/PROT_NONE/mremap unsupported; stacks/TCB protected; Linux worker VM/FD denied PASS");
}
static void gate_b()
{
    Worker *workers[16];
    for(unsigned i=0;i<16;i++) workers[i]=new Worker(1,i);
    errno=123;
    for(unsigned i=0;i<16;i++) workers[i]->Start();
    bigtime_t deadline=get_system_time()+180000000;
    while(__atomic_load_n(&done,__ATOMIC_SEQ_CST)!=16) { require(!failure && get_system_time()<deadline,"genuine allocator progress"); yield(); }
    for(unsigned i=0;i<16;i++) { workers[i]->WaitFor(); delete workers[i]; }
    require(!failure && allocation_cycles==160000 && message_cycles==10000 && errno==123,"exact malloc/Message counters and controller errno");
    for(unsigned i=0;i<16;i++) for(unsigned j=0;j<i;j++) require(tcbs[i]!=tcbs[j],"independent worker TCBs");
    printf("[native-heap-gate-B] workers=16 calloc/realloc/aligned/free cycles=160000 genuine worker Message decode/Queue cycles=10000 independent TCBs cpu=0 PASS\n");
}
static void gate_c()
{
    input=create_port("genuine-heap-input",1); output=create_port("genuine-heap-output",1);
    require(input>0 && output>0,"native ReadPort transport");
    {
        Worker reader(3); reader.Start();
        for(unsigned i=0;i<10000;i++) {
            os::Message m(73); unsigned char bytes[128]; uint32 code; int32 value;
            require(m.AddInt32("round",i)==0,"main genuine Message field"); size_t n=m.GetFlattenedSize();
            require(n<=sizeof(bytes) && m.Flatten(bytes,sizeof(bytes))==0 && send_msg_x(input,99,bytes,n,-1)==0 &&
                    get_msg_x(output,&code,&value,sizeof(value),-1)==0 && code==i && value==(int32)i,"genuine worker ReadPort and typed decode");
        }
        reader.WaitFor(); require(!failure,"real worker ReadPort status");
    }
    require(delete_port(input)==0 && delete_port(output)==0,"transport cleanup");
    unsigned before=caribe_heap_cancelled_results(); uint32_t deferred=stats().reserved[CARIBE_THREAD_HEAP_DEFERRED];
    for(unsigned i=0;i<64;i++) {
        held=0; Worker owner(4),victim(7);
        owner.Start(); wait_value(&held,1,"genuine allocator lock held"); victim.Start();
        bigtime_t deadline=get_system_time()+5000000;
        while(stats().reserved[CARIBE_THREAD_HEAP_WAITERS]!=1) { require(!failure && get_system_time()<deadline,"actual musl allocator futex waiter"); yield(); }
        victim.Terminate(); owner.WaitFor(); require(!failure && victim.GetThreadId()==-1,"deferred cancel after genuine lock release");
    }
    require(caribe_heap_cancelled_results()-before==64 && stats().reserved[CARIBE_THREAD_HEAP_DEFERRED]-deferred>=64,"cancelled unreturned allocations released");
    for(unsigned mode=0;mode<2;mode++) for(unsigned i=0;i<8;i++) {
        pid_t child=fork(); require(child>=0,"critical owner fork before workers");
        if(!child) { execl(program,program,mode?"--owner-exit":"--critical-fault",(char *)NULL); _exit(127); }
        int status=0; require(waitpid(child,&status,0)==child,"critical owner wait");
        require(mode?(WIFEXITED(status)&&WEXITSTATUS(status)==41):(WIFSIGNALED(status)&&WTERMSIG(status)==11),"whole-process fault/exit rather than heap reuse");
    }
    puts("[native-heap-gate-C] genuine worker ReadPort typed messages=10000; actual allocator futex cancellations=64 unreturned results freed=64; critical faults=8 owner exits=8 whole-process cleanup PASS");
}
int main(int argc,char **argv)
{
    program=argv[0]; controller_tcbs=pthread_self();
    if(argc==2 && !strcmp(argv[1],"--disabled")) {
        require(!(stats().reserved[CARIBE_THREAD_HEAP_FEATURE]&CARIBE_THREAD_HEAP_ENABLED) &&
                raw(CARIBE_THREAD_VM_ECALL,0,4096,3,0x22,UINT32_MAX,0,222)==-ENOTSUP &&
                caribe_heap_init()==-1 && errno==ENOTSUP,"default-off native heap channel");
        puts("[native-heap] disabled profile VM=ENOTSUP allocator activation denied; default musl and worker boundary unchanged PASS");
        return 0;
    }
    if(argc==2 && (!strcmp(argv[1],"--critical-fault") || !strcmp(argv[1],"--owner-exit"))) {
        require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"child heap init");
        Worker worker(!strcmp(argv[1],"--critical-fault")?6:5); worker.Start();
        if(!strcmp(argv[1],"--owner-exit")) { wait_value(&held,1,"exit worker actual allocator lock"); _exit(41); }
        worker.WaitFor(); require(false,"critical fault reused heap"); return 1;
    }
    char gate='C';
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0]; else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    caribe_thread_request before=stats(); require(before.live==0,"baseline live workers");
    gate_a();
    if(gate>='B') gate_b();
    if(gate>='C') gate_c();
    require(caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"actual pool release and locking restore");
    caribe_thread_request after=stats(); unsigned count=gate>='C'?163:gate>='B'?18:2;
    unsigned cancel=gate>='C'?72:0,faults=gate>='C'?8:0,aborted=gate>='C'?16:0;
    require(!failure && after.live==0 && after.created-before.created==count && after.exited-before.exited==count &&
            after.reaped-before.reaped==count && after.cancelled-before.cancelled==cancel && after.faults-before.faults==faults &&
            after.reserved[CARIBE_THREAD_HEAP_ABORTED]-before.reserved[CARIBE_THREAD_HEAP_ABORTED]==aborted &&
            after.reserved[CARIBE_THREAD_HEAP_ACTIVE]==0 && after.reserved[CARIBE_THREAD_HEAP_WAITERS]==0 &&
            after.reserved[CARIBE_THREAD_HEAP_ENTERS]-before.reserved[CARIBE_THREAD_HEAP_ENTERS]==
            after.reserved[CARIBE_THREAD_HEAP_LEAVES]-before.reserved[CARIBE_THREAD_HEAP_LEAVES]+aborted,"exact native reaping/scopes/fault resources");
    printf("[native-heap] created=reaped=%u cancelled=%u expected-faults=%u aborted-scopes=%u active=0 waiters=0 pool released PASS\n",count,cancel,faults,aborted);
    printf("[native-heap] gates A-%c PASS; genuine musl allocator and worker Message, not pthread/GNU exceptions or Looper/AppServer\n",gate);
    return 0;
}
