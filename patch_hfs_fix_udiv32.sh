#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

echo "[patch_hfs_fix_udiv32] arreglando division hv.cat.size / nodeSize a 32 bits..."

# Limpiar posible BOM/CRLF (por si acaso)
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c 2>/dev/null || true

awk '
  {
    # Si la línea contiene hv.cat.size / nodeSize, la sustituimos
    if ($0 ~ /hv.cat.size[[:space:]]*\/[[:space:]]*nodeSize/) {
      print "    {";
      print "        uint32_t cat_bytes = (uint32_t)hv.cat.size;";
      print "        if (nodeSize) totalNodes = cat_bytes / (uint32_t)nodeSize;";
      print "    }";
      next;
    }
    print;
  }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new

mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

echo "[patch_hfs_fix_udiv32] listo. Ahora ejecuta: ./build_run.sh"
