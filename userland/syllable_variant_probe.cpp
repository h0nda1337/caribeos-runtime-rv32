/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original Variant/Message values needed by real Syllable GUI controls.
 */
#include <util/variant.h>
#include <util/message.h>
#include <util/messenger.h>
#include <util/looper.h>
#include <util/thread.h>
#include <atheos/time.h>
#include <atheos/msgport.h>
#include <uapi/caribe_thread.h>
#include <uapi/caribe_ipc.h>
#include "heap_runtime.h"
#include "thread_runtime.h"
#include "looper_runtime.h"
#include <errno.h>
#include <new>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

static uint8 vectors[19][512];
static size_t sizes[19];
static unsigned vector_count;
static volatile unsigned inject_array_failure,injections,failure,done,cycles,handled,started;
extern "C" void *__real__Znaj(size_t);
extern "C" void *__wrap__Znaj(size_t size)
{
    if(__atomic_exchange_n(&inject_array_failure,0U,__ATOMIC_SEQ_CST)){
        __atomic_add_fetch(&injections,1U,__ATOMIC_SEQ_CST);throw std::bad_alloc();
    }
    return __real__Znaj(size);
}
static int raw(uint32_t number,void *request)
{
    register uintptr_t a0 __asm__("a0")=(uintptr_t)request,a7 __asm__("a7")=number;
    __asm__ volatile("ecall":"+r"(a0):"r"(a7):"a1","memory");return (int32_t)a0;
}
static void require(bool ok,const char *label)
{
    if(!ok){caribe_looper_flush_debug();fprintf(stderr,"[syllable-variant] FAIL %s worker=%u errno=%d\n",label,__atomic_load_n(&failure,__ATOMIC_SEQ_CST),errno);exit(1);}
}
static void check(bool ok,unsigned code)
{
    if(!ok){__atomic_store_n(&failure,code,__ATOMIC_SEQ_CST);exit_thread(code);}
}
static void yield()
{
    caribe_thread_request r={};r.abi=CARIBE_THREAD_ABI;r.operation=CARIBE_THREAD_YIELD;
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"actual native yield");
}
static void wait_value(volatile unsigned *p,unsigned count)
{
    bigtime_t limit=get_system_time()+180000000;
    while(__atomic_load_n(p,__ATOMIC_SEQ_CST)!=count){require(!__atomic_load_n(&failure,__ATOMIC_SEQ_CST) && get_system_time()<limit,"callback progress");yield();}
}
static caribe_thread_request stats()
{
    caribe_thread_request r={};r.abi=CARIBE_THREAD_ABI;r.operation=CARIBE_THREAD_STATS;
    require(raw(CARIBE_THREAD_ECALL,&r)==0,"thread statistics");return r;
}
static uint32 load(const uint8 *p){uint32 value;memcpy(&value,p,4);return value;}
static void put(uint8 *p,uint32 value){memcpy(p,&value,4);}
static int controller_guard_mprotect(void *page)
{
    // The bounded native allocator channel deliberately excludes PROT_NONE.
    // No workers are live here; use the existing controller Linux VM contract.
    register uintptr_t a0 __asm__("a0")=(uintptr_t)page,a1 __asm__("a1")=4096;
    register uintptr_t a2 __asm__("a2")=PROT_NONE,a7 __asm__("a7")=226;
    __asm__ volatile("ecall":"+r"(a0),"+r"(a1):"r"(a2),"r"(a7):"memory");
    return (int32_t)a0;
}
static void capture(const os::Variant &value,os::type_code type,size_t expected)
{
    require(vector_count<19 && value.GetFlattenedSize()==expected && expected<512,"golden wire size");
    uint8 *wire=vectors[vector_count];sizes[vector_count++]=expected;
    require(value.Flatten(wire,expected)==0 && load(wire)==(uint32)type,"original flatten status/type");
    for(unsigned offset=0;offset<4;offset++){
        uint8 unaligned[520],back[520];memcpy(unaligned+offset,wire,expected);
        os::Variant decoded(os::String("old payload"));
        require(decoded.Unflatten(unaligned+offset,expected)==0 && decoded.GetFlattenedSize()==expected &&
                decoded.Flatten(back+offset,expected)==0 && !memcmp(wire,back+offset,expected),"exact unaligned original roundtrip");
    }
}
static void gate_a()
{
    static_assert(sizeof(os::Variant)==16,"original RV32 class layout");
    capture(os::Variant(),os::T_ANY_TYPE,4);capture(os::Variant((void*)NULL),os::T_POINTER,8);
    os::Variant small;small.SetInt8(-7);capture(small,os::T_INT8,8);require(load(vectors[2]+4)==0xfffffff9U,"legacy sign-extended int8 wire");
    small.SetInt16(-300);capture(small,os::T_INT16,8);require(load(vectors[3]+4)==0xfffffed4U,"legacy sign-extended int16 wire");
    capture(os::Variant(-1234567),os::T_INT32,8);
    capture(os::Variant((int64)-1234567890123456LL),os::T_INT64,12);
    capture(os::Variant(false),os::T_BOOL,5);capture(os::Variant(true),os::T_BOOL,5);
    capture(os::Variant(1.25f),os::T_FLOAT,8);require(load(vectors[8]+4)==0x3fa00000U,"IEEE float wire without F extension");
    capture(os::Variant(-1.25),os::T_DOUBLE,12);require(load(vectors[9]+4)==0 && load(vectors[9]+8)==0xbff40000U,"IEEE double wire without D extension");
    capture(os::Variant(os::String("hola")),os::T_STRING,13);require(load(vectors[10]+4)==5,"string length prefix");
    capture(os::Variant(os::Point(1.5f,-2.5f)),os::T_POINT,12);capture(os::Variant(os::IPoint(-7,8)),os::T_IPOINT,12);
    capture(os::Variant(os::Rect(1,2,30,40)),os::T_RECT,20);capture(os::Variant(os::IRect(-1,-2,30,40)),os::T_IRECT,20);
    capture(os::Variant(os::Color32(1,2,3,255)),os::T_COLOR32,8);
    uint8 data[5]={1,2,3,4,5};capture(os::Variant(data,5),os::T_RAW,13);capture(os::Variant((void*)NULL,0),os::T_RAW,8);
    require(load(vectors[16]+4)==5 && !memcmp(vectors[16]+8,data,5),"raw length prefix and payload");
    os::Message message(33);require(message.AddInt32("x",7)==0 && message.GetFlattenedSize()==61,"nested original Message wire");
    capture(os::Variant(message),os::T_MESSAGE,69);require(load(vectors[18]+4)==61 && load(vectors[18]+8)==61,"nested Message length prefix");
    size_t total=0;for(unsigned i=0;i<19;i++)total+=sizes[i];require(total==253,"exact golden prefix count");
    os::Variant a(os::String("owned string"));a=a;require(a.AsString()=="owned string","self assignment retained");
    os::Variant b(a);a.SetInt32(5);require(b.AsString()=="owned string","deep string copy");
    a.SetRaw(data,5);size_t size=0;void *alias=a.AsRaw(&size);a.SetRaw(alias,(int)size);
    require(size==5 && !memcmp(a.AsRaw(&size),data,5),"raw setter alias copied before release");
    require(a.AsRaw(NULL)==NULL && errno==EINVAL,"raw output argument guard");
    require(os::Variant((int64)-1234567890123456LL).AsString()=="-1234567890123456" &&
            os::Variant(os::String("-1234567890123456")).AsInt64()==(int64)-1234567890123456LL,"genuine portable int64 conversion");
    puts("[syllable-variant-gate-A] original class ABI=16 vectors=19 offsets=4 exact-roundtrips=76 canonical wire; deep-copy self/alias and int64 conversions PASS");
}
static void gate_b()
{
    uint8 *pages=(uint8*)mmap(NULL,12288,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
    require(stats().live==0 && pages!=MAP_FAILED && controller_guard_mprotect(pages+8192)==0,"actual controller-only unmapped-access guard page");
    unsigned truncated=0;
    for(unsigned i=0;i<19;i++)for(size_t length=0;length<sizes[i];length++){
        uint8 *end=pages+8192-length;if(length)memcpy(end,vectors[i],length);
        os::Variant value(os::String("sentinel"));
        require(value.Unflatten(end,length)==-1 && errno==EINVAL && value.AsString()=="sentinel","all guarded prefixes preserve prior value");++truncated;
    }
    require(truncated==253,"all truncations actually executed");
    unsigned accepted=0,rejected=0;uint32 random=0x1729abcU;
    for(unsigned i=0;i<4096;i++){
        unsigned index=i%19;uint8 bytes[520]={};memcpy(bytes,vectors[index],sizes[index]);
        random=random*1664525U+1013904223U;size_t length=(i&3)?sizes[index]:random%(sizes[index]+2);
        if(length)bytes[(random>>8)%length]^=(uint8)(1U<<((random>>16)&7));
        uint8 *end=pages+8192-length;if(length)memcpy(end,bytes,length);
        os::Variant value(os::String("sentinel"));int result=value.Unflatten(end,length);
        if(result==0){uint8 back[520];require(value.GetFlattenedSize()==length && value.Flatten(back,length)==0 && !memcmp(back,bytes,length),"accepted fuzz canonical roundtrip");++accepted;}
        else{require(errno==EINVAL && value.AsString()=="sentinel","rejected fuzz retained state");++rejected;}
    }
    require(accepted && rejected && accepted+rejected==4096,"both fuzz paths executed");
    uint8 nested[2048];memcpy(nested,vectors[4],8);size_t length=8;
    for(unsigned depth=1;depth<=9;depth++){
        os::Message m(44);require(m.AddData("v",os::T_VARIANT,nested,length,false)==0,"adversarial nested bytes");
        uint8 next[2048];size_t bytes=m.GetFlattenedSize();put(next,os::T_MESSAGE);put(next+4,bytes);require(m.Flatten(next+8,bytes)==0,"nested original Message encoding");
        length=bytes+8;memcpy(nested,next,length);os::Variant value(os::String("sentinel"));
        int result=value.Unflatten(nested,length);
        require(depth<=8 ? result==0 : result==-1 && errno==EINVAL && value.AsString()=="sentinel","combined Message/Variant depth budget");
        if(depth==8){os::Message target;require(target.AddVariant("too-deep",value)==-1 && errno==EINVAL && target.CountNames()==0,"typed insertion includes parent depth");}
    }
    os::Variant pointer((void*)0x12345678U);uint8 untouched[16];memset(untouched,0xa5,sizeof(untouched));
    require(pointer.AsPointer()==(void*)0x12345678U && pointer.Flatten(untouched,sizeof(untouched))==-1 && errno==ENOTSUP && untouched[0]==0xa5,"local pointer supported but not serialized");
    os::Message target;require(target.AddInt32("keep",7)==0 && target.AddVariant("pointer",pointer)==-1 && errno==ENOTSUP && target.CountNames()==1,"failed typed addition does not mutate Message");
    os::Variant original(os::String("sentinel")),replacement(os::String("replacement"));
    __atomic_store_n(&inject_array_failure,1U,__ATOMIC_SEQ_CST);try{original=replacement;require(false,"copy OOM not injected");}catch(const std::bad_alloc&){}
    require(original.AsString()=="sentinel" && !inject_array_failure,"copy OOM retained original");
    __atomic_store_n(&inject_array_failure,1U,__ATOMIC_SEQ_CST);try{original.SetString(os::String("new"));require(false,"setter OOM not injected");}catch(const std::bad_alloc&){}
    require(original.AsString()=="sentinel" && !inject_array_failure,"setter OOM retained original");
    __atomic_store_n(&inject_array_failure,1U,__ATOMIC_SEQ_CST);require(original.Unflatten(vectors[10],sizes[10])==-1 && errno==ENOMEM && original.AsString()=="sentinel","decoder OOM rollback");
    __atomic_store_n(&inject_array_failure,1U,__ATOMIC_SEQ_CST);require(target.AddVariant("oom",replacement)==-1 && errno==ENOMEM && target.CountNames()==1,"typed insertion OOM rollback");
    require(target.AddVariant("value",replacement)==0,"valid typed insertion");
    __atomic_store_n(&inject_array_failure,1U,__ATOMIC_SEQ_CST);require(target.FindVariant("value",&original)==-1 && errno==ENOMEM && original.AsString()=="sentinel","typed lookup OOM rollback");
    require(injections==5 && !inject_array_failure && munmap(pages,12288)==0,"exact fault injection and VM cleanup");
    puts("[syllable-variant-gate-B] guard-page truncations=253 deterministic fuzz=4096 shared depth=16; pointer wire denied; allocation failures=5 prior Variant/Message retained PASS");
}
class Worker : public os::Thread {
public:
    Worker():Thread("genuine-variant-worker"){}
    int32 Run() override {
        caribe_thread_request self={};self.abi=CARIBE_THREAD_ABI;self.operation=CARIBE_THREAD_SELF;
        check(raw(CARIBE_THREAD_ECALL,&self)==0 && self.cpu==0,1);
        for(unsigned i=0;i<10000;i++){
            unsigned index=i%19;os::Variant value,copy;uint8 bytes[512],back[512];
            check(value.Unflatten(vectors[index],sizes[index])==0,2);copy=value;copy=copy;
            os::Message m(66),decoded;check(m.AddVariant("value",copy)==0,3);size_t length=m.GetFlattenedSize();
            check(length<512 && m.Flatten(bytes,length)==0 && decoded.Unflatten(bytes,length)==0 && decoded.FindVariant("value",&copy)==0 &&
                  copy.GetFlattenedSize()==sizes[index] && copy.Flatten(back,sizes[index])==0 && !memcmp(back,vectors[index],sizes[index]),4);
            __atomic_add_fetch(&cycles,1U,__ATOMIC_SEQ_CST);
        }
        __atomic_add_fetch(&done,1U,__ATOMIC_SEQ_CST);return 0;
    }
};
class Loop : public os::Looper {
public:
    Loop():Looper("genuine-variant-service",NORMAL_PRIORITY,2){}
    void Started() override {__atomic_add_fetch(&started,1U,__ATOMIC_SEQ_CST);}
};
class Echo : public os::Handler {
public:
    Echo():Handler("original-typed-value-reply"){}
    void HandleMessage(os::Message *m) override {
        os::Variant value;int32 sequence=-1;
        check(GetLooper()->IsLocked() && m->IsSourceRemote() && m->IsSourceWaiting() && m->FindVariant("value",&value)==0 && m->FindInt32("seq",&sequence)==0 && sequence==(int32)handled,5);
        os::Message reply(77);check(reply.AddVariant("value",value)==0 && reply.AddInt32("seq",sequence)==0 && m->SendReply(&reply)==0,6);
        __atomic_add_fetch(&handled,1U,__ATOMIC_SEQ_CST);
    }
};
static int peer(const char *name)
{
    require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"peer native heap/pool");port_id control=find_port(name);require(control>0,"peer control discovery");
    Loop *loop=new Loop;Echo echo;loop->AddHandler(&echo);loop->SetDefaultHandler(&echo);port_id port=loop->GetMsgPort();
    require(make_port_public(port)==0 && loop->Run()>0,"original typed service Run");wait_value(&started,1);
    require(send_msg_x(control,91,&port,sizeof(port),10000000)==0,"peer actual ready handoff");wait_value(&handled,10000);loop->Terminate();
    require(echo.GetLooper()==NULL && caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"peer actual reaping/teardown");
    uint32 result=0;require(send_msg_x(control,92,&result,4,10000000)==0,"peer completed");return 0;
}
static void cross_before_workers()
{
    char name[48];snprintf(name,sizeof(name),"variant-control-%u",(unsigned)getpid());port_id control=create_port(name,2);
    require(control>0 && make_port_public(control)==0,"public control");pid_t child=fork();require(child>=0,"real fork");
    if(child==0){execl("/bin/syllable-variant-probe","syllable-variant-probe","--server",name,(char*)NULL);_exit(127);}
    uint32 code=0;port_id port=-1;require(get_msg_x(control,&code,&port,sizeof(port),10000000)==0 && code==91,"independent exec service ready");os::Messenger target(port);
    for(unsigned i=0;i<10000;i++){
        unsigned index=i%19;os::Variant value,back;os::Message request(66),reply;
        require(value.Unflatten(vectors[index],sizes[index])==0 && request.AddVariant("value",value)==0 && request.AddInt32("seq",i)==0,"actual typed request");
        require(target.SendMessage(&request,&reply,1000000,1000000)==0 && reply.IsReply() && reply.GetCode()==77 && reply.FindVariant("value",&back)==0,"original remote typed reply");
        uint8 bytes[512];int32 sequence=-1;require(reply.FindInt32("seq",&sequence)==0 && sequence==(int32)i && back.Flatten(bytes,sizes[index])==0 && !memcmp(bytes,vectors[index],sizes[index]),"remote original typed bytes and sequence");
    }
    uint32 result=1;require(get_msg_x(control,&code,&result,4,10000000)==0 && code==92 && result==0,"peer completed cleanup");int status=-1;
    require(waitpid(child,&status,0)==child && WIFEXITED(status) && WEXITSTATUS(status)==0 && delete_port(control)==0,"real child exit(0)/reaping");
    puts("[syllable-variant-cross] independent fork/exec original Looper/Messenger typed request/reply=10000 value families=19 child exit(0) PASS");
}
static void gate_c()
{
    caribe_thread_request before=stats();Worker *workers[16];for(unsigned i=0;i<16;i++)workers[i]=new Worker;
    for(unsigned i=0;i<16;i++)workers[i]->Start();wait_value(&done,16);
    for(unsigned i=0;i<16;i++){workers[i]->WaitFor();delete workers[i];}
    caribe_thread_request after=stats();require(cycles==160000 && after.live==0 && after.created-before.created==16 && after.reaped-before.reaped==16 &&
      after.faults==before.faults && after.cancelled==before.cancelled && after.reserved[CARIBE_THREAD_HEAP_ACTIVE]==0 && after.reserved[CARIBE_THREAD_HEAP_WAITERS]==0,"exact native worker/value lifecycle");
    puts("[syllable-variant-gate-C] workers=16 typed Variant/Message cycles=160000 cpu=0 created=reaped=16 faults=0 active-scopes=0 waiters=0; cross-exec replies=10000 PASS");
}
int main(int argc,char **argv)
{
    if(argc==3 && !strcmp(argv[1],"--server"))return peer(argv[2]);
    char gate='C';if(argc==3 && !strcmp(argv[1],"--gate") && strlen(argv[2])==1)gate=argv[2][0];else if(argc!=1)return 2;if(gate<'A'||gate>'C')return 2;
    gate_a();if(gate=='C')cross_before_workers();require(caribe_heap_init()==0 && caribe_syllable_threads_init()==0,"native allocator/pool activation");
    if(gate>='B')gate_b();if(gate=='C')gate_c();
    require(caribe_syllable_threads_shutdown()==0 && caribe_heap_shutdown()==0,"native pool/heap shutdown");
    printf("[syllable-variant] gates A-%c PASS; original GUI typed values, not complete Application/AppServer/Desktop\n",gate);return 0;
}
