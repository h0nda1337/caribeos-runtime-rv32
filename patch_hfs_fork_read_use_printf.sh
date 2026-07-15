#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_use_printf] cambiando kprintf() por printf() en fork_read()..."

# Limpiar posibles BOM/CRLF raros
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

# 1) Cambiar todas las llamadas a kprintf(...) por printf(...)
perl -0pi -e 's/kprintf\(/printf(/g' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_use_printf] listo. Ahora ejecuta: ./build_run.sh"
