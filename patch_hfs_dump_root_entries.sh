#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_dump_root_entries] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_dump_root_entries] añadiendo hfsplus_dump_root_entries() si no existe..."
if ! grep -q 'hfsplus_dump_root_entries(void)' payload_hfsplus_boot.c; then
  cat >> payload_hfsplus_boot.c <<'EOC'

/* Debug: volcar entradas del catálogo HFS+ (nombre, parent, tipo) */
static void hfsplus_dump_root_entries(void){
    if (fork_read(&hv.cat, 0, secbuf, 4096)){
        puts("[hfs+] dump_root: fork_read header FAIL\r\n");
        return;
    }
    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;
    if (nd->kind != 0x01){
        puts("[hfs+] dump_root: header kind!=1\r\n");
        return;
    }

    puts("[hfs+] dump_root: inicio\r\n");
    for (uint64_t off = 4096; off < hv.cat.size; off += 4096){
        if (fork_read(&hv.cat, off, secbuf, 4096)){
            puts("[hfs+] dump_root: fork_read FAIL\r\n");
            return;
        }
        BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;
        if (d->kind != 0xFF) continue;  /* sólo nodos hoja */

        uint16_t num = be16(d->numRecords);
        uint16_t* idxv = (uint16_t*)(secbuf + 4096 - 2 * (num + 1));

        for (int r = 0; r < num; r++){
            uint16_t rec_off = be16(idxv[r]);
            uint8_t* rec = secbuf + rec_off;

            HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;
            uint32_t parent = be32(key->parentID);
            uint16_t nlen   = be16(key->nameLen);
            const uint8_t* uname = rec + 2 + 4 + 2;
            char name[128];
            u16be_to_ascii(uname, nlen, name, 128);

            uint8_t* data  = rec + 2 + be16(key->keyLength);
            uint16_t rtype = be16(*(uint16_t*)data);

            puts("[hfs+] cat entry: parent=");
            putu32(parent);
            puts(" name='");
            puts(name);
            puts("' type=");
            putu32((uint32_t)rtype);
            puts("\r\n");
        }
    }
    puts("[hfs+] dump_root: fin\r\n");
}
EOC
else
  echo "  (hfsplus_dump_root_entries() ya existe, no se duplica)"
fi

echo "[patch_hfs_dump_root_entries] enganchando llamada tras hfsplus_mount()..."
if ! grep -q 'hfsplus_dump_root_entries();' payload_hfsplus_boot.c; then
  awk '
    BEGIN { done = 0; }
    {
      if (!done && $0 ~ /static uint8_t plist\[8192\];/) {
        print "    hfsplus_dump_root_entries();";
        print "";
        done = 1;
      }
      print;
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (ya hay llamada a hfsplus_dump_root_entries();, no se duplica)"
fi

echo "[patch_hfs_dump_root_entries] listo. Ahora ejecuta: ./build_run.sh"
