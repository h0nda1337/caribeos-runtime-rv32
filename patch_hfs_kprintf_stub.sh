#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_kprintf_stub] reemplazando 'extern kprintf' por stub estático..."

# Reemplazar la PRIMERA línea que empiece con 'extern int kprintf'
# por una implementación estática mínima que no hace nada.
sed -i '0,/^extern int kprintf/s/^extern int kprintf.*/static int kprintf(const char *fmt, ...){ (void)fmt; return 0; }/' payload_hfsplus_boot.c

echo "[patch_hfs_kprintf_stub] listo. Ahora ejecuta: ./build_run.sh"
