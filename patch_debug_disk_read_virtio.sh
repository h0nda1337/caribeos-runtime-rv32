#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_debug_disk_read_virtio] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_debug_disk_read_virtio] asegurando include de virtio_blk_legacy.h..."
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

echo "[patch_debug_disk_read_virtio] renombrando el disk_read() actual a disk_read_base() (si existe)..."
# Solo la definición con uint64_t lba, uint32_t count, void *buf
sed -i 's/^static int disk_read(uint64_t lba, uint32_t count, void \*buf)/static int disk_read_base(uint64_t lba, uint32_t count, void *buf)/' payload_hfsplus_boot.c || true

echo "[patch_debug_disk_read_virtio] añadiendo NUEVO disk_read() con debug y virtio_blk_read_blocks()..."

cat >> payload_hfsplus_boot.c <<'EOC'

/* === Disco debug: todas las lecturas que haga HFS+ pasan por aquí === */
static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    puts("[disk_read] LBA=");
    putu32((uint32_t)lba);
    puts(" count=");
    putu32(count);
    puts("\r\n");

    /* Backend REAL: nuestro driver virtio-blk legacy */
    int r = virtio_blk_read_blocks(lba, count, buf);

    if (r != 0) {
        puts("[disk_read] virtio_blk_read_blocks FAIL\r\n");
        return r;
    }

    puts("[disk_read] OK\r\n");
    return 0;
}
EOC

echo "[patch_debug_disk_read_virtio] listo. Ahora ejecuta: ./build_run.sh"
