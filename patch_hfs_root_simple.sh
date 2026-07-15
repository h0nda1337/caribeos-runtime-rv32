#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_root_simple] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_root_simple] añadiendo hfsplus_find_root_file() si no existe..."
if ! grep -q 'hfsplus_find_root_file(const char* name' payload_hfsplus_boot.c; then
  awk '
    {
      print;
      if ($0 ~ /\/\* Lee un archivo completo de HFS\+ a memoria \*\//) {
        print "";
        print "/* Busca un archivo directamente en la raíz HFS+ (CNID=2) por nombre simple */";
        print "static int hfsplus_find_root_file(const char* name, ForkMeta* out_fork){";
        print "    uint32_t parent = 2; /* root CNID */";
        print "";
        print "    if (fork_read(&hv.cat, 0, secbuf, 4096)) return -1;";
        print "    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;";
        print "    if (nd->kind != 0x01){";
        print "        return -1;";
        print "    }";
        print "";
        print "    for (uint64_t off = 4096; off < hv.cat.size; off += 4096){";
        print "        if (fork_read(&hv.cat, off, secbuf, 4096)) return -1;";
        print "        BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;";
        print "        if (d->kind != 0xFF) continue;  /* nodos hoja */";
        print "";
        print "        uint16_t num = be16(d->numRecords);";
        print "        uint16_t* idxv = (uint16_t*)(secbuf + 4096 - 2 * (num + 1));";
        print "";
        print "        for (int r = 0; r < num; r++){";
        print "            uint16_t rec_off = be16(idxv[r]);";
        print "            uint8_t* rec = secbuf + rec_off;";
        print "";
        print "            HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;";
        print "            uint32_t p_id = be32(key->parentID);";
        print "            uint16_t nlen  = be16(key->nameLen);";
        print "            const uint8_t* uname = rec + 2 + 4 + 2;";
        print "            char tmp[128];";
        print "            u16be_to_ascii(uname, nlen, tmp, 128);";
        print "";
        print "            uint8_t* data  = rec + 2 + be16(key->keyLength);";
        print "            uint16_t rtype = be16(*(uint16_t*)data);";
        print "";
        print "            if (p_id == parent && rtype == 0x0002 && s_eq(tmp, name)){";
        print "                HFSPlusFileRecord* ff = (HFSPlusFileRecord*)data;";
        print "                if (out_fork){";
        print "                    out_fork->size = be64(ff->dataFork.logicalSize);";
        print "                    for (int i = 0; i < 8; i++){";
        print "                        out_fork->ext[i].start = be32(ff->dataFork.extents[i].startBlock);";
        print "                        out_fork->ext[i].count = be32(ff->dataFork.extents[i].blockCount);";
        print "                    }";
        print "                }";
        print "                return 0;";
        print "            }";
        print "        }";
        print "    }";
        print "";
        print "    return -1;";
        print "}";
        print "";
      }
    }
  ' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
else
  echo "  (hfsplus_find_root_file() ya existe, no se duplica)"
fi

echo "[patch_hfs_root_simple] reescribiendo hfsplus_read_file()..."
awk '
  BEGIN { in_fn=0; }
  {
    if ($0 ~ /static int hfsplus_read_file\(const char\* path, uint8_t\* dst, uint32_t cap, uint32_t\* out_sz\)\{/ && !in_fn) {
      in_fn=1;
      print "static int hfsplus_read_file(const char* path, uint8_t* dst, uint32_t cap, uint32_t* out_sz){";
      print "    ForkMeta fk;";
      print "    uint32_t cnid = 0;";
      print "";
      print "    /* Si la ruta es un nombre simple sin \x27/\x27, probar primero en la raíz HFS+ */";
      print "    int simple = 1;";
      print "    const char* p = path;";
      print "    if (!p || !*p) simple = 0;";
      print "    for (; *p; ++p) {";
      print "        if (*p == \x27/\x27) { simple = 0; break; }";
      print "    }";
      print "    if (simple) {";
      print "        if (hfsplus_find_root_file(path, &fk) == 0) {";
      print "            cnid = 1; /* valor no-cero arbitrario: indica éxito */";
      print "        }";
      print "    }";
      print "";
      print "    if (!cnid)";
      print "        cnid = find_cnid_by_path(path, 1, &fk);";
      print "";
      print "    if (!cnid){";
      print "        puts(\"[hfs+] no se resolvio: \");";
      print "        puts(path);";
      print "        puts(\"\\r\\n\");";
      print "        return -1;";
      print "    }";
      print "    if (fk.size > cap){";
      print "        puts(\"[hfs+] buffer chico\\r\\n\");";
      print "        return -1;";
      print "    }";
      print "    if (fork_read(&fk, 0, dst, (uint32_t)fk.size)) return -1;";
      print "    if (out_sz) *out_sz = (uint32_t)fk.size;";
      print "    return 0;";
      print "}";
      next;
    }
    if (in_fn) {
      if ($0 ~ /\/\* ===== ELF ===== \*\//) {
        in_fn=0;
        print "/* ===== ELF ===== */";
      }
      next;
    }
    print;
  }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

echo "[patch_hfs_root_simple] listo. Ahora ejecuta: ./build_run.sh"
