#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "=== Limpieza rápida de BOM/CRLF en payload_hfsplus_boot.c ==="
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo
echo "=== grep 'disk_read' en payload_hfsplus_boot.c ==="
grep -n 'disk_read' payload_hfsplus_boot.c || echo "(no aparece 'disk_read' en el archivo)"

echo
echo "=== grep 'virtio_blk_read_blocks' en payload_hfsplus_boot.c ==="
grep -n 'virtio_blk_read_blocks' payload_hfsplus_boot.c || echo "(no aparece 'virtio_blk_read_blocks' en el archivo)"

echo
echo "=== Contexto alrededor de cada 'disk_read' ==="
DISK_LINES=$(grep -n 'disk_read' payload_hfsplus_boot.c 2>/dev/null | cut -d: -f1 || true)
if [ -z "$DISK_LINES" ]; then
  echo "(no hay líneas con 'disk_read' para mostrar contexto)"
else
  for l in $DISK_LINES; do
    echo
    echo "--- contexto alrededor de la línea $l ---"
    sed -n "$((l-5)),$((l+12))p" payload_hfsplus_boot.c
    echo "----------------------------------------"
  done
fi

echo
echo "=== Contexto alrededor de cada 'virtio_blk_read_blocks' ==="
VIRT_LINES=$(grep -n 'virtio_blk_read_blocks' payload_hfsplus_boot.c 2>/dev/null | cut -d: -f1 || true)
if [ -z "$VIRT_LINES" ]; then
  echo "(no hay líneas con 'virtio_blk_read_blocks' para mostrar contexto)"
else
  for l in $VIRT_LINES; do
    echo
    echo "--- contexto alrededor de la línea $l ---"
    sed -n "$((l-5)),$((l+12))p" payload_hfsplus_boot.c
    echo "----------------------------------------"
  done
fi
