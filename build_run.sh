#!/usr/bin/env bash
# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

set -euo pipefail
cd /root/caribeos

# Por si vinieron de Windows, limpiar BOM/CRLF
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c virtio_blk_legacy.c 2>/dev/null || true

# Compilar payload HFS+ + virtio-blk legacy
clang --target=riscv32-unknown-elf -march=rv32imac -mabi=ilp32 \
  -nostdlib -ffreestanding -static \
  -Wl,--gc-sections -Wl,-T,rv32_payload.ld -Wl,--no-relax \
  -Wl,-e,payload_entry \
  payload_hfsplus_boot.c virtio_blk_legacy.c -o payload_hfsplus_boot.elf

echo "[readelf] Entry:"
readelf -h payload_hfsplus_boot.elf | grep -i 'Entry point' || true

# Asegurar HFS+ con kernel e init
mkdir -p /mnt/hfs
mount -t hfsplus -o loop,rw /root/caribeos/hfsplus.img /mnt/hfs
[ -f /mnt/hfs/kernel.elf ] || {
  echo "[HFS+] faltaba kernel.elf; creando demo"
  cat > /root/caribeos/kernel_hello.c <<'KELF'
#include <stdint.h>
#define UART_BASE 0x10000000u
#define THR (*(volatile uint8_t*)(UART_BASE+0))
#define LSR (*(volatile uint8_t*)(UART_BASE+5))
#define THRE 0x20
static void putc(char c){ while((LSR&THRE)==0){} THR=(uint8_t)c; }
static void puts(const char*s){ while(*s) putc(*s++); }
void _start(void){ puts("\r\n[Kernel demo] Hola desde kernel.elf (RV32)\r\n"); for(;;){} }
KELF
  clang --target=riscv32-unknown-elf -march=rv32imac -mabi=ilp32 \
    -nostdlib -ffreestanding -static \
    -Wl,--gc-sections -Wl,-T,rv32_payload.ld -Wl,--no-relax \
    /root/caribeos/kernel_hello.c -o /root/caribeos/kernel.elf
  cp -f /root/caribeos/kernel.elf /mnt/hfs/kernel.elf
}
cat > /mnt/hfs/com.apple.Boot.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Kernel Flags</key>
  <string>console=ttyS0 loglevel=7 BOOT=caribe kernel=/kernel.elf</string>
</dict></plist>
PLIST
sync
umount /mnt/hfs

# Ejecutar QEMU (MMIO legacy). En el prompt de CaribeBootX:
#   > bootelf 0x88000000
qemu-system-riscv32 -machine virt -m 256M -nographic \
  -bios default \
  -kernel /root/caribeos/build/caribe_rv32.elf \
  -device loader,file=/root/caribeos/payload_hfsplus_boot.elf,addr=0x88000000,force-raw=on \
  -drive if=none,file=/root/caribeos/hfsplus.img,format=raw,id=vd0 \
  -device virtio-blk-device,drive=vd0
