#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "=== Buscar el log de '[ramdisk] probe LBA2' ==="
grep -n '\[ramdisk] probe LBA2' payload_hfsplus_boot.c || echo "(no aparece el log de probe LBA2)"

echo
echo "=== Buscar el log de '[ramdisk] read LBA2 OK, sig=' ==="
grep -n '\[ramdisk] read LBA2 OK, sig=' payload_hfsplus_boot.c || echo "(no aparece el log de LBA2 OK)"

echo
echo "=== Contexto amplio alrededor de cada uno ==="
LINES=$(grep -n '\[ramdisk] probe LBA2' payload_hfsplus_boot.c 2>/dev/null | cut -d: -f1 || true)

if [ -z "$LINES" ]; then
  echo "(no hay líneas con '[ramdisk] probe LBA2' para mostrar contexto)"
else
  for l in $LINES; do
    echo
    echo "--- contexto alrededor de la línea $l ---"
    sed -n "$((l-40)),$((l+40))p" payload_hfsplus_boot.c
    echo "----------------------------------------"
  done
fi
