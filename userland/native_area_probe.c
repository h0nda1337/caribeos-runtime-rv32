/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Real shared Sv32 backing, independent processes, and GPU scanout gates.
 */
#define _GNU_SOURCE
#include <atheos/areas.h>
#include <atheos/msgport.h>
#include <uapi/caribe_area.h>
#include <uapi/caribe_graphics.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHECK(test) do { if (!(test)) { \
    printf("[native-area] FAIL line=%d errno=%d: %s\n", __LINE__, errno, #test); \
    return 1; } } while (0)
#define RW (AREA_READ | AREA_WRITE)
#define ROUNDS 10000U
static int control;
struct shared_packet { uint32_t sequence, value, answer, guard; };
struct peer_ready { area_id area; port_id port; };

static struct caribe_area_request request(uint32_t op)
{
    struct caribe_area_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_AREA_ABI;
    arg.operation = op;
    return arg;
}
static struct caribe_area_request stats(void)
{
    struct caribe_area_request arg = request(CARIBE_AREA_STATS);
    if (ioctl(control, CARIBE_AREA_CALL, &arg)) { perror("area stats"); exit(1); }
    return arg;
}
static int empty(void)
{
    struct caribe_area_request arg = stats();
    return !arg.objects && !arg.views && !arg.pages && arg.allocations == arg.frees;
}
static int child_ok(pid_t child)
{
    int status;
    return waitpid(child, &status, 0) == child && WIFEXITED(status) && !WEXITSTATUS(status);
}
static int peer(area_id source, port_id reply)
{
    void *address = 0;
    struct shared_packet *packet;
    struct peer_ready ready;
    uint32 code, seq;
    ready.area = clone_area("independent-peer", &address, RW, AREA_FULL_LOCK, source);
    CHECK(ready.area > 0 && address);
    CHECK(delete_area(source) == -1 && errno == EPERM);
    ready.port = create_port("area-peer-sync", 1);
    CHECK(ready.port > 0);
    packet = address;
    CHECK(send_msg_x(reply, 0, &ready, sizeof(ready), 5000000) == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        CHECK(get_msg_x(ready.port, &code, 0, 0, 5000000) == 0 && code == seq);
        __sync_synchronize();
        CHECK(packet->sequence == seq && packet->value == (seq * 37U) && packet->guard == 0xabcdef98U);
        packet->answer = seq ^ 0x71358246U;
        __sync_synchronize();
        CHECK(send_msg_x(reply, seq, 0, 0, 5000000) == 0);
    }
    CHECK(get_msg_x(ready.port, &code, 0, 0, 5000000) == 0 && code == ROUNDS + 1);
    CHECK(packet->guard == 0xabcdef98U);
    /* Leave the view and port for exit cleanup; another live view owns the pages. */
    return 0;
}
static int gates(void)
{
    struct caribe_area_request arg, after;
    AreaInfo_s info;
    area_id id, alias, ro, old, ids[CARIBE_AREA_MAX_VIEWS];
    void *address = 0, *other = 0, *readonly = 0, *fixed, *bad;
    uint32_t *words;
    uint32 code, value;
    unsigned i, seq;
    pid_t child;
    port_id reply;
    struct peer_ready ready;
    char id_arg[32], reply_arg[32];
    struct shared_packet *packet;
    CHECK(empty());
    arg = request(CARIBE_AREA_STATS); arg.abi++;
    CHECK(ioctl(control, CARIBE_AREA_CALL, &arg) == -1 && errno == EINVAL);
    CHECK(ioctl(control, CARIBE_AREA_CALL, (void *)0) == -1 && errno == EFAULT);
    CHECK(create_area("zero", &address, 0, RW, AREA_FULL_LOCK) == -1 && errno == EINVAL);
    CHECK(create_area("execute", &address, 4096, AREA_FULL_ACCESS, AREA_FULL_LOCK) == -1 && errno == EINVAL);
    CHECK(create_area("oversize", &address, 512 * 4096 + 1, RW, 0) == -1 && errno == EINVAL);
    id = create_area("zero-rounded", &address, 8193, RW, AREA_FULL_LOCK);
    CHECK(id > 0 && (uintptr_t)address >= CARIBE_AREA_BASE);
    CHECK(get_area_info(id, &info) == 0 && info.nSize == 12288 && info.pAddress == address &&
          info.hProcess == getpid() && info.nProtection == RW && info.nLock == AREA_FULL_LOCK);
    words = address;
    for (i = 0; i < 12288 / 4; i++) CHECK(words[i] == 0);
    words[0] = 0x12345678U; words[3071] = 0x56781234U;
    alias = clone_area("alias", &other, RW, 0, id);
    CHECK(alias > 0 && other != address && ((uint32_t *)other)[0] == words[0]);
    ((uint32_t *)other)[3071] = 0xcafebabeU;
    CHECK(words[3071] == 0xcafebabeU);
    ro = clone_area("read-only", &readonly, AREA_READ, 0, id);
    CHECK(ro > 0 && ((uint32_t *)readonly)[3071] == words[3071]);
    fixed = 0;
    CHECK(clone_area("no-escalation", &fixed, RW, 0, ro) == -1 && errno == EPERM);
    fixed = address;
    CHECK(create_area("occupied", &fixed, 4096, RW | AREA_EXACT_ADDRESS, 0) == -1 && errno == EEXIST);
    CHECK(mmap(address, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) == MAP_FAILED && errno == EINVAL);
    CHECK(munmap(address, 4096) == -1 && errno == EINVAL);
    CHECK(mprotect(readonly, 4096, PROT_READ | PROT_WRITE) == -1 && errno == EINVAL);
    CHECK(mremap(address, 12288, 12288, 0) == MAP_FAILED && errno == EINVAL);
    reply = create_port("area-read-only-check", 1);
    CHECK(reply > 0);
    value = 0x31415926U;
    CHECK(send_msg_x(reply, 9, &value, sizeof(value), 0) == 0);
    CHECK(get_msg_x(reply, &code, readonly, sizeof(value), 0) == -1 && errno == EFAULT);
    CHECK(get_msg_x(reply, &code, &value, sizeof(value), 0) == 0 && code == 9 && value == 0x31415926U);
    CHECK(delete_port(reply) == 0);
    CHECK(remap_area(id, (void *)0x80000000U) == -1 && errno == EPERM);
    CHECK(delete_area(id) == 0 && ((uint32_t *)other)[3071] == 0xcafebabeU);
    CHECK(delete_area(alias) == 0 && ((uint32_t *)readonly)[0] == 0x12345678U);
    CHECK(delete_area(ro) == 0 && empty());
    old = id;
    fixed = (void *)(CARIBE_AREA_BASE + 0x1000U);
    id = create_area("exact", &fixed, 4096, RW | AREA_EXACT_ADDRESS, 0);
    CHECK(id > 0 && id != old && (uintptr_t)fixed == CARIBE_AREA_BASE + 0x1000U);
    CHECK(get_area_info(old, &info) == -1 && errno == ENOENT);
    CHECK(delete_area(id) == 0);
    /* Copyout failure must undo the entire new mapping and backing allocation. */
    bad = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    CHECK(bad != MAP_FAILED);
    arg = request(CARIBE_AREA_CREATE); arg.size = 8192; arg.protection = RW;
    strcpy(arg.name, "copyout-rollback"); memcpy(bad, &arg, sizeof(arg));
    CHECK(mprotect(bad, 4096, PROT_READ) == 0);
    CHECK(ioctl(control, CARIBE_AREA_CALL, bad) == -1 && errno == EFAULT);
    CHECK(empty() && munmap(bad, 4096) == 0);
    puts("[native-area-gate-A] shared backing permissions no-escalation reserved-VA copyout-rollback zeroing PASS");

    for (i = 0; i < CARIBE_AREA_MAX_OBJECTS; i++) {
        address = 0; ids[i] = create_area("objects", &address, 4096, RW, 0);
        CHECK(ids[i] > 0);
    }
    address = 0;
    CHECK(create_area("object-overflow", &address, 4096, RW, 0) == -1 && errno == ENOSPC);
    for (i = CARIBE_AREA_MAX_OBJECTS; i < CARIBE_AREA_MAX_VIEWS; i++) {
        address = 0; ids[i] = clone_area("views", &address, RW, 0, ids[0]);
        CHECK(ids[i] > 0);
    }
    CHECK(clone_area("view-overflow", &address, RW, 0, ids[0]) == -1 && errno == ENOSPC);
    after = stats();
    CHECK(after.objects == 32 && after.views == 64 && after.pages == 32);
    /* Fork cannot silently omit views when the global view table is full. */
    CHECK(fork() == -1 && errno == EAGAIN);
    for (i = 0; i < CARIBE_AREA_MAX_VIEWS; i++) CHECK(delete_area(ids[i]) == 0);
    for (i = 0; i < 2; i++) {
        address = 0; ids[i] = create_area("page-pool", &address, 512 * 4096, RW, 0);
        CHECK(ids[i] > 0); memset(address, 0xa5, 512 * 4096);
    }
    address = 0;
    CHECK(create_area("page-overflow", &address, 4096, RW, 0) == -1 && errno == ENOMEM);
    CHECK(stats().pages == 1024);
    CHECK(delete_area(ids[0]) == 0 && delete_area(ids[1]) == 0);
    for (i = 0; i < 256; i++) {
        address = 0; id = create_area("recycled", &address, 4096, RW, 0);
        CHECK(id > 0 && ((uint32_t *)address)[0] == 0 && ((uint32_t *)address)[1023] == 0);
        memset(address, 0x75, 4096); CHECK(delete_area(id) == 0);
    }
    CHECK(empty());
    puts("[native-area-gate-B] objects=32 views=64 pages=1024 exhaustion fork-rollback recycling=256 zero-leak PASS");

    address = 0; id = create_area("fork-inherited", &address, 8193, RW, 0);
    CHECK(id > 0); words = address; words[0] = 0;
    child = fork(); CHECK(child >= 0);
    if (!child) {
        CHECK(get_area_info(id, &info) == 0 && info.pAddress == address && info.hProcess == getpid());
        words[0] = 0x72763132U; __sync_synchronize();
        CHECK(execl("/does-not-exist", "missing", (char *)0) == -1 && errno == ENOENT);
        CHECK(get_area_info(id, &info) == 0 && words[0] == 0x72763132U);
        snprintf(id_arg, sizeof(id_arg), "%d", id);
        execl("/bin/native-area-probe", "native-area-probe", "check-exec", id_arg, (char *)0);
        _exit(91);
    }
    CHECK(child_ok(child)); __sync_synchronize();
    CHECK(words[0] == 0x72763132U);
    after = stats(); CHECK(after.objects == 1 && after.views == 1 && after.pages == 3);
    CHECK(delete_area(id) == 0 && empty());
    puts("[native-area-gate-C] fork same-ID same-VA shared writes failed-exec-preserves successful-exec-revokes PASS");

    address = 0; id = create_area("cross-exec", &address, 32768, RW, 0);
    CHECK(id > 0); packet = address; packet->guard = 0xabcdef98U;
    reply = create_port("area-parent-sync", 1); CHECK(reply > 0);
    snprintf(id_arg, sizeof(id_arg), "%d", id); snprintf(reply_arg, sizeof(reply_arg), "%d", reply);
    child = fork(); CHECK(child >= 0);
    if (!child) {
        execl("/bin/native-area-probe", "native-area-probe", "peer", id_arg, reply_arg, (char *)0);
        _exit(92);
    }
    CHECK(get_msg_x(reply, &code, &ready, sizeof(ready), 5000000) == 0 && code == 0);
    for (seq = 1; seq <= ROUNDS; seq++) {
        packet->sequence = seq; packet->value = seq * 37U; packet->answer = 0;
        __sync_synchronize();
        CHECK(send_msg_x(ready.port, seq, 0, 0, 5000000) == 0);
        CHECK(get_msg_x(reply, &code, 0, 0, 5000000) == 0 && code == seq);
        __sync_synchronize(); CHECK(packet->answer == (seq ^ 0x71358246U));
    }
    other = 0; alias = clone_area("retained-after-creator", &other, RW, 0, ready.area);
    CHECK(alias > 0 && delete_area(id) == 0);
    packet = other; CHECK(packet->guard == 0xabcdef98U);
    CHECK(send_msg_x(ready.port, ROUNDS + 1, 0, 0, 5000000) == 0 && child_ok(child));
    CHECK(packet->answer == (ROUNDS ^ 0x71358246U));
    after = stats(); CHECK(after.objects == 1 && after.views == 1 && after.pages == 8);
    CHECK(delete_area(alias) == 0 && delete_port(reply) == 0 && empty());
    printf("[native-area-gate-D] independent-exec shared-memory rounds=%u creator-delete live-view-retained exit-cleanup PASS\n", ROUNDS);

    address = 0; id = create_area("shared-scanout", &address, 800 * 600 * 4, RW, AREA_FULL_LOCK);
    CHECK(id > 0);
    child = fork(); CHECK(child >= 0);
    if (!child) {
        unsigned x, y;
        uint32_t *pixels = address;
        for (y = 0; y < 600; y++) for (x = 0; x < 800; x++)
            pixels[y * 800 + x] = ((x & 255U) << 16) | ((y & 255U) << 8) | ((x ^ y) & 255U);
        __sync_synchronize();
        _exit(0);
    }
    CHECK(child_ok(child)); __sync_synchronize();
    {
        struct caribe_gfx_mode mode;
        struct caribe_gfx_blit blit;
        int gfx = open("/dev/caribe-graphics", O_RDWR | O_CLOEXEC);
        CHECK(gfx >= 0 && ioctl(gfx, CARIBE_GFX_GET_MODE, &mode) == 0);
        CHECK(mode.width == 800 && mode.height == 600);
        memset(&blit, 0, sizeof(blit)); blit.abi = CARIBE_GFX_ABI;
        blit.width = 800; blit.height = 600; blit.stride = 3200;
        blit.pixels = (uint32_t)(uintptr_t)address;
        CHECK(ioctl(gfx, CARIBE_GFX_BLIT, &blit) == 0 && ioctl(gfx, CARIBE_GFX_PRESENT, 0) == 0);
        CHECK(close(gfx) == 0);
    }
    CHECK(delete_area(id) == 0 && empty());
    puts("[native-area-gate-E] child-rendered shared framebuffer 800x600 GPU presented zero-leak PASS");
    puts("[native-area] gates A-E PASS; real shared Sv32 pages, no Wayland/X11");
    return 0;
}
int main(int argc, char **argv)
{
    setvbuf(stdout, 0, _IONBF, 0);
    control = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC); CHECK(control >= 0);
    if (argc == 4 && !strcmp(argv[1], "peer")) return peer(atoi(argv[2]), atoi(argv[3]));
    if (argc == 3 && !strcmp(argv[1], "check-exec")) {
        AreaInfo_s info;
        CHECK(get_area_info(atoi(argv[2]), &info) == -1 && errno == EPERM);
        CHECK(stats().objects == 1 && stats().views == 1 && stats().pages == 3);
        return 0;
    }
    return gates();
}
