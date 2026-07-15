#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

set -euo pipefail
cd /root/caribeos

# Compilar payload de diagnóstico virtio
clang --target=riscv32-unknown-elf -march=rv32imac -mabi=ilp32 \
  -nostdlib -ffreestanding -static \
  -Wl,--gc-sections -Wl,-T,rv32_payload.ld -Wl,--no-relax \
  -Wl,-e,payload_entry \
  payload_virtio_diag.c -o payload_virtio_diag.elf

echo "[readelf] Entry:"
readelf -h payload_virtio_diag.elf | grep -i 'Entry point' || true

# QEMU igual que antes, pero cargando el payload de diagnóstico
qemu-system-riscv32 -machine virt -m 256M -nographic \
  -bios default \
  -kernel /root/caribeos/build/caribe_rv32.elf \
  -device loader,file=/root/caribeos/payload_virtio_diag.elf,addr=0x88000000,force-raw=on \
  -drive if=none,file=/root/caribeos/hfsplus.img,format=raw,id=vd0 \
  -device virtio-blk-device,drive=vd0
