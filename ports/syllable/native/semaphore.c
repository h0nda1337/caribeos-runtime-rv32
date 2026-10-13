/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original public Syllable counting API adapter to native XNU objects.
 * No Syllable kernel implementation or native user-thread support is implied.
 */
#include <atheos/semaphore.h>
#include <uapi/caribe_sync.h>
#ifdef CARIBE_SYNC_RAW_TCB
#include <uapi/caribe_thread.h>
#endif
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#ifdef CARIBE_SYNC_NATIVE_CLOCK
#include <atheos/time.h>
#endif
#include <unistd.h>

#ifndef CARIBE_SYNC_RAW_TCB
static int sync_fd = -1;
#endif
static struct caribe_sync_request request(uint32_t operation, sem_id id)
{
    struct caribe_sync_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_SYNC_ABI;
    arg.operation = operation;
    arg.id = (uint32_t)id;
    return arg;
}
static int call(struct caribe_sync_request *arg)
{
#ifdef CARIBE_SYNC_RAW_TCB
    register uintptr_t a0 __asm__("a0")=(uintptr_t)arg;
    register uintptr_t a7 __asm__("a7")=CARIBE_THREAD_SYNC_ECALL;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    if ((int32_t)a0<0) { errno=-(int32_t)a0; return -1; }
    return 0;
#else
    if (sync_fd < 0) sync_fd = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC);
    return sync_fd < 0 ? -1 : ioctl(sync_fd, CARIBE_SYNC_CALL, arg);
#endif
}
static int unsupported(void) { errno = ENOTSUP; return -1; }
sem_id create_semaphore(const char *name, int count, uint32 flags)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_CREATE, 0);
    if (flags & ~SEM_GLOBAL) return unsupported();
    if (count < 0 || !name || !*name || strlen(name) >= sizeof(arg.name)) {
        errno = EINVAL; return -1;
    }
    arg.value = (uint32_t)count;
    arg.flags = flags & SEM_GLOBAL ? CARIBE_SYNC_GLOBAL : 0;
    memcpy(arg.name, name, strlen(name) + 1);
    return call(&arg) ? -1 : (sem_id)arg.id;
}
status_t delete_semaphore(sem_id id)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_DELETE, id);
    return call(&arg);
}
static int now_us(uint64_t *result)
{
#ifdef CARIBE_SYNC_NATIVE_CLOCK
    bigtime_t now=get_system_time();
    if (now<0) return -1;
    *result=(uint64_t)now;
#else
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now)) return -1;
    *result = (uint64_t)now.tv_sec * 1000000U + (uint64_t)now.tv_nsec / 1000U;
#endif
    return 0;
}
status_t lock_semaphore_x(sem_id id, int count, uint32 flags, bigtime_t timeout)
{
    struct caribe_sync_request arg;
    uint64_t start = 0, elapsed = 0, now;
    int result, infinite = timeout == -1 || timeout == INFINITE_TIMEOUT;
    if (flags) return unsupported();
    if (count <= 0 || timeout < -1) { errno = EINVAL; return -1; }
    if (timeout > 0 && !infinite && now_us(&start)) return -1;
    do {
        arg = request(CARIBE_SYNC_ACQUIRE, id);
        arg.units = (uint32_t)count;
        if (timeout) {
            uint64_t remaining = infinite ? 60000000U : (uint64_t)timeout - elapsed;
            arg.flags = CARIBE_SYNC_WAIT;
            arg.timeout_low = (uint32_t)(remaining > 60000000U ? 60000000U : remaining);
        }
        result = call(&arg);
        if (result < 0 && errno == ETIMEDOUT && timeout > 0 && !infinite) {
            if (now_us(&now)) return -1;
            elapsed = now - start;
        }
    } while (result < 0 && errno == ETIMEDOUT && (infinite || elapsed < (uint64_t)timeout));
    return result;
}
status_t raw_lock_semaphore_x(sem_id id, int count, uint32 flags, const bigtime_t *timeout)
{
    return lock_semaphore_x(id, count, flags, timeout ? *timeout : -1);
}
status_t lock_semaphore(sem_id id) { return lock_semaphore_x(id, 1, 0, -1); }
status_t lock_mutex(sem_id id, bool ignore_signals)
{
    int result;
    do { result = lock_semaphore(id); } while (result < 0 && errno == EINTR && ignore_signals);
    return result;
}
status_t unlock_semaphore_x(sem_id id, int count, uint32 flags)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_RELEASE, id);
    if (flags) return unsupported();
    if (count <= 0) { errno = EINVAL; return -1; }
    arg.units = (uint32_t)count;
    return call(&arg);
}
status_t unlock_semaphore(sem_id id) { return unlock_semaphore_x(id, 1, 0); }
status_t unlock_mutex(sem_id id) { return unlock_semaphore(id); }
status_t get_semaphore_info(sem_id id, proc_id owner, sem_info *info)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_INFO, id);
    if (!info) { errno = EINVAL; return -1; }
    if (call(&arg)) return -1;
    if (owner >= 0 && owner != (proc_id)arg.owner) { errno = EINVAL; return -1; }
    memset(info, 0, sizeof(*info));
    info->si_sema_id = id;
    info->si_owner = (proc_id)arg.owner;
    info->si_count = (int32)arg.value;
    info->si_latest_holder = arg.holder ? (thread_id)arg.holder : -1;
    memcpy(info->si_name, arg.name, sizeof(info->si_name));
    return 0;
}
int get_semaphore_count(sem_id id)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_INFO, id);
    return call(&arg) ? -1 : (int)arg.value;
}
/* These APIs require policies not present in the counting-only profile. */
status_t sleep_on_sem(sem_id id, bigtime_t timeout) { (void)id; (void)timeout; return unsupported(); }
status_t wakeup_sem(sem_id id, bool all) { (void)id; (void)all; return unsupported(); }
status_t unlock_and_suspend(sem_id wait, sem_id id) { (void)wait; (void)id; return unsupported(); }
status_t get_next_semaphore_info(sem_info *info) { (void)info; return unsupported(); }
thread_id get_semaphore_owner(sem_id id) { (void)id; return unsupported(); }
int is_semaphore_locked(sem_id id) { (void)id; return unsupported(); }
