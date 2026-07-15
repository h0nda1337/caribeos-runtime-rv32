#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_debug_decl] añadiendo prototipo extern de kprintf..."

# Insertar la declaración al inicio del archivo (si ya está, no pasa nada malo)
sed -i '1iextern int kprintf(const char *fmt, ...);' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_debug_decl] listo. Ahora ejecuta: ./build_run.sh"
