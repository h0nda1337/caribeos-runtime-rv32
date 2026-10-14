/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Genuine MessageQueue/Thread and actual XNU worker IPC; no Looper substitute.
 */
#include <util/messagequeue.h>
#include <util/message.h>
#include <util/thread.h>
#include <atheos/msgport.h>
#include <atheos/time.h>
#include <uapi/caribe_ipc.h>
#include <uapi/caribe_thread.h>
#include <uapi/caribe_sync.h>
#include "thread_runtime.h"
#include "message_io.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern "C" uint32_t *caribe_tcb_initialized_address(void);
extern "C" uint32_t *caribe_tcb_zero_address(void);
static volatile uint32_t failure, active, completed;
static uint32_t queue_cycles;
static os::MessageQueue *queue;
static os::Message *items[16];
static pthread_t main_tcb, tcbs[16];
static int *main_errno;
static port_id incoming, outgoing, waiter_ports[16];
static unsigned wire_size;
static unsigned char wire[8192], maximum[8192];

static int raw(uint32_t number, void *arg)
{
    register uintptr_t a0 __asm__("a0") = (uintptr_t)arg;
    register uintptr_t a7 __asm__("a7") = number;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    return (int32_t)a0;
}
static caribe_thread_request threads()
{
    caribe_thread_request r = {}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_STATS;
    if(raw(CARIBE_THREAD_ECALL,&r)) exit(1);
    return r;
}
static caribe_ipc_request ports()
{
    caribe_ipc_request r = {}; r.abi=CARIBE_IPC_ABI; r.operation=CARIBE_IPC_STATS;
    if(raw(CARIBE_THREAD_IPC_ECALL,&r)) exit(1);
    return r;
}
static uint32_t semaphores()
{
    caribe_sync_request r = {}; r.abi=CARIBE_SYNC_ABI; r.operation=CARIBE_SYNC_STATS;
    if(raw(CARIBE_THREAD_SYNC_ECALL,&r)) exit(1);
    return r.live;
}
static void require(bool ok, const char *what)
{
    if(!ok) { fprintf(stderr,"[syllable-queue] FAIL %s code=%u errno=%d\n",what,failure,errno); exit(1); }
}
static void check(bool ok, uint32_t code)
{
    if(!ok) { __atomic_store_n(&failure,code,__ATOMIC_SEQ_CST); exit_thread((int)code); }
}
static void yield()
{
    caribe_thread_request r = {}; r.abi=CARIBE_THREAD_ABI; r.operation=CARIBE_THREAD_YIELD;
    (void)raw(CARIBE_THREAD_ECALL,&r);
}
static void wait_blocks(uint32_t expected)
{
    bigtime_t deadline=get_system_time()+5000000;
    while(ports().limit<expected) { require(!failure && get_system_time()<deadline,"actual port wait registration"); yield(); }
}
class Worker : public os::Thread {
    unsigned mode,slot;
public:
    Worker(unsigned kind,unsigned index=0):Thread("genuine-queue-worker"),mode(kind),slot(index) {}
    int32 Run() override
    {
        caribe_thread_request self = {}; self.abi=CARIBE_THREAD_ABI; self.operation=CARIBE_THREAD_SELF;
        check(raw(CARIBE_THREAD_ECALL,&self)==0 && self.cpu==0 && self.id>=0x40000000U,1);
        check(pthread_self()!=main_tcb && __errno_location()!=main_errno && errno==0,2);
        check(*caribe_tcb_initialized_address()==0x13579bdfU && *caribe_tcb_zero_address()==0,15);
        *caribe_tcb_initialized_address()=self.id; *caribe_tcb_zero_address()=self.id^0xa5a5a5a5U;
        tcbs[slot]=pthread_self();
        if(mode==0) {
            errno=(int)(100+slot);
            for(unsigned i=0;i<10000;i++) {
                check(queue->Lock(),3);
                check(__atomic_add_fetch(&active,1U,__ATOMIC_SEQ_CST)==1 && queue->IsEmpty(),4);
                queue->AddMessage(items[slot]);
                int32 value=0;
                check(queue->GetMessageCount()==1 && queue->FindMessage(0)==items[slot] &&
                      queue->FindMessage((int)(73+slot),0)==items[slot] &&
                      items[slot]->FindInt32("slot",&value)==0 && value==(int32)slot,5);
                if(!(i&31U)) yield();
                check(queue->NextMessage()==items[slot] && queue->IsEmpty() && queue->NextMessage()==NULL &&
                      errno==(int)(100+slot) && pthread_self()==tcbs[slot] &&
                      *caribe_tcb_initialized_address()==self.id && *caribe_tcb_zero_address()==(self.id^0xa5a5a5a5U),6);
                queue_cycles++;
                check(__atomic_sub_fetch(&active,1U,__ATOMIC_SEQ_CST)==0,7);
                queue->Unlock();
            }
            __atomic_add_fetch(&completed,1U,__ATOMIC_SEQ_CST); return 0;
        }
        check(close(-1)==-1 && errno==ENOTSUP,8);
        unsigned char buffer[8192]; uint32 code=0; size_t received=0;
        if(mode==1) {
            for(unsigned i=0;i<=10000;i++) {
                unsigned size=i==10000?8192:wire_size;
                check(get_msg_size(incoming)==size,9);
                check(caribe_get_message(incoming,&code,buffer,sizeof(buffer),-1,&received)==0 &&
                      code==i && received==size && !memcmp(buffer,i==10000?maximum:wire,size),10);
                check(send_msg_x(outgoing,code,buffer,(int)received,-1)==0,11);
            }
            return 0;
        }
        if(mode==2) {
            bigtime_t before=get_system_time();
            check(get_msg_x(incoming,&code,buffer,sizeof(buffer),2000)==-1 && errno==ETIMEDOUT &&
                  get_system_time()-before>=2000,12); return 0;
        }
        if(mode==3) {
            check(get_msg_x(waiter_ports[slot],&code,buffer,sizeof(buffer),-1)==-1 && errno==ENOENT,13);
            return 0;
        }
        if(mode==4) (void)get_msg_x(incoming,&code,buffer,sizeof(buffer),-1);
        else (void)send_msg_x(outgoing,0xbad,maximum,4,-1);
        check(false,14); return 14;
    }
};
static void gate_a()
{
    for(unsigned i=0;i<100;i++) {
        os::MessageQueue q; os::Message outsider;
        os::Message *a=new os::Message(7),*b=new os::Message(8),*c=new os::Message(7),*d=new os::Message(9);
        require(q.Lock() && q.IsEmpty(),"original Queue lock/empty");
        q.AddMessage(a); q.AddMessage(b); q.AddMessage(c);
        require(q.GetMessageCount()==3 && q.FindMessage(7,1)==c && q.FindMessage(-1)==NULL &&
                q.FindMessage(3)==NULL && !q.RemoveMessage(&outsider),"original Queue search");
        require(q.RemoveMessage(c),"remove tail"); q.AddMessage(d);
        require(q.FindMessage(2)==d && q.RemoveMessage(b) && q.RemoveMessage(a) && q.NextMessage()==d &&
                q.GetMessageCount()==0 && q.NextMessage()==NULL,"tail append/middle/head/FIFO");
        delete d;
        q.AddMessage(new os::Message(10)); require(q.RemoveMessage(q.FindMessage(0)),"remove only node");
        q.AddMessage(new os::Message(11)); require(q.GetMessageCount()==1,"append after empty tail");
        q.Unlock();
    }
    caribe_ipc_request r={}; r.abi=CARIBE_IPC_ABI^1; r.operation=CARIBE_IPC_STATS;
    require(raw(CARIBE_THREAD_IPC_ECALL,&r)==-EINVAL && raw(CARIBE_THREAD_IPC_ECALL,(void *)1)==-EFAULT,"native IPC input guards");
    puts("[syllable-queue-gate-A] original MessageQueue FIFO/search/remove/destructor; tail reuse cycles=100; native IPC guards PASS");
}
static void gate_b()
{
    uint32_t before=semaphores();
    {
        os::MessageQueue q; queue=&q; Worker *workers[16];
        for(unsigned i=0;i<16;i++) { items[i]=new os::Message(73+i); require(items[i]->AddInt32("slot",i)==0,"preallocated genuine Message"); workers[i]=new Worker(0,i); }
        errno=123;
        for(unsigned i=0;i<16;i++) workers[i]->Start();
        bigtime_t deadline=get_system_time()+120000000;
        while(__atomic_load_n(&completed,__ATOMIC_SEQ_CST)<16) { require(!failure && get_system_time()<deadline,"queue worker progress"); yield(); }
        for(unsigned i=0;i<16;i++) { workers[i]->WaitFor(); require(workers[i]->GetThreadId()==-1,"actual Queue worker reaping"); }
        require(!failure && queue_cycles==160000 && active==0 && q.IsEmpty() && errno==123 && pthread_self()==main_tcb,"exact Queue/TLS state");
        for(unsigned i=0;i<16;i++) {
            for(unsigned j=0;j<i;j++) require(tcbs[i]!=tcbs[j],"private worker TCBs");
            delete workers[i]; delete items[i];
        }
    }
    require(semaphores()==before,"Queue semaphore cleanup");
    puts("[syllable-queue-gate-B] workers=16 original Queue/typed Message cycles=160000 overlaps=0 cpu=0 independent TCBs; controller-only allocation PASS");
}
static void gate_c()
{
    caribe_ipc_request initial=ports();
    incoming=create_port("queue-native-input",1); outgoing=create_port("queue-native-output",1);
    require(incoming>0 && outgoing>0,"native worker ports");
    os::Message source(73); require(source.AddInt32("value",0x12345678)==0,"typed transport source");
    wire_size=source.GetFlattenedSize(); require(wire_size<sizeof(wire) && source.Flatten(wire,sizeof(wire))==0,"controller Message Flatten");
    for(unsigned i=0;i<sizeof(maximum);i++) maximum[i]=(unsigned char)(i*37U);
    {
        Worker echo(1); uint32_t blocks=ports().limit; echo.Start(); wait_blocks(blocks+1);
        unsigned char buffer[8192]; uint32 code; size_t received;
        for(unsigned i=0;i<=10000;i++) {
            unsigned size=i==10000?8192:wire_size;
            require(send_msg_x(incoming,i,i==10000?maximum:wire,size,-1)==0 &&
                    caribe_get_message(outgoing,&code,buffer,sizeof(buffer),-1,&received)==0 &&
                    code==i && received==size && !memcmp(buffer,i==10000?maximum:wire,size),"actual native port ping-pong");
            if(i<10000) { os::Message decoded; int32 value=0; require(decoded.Unflatten(buffer,received)==0 &&
                decoded.GetCode()==73 && decoded.FindInt32("value",&value)==0 && value==0x12345678,"controller bounded typed Message decode"); }
        }
        echo.WaitFor(); require(!failure,"native echo status");
    }
    uint32_t timed=ports().code;
    {
        Worker timeout(2);
        for(unsigned i=0;i<64;i++) { if(i) timeout.Initialize("queue-finite-timeout"); timeout.Start(); timeout.WaitFor(); require(!failure,"worker port deadline"); }
    }
    require(ports().code-timed>=64,"actual port timeout counters");
    {
        Worker *waiters[16]; port_id replacements[16]; uint32_t blocks=ports().limit;
        for(unsigned i=0;i<16;i++) { waiter_ports[i]=create_port("queue-generation",1); require(waiter_ports[i]>0,"waiter port"); waiters[i]=new Worker(3,i); }
        for(unsigned i=0;i<16;i++) waiters[i]->Start();
        wait_blocks(blocks+16);
        for(unsigned i=0;i<16;i++) {
            require(delete_port(waiter_ports[i])==0,"delete blocked port"); replacements[i]=create_port("queue-generation",1);
            require(replacements[i]>0 && replacements[i]!=waiter_ports[i] && send_msg_x(replacements[i],i,&i,sizeof(i),0)==0,"generation replacement token");
        }
        for(unsigned i=0;i<16;i++) {
            waiters[i]->WaitFor(); uint32 code=0,value=0;
            require(!failure && get_msg_x(replacements[i],&code,&value,sizeof(value),0)==0 && code==i && value==i &&
                    delete_port(replacements[i])==0,"old waiter cannot consume new port"); delete waiters[i];
        }
    }
    uint32 token=0xfeed1234; require(send_msg_x(outgoing,0xabc,&token,sizeof(token),0)==0,"full writer-cancellation queue");
    for(unsigned i=0;i<64;i++) {
        Worker cancel(i&1U?5:4); uint32_t blocks=ports().limit;
        cancel.Start(); wait_blocks(blocks+1); cancel.Terminate();
        port_info input,output;
        require(cancel.GetThreadId()==-1 && !failure && get_port_info(incoming,&input)==0 && get_port_info(outgoing,&output)==0 &&
                input.pi_cur_count==0 && output.pi_cur_count==1,"cancelled reader/writer preserves queues");
    }
    uint32 code=0,value=0;
    require(get_msg_x(outgoing,&code,&value,sizeof(value),0)==0 && code==0xabc && value==token &&
            delete_port(incoming)==0 && delete_port(outgoing)==0,"final original queue token and port cleanup");
    caribe_ipc_request final=ports();
    require(final.ports==initial.ports && final.messages==initial.messages &&
            final.limit-initial.limit==final.flags-initial.flags && final.limit>initial.limit,"actual IPC wait/wakeup balance");
    printf("[syllable-queue-gate-C] native worker ping-pong=10000 max-payload=8192; finite timeouts=64 elapsed>=2000us; stale waiters=16 cancelled readers/writers=64; waits=wakeups=%u resources restored PASS\n",final.limit-initial.limit);
}
int main(int argc,char **argv)
{
    char gate='C';
    if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1) gate=argv[2][0]; else if(argc!=1) return 2;
    if(gate<'A'||gate>'C') return 2;
    caribe_thread_request before=threads(); caribe_ipc_request ipc=ports(); uint32_t sema=semaphores();
    require(before.live==0,"no existing native workers"); main_tcb=pthread_self(); main_errno=__errno_location();
    gate_a(); require(caribe_syllable_threads_init()==0,"controller-owned thread pool");
    if(gate>='B') gate_b();
    if(gate>='C') gate_c();
    require(caribe_syllable_threads_shutdown()==0,"pool release after generic reaping");
    caribe_thread_request after=threads(); caribe_ipc_request final=ports();
    unsigned count=gate>='C'?161:gate>='B'?16:0, cancelled=gate>='C'?64:0;
    require(!failure && after.live==0 && after.created-before.created==count && after.exited-before.exited==count &&
            after.reaped-before.reaped==count && after.cancelled-before.cancelled==cancelled && after.faults==before.faults &&
            final.ports==ipc.ports && final.messages==ipc.messages && semaphores()==sema,"exact final resources");
    printf("[syllable-queue] created=reaped=%u cancelled=%u live=0 ports/messages/semaphores restored pool released PASS\n",count,cancelled);
    printf("[syllable-queue] gates A-%c PASS; genuine MessageQueue/native worker ports, not Looper/AppServer or threaded libc\n",gate);
    return 0;
}
