/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Original musl/RV32 type adapter for the public Syllable API.
 */
#ifndef CARIBE_SYLLABLE_TYPES_H
#define CARIBE_SYLLABLE_TYPES_H
#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>
#ifndef __cplusplus
#include <stdbool.h>
#endif
#define OS_NAME_LENGTH 64
#define INFINITE_TIMEOUT INT64_MAX
typedef int32_t status_t;
typedef int32_t port_id;
typedef int32_t proc_id;
typedef int32_t thread_id;
typedef int32_t area_id;
typedef int32_t sem_id;
typedef uint32_t flags_t;
typedef int64_t bigtime_t;
typedef uint32_t uint32;
typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint64_t uint64;
typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;
typedef unsigned int uint;
#endif
