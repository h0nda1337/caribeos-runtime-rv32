#!/usr/bin/env bash
set -euo pipefail

cd /root/caribeos

# 0) Asegura LF/BOM
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c build_run.sh

# 1) Revertir cualquier 'disable-legacy=on' que se haya quedado en el run
sed -i 's/,disable-legacy=on//g' build_run.sh

# 2) Parchear la secuencia de STATUS para legacy: usar ASIGNACIÓN explícita

# 2.1) DRIVER: reemplaza el OR por asignación acumulada con ACK
sed -i 's/R(VMMIO_STATUS)|=VIRTIO_STATUS_DRIVER;/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE|VIRTIO_STATUS_DRIVER;/' payload_hfsplus_boot.c

# 2.2) FEATURES_OK: asignación explícita con ACK|DRIVER|FEATURES_OK
sed -i 's/R(VMMIO_STATUS)|=VIRTIO_STATUS_FEATURES_OK;/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE|VIRTIO_STATUS_DRIVER|VIRTIO_STATUS_FEATURES_OK;/' payload_hfsplus_boot.c

# 2.3) DRIVER_OK: asignación explícita con todos los bits
sed -i 's/R(VMMIO_STATUS)|=VIRTIO_STATUS_DRIVER_OK;/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE|VIRTIO_STATUS_DRIVER|VIRTIO_STATUS_FEATURES_OK|VIRTIO_STATUS_DRIVER_OK;/' payload_hfsplus_boot.c

# 3) Asegurar cola en cero (idx y flags) al inicializar vring
#    Insertamos flags=0 justo después de la línea donde pones idx=0 y g_aidx=0
awk '
  {print}
  /vq_avail->idx = 0; vq_used->idx = 0; g_aidx = 0;/ {
    print "  vq_avail->flags = 0;";
    print "  vq_used->flags  = 0;";
  }
' payload_hfsplus_boot.c > payload_hfsplus_boot.c.new && mv payload_hfsplus_boot.c.new payload_hfsplus_boot.c

# 4) Recompilar y lanzar
./build_run.sh
