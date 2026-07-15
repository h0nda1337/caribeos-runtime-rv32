#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

set -euo pipefail

mkdir -p build

# Extract the DTB QEMU uses for the rv32 virt machine.
qemu-system-riscv32 -machine dumpdtb=build/virt.dtb -display none -nodefaults -S || true

# Convert it to a C array. Some MSYS installations do not include xxd.
if command -v xxd >/dev/null 2>&1; then
  xxd -i build/virt.dtb > mfw/virt_dtb.c
  sed -i 's/unsigned char build_virt_dtb/unsigned char virt_dtb/g' mfw/virt_dtb.c || true
  sed -i 's/unsigned int build_virt_dtb_len/unsigned int virt_dtb_len/g' mfw/virt_dtb.c || true
else
  PYTHON_BIN="${PYTHON:-}"
  if [ -z "$PYTHON_BIN" ]; then
    PYTHON_BIN="$(command -v python3 || command -v python)"
  fi
  "$PYTHON_BIN" scripts/bin2c.py build/virt.dtb virt_dtb > mfw/virt_dtb.c
fi

echo "[ok] mfw/virt_dtb.c generated."
