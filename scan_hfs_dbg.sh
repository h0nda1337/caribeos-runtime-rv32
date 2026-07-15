#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

MNT=/mnt/hfs_dbg
IMG=/root/caribeos/hfsplus.img

mkdir -p "$MNT"

echo "[scan_hfs_dbg] comprobando si $MNT ya está montado..."
if mount | grep -q "on $MNT "; then
  echo "  -> $MNT ya está montado, lo uso tal cual."
else
  echo "  -> $MNT no está montado, monto $IMG en modo sólo lectura..."
  mount -t hfsplus -o loop,ro "$IMG" "$MNT"
fi

echo
echo "=== Contenido de la raíz de $MNT ==="
ls -la "$MNT" || echo "(ls falló)"

echo
echo "=== Búsqueda de Boot.plist y kernel.* (hasta profundidad 5) ==="
find "$MNT" -maxdepth 5 -type f \( \
  -iname "com.apple.Boot.plist" -o \
  -iname "*Boot.plist" -o \
  -iname "kernel.elf" -o \
  -iname "kernel" -o \
  -iname "mach_kernel" \
\) -printf "%p\n" || echo "(find no encontró nada)"

echo
echo "=== Árbol superficial (nivel hasta 2) ==="
find "$MNT" -maxdepth 2 -mindepth 1 -printf "%y %p\n" || echo "(find falló)"

echo
echo "[scan_hfs_dbg] listo (no desmonto para seguir depurando)."
