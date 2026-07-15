#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "=== grep 'find_cnid_by_path' en payload_hfsplus_boot.c ==="
grep -n 'find_cnid_by_path' payload_hfsplus_boot.c || echo "(no aparece)"

echo
echo "=== contexto extenso alrededor de la DEFINICIÓN de find_cnid_by_path ==="

# Intento 1: prototipo típico
START=$(grep -n 'find_cnid_by_path(' payload_hfsplus_boot.c | head -n1 | cut -d: -f1 || true)

if [ -z "$START" ]; then
  echo "(no encontré la cabecera de la función)"
else
  # Imprime 80 líneas alrededor para ver la función casi completa
  sed -n "$((START-10)),$((START+120))p" payload_hfsplus_boot.c
fi
