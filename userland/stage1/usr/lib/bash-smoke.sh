#!/bin/bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause


printf '[gnu-bash] version=%s machine=%s\n' "$BASH_VERSION" "$MACHTYPE"

declare -a sequence=(3 5 8)
declare -A platform=([kernel]=XNU [abi]=Linux [arch]=riscv32)
sum=0
for value in "${sequence[@]}"; do
    ((sum += value))
done

caribe_report()
{
    local proof
    printf -v proof '%s/%s/%s:%d' \
        "${platform[kernel]}" "${platform[abi]}" "${platform[arch]}" "$sum"
    case "$proof" in
        XNU/Linux/riscv32:16)
            printf '[gnu-bash] builtins proof=%s\n' "$proof"
            ;;
        *)
            printf '[gnu-bash] FAIL proof=%s\n' "$proof"
            return 70
            ;;
    esac
}

if [[ ${platform[kernel]} == XNU && ${platform[abi]} == Linux && $sum -eq 16 ]]; then
    caribe_report || exit $?
else
    printf '[gnu-bash] FAIL conditional\n'
    exit 71
fi

printf '[gnu-bash] PASS arrays loops arithmetic functions conditionals case\n'
exec /bin/musl-probe --after-bash
printf '[gnu-bash] FAIL exec handoff\n'
exit 72
