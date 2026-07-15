#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_call_debug_from_dump] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_call_debug_from_dump] insertando llamada a hfsplus_debug_cat_first_blocks() al inicio de hfsplus_dump_root_entries()..."

# Sólo si aún no hay llamada explícita
if ! grep -q 'hfsplus_debug_cat_first_blocks();' payload_hfsplus_boot.c; then
  awk '
    BEGIN { inserted = 0; }
    {
      if (!inserted && $0 ~ /static void hfsplus_dump_root_entries\(void\)\{/){
        print;
        print "    hfsplus_debug_cat_first_blocks();";
        inserted = 1;
      } else {
        print;
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new

  mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya existe una llamada a hfsplus_debug_cat_first_blocks();, no se inserta otra)"
fi

echo "[patch_hfs_call_debug_from_dump] listo. Ahora ejecuta: ./build_run.sh"
