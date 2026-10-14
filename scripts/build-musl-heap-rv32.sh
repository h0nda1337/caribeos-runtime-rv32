#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workspace=$(CDPATH= cd -- "$root/../.." && pwd)
export PATH="$workspace/msys64/ucrt64/bin:$workspace/msys64/usr/bin:$PATH"
jobs=${1:-2}
source="$root/build/musl-heap-source/musl-1.2.5"
build="$root/build/musl-heap-rv32"
mkdir -p "$build"
cd "$build"
if [ ! -f config.mak ]; then
    CC='riscv64-unknown-elf-gcc -march=rv32imac_zicsr_zifencei -mabi=ilp32' \
        "$source/configure" --target=riscv32-linux-musl --disable-shared --prefix=/usr --syslibdir=/lib
fi
make -j"$jobs" AR='bash ../../scripts/riscv32-ar-response.sh' RANLIB=riscv64-unknown-elf-ranlib
make install DESTDIR=../musl-heap-rv32-sysroot AR='bash ../../scripts/riscv32-ar-response.sh' RANLIB=riscv64-unknown-elf-ranlib
