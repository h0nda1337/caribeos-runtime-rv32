#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace=$(CDPATH= cd -- "$root/../.." && pwd)
export PATH="$workspace/msys64/ucrt64/bin:$workspace/msys64/usr/bin:$PATH"
jobs=${1:-4}
recompile=${2:-0}
build="$root/build/libstdcxx-rv32-musl"
prefix="$root/build/cxx-rv32-sysroot/usr"
source="$root/third_party/gcc-15.1.0/libstdc++-v3"
version=$(riscv64-unknown-elf-g++ -dumpfullversion)
test "$version" = 15.1.0 || { echo "GNU source/compiler version mismatch: $version" >&2; exit 1; }
test -f "$root/build/musl-rv32-sysroot/usr/lib/libc.a"
mkdir -p "$build" "$prefix"
cd "$build"
if [ -f config.status ] && [ ! -f src/Makefile ]; then
    bash ./config.status
fi
if [ ! -f src/Makefile ]; then
    CC="bash $script_dir/riscv32-musl-gcc.sh" \
    CXX="bash $script_dir/riscv32-musl-cxx.sh" \
    AR=riscv64-unknown-elf-ar RANLIB=riscv64-unknown-elf-ranlib \
    CFLAGS='-O2 -ffunction-sections -fdata-sections' \
    CXXFLAGS='-O2 -ffunction-sections -fdata-sections' \
    bash "$source/configure" --host=riscv32-unknown-linux-musl \
        --build=x86_64-pc-msys --prefix="$prefix" \
        --disable-shared --enable-static --disable-multilib --disable-nls \
        --disable-libstdcxx-threads --disable-libstdcxx-pch \
        --disable-libstdcxx-backtrace --disable-libstdcxx-filesystem-ts \
        --enable-clocale=generic --enable-libstdcxx-time=yes --disable-symvers \
        --with-libstdcxx-zoneinfo=no
fi
if [ "$recompile" = 1 ]; then
    make -C libsupc++ -W "$source/libsupc++/eh_alloc.cc" \
        -W "$source/libsupc++/new_op.cc" eh_alloc.lo new_op.lo
    make -C src/c++11 -W "$source/src/c++11/string-inst.cc" string-inst.lo
fi
make -j"$jobs"
make install
test -f "$prefix/lib/rv32imac/ilp32/libstdc++.a"
echo 'PASS GNU libstdc++ built against RV32-musl; single-thread model, native threads not claimed'
