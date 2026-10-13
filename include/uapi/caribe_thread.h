/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Native raw-thread wire ABI; this is not a pthread or GNU TLS implementation.
 */
#ifndef CARIBE_NATIVE_THREAD_H
#define CARIBE_NATIVE_THREAD_H
#include <stdint.h>
#define CARIBE_THREAD_ABI 0x00010000U
#define CARIBE_THREAD_CALL 0xc0805401U
#define CARIBE_THREAD_ECALL 0x05000001U
#define CARIBE_THREAD_SYNC_ECALL 0x05000002U
#define CARIBE_THREAD_CREATE 1U
#define CARIBE_THREAD_START 2U
#define CARIBE_THREAD_JOIN 3U
#define CARIBE_THREAD_CANCEL 4U
#define CARIBE_THREAD_INFO 5U
#define CARIBE_THREAD_STATS 6U
#define CARIBE_THREAD_SELF 7U
#define CARIBE_THREAD_EXIT 8U
#define CARIBE_THREAD_YIELD 9U
#define CARIBE_THREAD_CLOCK 10U
#define CARIBE_THREAD_SLEEP 11U
/* CLOCK output only: reserved[0:1] contain monotonic nanoseconds, low/high.
   All reserved words must still be zero on input for every operation. */
#define CARIBE_THREAD_TIME_LOW 0U
#define CARIBE_THREAD_TIME_HIGH 1U
/* STATS output only: actual native sleep thread_block calls. */
#define CARIBE_THREAD_SLEEP_WAITS 2U
#define CARIBE_THREAD_MAX 16U
#define CARIBE_THREAD_SUSPENDED 2U
#define CARIBE_THREAD_RUNNING 3U
#define CARIBE_THREAD_EXITED 4U
#define CARIBE_THREAD_CANCELLED 125U
#define CARIBE_THREAD_FAULTED 14U
struct caribe_thread_request {
    uint32_t abi, operation, id, entry, argument, stack_base, stack_size, tp;
    uint32_t status, state, owner, cpu, timeout_us, live, created, reaped;
    uint32_t entered, exited, cancelled, faults, waits, preemptions, reserved[10];
};
typedef char caribe_thread_abi_size[(sizeof(struct caribe_thread_request) == 128) ? 1 : -1];
#endif
