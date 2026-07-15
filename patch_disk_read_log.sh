#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_disk_read_log] reescribiendo cuerpo de disk_read() con logs..."

# Sustituye el cuerpo de la función disk_read(uint64_t lba, uint32_t count, void *buf)
# por una versión que imprime lba y count y luego llama a virtio_blk_read_blocks().
sed -i '/^static int disk_read(uint64_t lba, uint32_t count, void \*buf)/,/^}/c\
/* === Override: backend de lectura de bloques usando virtio-blk legacy (con log) === */\
static int disk_read(uint64_t lba, uint32_t count, void *buf)\
{\
    puts("[disk_read] lba=");\
    putu32((uint32_t)lba);\
    puts(" count=");\
    putu32(count);\
    puts("\\r\\n");\
    return virtio_blk_read_blocks(lba, count, buf);\
}\
' payload_hfsplus_boot.c

echo "[patch_disk_read_log] listo. Ahora ejecuta: ./build_run.sh"
