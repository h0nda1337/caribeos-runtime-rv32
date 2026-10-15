/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Bounded native port wakeups; local formatter, no worker shared stdio.
 */
#include "looper_runtime.h"
#include "cxx_context.h"
#include <atheos/msgport.h>
#include <atheos/threads.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
static caribe_context_mutex debug_mutex;
static char lines[16][256];
static unsigned read_pos,write_pos,count;
static uint32_t malformed,node_rejected,wake_sent,wake_full,debug_lines,debug_dropped;
void caribe_syllable_debug(const char *format,...)
{
    char line[256]={0}; int saved=errno; va_list ap;
    va_start(ap,format); (void)vsnprintf(line,sizeof(line),format,ap); va_end(ap);
    caribe_context_lock(&debug_mutex);
    if(count<16) { memcpy(lines[write_pos],line,sizeof(line)); write_pos=(write_pos+1U)%16U; count++; debug_lines++; }
    else debug_dropped++;
    caribe_context_unlock(&debug_mutex); errno=saved;
}
void caribe_looper_flush_debug(void)
{
    int saved=errno;
    /* Only the controller can perform ordinary Linux FD writes. */
    if(get_thread_id(NULL)!=get_process_id(NULL)) { errno=ENOTSUP; return; }
    for(;;) {
        char line[256];
        caribe_context_lock(&debug_mutex);
        if(!count) { caribe_context_unlock(&debug_mutex); break; }
        memcpy(line,lines[read_pos],sizeof(line)); read_pos=(read_pos+1U)%16U; count--;
        caribe_context_unlock(&debug_mutex);
        if(write(2,line,strlen(line))<0) return;
    }
    errno=saved;
}
void caribe_looper_wake(port_id port)
{
    int saved=errno;
    if(send_msg_x(port,CARIBE_LOOPER_WAKE,NULL,0,0)==0) __atomic_add_fetch(&wake_sent,1U,__ATOMIC_SEQ_CST);
    else if(errno==EAGAIN) __atomic_add_fetch(&wake_full,1U,__ATOMIC_SEQ_CST);
    else caribe_syllable_debug("Looper timer wake failed errno=%d\n",errno);
    errno=saved;
}
void caribe_looper_reject(int node)
{
    __atomic_add_fetch(node?&node_rejected:&malformed,1U,__ATOMIC_SEQ_CST);
}
void caribe_looper_statistics(caribe_looper_stats *s)
{
    s->malformed=__atomic_load_n(&malformed,__ATOMIC_SEQ_CST);
    s->node_rejected=__atomic_load_n(&node_rejected,__ATOMIC_SEQ_CST);
    s->wake_sent=__atomic_load_n(&wake_sent,__ATOMIC_SEQ_CST);
    s->wake_full=__atomic_load_n(&wake_full,__ATOMIC_SEQ_CST);
    s->debug_lines=__atomic_load_n(&debug_lines,__ATOMIC_SEQ_CST);
    s->debug_dropped=__atomic_load_n(&debug_dropped,__ATOMIC_SEQ_CST);
}
status_t rename_thread(thread_id id,const char *name)
{
    if(!name || !*name) { errno=EINVAL; return -1; }
    if(get_thread_proc(id)<0) return -1;
    /* Kernel debug-name storage is not implemented. Never report success. */
    errno=ENOTSUP; return -1;
}
