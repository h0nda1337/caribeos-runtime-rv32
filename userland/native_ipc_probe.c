/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Independent-process gates for Syllable's native message-port API on XNU.
 */
#include <atheos/msgport.h>
#include <uapi/caribe_ipc.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    printf("[native-ipc] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
#define ROUNDS 10000U
static uint8_t packet[8192], received[8192];
static int control;

static struct caribe_ipc_request arg_for(uint32_t op, port_id id)
{
    struct caribe_ipc_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_IPC_ABI;
    arg.operation = op;
    arg.id = (uint32_t)id;
    return arg;
}
static struct caribe_ipc_request stats(void)
{
    struct caribe_ipc_request arg = arg_for(CARIBE_IPC_STATS, 0);
    if (ioctl(control, CARIBE_IPC_CALL, &arg)) {
        perror("IPC stats");
        exit(1);
    }
    return arg;
}
static unsigned size_for(unsigned seq)
{
    return seq % 1000 == 0 ? sizeof(packet) : 16 + seq % 200;
}
static void fill(unsigned seq, unsigned size)
{
    unsigned i;
    for (i = 0; i < size; i++) packet[i] = (uint8_t)(seq * 37U + i * 13U);
}
static int child_status(pid_t child)
{
    int status;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}
static int peer(port_id destination, port_id reply)
{
    port_id own;
    uint32 code;
    unsigned seq, size;
    CHECK(find_port("caribe-ipc-server") == destination);
    CHECK(get_app_server_port() == destination);
    CHECK(delete_port(destination) == -1 && errno == EPERM);
    CHECK(get_msg_x(reply, &code, received, sizeof(received), 0) == -1 && errno == EPERM);
    own = create_port("caribe-ipc-peer", 1);
    CHECK(own > 0);
    CHECK(send_msg_x(reply, 0, &own, sizeof(own), 5000000) == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        size = size_for(seq);
        CHECK(get_msg_x(own, &code, received, sizeof(received), 5000000) == 0);
        CHECK(code == seq);
        fill(seq, size);
        CHECK(memcmp(packet, received, size) == 0);
        CHECK(send_msg_x(reply, seq, received, (int)size, 5000000) == 0);
    }
    /* Deliberately leak a queued port: kernel exit teardown must reclaim it. */
    CHECK(make_port_public(own) == 0);
    CHECK(send_msg_x(own, 123, packet, 17, 0) == 0);
    return 0;
}
static int leak_exec(void)
{
    port_id id = create_port("caribe-ipc-exec-owned", 1);
    CHECK(id > 0 && make_port_public(id) == 0);
    CHECK(send_msg_x(id, 7, packet, 10, 0) == 0);
    CHECK(execl("/bin/native-ipc-probe", "native-ipc-probe", "check-exec", (char *)0) == 0);
    return 1;
}
static int gates(void)
{
    struct caribe_ipc_request before = stats(), after, arg;
    port_id id, reply, own, old, objects[CARIBE_IPC_MAX_PORTS];
    port_info info;
    uint32 code;
    unsigned i, seq, size;
    pid_t child;
    char dest_arg[32], reply_arg[32];
    struct timespec start, end;
    uint64_t elapsed;
    CHECK(before.ports == 0 && before.messages == 0);
    arg = arg_for(CARIBE_IPC_STATS, 0);
    arg.abi++;
    CHECK(ioctl(control, CARIBE_IPC_CALL, &arg) == -1 && errno == EINVAL);
    CHECK(ioctl(control, CARIBE_IPC_CALL, (void *)0) == -1 && errno == EFAULT);
    CHECK(ioctl(control, 0, &arg) == -1 && errno == ENOTTY);
    CHECK(create_port("invalid", 0) == -1 && errno == EINVAL);
    CHECK(create_port("invalid", 33) == -1 && errno == EINVAL);
    id = create_port("caribe-ipc-fifo", 4);
    CHECK(id > 0);
    CHECK(find_port("caribe-ipc-fifo") == -1 && errno == ENOENT);
    CHECK(get_msg_x(id, &code, received, sizeof(received), 0) == -1 && errno == EAGAIN);
    CHECK(make_port_public(id) == 0 && find_port("caribe-ipc-fifo") == id);
    CHECK(get_port_info(id, &info) == 0 && info.pi_owner == getpid() &&
          info.pi_max_count == 4 && info.pi_cur_count == 0 &&
          info.pi_flags == MSG_PORT_PUBLIC);
    own = create_port("caribe-ipc-fifo", 1);
    CHECK(own > 0);
    CHECK(make_port_public(own) == -1 && errno == EEXIST);
    CHECK(delete_port(own) == 0);
    for (i = 1; i <= 4; i++) {
        fill(i, 32);
        CHECK(send_msg_x(id, i, packet, 32, 0) == 0);
    }
    CHECK(send_msg_x(id, 5, packet, 32, 0) == -1 && errno == EAGAIN);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &start) == 0);
    CHECK(send_msg_x(id, 5, packet, 32, 5000) == -1 && errno == ETIMEDOUT);
    CHECK(clock_gettime(CLOCK_MONOTONIC, &end) == 0);
    elapsed = ((uint64_t)end.tv_sec * 1000000000ULL + end.tv_nsec) -
              ((uint64_t)start.tv_sec * 1000000000ULL + start.tv_nsec);
    CHECK(elapsed >= 4000000ULL && elapsed < 1000000000ULL);
    CHECK(get_msg_size(id) == 32);
    memset(&info, 0, sizeof(info));
    info.pi_port_id = -1;
    CHECK(get_next_port_info(&info) == 1 && info.pi_port_id == id);
    CHECK(get_next_port_info(&info) == 0);
    CHECK(get_msg_x(id, &code, received, 31, 0) == -1 && errno == EMSGSIZE);
    CHECK(get_msg_x(id, &code, (void *)0, 32, 0) == -1 && errno == EFAULT);
    CHECK(get_port_info(id, &info) == 0 && info.pi_cur_count == 4);
    for (i = 1; i <= 4; i++) {
        CHECK(get_msg_x(id, &code, received, sizeof(received), 0) == 0 && code == i);
        fill(i, 32);
        CHECK(memcmp(packet, received, 32) == 0);
    }
    CHECK(send_msg_x(id, 0, 0, 0, 0) == 0);
    CHECK(get_msg_x(id, &code, 0, 0, 0) == 0 && code == 0);
    CHECK(send_msg_x(id, 0, 0, 0, INFINITE_TIMEOUT) == 0);
    CHECK(get_msg_x(id, &code, 0, 0, INFINITE_TIMEOUT) == 0);
    fill(3, 32);
    CHECK(send_msg_x(id, 3, packet, 32, 0) == 0);
    arg = arg_for(CARIBE_IPC_RECEIVE, id);
    arg.buffer = (uint32_t)(uintptr_t)&arg;
    arg.size = 32;
    CHECK(ioctl(control, CARIBE_IPC_CALL, &arg) == -1 && errno == EINVAL);
    CHECK(get_msg_x(id, &code, received, sizeof(received), 0) == 0 && code == 3);
    CHECK(send_msg_x(id, 7, packet, 8193, 0) == -1 && errno == EMSGSIZE);
    CHECK(send_msg_x(id, 7, 0, 32, 0) == -1 && errno == EFAULT);
    CHECK(delete_port(id) == 0);
    old = id;
    id = create_port("new-generation", 1);
    CHECK(id > 0 && id != old);
    CHECK(send_msg_x(old, 1, packet, 1, 0) == -1 && errno == ENOENT);
    CHECK(delete_port(id) == 0);
    puts("[native-ipc-gate-A] ABI FIFO bounds EFAULT no-loss permissions generations timeout PASS");

    for (i = 0; i < CARIBE_IPC_MAX_PORTS; i++) {
        objects[i] = create_port("bounded-resource-test", 4);
        CHECK(objects[i] > 0);
    }
    CHECK(create_port("overflow", 1) == -1 && errno == ENOSPC);
    for (i = 0; i < CARIBE_IPC_MAX_MESSAGES; i++)
        CHECK(send_msg_x(objects[i / 4], i, packet, 7, 0) == 0);
    CHECK(send_msg_x(objects[31], 0, packet, 7, 0) == -1 && errno == EAGAIN);
    after = stats();
    CHECK(after.ports == 32 && after.messages == 64);
    for (i = 0; i < CARIBE_IPC_MAX_PORTS; i++) CHECK(delete_port(objects[i]) == 0);
    for (i = 0; i < 256; i++) {
        id = create_port("recycled", 1);
        CHECK(id > 0);
        CHECK(get_msg_x(id, &code, received, sizeof(received), 0) == -1 && errno == EAGAIN);
        CHECK(send_msg_x(id, i, packet, 19, 0) == 0);
        CHECK(delete_port(id) == 0);
    }
    after = stats();
    CHECK(after.ports == 0 && after.messages == 0);
    puts("[native-ipc-gate-B] pool ports=32 messages=64 exhaustion recycling=256 zero-leak PASS");

    id = create_port("caribe-ipc-server", 1);
    reply = create_port("caribe-ipc-reply", 1);
    CHECK(id > 0 && reply > 0 && set_app_server_port(id) == 0);
    snprintf(dest_arg, sizeof(dest_arg), "%d", id);
    snprintf(reply_arg, sizeof(reply_arg), "%d", reply);
    child = fork();
    CHECK(child >= 0);
    if (!child) {
        execl("/bin/native-ipc-probe", "native-ipc-probe", "peer", dest_arg, reply_arg, (char *)0);
        _exit(91);
    }
    CHECK(get_msg_x(reply, &code, &own, sizeof(own), 5000000) == 0 && code == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        size = size_for(seq);
        fill(seq, size);
        CHECK(send_msg_x(own, seq, packet, (int)size, 5000000) == 0);
        CHECK(get_msg_x(reply, &code, received, sizeof(received), 5000000) == 0 && code == seq);
        CHECK(memcmp(packet, received, size) == 0);
    }
    CHECK(child_status(child));
    CHECK(find_port("caribe-ipc-peer") == -1 && errno == ENOENT);
    CHECK(delete_port(id) == 0 && delete_port(reply) == 0);
    CHECK(get_app_server_port() == -1 && errno == ENOENT);
    after = stats();
    CHECK(after.ports == 0 && after.messages == 0 && after.limit > before.limit &&
          after.flags > before.flags && after.code > before.code);
    printf("[native-ipc-gate-C] independent exec ping-pong=%u max-payload=8192 scheduler-waits=%u wakeups=%u PASS\n",
           ROUNDS, after.limit - before.limit, after.flags - before.flags);

    child = fork();
    CHECK(child >= 0);
    if (!child) _exit(leak_exec());
    CHECK(child_status(child));
    after = stats();
    CHECK(after.ports == before.ports && after.messages == before.messages);
    puts("[native-ipc-gate-D] successful exec revokes old ports queued messages server registry exit cleanup PASS");
    puts("[native-ipc] gates A-D PASS; native XNU ports, no Wayland/X11");
    return 0;
}
int main(int argc, char **argv)
{
    setvbuf(stdout, 0, _IONBF, 0);
    control = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC);
    CHECK(control >= 0);
    if (argc == 4 && !strcmp(argv[1], "peer")) return peer(atoi(argv[2]), atoi(argv[3]));
    if (argc == 2 && !strcmp(argv[1], "check-exec")) {
        CHECK(find_port("caribe-ipc-exec-owned") == -1 && errno == ENOENT);
        CHECK(stats().ports == 0 && stats().messages == 0);
        return 0;
    }
    return gates();
}
