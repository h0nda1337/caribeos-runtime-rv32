#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_reset] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_fork_read_reset] reescribiendo fork_read() y eliminando restos antiguos..."

# Reemplaza TODO el fork_read original (hasta el 'return left ? -1 : 0;')
# por una versión simple que asume una sola extent contigua en fk->ext[0].
perl -0pi -e '
  s#static int fork_read[^{]*\{.*?return left \? -1 : 0;\s*\}#static int fork_read(ForkMeta* fk, uint64_t off, void* dst, uint32_t len){
    uint32_t bs = hv.blockSize;
    uint32_t sectorsPerBlock;
    uint8_t *out = (uint8_t*)dst;

    if (!fk)
        return -1;

    if (!bs)
        bs = 4096;   /* valor por defecto por si el header viene raro */

    sectorsPerBlock = bs / 512;
    if (!sectorsPerBlock)
        sectorsPerBlock = 1;

    if (off >= fk->size)
        return -1;

    /* No leer mas alla del tamano real del fork */
    if (off + len > fk->size)
        len = (uint32_t)(fk->size - off);

    while (len > 0) {
        /* Bloque logico dentro del fork, en unidades de bs */
        uint64_t fileBlock = off / bs;
        uint32_t inBlock   = (uint32_t)(off % bs);

        /* Bloque fisico en el volumen (solo ext[0] de momento) */
        uint64_t physBlock = (uint64_t)fk->ext[0].start + fileBlock;

        /* LBA en sectores de 512 bytes */
        uint32_t lba = (uint32_t)(physBlock * (uint64_t)sectorsPerBlock);

        /* Leer el bloque completo al buffer secbuf */
        if (disk_read(lba, sectorsPerBlock, secbuf))
            return -1;

        /* Cuantos bytes podemos copiar de este bloque */
        uint32_t chunk = bs - inBlock;
        if (chunk > len)
            chunk = len;

        /* Copia manual para evitar depender de memcpy */
        uint8_t *src = ((uint8_t*)secbuf) + inBlock;
        for (uint32_t i = 0; i < chunk; ++i)
            out[i] = src[i];

        out += chunk;
        off += chunk;
        len -= chunk;
    }

    return 0;
}#s
' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_reset] listo. Ahora ejecuta: ./build_run.sh"
