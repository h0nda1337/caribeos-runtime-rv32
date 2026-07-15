#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_boot_paths_noslash] limpiando BOM/CRLF..."
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

echo "[patch_boot_paths_noslash] cambiando \"/com.apple.Boot.plist\" -> \"com.apple.Boot.plist\"..."
if grep -q '"/com.apple.Boot.plist"' payload_hfsplus_boot.c; then
  sed -i 's:"/com.apple.Boot.plist":"com.apple.Boot.plist":' payload_hfsplus_boot.c
else
  echo "  [WARN] no encontré la cadena \"/com.apple.Boot.plist\""
fi

echo "[patch_boot_paths_noslash] cambiando \"/kernel.elf\" -> \"kernel.elf\"..."
if grep -q '"/kernel.elf"' payload_hfsplus_boot.c; then
  sed -i 's:"/kernel.elf":"kernel.elf":' payload_hfsplus_boot.c
else
  echo "  [WARN] no encontré la cadena \"/kernel.elf\""
fi

echo "[patch_boot_paths_noslash] listo. Ahora ejecuta: ./build_run.sh"
