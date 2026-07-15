#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_force_disk_read2] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_force_disk_read2] eliminando TODAS las definiciones antiguas de disk_read()..."
awk '
/^static int disk_read\(.*\)/ {
    skip=1;
    depth=1;
    next;
}
skip {
    # contamos llaves dentro del cuerpo de la función
    for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1);
        if (c == "{") depth++;
        else if (c == "}") depth--;
    }
    if (depth <= 0) {
        skip=0;
        depth=0;
    }
    next;
}
{ print }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

echo "[patch_force_disk_read2] asegurando include de virtio_blk_legacy.h..."
if ! grep -q 'virtio_blk_legacy.h' payload_hfsplus_boot.c; then
  awk '{
    print;
    if ($0 ~ /^#include <stdint.h>/) {
      print "#include \"virtio_blk_legacy.h\"";
    }
  }' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c
fi

echo "[patch_force_disk_read2] añadiendo NUEVA disk_read() con log y virtio..."
cat >> payload_hfsplus_boot.c <<'EOC'

/* === Nuevo backend de lectura de bloques para HFS+: usa virtio-blk legacy === */
static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    puts("[disk_read] lba=");
    putu32((uint32_t)lba);
    puts(" count=");
    putu32(count);
    puts("\r\n");

    return virtio_blk_read_blocks(lba, count, buf);
}

EOC

echo "[patch_force_disk_read2] listo. Ahora ejecuta: ./build_run.sh"
