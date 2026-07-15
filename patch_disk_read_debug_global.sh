#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_disk_read_debug_global] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_disk_read_debug_global] limpiando restos de hfs_hexdump2(sec, 64)..."
sed -i '/hfs_hexdump2(sec, 64);/d' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_disk_read_debug_global] asegurando include de virtio_blk_legacy.h..."
if ! grep -q 'virtio_blk_legacy.h' payload_hfsplus_boot.c; then
  awk '{
    print;
    if ($0 ~ /^#include <stdint.h>/) {
      print "#include \"virtio_blk_legacy.h\"";
    }
  }' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya existe el include, se deja igual)"
fi

echo "[patch_disk_read_debug_global] insertando definicion de hfs_hexdump2() si no existe..."
if ! grep -q 'hfs_hexdump2(const uint8_t*' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /virtio_blk_legacy.h"/) {
        print "";
        print "/* === Debug: hexdump directo de lo que ve disk_read() en buf === */";
        print "static void hfs_hexdump2(const uint8_t* p, uint32_t len){";
        print "    const char *D = \"0123456789abcdef\";";
        print "    for (uint32_t i = 0; i < len; i++){";
        print "        if ((i % 16) == 0){";
        print "            puts(\"\\r\\n\");";
        print "        }";
        print "        uint8_t v = p[i];";
        print "        putc(D[(v >> 4) & 0xF]);";
        print "        putc(D[v & 0xF]);";
        print "        putc(' ');";
        print "    }";
        print "    puts(\"\\r\\n\");";
        print "}";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (hfs_hexdump2() ya existe, no se duplica)"
fi

echo "[patch_disk_read_debug_global] parcheando cuerpo de disk_read() override..."
if grep -q 'static int disk_read(uint64_t lba, uint32_t count, void *buf)' payload_hfsplus_boot.c; then
  sed -i $'/return virtio_blk_read_blocks(lba, count, buf);/c\
    int rc = virtio_blk_read_blocks(lba, count, buf);\
    if (rc == 0) {\
        puts("[disk_read debug] LBA=");\
        putu32((uint32_t)lba);\
        puts(" count=");\
        putu32(count);\
        puts("\\r\\n");\
        hfs_hexdump2((const uint8_t*)buf, 64);\
    }\
    return rc;' payload_hfsplus_boot.c
else
  echo "  [WARN] No encontré 'static int disk_read(uint64_t lba, uint32_t count, void *buf)' en payload_hfsplus_boot.c"
fi

echo "[patch_disk_read_debug_global] listo. Ahora ejecuta: ./build_run.sh"
