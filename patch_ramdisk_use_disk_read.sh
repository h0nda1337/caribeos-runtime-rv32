#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_ramdisk_use_disk_read] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_ramdisk_use_disk_read] asegurando prototipo de disk_read()..."
if ! grep -q 'static int disk_read(uint64_t lba, uint32_t count, void *buf);' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /virtio_blk_legacy.h"/) {
        print "";
        print "/* Prototipo para poder usar disk_read() antes de su definición */";
        print "static int disk_read(uint64_t lba, uint32_t count, void *buf);";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya existe prototipo de disk_read(), se deja igual)"
fi

echo "[patch_ramdisk_use_disk_read] sustituyendo virtio_blk_read_sectors(2, 1, secbuf) -> disk_read(2, 1, secbuf)..."
if grep -q 'virtio_blk_read_sectors(2, 1, secbuf)' payload_hfsplus_boot.c; then
  sed -i 's/virtio_blk_read_sectors(2, 1, secbuf)/disk_read(2, 1, secbuf)/' payload_hfsplus_boot.c
else
  echo "  [WARN] No encontré la llamada exacta 'virtio_blk_read_sectors(2, 1, secbuf)'"
fi

echo "[patch_ramdisk_use_disk_read] listo. Ahora ejecuta: ./build_run.sh"
