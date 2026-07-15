#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_virtio_blk_debug] limpiando BOM/CRLF en virtio_blk_legacy.c..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' virtio_blk_legacy.c 2>/dev/null || true

echo "[patch_virtio_blk_debug] añadiendo v_hexdump() si no existe..."
if ! grep -q 'v_hexdump(const uint8_t*' virtio_blk_legacy.c; then
  cat >> virtio_blk_legacy.c <<'EOC'

/* Debug hexdump para ver qué está devolviendo virtio-blk */
static void v_hexdump(const uint8_t* p, uint32_t len){
    const char *D = "0123456789abcdef";
    for(uint32_t i = 0; i < len; i++){
        if((i % 16) == 0){
            v_putc('\r');
            v_putc('\n');
        }
        uint8_t v = p[i];
        v_putc(D[(v >> 4) & 0xF]);
        v_putc(D[v & 0xF]);
        v_putc(' ');
    }
    v_putc('\r');
    v_putc('\n');
}
EOC
fi

echo "[patch_virtio_blk_debug] enganchando debug dentro de virtio_blk_read_blocks()..."
if ! grep -q 'v_hexdump((const uint8_t*)buf, 64);' virtio_blk_legacy.c; then
  sed -i '/v_puts("\[virtio] read OK. used.idx="); v_putu32(vq_used->idx); v_puts("\\r\\n");/a \
    v_puts("[virtio] data lba="); v_putu32((uint32_t)lba); v_puts(" count="); v_putu32(count); v_puts("\\r\\n"); \
    v_hexdump((const uint8_t*)buf, 64);' virtio_blk_legacy.c
else
  echo "  (debug ya estaba enganchado, no se duplica)"
fi

echo "[patch_virtio_blk_debug] listo. Ahora ejecuta:  ./build_run.sh"
