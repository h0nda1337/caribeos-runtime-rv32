#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fork_read_debug] agregando trazas a fork_read()..."

# Por si quedó algún BOM/CRLF raro
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

# Inyectar un kprintf al inicio de fork_read()
perl -0pi -e '
  s#static int fork_read\(ForkMeta\* fk, uint64_t off, void\* dst, uint32_t len\)\{#static int fork_read(ForkMeta* fk, uint64_t off, void* dst, uint32_t len){\
    uint64_t fsize = fk ? fk->size : 0; \
    kprintf("[fork_read] fk=%p off=%llu len=%u size=%llu ext0={start=%u,count=%u}\\n", \
            (void*)fk, \
            (unsigned long long)off, \
            (unsigned)len, \
            (unsigned long long)fsize, \
            fk ? fk->ext[0].start : 0, \
            fk ? fk->ext[0].count : 0); \
#' payload_hfsplus_boot.c

echo "[patch_hfs_fork_read_debug] listo. Ahora ejecuta: ./build_run.sh"
