#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_fix_div32] ajustando fork_read() para no usar divisiones 64-bit..."

# Limpiar BOM/CRLF por si acaso
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

# Sustituimos la versión actual de fork_read() por una que solo use 32-bit para / y %
perl -0pi -e '
  s#static int fork_read\(ForkMeta\* fk, uint64_t off, void\* dst, uint32_t len\)\{.*?return 0;\s*\}#static int fork_read(ForkMeta* fk, uint64_t off, void* dst, uint32_t len){
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

    /* Trabajamos con offset de 32 bits para evitar __udivdi3/__umoddi3 */
    uint32_t off32 = (uint32_t)off;

    while (len > 0) {
        /* Bloque logico dentro del fork, en unidades de bs (todo en 32 bits) */
        uint32_t fileBlock = off32 / bs;
        uint32_t inBlock   = off32 % bs;

        /* Bloque fisico en el volumen (solo ext[0] de momento) */
        uint32_t physBlock = fk->ext[0].start + fileBlock;

        /* LBA en sectores de 512 bytes, todo 32 bits */
        uint32_t lba = physBlock * sectorsPerBlock;

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

        out   += chunk;
        off32 += chunk;
        len   -= chunk;
    }

    return 0;
}#s
' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_fix_div32] listo. Ahora ejecuta: ./build_run.sh"
