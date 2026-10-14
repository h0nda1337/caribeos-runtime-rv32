/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original Syllable API adapter to XNU native ports, not AtheOS kernel code.
 */
#include <atheos/msgport.h>
#include "message_io.h"
#include <uapi/caribe_ipc.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#ifdef CARIBE_IPC_RAW_THREAD
#include <uapi/caribe_thread.h>
#include <atheos/time.h>
#else
static int ipc_fd = -1;
#endif
static struct caribe_ipc_request request(uint32_t op, port_id id)
{
    struct caribe_ipc_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_IPC_ABI;
    arg.operation = op;
    arg.id = (uint32_t)id;
    return arg;
}
static int call(struct caribe_ipc_request *arg)
{
#ifdef CARIBE_IPC_RAW_THREAD
    register uintptr_t a0 __asm__("a0") = (uintptr_t)arg;
    register uintptr_t a7 __asm__("a7") = CARIBE_THREAD_IPC_ECALL;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    if ((int32_t)a0 < 0) { errno = -(int32_t)a0; return -1; }
    return 0;
#else
    if (ipc_fd < 0) ipc_fd = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC);
    return ipc_fd < 0 ? -1 : ioctl(ipc_fd, CARIBE_IPC_CALL, arg);
#endif
}
static int set_name(struct caribe_ipc_request *arg, const char *name)
{
    if (!name || !*name || strlen(name) >= sizeof(arg->name)) {
        errno = EINVAL;
        return -1;
    }
    memcpy(arg->name, name, strlen(name) + 1);
    return 0;
}
port_id create_port(const char *const name, int limit)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_CREATE, 0);
    arg.limit = (uint32_t)limit;
    if (set_name(&arg, name) || call(&arg)) return -1;
    return (port_id)arg.id;
}
status_t delete_port(port_id id)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_DELETE, id);
    return call(&arg);
}
static int transfer(port_id id, uint32_t code, void *buffer, int size,
    bigtime_t timeout, int sending, uint32_t *received_code, size_t *received_size)
{
    struct caribe_ipc_request arg;
    int result;
#ifdef CARIBE_IPC_RAW_THREAD
    bigtime_t now;
#else
    struct timespec now;
#endif
    uint64_t start = 0, elapsed = 0;
    int infinite = timeout == -1 || timeout == INFINITE_TIMEOUT;
    if (size < 0 || timeout < -1) { errno = EINVAL; return -1; }
    if (!sending && received_code && ((uintptr_t)received_code & 3U)) {
        errno = EINVAL; return -1;
    }
    if (timeout > 0 && !infinite) {
#ifdef CARIBE_IPC_RAW_THREAD
        now = get_system_time();
        if (now < 0) return -1;
        start = (uint64_t)now;
#else
        if (clock_gettime(CLOCK_MONOTONIC, &now)) return -1;
        start = (uint64_t)now.tv_sec * 1000000U + (uint64_t)now.tv_nsec / 1000U;
#endif
    }
    do {
        arg = request(sending ? CARIBE_IPC_SEND : CARIBE_IPC_RECEIVE, id);
        arg.code = code;
        arg.size = (uint32_t)size;
        arg.buffer = (uint32_t)(uintptr_t)buffer;
        if (timeout != 0) {
            uint64_t remaining = infinite ? 60000000U : (uint64_t)timeout - elapsed;
            uint32_t bounded = remaining > 60000000U ? 60000000U : (uint32_t)remaining;
            arg.flags = CARIBE_IPC_WAIT;
            arg.timeout_low = (uint32_t)bounded;
        }
        result = call(&arg);
        if (result < 0 && errno == ETIMEDOUT && timeout > 0 && !infinite) {
#ifdef CARIBE_IPC_RAW_THREAD
            now = get_system_time();
            if (now < 0) return -1;
            elapsed = (uint64_t)now - start;
#else
            if (clock_gettime(CLOCK_MONOTONIC, &now)) return -1;
            elapsed = (uint64_t)now.tv_sec * 1000000U + (uint64_t)now.tv_nsec / 1000U - start;
#endif
        }
    } while (result < 0 && errno == ETIMEDOUT && (infinite || elapsed < (uint64_t)timeout));
    if (!result && !sending && received_code) *received_code = arg.code;
    if (!result && !sending && received_size) *received_size = arg.size;
    return result;
}
status_t send_msg_x(port_id id, uint32 code, const void *buffer, int size, bigtime_t timeout)
{
    return transfer(id, code, (void *)buffer, size, timeout, 1, 0, 0);
}
status_t get_msg_x(port_id id, uint32 *code, void *buffer, int size, bigtime_t timeout)
{
    return transfer(id, 0, buffer, size, timeout, 0, code, 0);
}
status_t caribe_get_message(port_id id, uint32 *code, void *buffer,
    int capacity, bigtime_t timeout, size_t *received_size)
{
    if (!received_size) { errno = EINVAL; return -1; }
    return transfer(id, 0, buffer, capacity, timeout, 0, code, received_size);
}
status_t send_msg(port_id id, uint32 code, const void *buffer, int size)
{
    return send_msg_x(id, code, buffer, size, -1);
}
status_t get_msg(port_id id, uint32 *code, void *buffer, int size)
{
    return get_msg_x(id, code, buffer, size, -1);
}
status_t raw_send_msg_x(port_id id, uint32 code, const void *buffer, int size, const bigtime_t *timeout)
{
    return send_msg_x(id, code, buffer, size, timeout ? *timeout : -1);
}
status_t raw_get_msg_x(port_id id, uint32 *code, void *buffer, int size, const bigtime_t *timeout)
{
    return get_msg_x(id, code, buffer, size, timeout ? *timeout : -1);
}
status_t get_port_info(port_id id, port_info *info)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_INFO, id);
    if (!info) { errno = EINVAL; return -1; }
    if (call(&arg)) return -1;
    memset(info, 0, sizeof(*info));
    info->pi_port_id = id;
    info->pi_owner = (proc_id)arg.owner;
    info->pi_flags = arg.code ? MSG_PORT_PUBLIC : 0;
    info->pi_max_count = (int)arg.limit;
    info->pi_cur_count = (int)arg.queued;
    memcpy(info->pi_name, arg.name, sizeof(info->pi_name));
    return 0;
}
status_t get_next_port_info(port_info *info)
{
    struct caribe_ipc_request arg;
    if (!info) { errno = EINVAL; return -1; }
    arg = request(CARIBE_IPC_ENUM, info->pi_port_id);
    if (call(&arg)) return -1;
    if (!arg.code) return 0;
    memset(info, 0, sizeof(*info));
    info->pi_port_id = (port_id)arg.id;
    info->pi_owner = (proc_id)arg.owner;
    info->pi_flags = arg.messages ? MSG_PORT_PUBLIC : 0;
    info->pi_max_count = (int)arg.limit;
    info->pi_cur_count = (int)arg.queued;
    memcpy(info->pi_name, arg.name, sizeof(info->pi_name));
    return 1;
}
static int visibility(port_id id, uint32_t public_port)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_PUBLIC, id);
    arg.code = public_port;
    return call(&arg);
}
status_t make_port_public(port_id id) { return visibility(id, 1); }
status_t make_port_private(port_id id) { return visibility(id, 0); }
port_id find_port(const char *name)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_FIND, 0);
    if (set_name(&arg, name) || call(&arg)) return -1;
    return (port_id)arg.id;
}
size_t get_msg_size(port_id id)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_PEEK, id);
    int result;
    arg.flags = CARIBE_IPC_WAIT;
    arg.timeout_low = 60000000U;
    do { result = call(&arg); } while (result < 0 && errno == ETIMEDOUT);
    return result ? (size_t)-1 : arg.size;
}
int set_app_server_port(port_id id)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_SET_SERVER, id);
    return call(&arg);
}
port_id get_app_server_port(void)
{
    struct caribe_ipc_request arg = request(CARIBE_IPC_GET_SERVER, 0);
    return call(&arg) ? -1 : (port_id)arg.id;
}
