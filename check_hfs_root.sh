#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

mkdir -p /mnt/hfs_check

echo "[check_hfs_root] montando hfsplus.img..."
mount -t hfsplus -o loop,ro /root/caribeos/hfsplus.img /mnt/hfs_check

echo
echo "=== Contenido de la raíz de /mnt/hfs_check ==="
ls -la /mnt/hfs_check || echo "(ls fallo)"

echo
echo "=== com.apple.Boot.plist ==="
if [ -f /mnt/hfs_check/com.apple.Boot.plist ]; then
  echo "-> com.apple.Boot.plist EXISTE"
  echo "--- primeras líneas (formateadas) ---"
  head -c 256 /mnt/hfs_check/com.apple.Boot.plist | sed 's/[^[:print:]\t]/./g'
  echo
else
  echo "-> com.apple.Boot.plist NO existe en la raíz"
fi

echo
echo "=== kernel.elf ==="
if [ -f /mnt/hfs_check/kernel.elf ]; then
  echo "-> kernel.elf EXISTE"
  echo "--- cabecera ELF ---"
  head -c 64 /mnt/hfs_check/kernel.elf | hexdump -C
else
  echo "-> kernel.elf NO existe en la raíz"
fi

echo
echo "[check_hfs_root] desmontando..."
umount /mnt/hfs_check || echo "(falló umount)"
