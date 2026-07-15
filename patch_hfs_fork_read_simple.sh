#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_simple] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_hfs_fork_read_simple] reescribiendo fork_read() con una extent contigua..."

# Usamos perl para reemplazar TODO el cuerpo de fork_read por una versión simple
perl -0pi -e '
  s#static int fork_read[^{]*\{.*?^\}#static int fork_read(ForkMeta* fk, uint64_t off, void* dst, uint32_t len){
    uint32_t bs = hv.blockSize;
    uint32_t sectorsPerBlock;
    uint8_t *out = (uint8_t*)dst;

    if (!fk)
        return -1;

    if (!bs)
        bs = 4096;   /* fallback por si acaso */

    sectorsPerBlock = bs / 512;
    if (!sectorsPerBlock)
        sectorsPerBlock = 1;

    if (off >= fk->size)
        return -1;

    /* No leer más allá del tamaño real del fork */
    if (off + len > fk->size)
        len = (uint32_t)(fk->size - off);

    while (len > 0) {
        /* Bloque lógico dentro del fork, en unidades de bs */
        uint64_t fileBlock = off / bs;
        uint32_t inBlock   = (uint32_t)(off % bs);

        /* Bloque físico en el volumen (solo ext[0] por ahora) */
        uint64_t physBlock = (uint64_t)fk->ext[0].start + fileBlock;

        /* LBA en sectores de 512 bytes */
        uint32_t lba = (uint32_t)(physBlock * (uint64_t)sectorsPerBlock);

        /* Leer el bloque completo al buffer secbuf */
        if (disk_read(lba, sectorsPerBlock, secbuf))
            return -1;

        /* Cuántos bytes podemos copiar de este bloque */
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
}#ms
' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_simple] listo. Ahora ejecuta: ./build_run.sh"
