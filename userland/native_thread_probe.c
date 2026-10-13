/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Genuine XNU user threads share a task/pmap. Worker code deliberately uses
 * no libc, errno, pthread, libstdc++ or emutls before their threading gates.
 */
#define _GNU_SOURCE
#include <uapi/caribe_thread.h>
#include <uapi/caribe_sync.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>
#define CHECK(x) do { if (!(x)) { printf("[native-thread] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #x); return 1; } } while (0)
#define STACK_SIZE 32768U
#define CHUNK_SIZE (STACK_SIZE + 4096U)
#define ROUNDS 10000U
struct shared_packet {
    volatile uint32_t entered, tid, tp, sp, value, sequence, answer, error;
    uint32_t request_sem, response_sem;
};
static struct shared_packet shared;
static unsigned char *stacks;
static int control;
static long raw_call(uint32_t number, void *argument)
{
    register uintptr_t a0 __asm__("a0") = (uintptr_t)argument;
    register uintptr_t a7 __asm__("a7") = number;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "a1", "memory");
    return (int32_t)a0;
}
static void zero_words(void *memory, unsigned words)
{
    volatile uint32_t *p = memory;
    while (words--) *p++ = 0;
}
static struct caribe_thread_request request(uint32_t op)
{
    struct caribe_thread_request arg;
    zero_words(&arg, 32); arg.abi = CARIBE_THREAD_ABI; arg.operation = op;
    return arg;
}
static int call(struct caribe_thread_request *arg) { return ioctl(control, CARIBE_THREAD_CALL, arg); }
static struct caribe_thread_request stats(void)
{
    struct caribe_thread_request arg = request(CARIBE_THREAD_STATS);
    if (call(&arg)) { perror("native thread stats"); exit(1); }
    return arg;
}
static void yield(void)
{
    struct caribe_thread_request arg = request(CARIBE_THREAD_YIELD);
    (void)raw_call(CARIBE_THREAD_ECALL, &arg);
}
static void worker_exit(uint32_t status) __attribute__((noreturn));
static void worker_exit(uint32_t status)
{
    struct caribe_thread_request arg;
    zero_words(&arg, 32); arg.abi = CARIBE_THREAD_ABI; arg.operation = CARIBE_THREAD_EXIT; arg.status = status;
    (void)raw_call(CARIBE_THREAD_ECALL, &arg);
    for (;;) __asm__ volatile("nop");
}
static void worker_note(struct shared_packet *packet, uint32_t tid)
{
    uint32_t tp, sp;
    __asm__ volatile("mv %0, tp; mv %1, sp" : "=r"(tp), "=r"(sp));
    packet->tid = tid; packet->tp = tp; packet->sp = sp;
    __sync_synchronize(); packet->entered = 1;
}
static void worker_basic(struct shared_packet *packet, uint32_t tid)
{
    uint32_t i;
    struct caribe_thread_request arg;
    worker_note(packet, tid);
    zero_words(&arg, 32); arg.abi = CARIBE_THREAD_ABI; arg.operation = CARIBE_THREAD_SELF;
    if (raw_call(CARIBE_THREAD_ECALL, &arg) || arg.id != tid || arg.cpu != 0) worker_exit(1);
    /* Linux getpid remains unsupported for this raw-worker profile. */
    if (raw_call(172U, 0) != -ENOTSUP) worker_exit(2);
    for (i = 0; i < ROUNDS; i++) __sync_add_and_fetch(&packet->value, 1U);
    worker_exit(37U);
}
static long worker_sem(uint32_t id, uint32_t operation)
{
    struct caribe_sync_request arg;
    zero_words(&arg, 32); arg.abi = CARIBE_SYNC_ABI; arg.operation = operation; arg.id = id; arg.units = 1;
    if (operation == CARIBE_SYNC_ACQUIRE) { arg.flags = CARIBE_SYNC_WAIT; arg.timeout_low = 5000000U; }
    return raw_call(CARIBE_THREAD_SYNC_ECALL, &arg);
}
static void worker_pingpong(struct shared_packet *packet, uint32_t tid)
{
    uint32_t i;
    worker_note(packet, tid);
    for (i = 1; i <= ROUNDS; i++) {
        if (worker_sem(packet->request_sem, CARIBE_SYNC_ACQUIRE)) worker_exit(3);
        __sync_synchronize();
        if (packet->sequence != i || packet->value != (i ^ 0x2468ace0U)) worker_exit(4);
        packet->answer = packet->value ^ 0x13579bdfU;
        __sync_synchronize();
        if (worker_sem(packet->response_sem, CARIBE_SYNC_RELEASE)) worker_exit(5);
    }
    worker_exit(0);
}
static void worker_spin(struct shared_packet *packet, uint32_t tid)
{
    worker_note(packet, tid);
    for (;;) __sync_add_and_fetch(&packet->value, 1U);
}
static void worker_block(struct shared_packet *packet, uint32_t tid)
{
    worker_note(packet, tid);
    (void)worker_sem(packet->request_sem, CARIBE_SYNC_ACQUIRE);
    worker_exit(9);
}
static void worker_fault(struct shared_packet *packet, uint32_t tid)
{
    worker_note(packet, tid);
    __asm__ volatile(".word 0");
    worker_exit(10);
}
typedef void (*entry_fn)(struct shared_packet *, uint32_t);
static struct caribe_thread_request creation(entry_fn entry, unsigned slot)
{
    struct caribe_thread_request arg = request(CARIBE_THREAD_CREATE);
    arg.entry = (uintptr_t)entry; arg.argument = (uintptr_t)&shared;
    arg.stack_base = (uintptr_t)(stacks + slot * CHUNK_SIZE); arg.stack_size = STACK_SIZE;
    arg.tp = arg.stack_base + STACK_SIZE;
    return arg;
}
static int operation(uint32_t op, uint32_t id)
{
    struct caribe_thread_request arg = request(op); arg.id = id;
    return call(&arg);
}
static int join(uint32_t id, uint32_t *status)
{
    struct caribe_thread_request arg = request(CARIBE_THREAD_JOIN);
    arg.id = id; arg.timeout_us = 60000000U;
    if (call(&arg)) return -1;
    *status = arg.status; return 0;
}
static int gate_a(void)
{
    struct caribe_thread_request arg, before = stats(), after;
    uint32_t status, tp;
    void *readonly = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    CHECK(readonly != MAP_FAILED);
    arg = creation(worker_basic, 0); arg.entry = (uintptr_t)&shared;
    CHECK(call(&arg) == -1 && errno == EINVAL);
    arg = creation(worker_basic, 0); arg.stack_base++;
    CHECK(call(&arg) == -1 && errno == EINVAL);
    arg = creation(worker_basic, 0); arg.tp = 0;
    CHECK(call(&arg) == -1 && errno == EINVAL);
    __asm__ volatile("mv %0, tp" : "=r"(tp));
    arg = creation(worker_basic, 0); arg.tp = tp;
    CHECK(call(&arg) == -1 && errno == EBUSY);
    arg = creation(worker_basic, 0); arg.reserved[0] = 1;
    CHECK(call(&arg) == -1 && errno == EINVAL);
    arg = creation(worker_basic, 0); memcpy(readonly, &arg, sizeof(arg));
    CHECK(mprotect(readonly, 4096, PROT_READ) == 0);
    CHECK(ioctl(control, CARIBE_THREAD_CALL, readonly) == -1 && errno == EFAULT);
    CHECK(stats().created == before.created && stats().live == 0);
    CHECK(munmap(readonly, 4096) == 0);
    memset(&shared, 0, sizeof(shared)); arg = creation(worker_basic, 0);
    CHECK(call(&arg) == 0 && arg.id > 0 && arg.state == CARIBE_THREAD_SUSPENDED && arg.cpu == 0 && arg.owner == (uint32_t)getpid());
    CHECK(shared.entered == 0 && stats().live == 1);
    CHECK(operation(CARIBE_THREAD_START, arg.id) == 0 && operation(CARIBE_THREAD_START, arg.id) == -1 && errno == EBUSY);
    CHECK(join(arg.id, &status) == 0 && status == 37 && shared.value == ROUNDS && shared.tid == arg.id);
    __asm__ volatile("mv %0, tp" : "=r"(tp));
    CHECK(shared.tp == arg.tp && shared.tp != tp && shared.sp >= arg.stack_base && shared.sp < arg.stack_base + arg.stack_size);
    CHECK(operation(CARIBE_THREAD_INFO, arg.id) == -1 && errno == EINVAL);
    after = stats(); CHECK(after.live == 0 && after.created == before.created + 1 && after.reaped == before.reaped + 1 && after.entered == before.entered + 1);
    puts("[native-thread-gate-A] genuine same-task U-mode entry, independent stack/TP, suspended start, shared increments=10000, join/reaper PASS");
    return 0;
}
static int gate_b(void)
{
    struct caribe_thread_request arg, before = stats(), after;
    uint32_t ids[CARIBE_THREAD_MAX], status, old = 0;
    unsigned i;
    for (i = 0; i < CARIBE_THREAD_MAX; i++) { arg = creation(worker_basic, i); CHECK(call(&arg) == 0); ids[i] = arg.id; }
    arg = creation(worker_basic, 0); CHECK(call(&arg) == -1 && errno == EBUSY);
    arg = creation(worker_basic, CARIBE_THREAD_MAX); CHECK(call(&arg) == -1 && errno == ENOSPC);
    CHECK(stats().live == CARIBE_THREAD_MAX);
    for (i = 0; i < CARIBE_THREAD_MAX; i++) {
        CHECK(operation(CARIBE_THREAD_CANCEL, ids[i]) == 0 && join(ids[i], &status) == 0 && status == CARIBE_THREAD_CANCELLED);
    }
    for (i = 0; i < 256; i++) {
        memset(&shared, 0, sizeof(shared)); arg = creation(worker_basic, 0);
        CHECK(call(&arg) == 0 && arg.id != old);
        CHECK(operation(CARIBE_THREAD_START, arg.id) == 0 && join(arg.id, &status) == 0 && status == 37 && shared.value == ROUNDS);
        if (old) CHECK(operation(CARIBE_THREAD_INFO, old) == -1 && errno == EINVAL);
        old = arg.id;
    }
    after = stats(); CHECK(after.live == 0 && after.created - before.created == 272 && after.reaped - before.reaped == 272);
    puts("[native-thread-gate-B] suspended capacity=16, cancel-before-entry=16, real entry/join/reaper cycles=256, stale IDs rejected PASS");
    return 0;
}
static int create_sem(uint32_t *id)
{
    struct caribe_sync_request arg;
    memset(&arg, 0, sizeof(arg)); arg.abi = CARIBE_SYNC_ABI; arg.operation = CARIBE_SYNC_CREATE;
    strcpy(arg.name, "same-task-native-thread");
    if (raw_call(CARIBE_THREAD_SYNC_ECALL, &arg)) return -1;
    *id = arg.id; return 0;
}
static int delete_sem(uint32_t id)
{
    struct caribe_sync_request arg;
    memset(&arg, 0, sizeof(arg)); arg.abi = CARIBE_SYNC_ABI; arg.operation = CARIBE_SYNC_DELETE; arg.id = id;
    return raw_call(CARIBE_THREAD_SYNC_ECALL, &arg);
}
static struct caribe_sync_request sync_stats(void)
{
    struct caribe_sync_request arg;
    memset(&arg, 0, sizeof(arg)); arg.abi = CARIBE_SYNC_ABI; arg.operation = CARIBE_SYNC_STATS;
    if (raw_call(CARIBE_THREAD_SYNC_ECALL, &arg)) exit(1);
    return arg;
}
static int gate_c(void)
{
    struct caribe_thread_request arg;
    struct caribe_sync_request before = sync_stats(), after, info;
    uint32_t i, status;
    memset(&shared, 0, sizeof(shared));
    CHECK(create_sem(&shared.request_sem) == 0 && create_sem(&shared.response_sem) == 0);
    arg = creation(worker_pingpong, 0); CHECK(call(&arg) == 0 && operation(CARIBE_THREAD_START, arg.id) == 0);
    for (i = 1; i <= ROUNDS; i++) {
        shared.sequence = i; shared.value = i ^ 0x2468ace0U; __sync_synchronize();
        CHECK(worker_sem(shared.request_sem, CARIBE_SYNC_RELEASE) == 0);
        CHECK(worker_sem(shared.response_sem, CARIBE_SYNC_ACQUIRE) == 0);
        __sync_synchronize(); CHECK(shared.answer == ((i ^ 0x2468ace0U) ^ 0x13579bdfU));
    }
    CHECK(join(arg.id, &status) == 0 && status == 0 && shared.tid == arg.id);
    memset(&info, 0, sizeof(info)); info.abi = CARIBE_SYNC_ABI; info.operation = CARIBE_SYNC_INFO; info.id = shared.request_sem;
    CHECK(raw_call(CARIBE_THREAD_SYNC_ECALL, &info) == 0 && info.holder == arg.id);
    after = sync_stats();
    CHECK(after.acquires - before.acquires == 20000 && after.releases - before.releases == 20000 && after.waits > before.waits);
    CHECK(delete_sem(shared.request_sem) == 0 && delete_sem(shared.response_sem) == 0 && sync_stats().live == 0 && stats().live == 0);
    printf("[native-thread-gate-C] same-pmap semaphore rounds=10000 acquisitions=20000 releases=20000 scheduler-waits=%u; distinct holder TID PASS\n", after.waits - before.waits);
    return 0;
}
static int wait_entry(void)
{
    unsigned i;
    for (i = 0; i < 10000; i++) { if (shared.entered) return 1; yield(); }
    return 0;
}
static int gate_d(void)
{
    struct caribe_thread_request arg, before = stats(), after;
    uint32_t status, i;
    char *argv[] = {"/bin/native-thread-probe", "--gate", "A", 0};
    memset(&shared, 0, sizeof(shared)); arg = creation(worker_spin, 0);
    CHECK(call(&arg) == 0 && operation(CARIBE_THREAD_START, arg.id) == 0);
    /* No syscall/yield in this polling interval: the main thread must also be
       preemptible so the pending worker gets an actual scheduling opportunity. */
    for (i = 0; i < 500000000U && !shared.entered; i++) __asm__ volatile("" ::: "memory");
    CHECK(shared.entered);
    CHECK(fork() == -1 && errno == EBUSY);
    CHECK(execv(argv[0], argv) == -1 && errno == EBUSY);
    CHECK(mprotect(stacks, 4096, PROT_NONE) == -1 && errno == EBUSY);
    CHECK(munmap(stacks, CHUNK_SIZE) == -1 && errno == EBUSY);
    CHECK(operation(CARIBE_THREAD_CANCEL, arg.id) == 0 && join(arg.id, &status) == 0 && status == CARIBE_THREAD_CANCELLED);
    memset(&shared, 0, sizeof(shared)); arg = creation(worker_fault, 0);
    CHECK(call(&arg) == 0 && operation(CARIBE_THREAD_START, arg.id) == 0 && join(arg.id, &status) == 0 && status == CARIBE_THREAD_FAULTED);
    memset(&shared, 0, sizeof(shared)); CHECK(create_sem(&shared.request_sem) == 0);
    arg = creation(worker_block, 0); CHECK(call(&arg) == 0 && operation(CARIBE_THREAD_START, arg.id) == 0 && wait_entry());
    yield(); CHECK(operation(CARIBE_THREAD_CANCEL, arg.id) == 0 && join(arg.id, &status) == 0 && status == CARIBE_THREAD_CANCELLED);
    CHECK(delete_sem(shared.request_sem) == 0);
    for (i = 0; i < 16; i++) {
        int from_child[2], to_child[2], child_status;
        uint32_t ids[2]; char ack = 'K'; pid_t child;
        CHECK(pipe(from_child) == 0 && pipe(to_child) == 0);
        child = fork();
        CHECK(child >= 0);
        if (!child) {
            close(from_child[0]); close(to_child[1]);
            memset(&shared, 0, sizeof(shared)); arg = creation(worker_spin, 0);
            if (call(&arg) || operation(CARIBE_THREAD_START, arg.id) || !wait_entry()) _exit(1);
            ids[0] = arg.id;
            arg = creation(worker_basic, 1); if (call(&arg)) _exit(2);
            ids[1] = arg.id;
            if (write(from_child[1], ids, sizeof(ids)) != sizeof(ids) || read(to_child[0], &ack, 1) != 1 || ack != 'K') _exit(3);
            _exit(0); /* Shared-task cancellation/reaper must precede process teardown. */
        }
        CHECK(close(from_child[1]) == 0 && close(to_child[0]) == 0);
        CHECK(read(from_child[0], ids, sizeof(ids)) == sizeof(ids));
        CHECK(operation(CARIBE_THREAD_START, ids[1]) == -1 && errno == EPERM);
        CHECK(operation(CARIBE_THREAD_CANCEL, ids[0]) == -1 && errno == EPERM);
        CHECK(operation(CARIBE_THREAD_INFO, ids[0]) == -1 && errno == EPERM);
        CHECK(operation(CARIBE_THREAD_JOIN, ids[0]) == -1 && errno == EPERM);
        CHECK(write(to_child[1], &ack, 1) == 1 && close(from_child[0]) == 0 && close(to_child[1]) == 0);
        CHECK(waitpid(child, &child_status, 0) == child && WIFEXITED(child_status) && WEXITSTATUS(child_status) == 0 && stats().live == 0);
    }
    after = stats();
    CHECK(after.live == 0 && after.created - before.created == 35 && after.reaped - before.reaped == 35 && after.cancelled - before.cancelled == 34 && after.faults - before.faults == 1 && after.preemptions > before.preemptions);
    printf("[native-thread-gate-D] busy-loop timer preemption/cancel, blocked/suspended cleanup, fault isolation, owner-exit cycles=16; created=reaped=35 preemptions=%u PASS\n", after.preemptions - before.preemptions);
    puts("[native-thread-gate-D] foreign process START/CANCEL/INFO/JOIN denied=64 owner unchanged PASS");
    return 0;
}
int main(int argc, char **argv)
{
    char gate = 'D'; unsigned last; struct caribe_thread_request before, after;
    int profile_off = argc == 2 && !strcmp(argv[1], "--profile-off");
    if (argc == 3 && !strcmp(argv[1], "--gate") && strlen(argv[2]) == 1) gate = argv[2][0];
    else if (argc != 1 && !profile_off) return 2;
    if (gate < 'A' || gate > 'D') return 2;
    control = open("/dev/caribe-ipc", O_RDWR); CHECK(control >= 0);
    stacks = mmap(0, (CARIBE_THREAD_MAX + 1U) * CHUNK_SIZE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    CHECK(stacks != MAP_FAILED); before = stats(); CHECK(before.live == 0);
    if (profile_off) {
        struct caribe_thread_request arg = creation(worker_basic, 0);
        CHECK(call(&arg) == -1 && errno == ENOTSUP && stats().live == 0 && stats().created == before.created);
        CHECK(munmap(stacks, (CARIBE_THREAD_MAX + 1U) * CHUNK_SIZE) == 0 && close(control) == 0);
        puts("[native-thread] disabled-profile create=ENOTSUP no threads created PASS");
        return 0;
    }
    if (gate_a()) return 1;
    if (gate >= 'B' && gate_b()) return 1;
    if (gate >= 'C' && gate_c()) return 1;
    if (gate >= 'D' && gate_d()) return 1;
    after = stats(); last = after.created - before.created;
    CHECK(after.live == 0 && after.reaped - before.reaped == last && after.exited - before.exited == last);
    CHECK(munmap(stacks, (CARIBE_THREAD_MAX + 1U) * CHUNK_SIZE) == 0 && close(control) == 0);
    printf("[native-thread] gates A-%c PASS; real shared-task raw RV32 threads cpu=0; pthread/GNU TLS not yet implemented\n", gate);
    return 0;
}
