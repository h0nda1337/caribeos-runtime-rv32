#!/usr/bin/env bash
set -euo pipefail

real_ar="${RISCV32_AR_REAL:-riscv64-unknown-elf-ar}"

if (( $# < 3 || $# < 96 )); then
    exec "$real_ar" "$@"
fi

operation=$1
archive=$2
shift 2

response_file=".riscv32-ar-$$.rsp"
trap 'rm -f "$response_file"' EXIT
printf '%s\n' "$@" > "$response_file"

"$real_ar" "$operation" "$archive" "@$response_file"
