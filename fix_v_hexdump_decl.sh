#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[fix_v_hexdump_decl] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' virtio_blk_legacy.c 2>/dev/null || true

echo "[fix_v_hexdump_decl] insertando prototipo de v_hexdump() si falta..."

if ! grep -q 'v_hexdump(const uint8_t* p, uint32_t len);' virtio_blk_legacy.c; then
  sed -i '/#include "virtio_blk_legacy.h"/a static void v_hexdump(const uint8_t* p, uint32_t len);' virtio_blk_legacy.c
else
  echo "  (prototipo de v_hexdump() ya existe, no se duplica)"
fi

echo "[fix_v_hexdump_decl] listo. Ahora ejecuta: ./build_run.sh"
