#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_disk_read_virtio] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_disk_read_virtio] asegurando include de virtio_blk_legacy.h..."
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

echo "[patch_disk_read_virtio] insertando wrapper disk_read() -> virtio_blk_read_blocks()..."
if ! grep -q 'disk_read(uint64_t lba' payload_hfsplus_boot.c; then
  cat >> payload_hfsplus_boot.c <<'EOC'

/* === Backend de lectura de bloques: usar virtio-blk legacy === */
static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    return virtio_blk_read_blocks(lba, count, buf);
}

EOC
else
  echo "  (disk_read() ya existe con esa firma, no se duplica)"
fi

echo "[patch_disk_read_virtio] insertando helper hfs_hexdump() si no existe..."
if ! grep -q 'hfs_hexdump(const uint8_t*' payload_hfsplus_boot.c; then
  cat >> payload_hfsplus_boot.c <<'EOC'

/* === Pequeño hexdump para depurar lo que llega de disco en HFS+ === */
static void hfs_hexdump(const uint8_t* p, uint32_t len){
    const char *D = "0123456789abcdef";
    for(uint32_t i=0;i<len;i++){
        if((i % 16)==0){
            puts("\r\n");
        }
        uint8_t v = p[i];
        putc(D[(v>>4)&0xF]);
        putc(D[v&0xF]);
        putc(' ');
    }
    puts("\r\n");
}

EOC
else
  echo "  (hfs_hexdump() ya existe, no se duplica)"
fi

echo "[patch_disk_read_virtio] enganchando hfs_hexdump() después del log de LBA2..."

if ! grep -q 'hfs_hexdump(sec, 64);' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /puts\("\\[ramdisk] read LBA2 OK, sig="\\);/) {
        in_sig_block=1;
      } else if (in_sig_block && $0 ~ /puts\("\\r\\n"\\);/) {
        print "    hfs_hexdump(sec, 64);";
        in_sig_block=0;
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya hay llamada a hfs_hexdump(sec, 64);, no se toca)"
fi

echo "[patch_disk_read_virtio] listo. Ahora ejecuta:  ./build_run.sh"
