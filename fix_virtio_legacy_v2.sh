#!/usr/bin/env bash
set -euo pipefail
cd /root/caribeos

# Asegura LF y sin BOM
sed -i $'1s/^\xEF\xBB\xBF//; s/\r$//' payload_hfsplus_boot.c build_run.sh

# --- A) NO usar registros modernos (DESC/AVAIL/USED LOW/HIGH/READY) ---
#     Eliminamos cualquier escritura a esos registros para evitar confundir al dispositivo legacy
sed -i '/VMMIO_QUEUE_DESC_LOW/s/^/\/\/ /'  payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_DESC_HIGH/s/^/\/\/ /' payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_AVAIL_LOW/s/^/\/\/ /' payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_AVAIL_HIGH/s/^/\/\/ /'payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_USED_LOW/s/^/\/\/ /'  payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_USED_HIGH/s/^/\/\/ /' payload_hfsplus_boot.c
sed -i '/VMMIO_QUEUE_READY/s/^/\/\/ /'     payload_hfsplus_boot.c

# --- B) STATUS: mantener secuencia correcta y estable ---
# ACK + DRIVER
sed -i 's/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE;/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE;/' payload_hfsplus_boot.c
sed -i 's/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE|VIRTIO_STATUS_DRIVER;/R(VMMIO_STATUS)=VIRTIO_STATUS_ACKNOWLEDGE|VIRTIO_STATUS_DRIVER;/' payload_hfsplus_boot.c
# FEATURES_OK (no cambiamos orden, solo aseguramos OR consistente)
sed -i 's/R(VMMIO_STATUS)|=VIRTIO_STATUS_FEATURES_OK;/R(VMMIO_STATUS)=R(VMMIO_STATUS)|VIRTIO_STATUS_FEATURES_OK;/' payload_hfsplus_boot.c
# DRIVER_OK al final
sed -i 's/R(VMMIO_STATUS)|=VIRTIO_STATUS_DRIVER_OK;/R(VMMIO_STATUS)=R(VMMIO_STATUS)|VIRTIO_STATUS_DRIVER_OK;/' payload_hfsplus_boot.c

# --- C) Asegurar configuración de cola legacy en orden clásico ---
# 1) GUEST_PAGE_SIZE 2) QUEUE_ALIGN 3) QUEUE_NUM 4) QUEUE_PFN
# (Normalmente ya está así, solo reforzamos que no haya otros writes modernos)
# Nada que tocar aquí si tu archivo ya lo hace en ese orden.

# --- D) Publicación en AVAIL: usar idx actual y luego incrementarlo ---
# Reemplazar:
#   static uint16_t aidx=0;
#   vq_avail->ring[aidx % QNUM]=0;
#   __sync_synchronize();
#   vq_avail->idx = ++aidx;
# por una versión que lee el idx real del ring y lo incrementa:
sed -i 's/static uint16_t aidx=0;/static uint16_t aidx=0; \/\/ (ya no se usa, pero lo dejamos)/' payload_hfsplus_boot.c
sed -i 's/vq_avail->ring\[aidx % QNUM\]=0;/do { uint16_t _i = vq_avail->idx; vq_avail->ring[_i % QNUM] = 0; __sync_synchronize(); vq_avail->idx = (uint16_t)(_i + 1); } while(0);/' payload_hfsplus_boot.c
sed -i 's/vq_avail->idx = ++aidx;//' payload_hfsplus_boot.c

# --- E) Micro-barrera adicional tras notificar ---
# Duplicamos el notify por si acaso pero con barreras claras
sed -i 's/R(VMMIO_QUEUE_NOTIFY)=0;/__sync_synchronize(); R(VMMIO_QUEUE_NOTIFY)=0; __sync_synchronize();/' payload_hfsplus_boot.c

# --- F) Más debug de la cola tras configurar legacy ---
awk '
  /dbg_regs\("\[virtio] dbg_after_init"\);/ {
    print "  puts(\"[virtio] legacy cfg: QNUM=\"); putu32(R(VMMIO_QUEUE_NUM)); puts(\" QALIGN=\"); putu32(R(VMMIO_QUEUE_ALIGN)); puts(\" QPFN=\"); putu32(R(VMMIO_QUEUE_PFN)); puts(\"\\r\\n\");";
  }
  {print > "/dev/stderr"}
' payload_hfsplus_boot.c >/dev/null 2>&1 || true
# (si awk no insertó nada, no pasa nada; era opcional)

# --- G) Recompilar y lanzar ---
./build_run.sh
