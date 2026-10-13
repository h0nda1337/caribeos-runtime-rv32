/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Real native XNU scheduler waits, process ownership and shared memory gates.
 */
#define _GNU_SOURCE
#include <atheos/semaphore.h>
#include <atheos/areas.h>
#include <atheos/msgport.h>
#include <uapi/caribe_sync.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    printf("[native-sync] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
#define ROUNDS 10000U
#define RW (AREA_READ | AREA_WRITE)
static int control;
static volatile sig_atomic_t signals;
struct packet { uint32_t sequence, value, answer, guard; };
static struct caribe_sync_request request(uint32_t operation)
{
    struct caribe_sync_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_SYNC_ABI;
    arg.operation = operation;
    return arg;
}
static struct caribe_sync_request stats(void)
{
    struct caribe_sync_request arg = request(CARIBE_SYNC_STATS);
    if (ioctl(control, CARIBE_SYNC_CALL, &arg)) { perror("sync stats"); exit(1); }
    return arg;
}
static int child_ok(pid_t child)
{
    int status;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}
static int pause_ms(void)
{
    struct timespec delay = {0, 1000000};
    return nanosleep(&delay, 0);
}
static int wait_blocked(uint32_t before)
{
    unsigned i;
    for (i = 0; i < 5000; i++) {
        if (stats().waits > before) return 1;
        if (pause_ms()) { perror("coordination nanosleep"); return 0; }
    }
    return 0;
}
static int gate_a(void)
{
    struct caribe_sync_request arg;
    sem_info info;
    sem_id id, old;
    struct timespec delay = {0, 20000000}, now, target, end;
    uint64_t start_ns, end_ns;
    int32_t ts32[2] = {0, 20000000};
    CHECK(clock_gettime(CLOCK_MONOTONIC, &now) == 0);
    start_ns = (uint64_t)now.tv_sec * 1000000000U + now.tv_nsec;
    CHECK(nanosleep(&delay, 0) == 0);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &end) == 0);
    end_ns = (uint64_t)end.tv_sec * 1000000000U + end.tv_nsec;
    CHECK(end_ns >= start_ns + 20000000U);
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, 0, &delay, 0) == 0);
    CHECK(syscall(101, ts32, 0) == 0);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &now) == 0);
    start_ns = (uint64_t)now.tv_sec * 1000000000U + now.tv_nsec;
    CHECK(syscall(115, CLOCK_MONOTONIC, 0, ts32, 0) == 0);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &end) == 0);
    end_ns = (uint64_t)end.tv_sec * 1000000000U + end.tv_nsec;
    CHECK(end_ns >= start_ns + 20000000U);
    target = end; target.tv_nsec += 20000000;
    if (target.tv_nsec >= 1000000000) { target.tv_sec++; target.tv_nsec -= 1000000000; }
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &target, (void *)-1) == 0);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &end) == 0);
    CHECK(end.tv_sec > target.tv_sec || (end.tv_sec == target.tv_sec && end.tv_nsec >= target.tv_nsec));
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &now, 0) == 0);
    CHECK(clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &now, 0) == ENOTSUP);
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, 2, &delay, 0) == EINVAL);
    CHECK(clock_nanosleep(CLOCK_BOOTTIME, 0, &delay, 0) == ENOTSUP);
    delay.tv_nsec = 1000000000;
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, 0, &delay, 0) == EINVAL);
    delay.tv_nsec = -1;
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, 0, &delay, 0) == EINVAL);
    delay.tv_nsec = 0; delay.tv_sec = -1;
    CHECK(clock_nanosleep(CLOCK_MONOTONIC, 0, &delay, 0) == EINVAL);
    CHECK(syscall(407, CLOCK_MONOTONIC, 0, 0, 0) == -1 && errno == EFAULT);
    CHECK(stats().live == 0);
    id = create_semaphore("counting-A", 3, 0);
    CHECK(id > 0 && get_semaphore_count(id) == 3);
    CHECK(get_semaphore_info(id, getpid(), &info) == 0);
    CHECK(info.si_owner == getpid() && info.si_latest_holder == -1 && !strcmp(info.si_name, "counting-A"));
    CHECK(lock_semaphore_x(id, 2, 0, 0) == 0 && get_semaphore_count(id) == 1);
    CHECK(get_semaphore_info(id, -1, &info) == 0 && info.si_latest_holder == getpid());
    CHECK(lock_semaphore_x(id, 2, 0, 0) == -1 && errno == EAGAIN);
    CHECK(get_semaphore_count(id) == 1);
    CHECK(lock_semaphore_x(id, 2, 0, 20000) == -1 && errno == ETIMEDOUT);
    CHECK(get_semaphore_count(id) == 1);
    CHECK(unlock_semaphore_x(id, INT_MAX, 0) == -1 && errno == EOVERFLOW);
    CHECK(unlock_semaphore_x(id, 2, 0) == 0 && get_semaphore_count(id) == 3);
    CHECK(lock_mutex(id, false) == 0 && unlock_mutex(id) == 0);
    CHECK(create_semaphore("recursive-unported", 1, SEM_RECURSIVE) == -1 && errno == ENOTSUP);
    CHECK(create_semaphore("rw-unported", 1, SEMSTYLE_RWLOCK) == -1 && errno == ENOTSUP);
    CHECK(lock_semaphore_x(id, 1, SEM_WARN_DBL_LOCK, 0) == -1 && errno == ENOTSUP);
    CHECK(lock_semaphore_x(id, 0, 0, 0) == -1 && errno == EINVAL);
    CHECK(lock_semaphore_x(id, 1, 0, -2) == -1 && errno == EINVAL);
    CHECK(sleep_on_sem(id, 0) == -1 && errno == ENOTSUP);
    CHECK(wakeup_sem(id, true) == -1 && errno == ENOTSUP);
    CHECK(unlock_and_suspend(id, id) == -1 && errno == ENOTSUP);
    arg = request(CARIBE_SYNC_STATS); arg.abi++;
    CHECK(ioctl(control, CARIBE_SYNC_CALL, &arg) == -1 && errno == EINVAL);
    arg = request(CARIBE_SYNC_ACQUIRE); arg.id = id; arg.units = 1; arg.flags = 4;
    CHECK(ioctl(control, CARIBE_SYNC_CALL, &arg) == -1 && errno == EINVAL);
    arg = request(CARIBE_SYNC_ACQUIRE); arg.id = id; arg.units = 1; arg.flags = CARIBE_SYNC_WAIT;
    CHECK(ioctl(control, CARIBE_SYNC_CALL, &arg) == -1 && errno == EINVAL);
    CHECK(ioctl(control, CARIBE_SYNC_CALL, (void *)0) == -1 && errno == EFAULT);
    CHECK(ioctl(control, CARIBE_SYNC_CALL + 1, &arg) == -1 && errno == ENOTTY);
    old = id;
    CHECK(delete_semaphore(id) == 0 && get_semaphore_count(old) == -1 && errno == EINVAL);
    id = create_semaphore("reused-A", 0, 0);
    CHECK(id > 0 && id != old && delete_semaphore(id) == 0 && stats().live == 0);
    puts("[native-sync-gate-A] counting, timed scheduler wait, generation IDs; real 32/64-bit relative/absolute sleeps PASS");
    return 0;
}
static int gate_b(void)
{
    sem_id ids[CARIBE_SYNC_MAX_OBJECTS], id;
    struct caribe_sync_request *arg;
    unsigned i;
    for (i = 0; i < CARIBE_SYNC_MAX_OBJECTS; i++) {
        ids[i] = create_semaphore("capacity-B", 1, 0); CHECK(ids[i] > 0);
    }
    CHECK(stats().live == CARIBE_SYNC_MAX_OBJECTS);
    CHECK(create_semaphore("full-B", 0, 0) == -1 && errno == ENOSPC);
    for (i = 0; i < CARIBE_SYNC_MAX_OBJECTS; i++) CHECK(delete_semaphore(ids[i]) == 0);
    arg = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    CHECK(arg != MAP_FAILED);
    *arg = request(CARIBE_SYNC_CREATE); arg->value = 3; strcpy(arg->name, "copyout-B");
    CHECK(mprotect(arg, 4096, PROT_READ) == 0);
    CHECK(ioctl(control, CARIBE_SYNC_CALL, arg) == -1 && errno == EFAULT && stats().live == 0);
    CHECK(mprotect(arg, 4096, PROT_READ | PROT_WRITE) == 0);
    id = create_semaphore("transaction-B", 3, 0); CHECK(id > 0);
    *arg = request(CARIBE_SYNC_ACQUIRE); arg->id = id; arg->units = 2;
    CHECK(mprotect(arg, 4096, PROT_READ) == 0);
    CHECK(ioctl(control, CARIBE_SYNC_CALL, arg) == -1 && errno == EFAULT && get_semaphore_count(id) == 3);
    CHECK(mprotect(arg, 4096, PROT_READ | PROT_WRITE) == 0);
    *arg = request(CARIBE_SYNC_RELEASE); arg->id = id; arg->units = 2;
    CHECK(mprotect(arg, 4096, PROT_READ) == 0);
    CHECK(ioctl(control, CARIBE_SYNC_CALL, arg) == -1 && errno == EFAULT && get_semaphore_count(id) == 3);
    CHECK(munmap(arg, 4096) == 0 && delete_semaphore(id) == 0);
    for (i = 0; i < 256; i++) {
        id = create_semaphore("recycle-B", 1, 0);
        CHECK(id > 0 && lock_semaphore(id) == 0 && unlock_semaphore(id) == 0);
        CHECK(delete_semaphore(id) == 0);
    }
    CHECK(stats().live == 0);
    puts("[native-sync-gate-B] capacity=64 recycling=256 EFAULT transactions without credit/object loss PASS");
    return 0;
}
static int gate_c(void)
{
    sem_id local = create_semaphore("local-C", 1, 0), global = create_semaphore("global-C", 1, SEM_GLOBAL);
    pid_t child;
    unsigned i;
    CHECK(local > 0 && global > 0);
    child = fork(); CHECK(child >= 0);
    if (!child) {
        CHECK(lock_semaphore_x(local, 1, 0, 0) == -1 && errno == EPERM);
        CHECK(lock_semaphore_x(global, 1, 0, 0) == 0 && unlock_semaphore(global) == 0);
        CHECK(delete_semaphore(global) == -1 && errno == EPERM);
        CHECK(create_semaphore("exit-C", 1, 0) > 0);
        _exit(0);
    }
    CHECK(child_ok(child) && stats().live == 2 && get_semaphore_count(local) == 1);
    CHECK(delete_semaphore(local) == 0 && delete_semaphore(global) == 0);
    for (i = 0; i < 16; i++) {
        child = fork(); CHECK(child >= 0);
        if (!child) {
            sem_id id = create_semaphore("exec-C", 1, 0);
            char id_text[20];
            CHECK(id > 0);
            execl("/missing-sync-exec", "missing", (char *)0);
            CHECK(errno == ENOENT && get_semaphore_count(id) == 1);
            snprintf(id_text, sizeof(id_text), "%d", id);
            execl("/bin/native-sync-probe", "native-sync-probe", "--after-exec", id_text, (char *)0);
            _exit(1);
        }
        CHECK(child_ok(child) && stats().live == 0);
    }
    puts("[native-sync-gate-C] local/global permissions; exit and successful exec cleanup=16; failed exec preserves objects PASS");
    return 0;
}
static int peer(area_id area, sem_id ping, sem_id pong, port_id ready)
{
    void *address = 0;
    area_id view = clone_area("sync-peer-D", &address, RW, AREA_FULL_LOCK, area);
    struct packet *packet = address;
    uint32_t seq;
    CHECK(view > 0 && address);
    CHECK(send_msg_x(ready, 0, 0, 0, 5000000) == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        CHECK(lock_semaphore_x(ping, 1, 0, 5000000) == 0);
        __sync_synchronize();
        CHECK(packet->sequence == seq && packet->value == seq * 37U && packet->guard == 0xdecafbadU);
        packet->answer = seq ^ 0x1234ab78U;
        __sync_synchronize();
        CHECK(unlock_semaphore(pong) == 0);
    }
    return 0;
}
static int gate_d(void)
{
    void *address = 0;
    area_id area = create_area("shared-sync-D", &address, 4096, RW, AREA_FULL_LOCK);
    struct packet *packet = address;
    sem_id ping = create_semaphore("ping-D", 0, SEM_GLOBAL), pong = create_semaphore("pong-D", 0, SEM_GLOBAL);
    port_id ready = create_port("ready-D", 1);
    struct caribe_sync_request before = stats(), after;
    pid_t child;
    uint32 code, seq;
    CHECK(area > 0 && address && ping > 0 && pong > 0 && ready > 0);
    child = fork(); CHECK(child >= 0);
    if (!child) {
        char args[4][20];
        snprintf(args[0], 20, "%d", area); snprintf(args[1], 20, "%d", ping);
        snprintf(args[2], 20, "%d", pong); snprintf(args[3], 20, "%d", ready);
        execl("/bin/native-sync-probe", "native-sync-probe", "--peer", args[0], args[1], args[2], args[3], (char *)0);
        _exit(1);
    }
    CHECK(get_msg_x(ready, &code, 0, 0, 5000000) == 0 && code == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        packet->sequence = seq; packet->value = seq * 37U; packet->guard = 0xdecafbadU;
        __sync_synchronize();
        CHECK(unlock_semaphore(ping) == 0 && lock_semaphore_x(pong, 1, 0, 5000000) == 0);
        __sync_synchronize();
        CHECK(packet->answer == (seq ^ 0x1234ab78U));
    }
    CHECK(child_ok(child));
    after = stats();
    CHECK(after.waits > before.waits && after.wakes > before.wakes);
    CHECK(after.acquires - before.acquires == 2 * ROUNDS && after.releases - before.releases == 2 * ROUNDS);
    CHECK(delete_port(ready) == 0 && delete_area(area) == 0);
    CHECK(delete_semaphore(ping) == 0 && delete_semaphore(pong) == 0 && stats().live == 0);
    printf("[native-sync-gate-D] independent-exec semaphore/shared-memory rounds=10000 acquisitions=20000 releases=20000 scheduler-waits=%u PASS\n",
        after.waits - before.waits);
    return 0;
}
static void signal_handler(int signal) { (void)signal; signals++; }
static int gate_e(void)
{
    sem_id id, replacement;
    pid_t child;
    uint32_t before;
    uint32 code;
    port_id ready;
    struct sigaction action;
    struct timespec delay, remaining, deadline;
    int result;
    unsigned i;
    for (i = 0; i < 16; i++) {
        id = create_semaphore("delete-wait-E", 0, SEM_GLOBAL); CHECK(id > 0);
        before = stats().waits;
        child = fork(); CHECK(child >= 0);
        if (!child) {
            CHECK(lock_semaphore_x(id, 1, 0, 5000000) == -1 && errno == EIDRM);
            _exit(0);
        }
        CHECK(wait_blocked(before));
        CHECK(delete_semaphore(id) == 0);
        replacement = create_semaphore("reused-wait-E", 0, SEM_GLOBAL);
        CHECK(replacement > 0 && replacement != id && unlock_semaphore(replacement) == 0);
        CHECK(child_ok(child) && get_semaphore_count(replacement) == 1);
        CHECK(delete_semaphore(replacement) == 0 && stats().live == 0);
    }
    ready = create_port("owner-lifecycle-E", 1); CHECK(ready > 0);
    for (i = 0; i < 16; i++) {
        child = fork(); CHECK(child >= 0);
        if (!child) {
            char id_text[20];
            id = create_semaphore("owner-cleanup-E", 0, SEM_GLOBAL); CHECK(id > 0);
            before = stats().waits;
            CHECK(send_msg_x(ready, 0, &id, sizeof(id), 5000000) == 0);
            CHECK(wait_blocked(before));
            if (i & 1U) {
                snprintf(id_text, sizeof(id_text), "%d", id);
                execl("/bin/native-sync-probe", "native-sync-probe", "--after-exec", id_text, (char *)0);
                _exit(1);
            }
            _exit(0);
        }
        CHECK(get_msg_x(ready, &code, &id, sizeof(id), 5000000) == 0);
        CHECK(lock_semaphore_x(id, 1, 0, 5000000) == -1 && errno == EIDRM);
        CHECK(child_ok(child) && stats().live == 0);
    }
    CHECK(delete_port(ready) == 0);
    id = create_semaphore("signal-E", 0, SEM_GLOBAL); CHECK(id > 0);
    before = stats().waits;
    child = fork(); CHECK(child >= 0);
    if (!child) {
        memset(&action, 0, sizeof(action)); action.sa_handler = signal_handler;
        CHECK(sigaction(SIGUSR1, &action, 0) == 0);
        CHECK(lock_semaphore_x(id, 1, 0, 5000000) == -1 && errno == EINTR && signals == 1);
        CHECK(get_semaphore_count(id) == 0);
        _exit(0);
    }
    CHECK(wait_blocked(before) && kill(child, SIGUSR1) == 0 && child_ok(child));
    CHECK(delete_semaphore(id) == 0 && stats().live == 0);
    ready = create_port("clock-signal-E", 1); CHECK(ready > 0);
    for (i = 0; i < 3; i++) {
        child = fork(); CHECK(child >= 0);
        if (!child) {
            signals = 0;
            memset(&action, 0, sizeof(action)); action.sa_handler = signal_handler;
            action.sa_flags = SA_RESTART;
            CHECK(sigaction(SIGUSR1, &action, 0) == 0);
            delay.tv_sec = 2; delay.tv_nsec = 0;
            remaining.tv_sec = 42; remaining.tv_nsec = 7;
            CHECK(clock_gettime(CLOCK_MONOTONIC, &deadline) == 0);
            deadline.tv_sec += 2;
            CHECK(send_msg_x(ready, 0, 0, 0, 5000000) == 0);
            if (i == 0) {
                result = nanosleep(&delay, &remaining);
                CHECK(result == -1 && errno == EINTR);
            } else {
                result = clock_nanosleep(CLOCK_MONOTONIC, i == 2 ? TIMER_ABSTIME : 0,
                    i == 2 ? &deadline : &delay, &remaining);
                CHECK(result == EINTR);
            }
            CHECK(signals == 1);
            if (i == 2) CHECK(remaining.tv_sec == 42 && remaining.tv_nsec == 7);
            else CHECK(remaining.tv_sec >= 0 && remaining.tv_sec < 2 && remaining.tv_nsec >= 0 && remaining.tv_nsec < 1000000000);
            _exit(0);
        }
        CHECK(get_msg_x(ready, &code, 0, 0, 5000000) == 0);
        delay.tv_sec = 0; delay.tv_nsec = 20000000;
        CHECK(nanosleep(&delay, 0) == 0);
        CHECK(kill(child, SIGUSR1) == 0 && child_ok(child));
    }
    CHECK(delete_port(ready) == 0);
    puts("[native-sync-gate-E] deletion/reuse EIDRM=16; owner exit/exec wakes=16; signal credit preservation; sleep EINTR/remainder=3 PASS");
    return 0;
}
int main(int argc, char **argv)
{
    int (*const gates[])(void) = {gate_a, gate_b, gate_c, gate_d, gate_e};
    unsigned i, last = 4;
    setvbuf(stdout, 0, _IONBF, 0);
    control = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC);
    CHECK(control >= 0);
    if (argc == 6 && !strcmp(argv[1], "--peer"))
        return peer(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
    if (argc == 3 && !strcmp(argv[1], "--after-exec")) {
        CHECK(get_semaphore_count(atoi(argv[2])) == -1 && errno == EINVAL && stats().live == 0);
        return 0;
    }
    if (argc == 3 && !strcmp(argv[1], "--gate") && strlen(argv[2]) == 1 && argv[2][0] >= 'A' && argv[2][0] <= 'E')
        last = (unsigned)(argv[2][0] - 'A');
    else if (argc != 1) return 2;
    for (i = 0; i <= last; i++) if (gates[i]()) return 1;
    printf("[native-sync] gates A-%c PASS; native XNU counting semaphores, no user-thread claims\n", 'A' + last);
    return 0;
}
