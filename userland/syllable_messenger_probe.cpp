/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Exercise original Messenger/Message/Looper, including an independent exec.
 */
#include <util/looper.h>
#include <util/message.h>
#include <util/messenger.h>
#include <atheos/msgport.h>
#include <atheos/threads.h>
#include <atheos/time.h>
#include <uapi/caribe_ipc.h>
#include <uapi/caribe_thread.h>
#include "thread_runtime.h"
#include "heap_runtime.h"
#include "looper_runtime.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile unsigned failure,started,handled,acknowledged,chains,destroyed,private_denied;
static int raw(uint32_t number,void *request)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)request,a7 __asm__("a7")=number;
    __asm__ volatile("ecall":"+r"(a0):"r"(a7):"a1","memory"); return (int32_t)a0;
}
static void require(bool ok,const char *what)
{
    if(!ok){caribe_looper_flush_debug(); fprintf(stderr,"[syllable-messenger] FAIL %s worker=%u errno=%d\n",what,__atomic_load_n(&failure,__ATOMIC_SEQ_CST),errno); exit(1);}
}
static void check(bool ok,unsigned code)
{
    if(!ok){__atomic_store_n(&failure,code,__ATOMIC_SEQ_CST);exit_thread(code);}
}
static caribe_ipc_request ipc_stats()
{
    caribe_ipc_request r={};r.abi=CARIBE_IPC_ABI;r.operation=CARIBE_IPC_STATS;
    require(raw(CARIBE_THREAD_IPC_ECALL,&r)==0,"native IPC statistics");return r;
}
static caribe_thread_request thread_stats()
{
    caribe_thread_request r={};r.abi=CARIBE_THREAD_ABI;r.operation=CARIBE_THREAD_STATS;
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"native thread statistics");return r;
}
static void wait_value(volatile unsigned *p,unsigned count,bigtime_t timeout=10000000)
{
    bigtime_t deadline=get_system_time()+timeout;
    while(__atomic_load_n(p,__ATOMIC_SEQ_CST)!=count){
        require(!__atomic_load_n(&failure,__ATOMIC_SEQ_CST) && get_system_time()<deadline,"actual callback progress");
        caribe_thread_request r={};r.abi=CARIBE_THREAD_ABI;r.operation=CARIBE_THREAD_YIELD;
        require(raw(CARIBE_THREAD_ECALL,&r)==0,"native yield");
    }
}
class Loop : public os::Looper {
public:
    Loop():Looper("original-messenger-loop",NORMAL_PRIORITY,2){}
    ~Loop() override {__atomic_add_fetch(&destroyed,1U,__ATOMIC_SEQ_CST);}
    void Started() override {check(IsLocked(),1);__atomic_add_fetch(&started,1U,__ATOMIC_SEQ_CST);}
};
class Service : public os::Handler {
    unsigned slot;
    bool remote;
public:
    Service(unsigned index,bool other):Handler("original-message-reply"),slot(index),remote(other){}
    void HandleMessage(os::Message *m) override {
        int32 seq=-1,index=-1;
        check(GetLooper()->IsLocked() && m->IsSourceWaiting() && m->IsSourceRemote()==remote &&
              m->ReturnAddress().IsValid() && m->ReturnAddress().IsTargetLocal()!=remote &&
              m->FindInt32("seq",&seq)==0 && seq>=0 && seq<10000 &&
              m->FindInt32("slot",&index)==0 && index==(int32)slot,2);
        if(remote && seq==0){
            caribe_syllable_debug("[syllable-messenger-peer] actual first dispatch owner=%d native-thread=%d\n",get_process_id(NULL),get_thread_id(NULL));
            uint8 bytes[256];port_id reply_port=-1;
            check(m->Flatten(bytes,sizeof(bytes))==0,8);memcpy(&reply_port,bytes+16,sizeof(reply_port));
            check(get_msg_x(reply_port,NULL,NULL,0,0)==-1 && errno==EPERM,9);
            __atomic_add_fetch(&private_denied,1U,__ATOMIC_SEQ_CST);
            caribe_syllable_debug("[syllable-messenger-peer] private reply receive correctly denied\n");
        }
        os::Message reply(81); check(reply.AddInt32("seq",seq)==0 && reply.AddInt32("slot",index)==0,3);
        if(m->GetCode()==72){
            os::Message back;
            check(m->SendReply(&reply,&back,1000000,1000000)==0 && back.IsReply() && back.GetCode()==82,4);
            __atomic_add_fetch(&chains,1U,__ATOMIC_SEQ_CST);
        }else check(m->SendReply(&reply,(os::Handler*)NULL,1000000)==0,5);
        check(!m->IsSourceWaiting() && !reply.IsReply() && !reply.WasDelivered(),6);
        __atomic_add_fetch(&handled,1U,__ATOMIC_SEQ_CST);
    }
};
class Ack : public os::Handler {
public:
    Ack():Handler("original-async-reply"){}
    void HandleMessage(os::Message *m) override {
        int32 seq=-1,index=-1;unsigned count=__atomic_load_n(&acknowledged,__ATOMIC_SEQ_CST);
        check(GetLooper()->IsLocked() && m->IsReply() && m->GetCode()==81 &&
              m->FindInt32("seq",&seq)==0 && seq==(int32)count &&
              m->FindInt32("slot",&index)==0 && index==(int32)(count%4),7);
        __atomic_add_fetch(&acknowledged,1U,__ATOMIC_SEQ_CST);
    }
};
static void request(os::Message &m,unsigned seq,unsigned slot)
{
    require(m.AddInt32("seq",seq)==0 && m.AddInt32("slot",slot)==0,"typed request");
}
static void reply_ok(os::Message &reply,unsigned seq,unsigned slot)
{
    int32 n=-1,index=-1;
    require(reply.IsReply() && reply.GetCode()==81 && reply.FindInt32("seq",&n)==0 && n==(int32)seq &&
            reply.FindInt32("slot",&index)==0 && index==(int32)slot,"original reply flags/typed result");
}
static void gate_a()
{
    caribe_thread_request before=thread_stats();Loop *loops[4];Service *services[4];
    for(unsigned i=0;i<4;i++){loops[i]=new Loop;services[i]=new Service(i,false);loops[i]->AddHandler(services[i]);}
    Loop *reply_loop=new Loop;Ack ack;reply_loop->AddHandler(&ack);
    os::Messenger targets[4];
    for(unsigned i=0;i<4;i++){
        targets[i]=os::Messenger(services[i]);os::Messenger copy(targets[i]);os::Looper *found=NULL;
        require(copy==targets[i] && copy.IsValid() && copy.IsTargetLocal() && copy.LockTarget()==0,"original Messenger identity/lock");
        require(copy.GetTarget(&found)==services[i] && found==loops[i],"original local target");found->Unlock();
        require(os::Messenger((os::Handler*)NULL,loops[i]).GetTarget(&found)==loops[i],"default Looper target");
        require(loops[i]->Run()>0,"original service Run");
    }
    require(reply_loop->Run()>0,"original async reply Run");wait_value(&started,5);
    for(unsigned n=0;n<10000;n++){
        os::Message m(70),reply;request(m,n,n%4);
        require(targets[n%4].SendMessage(&m,&reply,1000000,1000000)==0,"actual synchronous original request/reply");reply_ok(reply,n,n%4);
        require(!m.WasDelivered() && !m.ReturnAddress().IsValid(),"caller metadata retained");
    }
    for(unsigned n=0;n<10000;n++){
        os::Message m(71);request(m,n,n%4);
        require(targets[n%4].SendMessage(&m,&ack,1000000)==0,"original asynchronous reply Handler");wait_value(&acknowledged,n+1);
    }
    for(unsigned n=0;n<64;n++){
        os::Message m(72),reply;request(m,n,n%4);
        require(targets[n%4].SendMessage(&m,&reply,1000000,1000000)==0,"reply-to-reply request");reply_ok(reply,n,n%4);
        require(reply.SendReply(82)==0,"original reply-to-reply acknowledgement");
    }
    wait_value(&handled,20064);wait_value(&chains,64);
    for(unsigned i=0;i<4;i++){loops[i]->Terminate();require(services[i]->GetLooper()==NULL,"service detachment");delete services[i];}
    reply_loop->Terminate();require(ack.GetLooper()==NULL && destroyed==5,"reply Handler detachment");
    caribe_thread_request after=thread_stats();
    require(after.live==0 && after.created-before.created==5 && after.reaped-before.reaped==5 &&
            after.faults==before.faults && after.cancelled==before.cancelled,"exact original five-Looper lifecycle");
    puts("[syllable-messenger-gate-A] original Messenger sync=10000 async Handler replies=10000 reply-to-reply=64; loops=5 created=reaped=5 faults=0 cpu=0 PASS");
}
static void gate_b()
{
    caribe_ipc_request before=ipc_stats();require(before.ports==0 && before.messages==0,"empty ports before pressure");
    port_id ports[32];for(unsigned i=0;i<32;i++){ports[i]=create_port("reply-pressure",1);require(ports[i]>0,"fill actual native port capacity");}
    os::Messenger target(ports[0]);os::Message m(70),reply;request(m,0,0);port_info info;
    require(target.SendMessage(&m,&reply,0,0)==-1 && errno==ENOSPC,"temporary reply allocation failure");
    require(get_port_info(ports[0],&info)==0 && info.pi_cur_count==0 && !m.WasDelivered(),"failed allocation never posts request");
    for(unsigned i=1;i<32;i++)require(delete_port(ports[i])==0,"release pressure ports");
    require(target.SendMessage(&m,(os::Handler*)NULL,0)==0,"fill bounded destination queue");bigtime_t start=get_system_time();
    require(target.SendMessage(&m,(os::Handler*)NULL,2000)==-1 && errno==ETIMEDOUT,"send deadline honored");
    require(get_system_time()-start>=2000 && get_system_time()-start<250000,"bounded send elapsed");
    os::Message received;require(received.ReadPort(ports[0],0)==0,"drain actual queued message");
    start=get_system_time();require(target.SendMessage(&m,&reply,2000,2000)==-1 && errno==ETIMEDOUT,"reply deadline honored");
    require(get_system_time()-start>=2000 && get_system_time()-start<250000 && !m.ReturnAddress().IsValid(),"bounded reply/metadata");
    require(received.ReadPort(ports[0],0)==0 && received.IsSourceWaiting(),"read real timed-out request");
    require(received.SendReply(81)==-1 && errno==ENOENT && received.IsSourceWaiting(),"failed late reply retains retry state");
    require(delete_port(ports[0])==0,"sink cleanup");caribe_ipc_request after=ipc_stats();
    require(after.ports==0 && after.messages==0,"no temporary reply port/message leak");caribe_looper_flush_debug();
    puts("[syllable-messenger-gate-B] ports exhausted=32 no request posted; send/reply deadlines=2 preserved errno; failed late reply retry state retained; ports=0 messages=0 PASS");
}
static int peer(const char *control_name)
{
    require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"peer heap/native pool");
    port_id control=find_port(control_name);require(control>0,"independent exec control discovery");
    Loop *loop=new Loop;Service service(0,true);loop->AddHandler(&service);loop->SetDefaultHandler(&service);
    require(loop->GetDefaultHandler()==&service,"peer original default Handler registration");
    port_id destination=loop->GetMsgPort();require(make_port_public(destination)==0 && loop->Run()>0,"peer original public Looper");
    wait_value(&started,1);
    printf("[syllable-messenger-peer] original Looper started owner=%d port=%d\n",get_process_id(NULL),destination);
    require(send_msg_x(control,91,&destination,sizeof(destination),5000000)==0,"peer actual port handoff");
    bigtime_t deadline=get_system_time()+180000000;
    while(__atomic_load_n(&handled,__ATOMIC_SEQ_CST)!=10000){
        caribe_looper_flush_debug();
        require(!__atomic_load_n(&failure,__ATOMIC_SEQ_CST) && get_system_time()<deadline,"peer actual callback progress");
        caribe_thread_request r={};r.abi=CARIBE_THREAD_ABI;r.operation=CARIBE_THREAD_YIELD;
        require(raw(CARIBE_THREAD_ECALL,&r)==0,"peer native yield");
    }
    loop->Terminate();require(service.GetLooper()==NULL && destroyed==1 && private_denied==1,"peer reaping/private reply receive denied");
    require(caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"peer shutdown");
    uint32 result=0;require(send_msg_x(control,92,&result,sizeof(result),5000000)==0,"peer completion");return 0;
}
static void gate_c_before_workers()
{
    char name[48];snprintf(name,sizeof(name),"messenger-control-%u",(unsigned)getpid());
    port_id control=create_port(name,2);require(control>0 && make_port_public(control)==0,"public control port");
    pid_t child=fork();require(child>=0,"real independent process fork");
    if(child==0){execl("/bin/syllable-messenger-probe","syllable-messenger-probe","--server",name,(char*)NULL);_exit(127);}
    uint32 code=0;port_id destination=-1;
    require(get_msg_x(control,&code,&destination,sizeof(destination),10000000)==0 && code==91 && destination>0,"independent exec Looper ready");
    os::Messenger target(destination);require(target.IsValid() && !target.IsTargetLocal(),"remote original Messenger");
    for(unsigned n=0;n<10000;n++){
        os::Message m(70),reply;request(m,n,0);
        if(target.SendMessage(&m,&reply,1000000,1000000)!=0){fprintf(stderr,"[syllable-messenger-peer] failed remote sequence=%u\n",n);require(false,"cross-exec original request/reply");}
        reply_ok(reply,n,0);
    }
    uint32 result=1;require(get_msg_x(control,&code,&result,sizeof(result),10000000)==0 && code==92 && result==0,"peer cleanup acknowledgement");
    int status=-1;require(waitpid(child,&status,0)==child && WIFEXITED(status) && WEXITSTATUS(status)==0,"independent exec exit(0)");
    require(delete_port(control)==0 && ipc_stats().ports==0 && ipc_stats().messages==0,"cross-process owner cleanup");
    puts("[syllable-messenger-gate-C] independent fork/exec original Looper service; remote typed request/reply=10000 private reply receive ownership; child exit(0) ports=0 messages=0 PASS");
}
int main(int argc,char **argv)
{
    if(argc==3 && !strcmp(argv[1],"--server"))return peer(argv[2]);
    char gate='C';if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1)gate=argv[2][0];else if(argc!=1)return 2;
    if(gate<'A'||gate>'C')return 2;
    if(gate=='C')gate_c_before_workers();
    require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"actual heap/native thread activation");
    gate_a();if(gate>='B')gate_b();caribe_looper_flush_debug();
    require(caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"native pool/heap shutdown");
    printf("[syllable-messenger] gates A-%c PASS; original toolkit transport, not complete AppServer/Desktop\n",gate);return 0;
}
