#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_step4] Limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c || true

echo "[patch_step4] Asegurando include de virtio_blk_legacy.h..."
if ! grep -q 'virtio_blk_legacy.h' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /^#include <stdint.h>/) {
        print "#include \"virtio_blk_legacy.h\"";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya existe include de virtio_blk_legacy.h, se deja igual)"
fi

echo "[patch_step4] Insertando wrapper disk_read() si no existe..."
if ! grep -q 'disk_read(uint64_t lba' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /#include "virtio_blk_legacy.h"/) {
        print "";
        print "static int disk_read(uint64_t lba, uint32_t count, void *buf) {";
        print "    return virtio_blk_read_blocks(lba, count, buf);";
        print "}";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (disk_read() ya existe, no se duplica)"
fi

echo "[patch_step4] Insertando llamada a virtio_blk_init() tras el banner HFS+ RAM..."
if ! grep -q 'virtio_blk_init()' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /CaribeBootX HFS\+ RAM/) {
        print "    if (virtio_blk_init() != 0) {";
        print "        puts(\"[boot] virtio_blk_init FAIL\\r\\n\");";
        print "        for(;;){}";
        print "    }";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (virtio_blk_init() ya está referenciado, no se duplica)"
fi

echo "[patch_step4] Listo. Ahora ejecuta:  ./build_run.sh"
