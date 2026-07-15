#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

set -e

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace_root=$(CDPATH= cd -- "$project_root/../.." && pwd)
sysroot=${CARIBE_MUSL_SYSROOT:-$project_root/build/musl-rv32-sysroot}
cc=${CARIBE_RISCV32_CC:-riscv64-unknown-elf-gcc}
bundled_bin="$workspace_root/msys64/ucrt64/bin"

if [ -d "$bundled_bin" ]; then
    PATH="$bundled_bin:$PATH"
    export PATH
fi

if ! command -v "$cc" >/dev/null 2>&1; then
    bundled_cc="$bundled_bin/$cc"
    if [ -x "$bundled_cc" ]; then
        cc=$bundled_cc
    fi
fi

if [ "$#" -eq 1 ] && [ "$1" = "-dumpmachine" ]; then
    printf '%s\n' riscv32-linux-musl
    exit 0
fi

if [ ! -r "$sysroot/usr/lib/libc.a" ]; then
    printf '%s\n' "riscv32-musl-gcc: missing sysroot at $sysroot" >&2
    exit 1
fi

common=(
    -march=rv32imac_zicsr_zifencei
    -mabi=ilp32
    -fcommon
    -fno-stack-protector
    -nostdinc
    -isystem "$sysroot/usr/include"
)

link=yes
args=()
for arg in "$@"; do
    case "$arg" in
        -c|-E|-S|-M|-MM|-fsyntax-only)
            link=no
            args+=("$arg")
            ;;
        -rdynamic)
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

if [ "$link" = no ]; then
    exec "$cc" "${common[@]}" "${args[@]}"
fi

exec "$cc" "${common[@]}" \
    -nostdlib -static -Wl,--no-relax -Wl,--gc-sections \
    "$sysroot/usr/lib/crt1.o" "$sysroot/usr/lib/crti.o" \
    "${args[@]}" -L"$sysroot/usr/lib" \
    -Wl,--start-group -lc -lgcc -Wl,--end-group \
    "$sysroot/usr/lib/crtn.o"
