#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

set -euo pipefail
mkdir -p build
QEMU="${QEMU:-qemu-system-riscv32}"

exec "$QEMU" \
  -M virt \
  -m 256 \
  -nographic \
  -serial stdio \
  -monitor none \
  -no-reboot \
  -no-shutdown \
  -bios default \
  -kernel build/caribe_rv32.elf \
  -drive if=none,file=hfsplus.img,format=raw,id=vd0 \
  -device virtio-blk-device,drive=vd0
