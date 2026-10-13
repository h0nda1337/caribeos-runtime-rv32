/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original integration using unmodified musl ABI and __copy_tls.
 */
#include "tcb_bootstrap.h"
#include <errno.h>
#include <string.h>
#include "pthread_impl.h"
int caribe_musl_raw_tcb_prepare(void *reserve,size_t bytes,uintptr_t *tp)
{
    pthread_t td,main=__pthread_self();
    uintptr_t start=(uintptr_t)reserve,end;
    if (!reserve || !tp || (start&15U) || bytes<libc.tls_size || bytes>4096U || start>UINTPTR_MAX-bytes) {
        errno=EINVAL; return -1;
    }
    end=start+bytes;
    memset(reserve,0,bytes);
    td=__copy_tls(reserve);
    if ((uintptr_t)td<start || (uintptr_t)TP_ADJ(td)>end-16U || ((uintptr_t)TP_ADJ(td)&15U)) {
        errno=ENOTSUP; return -1;
    }
    /* These raw TCBs deliberately do not enter musl's pthread list. */
    td->self=td; td->locale=&libc.global_locale; td->canary=main->canary;
    td->robust_list.head=&td->robust_list.head; td->sysinfo=main->sysinfo;
    *tp=(uintptr_t)TP_ADJ(td);
    return 0;
}
