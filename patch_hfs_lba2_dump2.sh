#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_lba2_dump2] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_lba2_dump2] añadiendo hfs_hexdump2() si no existe..."
if ! grep -q 'hfs_hexdump2(const uint8_t*' payload_hfsplus_boot.c; then
  cat >> payload_hfsplus_boot.c <<'EOC'

/* === Debug: hexdump directo de lo que ve HFS+ en sec[] === */
static void hfs_hexdump2(const uint8_t* p, uint32_t len){
    const char *D = "0123456789abcdef";
    for (uint32_t i = 0; i < len; i++){
        if ((i % 16) == 0){
            puts("\r\n");
        }
        uint8_t v = p[i];
        putc(D[(v >> 4) & 0xF]);
        putc(D[v & 0xF]);
        putc(' ');
    }
    puts("\r\n");
}
EOC
fi

echo "[patch_hfs_lba2_dump2] enganchando hfs_hexdump2() después del log de LBA2..."
if ! grep -q 'hfs_hexdump2(sec, 64);' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /puts\("\\[ramdisk] read LBA2 OK, sig="/) {
        print "    hfs_hexdump2(sec, 64);";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya hay llamada a hfs_hexdump2(sec, 64);, no se duplica)"
fi

echo "[patch_hfs_lba2_dump2] listo. Ahora ejecuta: ./build_run.sh"
