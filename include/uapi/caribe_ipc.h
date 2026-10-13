/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original CaribeOS fixed-width native message port ABI.
 */
#ifndef CARIBE_NATIVE_IPC_H
#define CARIBE_NATIVE_IPC_H
#include <stdint.h>
#define CARIBE_IPC_ABI 0x00010000U
#define CARIBE_IPC_CALL 0xc0804901U
#define CARIBE_IPC_CREATE 1U
#define CARIBE_IPC_DELETE 2U
#define CARIBE_IPC_SEND 3U
#define CARIBE_IPC_RECEIVE 4U
#define CARIBE_IPC_PEEK 5U
#define CARIBE_IPC_FIND 6U
#define CARIBE_IPC_PUBLIC 7U
#define CARIBE_IPC_INFO 8U
#define CARIBE_IPC_STATS 9U
#define CARIBE_IPC_SET_SERVER 10U
#define CARIBE_IPC_GET_SERVER 11U
#define CARIBE_IPC_ENUM 12U
#define CARIBE_IPC_WAIT 1U
#define CARIBE_IPC_MAX_PORTS 32U
#define CARIBE_IPC_MAX_MESSAGES 64U
#define CARIBE_IPC_MAX_PAYLOAD 8192U
#define CARIBE_IPC_MAX_QUEUE 32U
struct caribe_ipc_request {
    uint32_t abi, operation, id, code, buffer, size, limit, flags;
    uint32_t owner, queued, ports, messages, sends, receives;
    uint32_t timeout_low, timeout_high;
    char name[64];
};
typedef char caribe_ipc_abi_size[(sizeof(struct caribe_ipc_request) == 128) ? 1 : -1];
#endif
