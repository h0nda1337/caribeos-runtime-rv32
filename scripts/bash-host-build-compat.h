/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef CARIBE_BASH_HOST_BUILD_COMPAT_H
#define CARIBE_BASH_HOST_BUILD_COMPAT_H

#if defined(_WIN32) && !defined(__CYGWIN__)
#include <direct.h>
#include <io.h>
#include <unistd.h>

static __inline int
caribe_bash_host_mkdir(const char *path, int mode)
{
    (void)mode;
    return _mkdir(path);
}

#define mkdir(path, mode) caribe_bash_host_mkdir((path), (mode))
#endif

#endif
