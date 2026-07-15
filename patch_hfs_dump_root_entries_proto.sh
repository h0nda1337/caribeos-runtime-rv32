#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_dump_root_entries_proto] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_dump_root_entries_proto] añadiendo prototipo de hfsplus_dump_root_entries() tras el include de virtio_blk_legacy.h..."
if ! grep -q 'static void hfsplus_dump_root_entries(void);' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /"virtio_blk_legacy.h"/) {
        print "";
        print "/* Prototipo para hfsplus_dump_root_entries() (debug catálogo HFS+) */";
        print "static void hfsplus_dump_root_entries(void);";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (prototipo ya existe, no se duplica)"
fi

echo "[patch_hfs_dump_root_entries_proto] listo. Ahora ejecuta: ./build_run.sh"
