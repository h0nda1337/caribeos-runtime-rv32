/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Actual original Looper/Handler/filter execution, not a replacement loop.
 */
#include <util/looper.h>
#include <util/message.h>
#include <util/messagefilter.h>
#include <util/thread.h>
#include <gui/guidefines.h>
#include <atheos/time.h>
#include <atheos/msgport.h>
#include <uapi/caribe_thread.h>
#include "thread_runtime.h"
#include "heap_runtime.h"
#include "cxx_context.h"
#include "looper_runtime.h"
#include <cxxabi.h>
#include <stdexcept>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static volatile unsigned failure,done,throws_count,unwinds,static_initializations,dispatches,started,destroyed,ticks,filter_destructors,common_drops,local_drops;
static void *main_globals,*globals[16];
static int raw(caribe_thread_request *r)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)r,a7 __asm__("a7")=CARIBE_THREAD_ECALL;
    __asm__ volatile("ecall":"+r"(a0):"r"(a7):"a1","memory"); return (int32_t)a0;
}
static caribe_thread_request stats()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_STATS;
    if(raw(&r)) exit(1); return r;
}
static void require(bool ok,const char *what)
{
    if(!ok) { caribe_looper_flush_debug(); fprintf(stderr,"[syllable-looper] FAIL %s code=%u errno=%d\n",what,failure,errno); exit(1); }
}
static void check(bool ok,unsigned code)
{
    if(!ok) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); exit_thread(code); }
}
static void yield()
{
    caribe_thread_request r={}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_YIELD; (void)raw(&r);
}
static void wait_value(volatile unsigned *p,unsigned value,const char *label)
{
    bigtime_t end=get_system_time()+180000000;
    while(__atomic_load_n(p,__ATOMIC_SEQ_CST)!=value){require(!failure && get_system_time()<end,label); yield();}
}
struct Sentinel { ~Sentinel(){__atomic_add_fetch(&unwinds,1U,__ATOMIC_SEQ_CST);} };
struct StaticValue {
    unsigned value;
    StaticValue():value(0x13579bdfU){__atomic_add_fetch(&static_initializations,1U,__ATOMIC_SEQ_CST); snooze(2000);}
};
static StaticValue &shared_static(){static StaticValue value; return value;}
class ExceptionWorker : public os::Thread {
    unsigned slot;
public:
    ExceptionWorker(unsigned n):Thread("genuine-GNU-context"),slot(n){}
    int32 Run() override {
        globals[slot]=__cxxabiv1::__cxa_get_globals();
        check(globals[slot]!=main_globals && shared_static().value==0x13579bdfU,1);
        for(unsigned i=0;i<10000;i++){
            try { Sentinel guard; throw std::runtime_error("native GNU worker unwind"); }
            catch(const std::runtime_error &e){check(!strcmp(e.what(),"native GNU worker unwind"),2); __atomic_add_fetch(&throws_count,1U,__ATOMIC_SEQ_CST);}
            check(__cxxabiv1::__cxa_get_globals()==globals[slot] && std::uncaught_exceptions()==0,3);
            if(!(i&31U)) yield();
        }
        __atomic_add_fetch(&done,1U,__ATOMIC_SEQ_CST); return 0;
    }
};
static void gate_a()
{
    main_globals=__cxxabiv1::__cxa_get_globals();
    ExceptionWorker *workers[16];
    for(unsigned i=0;i<16;i++) workers[i]=new ExceptionWorker(i);
    for(unsigned i=0;i<16;i++) workers[i]->Start();
    wait_value(&done,16,"GNU native exception progress");
    for(unsigned i=0;i<16;i++){workers[i]->WaitFor(); delete workers[i];}
    require(!failure && throws_count==160000 && unwinds==160000 && static_initializations==1,"exact genuine GNU contexts/guards/unwind");
    for(unsigned i=0;i<16;i++) for(unsigned j=0;j<i;j++) require(globals[i]!=globals[j],"independent GNU exception globals");
    caribe_context_stats s; caribe_context_statistics(&s);
    require(s.fde_calls>0 && s.guard_calls>0 && s.waits>0,"real GNU lookup/guard and native contention");
    puts("[syllable-looper-gate-A] GNU native ELF exception TLS workers=16 throws=160000 unwind-destructors=160000 static-init=1 independent contexts cpu=0 PASS");
}
class Echo : public os::Handler {
    port_id ack;
    unsigned slot,round;
public:
    Echo(port_id p,unsigned n):Handler("original-echo-handler"),ack(p),slot(n),round(0){}
    void HandleMessage(os::Message *m) override {
        int32 value=-1,index=-1;
        check(GetLooper()!=NULL && GetLooper()->IsLocked() && m->FindInt32("round",&value)==0 &&
              m->FindInt32("slot",&index)==0 && value==(int32)round && index==(int32)slot,4);
        ++round; __atomic_add_fetch(&dispatches,1U,__ATOMIC_SEQ_CST);
        check(send_msg_x(ack,73,&value,sizeof(value),-1)==0,5);
    }
};
class Loop : public os::Looper {
public:
    Loop():Looper("genuine-original-looper",NORMAL_PRIORITY,2){}
    ~Loop() override {__atomic_add_fetch(&destroyed,1U,__ATOMIC_SEQ_CST);}
    void Started() override {
        check(GetLooperForThread(get_thread_id(NULL))==this && IsLocked(),6);
        __atomic_add_fetch(&started,1U,__ATOMIC_SEQ_CST);
    }
};
static void gate_b()
{
    Loop *loops[16]; Echo *handlers[16]; port_id acks[16]; thread_id ids[16];
    for(unsigned i=0;i<16;i++){
        acks[i]=create_port("original-loop-ack",2); require(acks[i]>0,"ack port");
        loops[i]=new Loop; handlers[i]=new Echo(acks[i],i); loops[i]->AddHandler(handlers[i]);
        require(loops[i]->GetHandlerCount()==2 && handlers[i]->GetLooper()==loops[i],"original handler registration");
    }
    for(unsigned i=0;i<16;i++) ids[i]=loops[i]->Run();
    wait_value(&started,16,"original Looper entry");
    for(unsigned n=0;n<10000;n++){
        for(unsigned i=0;i<16;i++){
            os::Message m(73); require(m.AddInt32("round",n)==0 && m.AddInt32("slot",i)==0 &&
              loops[i]->PostMessage(&m,handlers[i])==0,"original targeted PostMessage");
        }
        for(unsigned i=0;i<16;i++){uint32 code=0; int32 value=-1; require(get_msg_x(acks[i],&code,&value,sizeof(value),-1)==0 && code==73 && value==(int32)n,"original Handler callback");}
    }
    for(unsigned i=0;i<16;i++) loops[i]->Terminate();
    require(dispatches==160000 && destroyed==16 && !failure,"exact original dispatch/termination");
    for(unsigned i=0;i<16;i++){require(handlers[i]->GetLooper()==NULL,"non-owned handler detached"); delete handlers[i]; require(delete_port(acks[i])==0,"ack cleanup");}
    puts("[syllable-looper-gate-B] original loops=16 targeted typed messages=160000 Handler dispatch and graceful native reaping; non-owned handlers detached PASS");
}
class TimerHandler : public os::Handler {
public:
    TimerHandler():Handler("original-timer-handler"){}
    void TimerTick(int id) override {check(id==17 && GetLooper()->IsLocked(),7); __atomic_add_fetch(&ticks,1U,__ATOMIC_SEQ_CST);}
    void HandleMessage(os::Message *) override {check(false,8);}
};
class Drop : public os::MessageFilter {
    bool common;
public:
    Drop(bool global):common(global){}
    ~Drop() override {__atomic_add_fetch(&filter_destructors,1U,__ATOMIC_SEQ_CST);}
    os::MessageFilterResult Filter(os::Message*,os::Handler**) override {__atomic_add_fetch(common?&common_drops:&local_drops,1U,__ATOMIC_SEQ_CST); return os::MF_DISCARD_MESSAGE;}
};
static void gate_c()
{
    unsigned baseline=destroyed;
    for(unsigned i=0;i<64;i++){
        Loop *loop=new Loop; TimerHandler timer; loop->AddHandler(&timer);
        thread_id id=loop->Run(); require(id>0,"timer original loop"); wait_value(&started,17+i,"timer entry");
        require(snooze(2000)==0 && loop->Lock()==0,"live original timer lock");
        bigtime_t now=get_system_time(); loop->AddTimer(&timer,17,3000,true); loop->Unlock();
        wait_value(&ticks,i+1,"live original timer wake");
        require(get_system_time()-now>=3000 && get_system_time()-now<250000,"timer wake not old 500ms receive");
        require(loop->Lock()==0,"filter/malformed setup"); Drop *common=new Drop(true),*local=new Drop(false);
        loop->AddCommonFilter(common); timer.AddFilter(local); loop->Unlock();
        unsigned char invalid[1]={0}; require(send_msg_x(loop->GetMsgPort(),99,invalid,1,-1)==0,"malformed native input");
        require(send_msg_x(loop->GetMsgPort(),os::M_NODE_MONITOR,invalid,1,-1)==0,"unsupported node input");
        require(loop->PostMessage(73,&timer)==0,"common discard filter input");
        wait_value(&common_drops,i+1,"actual common filter discard");
        require(loop->Lock()==0,"remove common filter"); loop->RemoveCommonFilter(common); delete common; loop->Unlock();
        require(loop->PostMessage(73,&timer)==0,"local discard filter input");
        wait_value(&local_drops,i+1,"actual local filter discard");
        require(loop->Lock()==0,"pending timer removal"); loop->AddTimer(&timer,17,500000,true);
        require(loop->RemoveHandler(&timer) && !loop->RemoveTimer(&timer,17) && timer.GetLooper()==NULL,"detach removes pending timers");
        require(loop->Lock()==0,"recursive termination lock"); loop->Terminate();
        timer.RemoveFilter(local); delete local;
    }
    require(destroyed-baseline==64 && ticks==64 && common_drops==64 && local_drops==64 && filter_destructors==128,"original lifecycle/filter cleanup");
    caribe_looper_stats s; caribe_looper_statistics(&s);
    require(s.malformed==64 && s.node_rejected==64 && s.wake_sent>=64 && s.debug_dropped==0,"bounded native decode/wake counters");
    puts("[syllable-looper-gate-C] live original timers=64 wake<250000us; malformed=64 node-unsupported=64; common/local discards=64/64; pending timer removal=64 recursive termination=64 filters deleted=128 PASS");
}
int main(int argc,char **argv)
{
    char gate='C'; if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0]; else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"real heap/pool activation");
    caribe_thread_request before=stats(); gate_a(); if(gate>='B') gate_b(); if(gate>='C') gate_c();
    caribe_looper_flush_debug(); caribe_thread_request after=stats();
    unsigned count=gate=='A'?16:gate=='B'?32:96;
    require(!failure && after.live==0 && after.created-before.created==count && after.reaped-before.reaped==count &&
      after.exited-before.exited==count && after.faults==before.faults && after.cancelled==before.cancelled &&
      after.reserved[CARIBE_THREAD_HEAP_ACTIVE]==0 && after.reserved[CARIBE_THREAD_HEAP_WAITERS]==0,"exact real native lifecycle");
    require(caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"pool/heap shutdown");
    printf("[syllable-looper] created=reaped=%u faults=0 cancelled=0 active-scopes=0 waiters=0 PASS\n",count);
    printf("[syllable-looper] gates A-%c PASS; original event loop, not complete AppServer/Desktop\n",gate);
}
