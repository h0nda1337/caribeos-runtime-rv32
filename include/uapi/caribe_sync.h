/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original CaribeOS fixed-width native counting semaphore ABI.
 */
#ifndef CARIBE_NATIVE_SYNC_H
#define CARIBE_NATIVE_SYNC_H
#include <stdint.h>
#define CARIBE_SYNC_ABI 0x00010000U
#define CARIBE_SYNC_CALL 0xc0805301U
#define CARIBE_SYNC_CREATE 1U
#define CARIBE_SYNC_DELETE 2U
#define CARIBE_SYNC_ACQUIRE 3U
#define CARIBE_SYNC_RELEASE 4U
#define CARIBE_SYNC_INFO 5U
#define CARIBE_SYNC_STATS 6U
#define CARIBE_SYNC_WAIT 1U
#define CARIBE_SYNC_GLOBAL 2U
#define CARIBE_SYNC_MAX_OBJECTS 64U
#define CARIBE_SYNC_MAX_VALUE 0x7fffffffU
struct caribe_sync_request {
    uint32_t abi, operation, id, units, value, flags, owner, holder;
    uint32_t timeout_low, timeout_high, live, waits, wakes, timeouts, acquires, releases;
    char name[64];
};
typedef char caribe_sync_abi_size[(sizeof(struct caribe_sync_request) == 128) ? 1 : -1];
#endif
