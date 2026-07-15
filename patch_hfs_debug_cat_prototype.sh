#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_debug_cat_prototype] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_debug_cat_prototype] añadiendo prototipo de hfsplus_debug_cat_first_blocks() al inicio..."

# Si ya existe el prototipo, no hacemos nada
if grep -q 'hfsplus_debug_cat_first_blocks(void);' payload_hfsplus_boot.c; then
  echo "  (prototipo ya existe, nada que hacer)"
else
  awk '
    BEGIN { done = 0; }
    {
      # En la primera línea que parezca declaración/definición "static ...(...)" insertamos el prototipo antes
      if (!done && $0 ~ /static/ && $0 ~ /\(/ && $0 ~ /\)/) {
        print "static void hfsplus_debug_cat_first_blocks(void);";
        print;
        done = 1;
      } else {
        print;
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new

  mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
fi

echo "[patch_hfs_debug_cat_prototype] listo. Ahora ejecuta: ./build_run.sh"
