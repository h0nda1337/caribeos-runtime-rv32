/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Scoped compatibility umbrella over actual public/native API headers.
 * No kernel implementation or successful unsupported-operation stub is supplied.
 */
#ifndef CARIBE_SERVER_PLATFORM_KERNEL_H
#define CARIBE_SERVER_PLATFORM_KERNEL_H
#include <atheos/types.h>
#include <atheos/threads.h>
#include <atheos/msgport.h>
#include <atheos/semaphore.h>
#include <atheos/areas.h>
#include <atheos/time.h>
#include <atheos/sysinfo.h>
#include <atheos/kdebug.h>
#include <atheos/filesystem.h>
#include <atheos/power.h>
#ifndef EOK
#define EOK 0
#endif
#endif
