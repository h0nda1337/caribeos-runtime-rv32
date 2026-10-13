/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original Syllable shared-area bindings to native XNU objects and views.
 */
#include <atheos/areas.h>
#include <uapi/caribe_area.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int call(struct caribe_area_request *arg)
{
    int fd = open("/dev/caribe-ipc", O_RDWR | O_CLOEXEC);
    int result, error;
    if (fd < 0) return -1;
    result = ioctl(fd, CARIBE_AREA_CALL, arg);
    error = errno;
    close(fd);
    errno = error;
    return result;
}
static struct caribe_area_request request(uint32_t operation, area_id id)
{
    struct caribe_area_request arg;
    memset(&arg, 0, sizeof(arg));
    arg.abi = CARIBE_AREA_ABI;
    arg.operation = operation;
    arg.id = (uint32_t)id;
    return arg;
}
static area_id map(const char *name, void **address, size_t size,
    flags_t protection, flags_t locking, area_id source, int clone)
{
    struct caribe_area_request arg = request(clone ? CARIBE_AREA_CLONE : CARIBE_AREA_CREATE, 0);
    flags_t policy = protection & AREA_ADDR_SPEC_MASK;
    if (!name || !*name || strlen(name) >= sizeof(arg.name) || !address ||
        locking > AREA_FULL_LOCK ||
        (protection & ~(AREA_READ | AREA_WRITE | AREA_ADDR_SPEC_MASK)) ||
        (policy != AREA_ANY_ADDRESS && policy != AREA_EXACT_ADDRESS)) {
        errno = EINVAL;
        return -1;
    }
    memcpy(arg.name, name, strlen(name) + 1);
    arg.size = (uint32_t)size;
    arg.source = (uint32_t)source;
    arg.address = (uint32_t)(uintptr_t)*address;
    arg.protection = protection & (AREA_READ | AREA_WRITE);
    arg.policy = policy == AREA_EXACT_ADDRESS ? CARIBE_AREA_EXACT : 0;
    if (call(&arg)) return -1;
    *address = (void *)(uintptr_t)arg.address;
    return (area_id)arg.id;
}
area_id create_area(const char *name, void **address, size_t size, flags_t protection, flags_t locking)
{
    return map(name, address, size, protection, locking, 0, 0);
}
area_id clone_area(const char *name, void **address, flags_t protection, flags_t locking, area_id source)
{
    return map(name, address, 0, protection, locking, source, 1);
}
status_t delete_area(area_id id)
{
    struct caribe_area_request arg = request(CARIBE_AREA_DELETE, id);
    return call(&arg);
}
status_t get_area_info(area_id id, AreaInfo_s *info)
{
    struct caribe_area_request arg = request(CARIBE_AREA_INFO, id);
    if (!info) { errno = EINVAL; return -1; }
    if (call(&arg)) return -1;
    memset(info, 0, sizeof(*info));
    memcpy(info->zName, arg.name, sizeof(info->zName));
    info->hAreaID = id;
    info->nSize = info->nAllocSize = arg.size;
    info->nLock = AREA_FULL_LOCK;
    info->nProtection = arg.protection;
    info->hProcess = getpid();
    info->pAddress = (void *)(uintptr_t)arg.address;
    return 0;
}
status_t remap_area(area_id id, void *physical)
{
    (void)id;
    (void)physical;
    errno = EPERM;
    return -1;
}
