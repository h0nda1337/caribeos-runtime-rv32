#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_debug_cat_hexdump] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_debug_cat_hexdump] añadiendo hfsplus_debug_cat_first_blocks() si no existe..."
if ! grep -q 'hfsplus_debug_cat_first_blocks(void)' payload_hfsplus_boot.c; then
  cat >> payload_hfsplus_boot.c <<'EOC'

/* Debug extra: volcar los primeros bloques del catálogo HFS+ */
static void hfsplus_debug_cat_first_blocks(void){
    puts("[hfs+] debug_cat: size=");
    putu32((uint32_t)hv.cat.size);
    puts(" ext0.start=");
    putu32(hv.cat.ext[0].start);
    puts(" ext0.count=");
    putu32(hv.cat.ext[0].count);
    puts("\r\n");

    for (uint32_t i = 0; i < 4; i++){
        uint64_t off = (uint64_t)i * 4096;
        if (off >= hv.cat.size) break;
        if (fork_read(&hv.cat, off, secbuf, 4096)){
            puts("[hfs+] debug_cat: fork_read FAIL at off=");
            putu32((uint32_t)off);
            puts("\r\n");
            break;
        }
        puts("[hfs+] debug_cat: block#");
        putu32(i);
        puts("\r\n");
        hfs_hexdump(secbuf, 64);
    }
}
EOC
fi

echo "[patch_hfs_debug_cat_hexdump] enganchando llamada tras cat.ext 0..."
if ! grep -q 'hfsplus_debug_cat_first_blocks();' payload_hfsplus_boot.c; then
  awk '
    BEGIN { done = 0; }
    {
      if (!done && index($0, "cat.ext 0: start=") != 0) {
        print;
        print "    hfsplus_debug_cat_first_blocks();";
        print "";
        done = 1;
      } else {
        print;
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
fi

echo "[patch_hfs_debug_cat_hexdump] listo. Ahora ejecuta: ./build_run.sh"
