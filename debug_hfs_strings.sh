#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[debug] Buscando referencias a kernel/mach_kernel en payload_hfsplus_boot.c..."
grep -n "kernel.elf" payload_hfsplus_boot.c || true
grep -n "mach_kernel" payload_hfsplus_boot.c || true
grep -n "fallo leyendo kernel" payload_hfsplus_boot.c || true
grep -n "Boot.plist" payload_hfsplus_boot.c || true
