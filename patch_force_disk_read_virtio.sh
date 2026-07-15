#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_force_disk_read_virtio] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_force_disk_read_virtio] renombrando disk_read() viejo a disk_read_old()..."
# Sólo líneas que empiezan con "static int disk_read(" para no tocar las llamadas
sed -i 's/^static int disk_read(/static int disk_read_old(/' payload_hfsplus_boot.c

echo "[patch_force_disk_read_virtio] añadiendo disk_read() nuevo usando virtio_blk_read_blocks()..."
cat >> payload_hfsplus_boot.c <<'EOC'

/* === Override: backend de lectura de bloques usando virtio-blk legacy === */
static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    /* Todo acceso a disco HFS+ pasa ahora por virtio_blk_legacy */
    return virtio_blk_read_blocks(lba, count, buf);
}

EOC

echo "[patch_force_disk_read_virtio] listo. Ahora ejecuta: ./build_run.sh"
