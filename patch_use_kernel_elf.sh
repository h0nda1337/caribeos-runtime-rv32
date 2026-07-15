#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_use_kernel_elf] Normalizando nombre de kernel a 'kernel.elf'..."

# Limpiar BOM/CRLF raros en el fuente del payload HFS+
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

# 1) Si aún hay referencias viejas a 'mach_kernel', cámbialas por 'kernel.elf'
perl -0pi -e 's/"mach_kernel"/"kernel.elf"/g' payload_hfsplus_boot.c

# 2) Si el mensaje de error dice una cosa y la búsqueda otra,
# fuerza que todo mencione 'kernel.elf' cuando haya el texto de fallo.
perl -0pi -e '
  s/"kernel"/"kernel.elf"/g
    if /\[boot\]\s*fallo leyendo kernel/;
' payload_hfsplus_boot.c

echo "[patch_use_kernel_elf] Listo. Ahora ejecuta: ./build_run.sh"
