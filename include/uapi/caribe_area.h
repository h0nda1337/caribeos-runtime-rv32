/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original CaribeOS native shared-area ABI.
 */
#ifndef CARIBE_NATIVE_AREA_H
#define CARIBE_NATIVE_AREA_H
#include <stdint.h>
#define CARIBE_AREA_ABI 0x00010000U
#define CARIBE_AREA_CALL 0xc0804101U
#define CARIBE_AREA_CREATE 1U
#define CARIBE_AREA_CLONE 2U
#define CARIBE_AREA_DELETE 3U
#define CARIBE_AREA_INFO 4U
#define CARIBE_AREA_STATS 5U
#define CARIBE_AREA_MAX_OBJECTS 32U
#define CARIBE_AREA_MAX_VIEWS 64U
#define CARIBE_AREA_POOL_PAGES 1024U
#define CARIBE_AREA_MAX_PAGES 512U
#define CARIBE_AREA_BASE 0x68000000U
#define CARIBE_AREA_END 0x70000000U
#define CARIBE_AREA_SLOT_SIZE 0x00200000U
#define CARIBE_AREA_EXACT 1U
struct caribe_area_request {
    uint32_t abi, operation, id, source, address, size, protection, policy;
    uint32_t objects, views, pages, allocations, frees, reserved[3];
    char name[64];
};
typedef char caribe_area_abi_size[(sizeof(struct caribe_area_request) == 128) ? 1 : -1];
#endif
