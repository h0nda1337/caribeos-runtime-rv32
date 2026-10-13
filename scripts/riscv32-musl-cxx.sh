#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
set -e
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace=$(CDPATH= cd -- "$root/../.." && pwd)
PATH="$workspace/msys64/ucrt64/bin:$PATH"
export PATH
sysroot=${CARIBE_MUSL_SYSROOT:-$root/build/musl-rv32-sysroot}
cxx=${CARIBE_RISCV32_CXX:-riscv64-unknown-elf-g++}
if [ "$#" -eq 1 ] && [ "$1" = -dumpmachine ]; then
    printf '%s\n' riscv32-unknown-linux-musl
    exit 0
fi
compiler_include=$("$cxx" -print-file-name=include)
common=(-march=rv32imac_zicsr_zifencei -mabi=ilp32 -fno-stack-protector
    -nostdinc -nostdinc++ -isystem "$sysroot/usr/include" -idirafter "$compiler_include")
link=yes
for arg in "$@"; do
    case "$arg" in -c|-E|-S|-M|-MM|-fsyntax-only) link=no ;; esac
done
if [ "$link" = no ]; then
    exec "$cxx" "${common[@]}" "$@"
fi
crtbegin=$("$cxx" -march=rv32imac_zicsr_zifencei -mabi=ilp32 -print-file-name=crtbegin.o)
crtend=$("$cxx" -march=rv32imac_zicsr_zifencei -mabi=ilp32 -print-file-name=crtend.o)
exec "$cxx" "${common[@]}" -nostdlib -static -Wl,--no-relax \
    "$sysroot/usr/lib/crt1.o" "$sysroot/usr/lib/crti.o" "$crtbegin" \
    "$@" -L"$sysroot/usr/lib" -Wl,--start-group -lc -lgcc -Wl,--end-group \
    "$crtend" "$sysroot/usr/lib/crtn.o"
