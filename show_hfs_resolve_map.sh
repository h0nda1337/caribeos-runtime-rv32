#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "=== Limpieza rápida de BOM/CRLF en payload_hfsplus_boot.c ==="
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo
echo "=== grep 'hfsplus_read_file' ==="
grep -n 'hfsplus_read_file' payload_hfsplus_boot.c || echo "(no aparece 'hfsplus_read_file' en el archivo)"

echo
echo "=== grep 'no se resolvio' ==="
grep -n 'no se resolvio' payload_hfsplus_boot.c || echo "(no aparece el texto 'no se resolvio')"

echo
echo "=== grep 'hfsplus_' (vista rápida de helpers HFS+) ==="
grep -n 'hfsplus_' payload_hfsplus_boot.c || echo "(no hay símbolos hfsplus_ visibles)"

echo
echo "=== Contexto alrededor de 'hfsplus_read_file' ==="
RF_LINES=$(grep -n 'hfsplus_read_file' payload_hfsplus_boot.c 2>/dev/null | cut -d: -f1 || true)
if [ -z "$RF_LINES" ]; then
  echo "(no hay líneas con 'hfsplus_read_file' para mostrar contexto)"
else
  for l in $RF_LINES; do
    echo
    echo "--- contexto alrededor de la línea $l ---"
    sed -n "$((l-20)),$((l+40))p" payload_hfsplus_boot.c
    echo "----------------------------------------"
  done
fi

echo
echo "=== Contexto alrededor de 'no se resolvio' ==="
NSR_LINES=$(grep -n 'no se resolvio' payload_hfsplus_boot.c 2>/dev/null | cut -d: -f1 || true)
if [ -z "$NSR_LINES" ]; then
  echo "(no hay líneas con 'no se resolvio' para mostrar contexto)"
else
  for l in $NSR_LINES; do
    echo
    echo "--- contexto alrededor de la línea $l ---"
    sed -n "$((l-20)),$((l+40))p" payload_hfsplus_boot.c
    echo "----------------------------------------"
  done
fi
