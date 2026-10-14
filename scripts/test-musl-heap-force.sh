#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workspace=$(CDPATH= cd -- "$root/../.." && pwd)
export PATH="$workspace/msys64/ucrt64/bin:$workspace/msys64/usr/bin:$PATH"
source="$root/build/musl-heap-source/musl-1.2.5"
cd "$root/build/musl-heap-rv32"
make -j2 AR='bash ../../scripts/riscv32-ar-response.sh' RANLIB=riscv64-unknown-elf-ranlib \
    -W "$source/src/malloc/mallocng/malloc.c" -W "$source/src/malloc/mallocng/free.c" \
    -W "$source/src/malloc/mallocng/realloc.c" -W "$source/src/thread/__lock.c" \
    -W "$source/src/mman/mmap.c" -W "$source/src/mman/munmap.c"
make install DESTDIR=../musl-heap-rv32-sysroot AR='bash ../../scripts/riscv32-ar-response.sh' RANLIB=riscv64-unknown-elf-ranlib
