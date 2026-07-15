#ifndef VIRTIO_BLK_LEGACY_H
#define VIRTIO_BLK_LEGACY_H

#include <stdint.h>

/*
 * Inicializa el dispositivo virtio-blk en modo MMIO legacy.
 * Devuelve 0 si todo OK, -1 si falla.
 */
int virtio_blk_init(void);

/*
 * Lee "count" sectores de 512 bytes a partir del LBA dado
 * y los escribe en "buf".
 * Devuelve 0 si OK, -1 si falla.
 */
int virtio_blk_read_blocks(uint64_t lba, uint32_t count, void *buf);

#endif /* VIRTIO_BLK_LEGACY_H */
