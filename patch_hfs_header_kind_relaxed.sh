#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_header_kind_relaxed] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_header_kind_relaxed] relajando chequeo de nd->kind en find_cnid_by_path, hfsplus_find_root_file y hfsplus_dump_root_entries..."

awk '
  BEGIN {
    state = 0;
    skip1 = skip2 = skip3 = 0;
  }

  {
    # saltos de bloques ya reemplazados
    if (skip1 > 0) { skip1--; next; }
    if (skip2 > 0) { skip2--; next; }
    if (skip3 > 0) { skip3--; next; }

    # detectar entrada a funciones
    if ($0 ~ /static uint32_t find_cnid_by_path\(const char\* path, int want_file, ForkMeta\* out_fork\)\{/) {
      state = 1;
      print;
      next;
    }
    if ($0 ~ /static int hfsplus_find_root_file\(const char\* name, ForkMeta\* out_fork\)\{/) {
      state = 2;
      print;
      next;
    }
    if ($0 ~ /static void hfsplus_dump_root_entries\(void\)\{/) {
      state = 3;
      print;
      next;
    }

    # dentro de find_cnid_by_path: reemplazar bloque del header
    if (state == 1 &&
        $0 ~ /if \(fork_read\(&hv.cat, 0, secbuf, 4096\)\) return 0;/) {

      print "    if (fork_read(&hv.cat, 0, secbuf, 4096)) return 0;";
      print "    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;";
      print "    if (nd->kind != 0x01){";
      print "        puts(\"[hfs+] warn: cat header kind=\");";
      print "        putu32(nd->kind);";
      print "        puts(\"\\r\\n\");";
      print "    }";
      skip1 = 4; # saltar las 4 líneas originales
      next;
    }

    # dentro de hfsplus_find_root_file: reemplazar bloque del header
    if (state == 2 &&
        $0 ~ /if \(fork_read\(&hv.cat, 0, secbuf, 4096\)\) return -1;/) {

      print "    if (fork_read(&hv.cat, 0, secbuf, 4096)) return -1;";
      print "    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;";
      print "    if (nd->kind != 0x01){";
      print "        puts(\"[hfs+] warn: root header kind=\");";
      print "        putu32(nd->kind);";
      print "        puts(\"\\r\\n\");";
      print "    }";
      skip2 = 4; # saltar las 4 líneas originales
      next;
    }

    # dentro de hfsplus_dump_root_entries: reemplazar bloque de header
    if (state == 3 &&
        $0 ~ /if \(fork_read\(&hv.cat, 0, secbuf, 4096\)\)\{/) {

      print "    if (fork_read(&hv.cat, 0, secbuf, 4096)){";
      print "        puts(\"[hfs+] dump_root: fork_read header FAIL\\r\\n\");";
      print "        return;";
      print "    }";
      print "    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;";
      print "    puts(\"[hfs+] dump_root: header kind=\");";
      print "    putu32(nd->kind);";
      print "    puts(\"\\r\\n\");";
      skip3 = 8; # saltar las 8 líneas originales
      next;
    }

    # salir de función al ver cierre de bloque al inicio de línea
    if (state != 0 && $0 ~ /^}/) {
      state = 0;
      print;
      next;
    }

    # por defecto, imprimir línea original
    print;
  }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new

mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

echo "[patch_hfs_header_kind_relaxed] listo. Ahora ejecuta: ./build_run.sh"
