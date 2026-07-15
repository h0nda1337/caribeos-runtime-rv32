/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>

/* ===== UART ===== */
#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){
    while((UART_LSR & LSR_THRE)==0){}
    UART_THR = (uint8_t)c;
}
static void puts(const char* s){
    while(*s) putc(*s++);
}
static void puthex8(uint8_t v){
    const char* D = "0123456789abcdef";
    putc(D[(v >> 4) & 0xF]);
    putc(D[v & 0xF]);
}
static void puthex32(uint32_t v){
    const char* D = "0123456789abcdef";
    for(int i=7;i>=0;i--)
        putc(D[(v>>(i*4))&0xF]);
}
static void putu32(uint32_t v){
    char b[11];
    int i = 10;
    b[i--] = 0;
    if(!v) b[i--] = '0';
    while(v){
        b[i--] = '0' + (v % 10);
        v /= 10;
    }
    puts(&b[i+1]);
}

/* ===== VIRTIO-MMIO ===== */
#define VIRTIO_MAGIC  0x74726976u
#define VIRTIO_ID_BLOCK 2

/* MMIO offsets (legacy/transitional) */
#define VMMIO_MAGIC               0x000
#define VMMIO_VERSION             0x004
#define VMMIO_DEVICE_ID           0x008
#define VMMIO_VENDOR_ID           0x00c
#define VMMIO_DEVICE_FEATURES     0x010
#define VMMIO_DEVICE_FEATURES_SEL 0x014
#define VMMIO_DRIVER_FEATURES     0x020
#define VMMIO_DRIVER_FEATURES_SEL 0x024
#define VMMIO_GUEST_PAGE_SIZE     0x028   /* legacy */
#define VMMIO_QUEUE_SEL           0x030
#define VMMIO_QUEUE_NUM_MAX       0x034
#define VMMIO_QUEUE_NUM           0x038
#define VMMIO_QUEUE_ALIGN         0x03c   /* legacy */
#define VMMIO_QUEUE_PFN           0x040   /* legacy */
#define VMMIO_QUEUE_NOTIFY        0x050
#define VMMIO_INTERRUPT_STATUS    0x060
#define VMMIO_INTERRUPT_ACK       0x064
#define VMMIO_STATUS              0x070

/* virtio status bits */
#define VIRTIO_STATUS_ACKNOWLEDGE 1
#define VIRTIO_STATUS_DRIVER      2
#define VIRTIO_STATUS_DRIVER_OK   4
#define VIRTIO_STATUS_FEATURES_OK 8

/* vring */
#define QNUM 8

struct virtq_desc {
    uint64_t addr;
    uint32_t len;
    uint16_t flags;
    uint16_t next;
} __attribute__((packed));

struct virtq_used_elem {
    uint32_t id;
    uint32_t len;
} __attribute__((packed));

struct virtq_avail {
    uint16_t flags;
    uint16_t idx;
    uint16_t ring[QNUM];
    uint16_t used_event; /* opcional */
} __attribute__((packed));

struct virtq_used {
    uint16_t flags;
    uint16_t idx;
    struct virtq_used_elem ring[QNUM];
    uint16_t avail_event; /* opcional */
} __attribute__((packed));

#define VIRTQ_DESC_F_NEXT  1
#define VIRTQ_DESC_F_WRITE 2

/* virtio-blk request */
#define VIRTIO_BLK_T_IN 0

struct virtio_blk_req {
    uint32_t type;
    uint32_t ioprio;
    uint64_t sector;
} __attribute__((packed));

/* ===== Globals ===== */
static volatile uint32_t* mmio = 0;
#define R(off) (*(volatile uint32_t*)((uintptr_t)mmio + (off)))

/* vring en RAM invitado, alineado a 4K */
static uint8_t vr_raw[8192] __attribute__((aligned(4096)));
static struct virtq_desc *vq_desc;
static struct virtq_avail *vq_avail;
static struct virtq_used  *vq_used;

static struct virtio_blk_req g_hdr;
static volatile uint8_t g_status;

/* ===== Utils ===== */
static inline uint32_t align_up(uint32_t x, uint32_t a){
    return (x + a - 1) & ~(a - 1);
}

static void hexdump(const uint8_t* p, uint32_t len){
    for(uint32_t i=0;i<len;i++){
        if((i % 16)==0){
            putc('\r'); putc('\n');
            puthex32(i);
            puts(": ");
        }
        puthex8(p[i]);
        putc(' ');
    }
    puts("\r\n");
}

static void dbg_regs(const char* tag){
    puts(tag);
    puts(" STATUS="); putu32(R(VMMIO_STATUS));
    puts(" ISR=");    putu32(R(VMMIO_INTERRUPT_STATUS));
    puts(" QSEL=");   putu32(R(VMMIO_QUEUE_SEL));
    puts(" QNUM=");   putu32(R(VMMIO_QUEUE_NUM));
    puts(" QPFN=");   putu32(R(VMMIO_QUEUE_PFN));
    puts("\r\n");
}

/* ===== Init virtio-blk (LEGACY) ===== */
static int virtio_blk_init(void){
    /* Buscar dispositivo block en el rango típico de virtio-mmio de QEMU */
    for(uint32_t base = 0x10001000; base <= 0x10008000; base += 0x1000){
        volatile uint32_t* r = (volatile uint32_t*)base;
        uint32_t magic = r[VMMIO_MAGIC/4];
        uint32_t devid = r[VMMIO_DEVICE_ID/4];
        if(magic != VIRTIO_MAGIC) continue;
        if(devid != VIRTIO_ID_BLOCK) continue;
        mmio = r;
        break;
    }
    if(!mmio){
        puts("[virtio] blk no encontrado\r\n");
        return -1;
    }

    /* Reset + estado básico */
    R(VMMIO_STATUS) = 0;
    R(VMMIO_STATUS) = VIRTIO_STATUS_ACKNOWLEDGE;
    R(VMMIO_STATUS) |= VIRTIO_STATUS_DRIVER;

    uint32_t ver = R(VMMIO_VERSION);
    puts("[virtio] version="); putu32(ver); puts("\r\n");

    /* No negociamos features especiales: todo a 0 => modo legacy simple */
    R(VMMIO_DEVICE_FEATURES_SEL) = 0;
    (void)R(VMMIO_DEVICE_FEATURES);

    R(VMMIO_DRIVER_FEATURES_SEL) = 0;
    R(VMMIO_DRIVER_FEATURES) = 0;

    R(VMMIO_STATUS) |= VIRTIO_STATUS_FEATURES_OK;
    if(!(R(VMMIO_STATUS) & VIRTIO_STATUS_FEATURES_OK)){
        puts("[virtio] FEATURES_OK rechazado\r\n");
        return -1;
    }

    /* Cola 0 */
    R(VMMIO_QUEUE_SEL) = 0;
    uint32_t qmax = R(VMMIO_QUEUE_NUM_MAX);
    puts("[virtio] qmax="); putu32(qmax); puts("\r\n");
    if(qmax == 0){
        puts("[virtio] cola 0 no disponible\r\n");
        return -1;
    }
    if(qmax < QNUM){
        puts("[virtio] WARNING: qmax < QNUM, ajustando\r\n");
        R(VMMIO_QUEUE_NUM) = qmax;
    } else {
        R(VMMIO_QUEUE_NUM) = QNUM;
    }

    /* Layout legacy: desc | avail | [padding] | used */
    uint32_t desc_sz  = sizeof(struct virtq_desc) * QNUM;
    uint32_t avail_off = desc_sz;
    uint32_t avail_sz  = sizeof(uint16_t)*2 + sizeof(uint16_t)*QNUM + sizeof(uint16_t);
    uint32_t used_off  = align_up(avail_off + avail_sz, 4096);

    for(unsigned i=0;i<sizeof(vr_raw);i++) vr_raw[i] = 0;

    vq_desc  = (struct virtq_desc*)(vr_raw + 0);
    vq_avail = (struct virtq_avail*)(vr_raw + avail_off);
    vq_used  = (struct virtq_used*)(vr_raw + used_off);

    uintptr_t pa = (uintptr_t)vr_raw;

    R(VMMIO_GUEST_PAGE_SIZE) = 4096;
    R(VMMIO_QUEUE_ALIGN)     = 4096;
    R(VMMIO_QUEUE_PFN)       = (uint32_t)(pa >> 12);

    /* Cola inicial en cero */
    vq_avail->flags = 0;
    vq_avail->idx   = 0;
    vq_used->flags  = 0;
    vq_used->idx    = 0;

    R(VMMIO_STATUS) |= VIRTIO_STATUS_DRIVER_OK;

    puts("[virtio] desc@");  puthex32((uint32_t)(uintptr_t)vq_desc);
    puts(" avail@");         puthex32((uint32_t)(uintptr_t)vq_avail);
    puts(" used@");          puthex32((uint32_t)(uintptr_t)vq_used);
    puts("\r\n");

    dbg_regs("[virtio] after init");
    puts("[virtio] blk OK @ "); puthex32((uint32_t)(uintptr_t)mmio); puts("\r\n");
    return 0;
}

/* ===== Leer sectores vía virtio-blk (LEGACY) ===== */
static int virtio_blk_read(uint64_t lba, uint32_t count, void* buf){
    if(count == 0) return 0;

    g_hdr.type   = VIRTIO_BLK_T_IN;
    g_hdr.ioprio = 0;
    g_hdr.sector = lba;
    g_status     = 0xFF;

    /* Limpiar posibles IRQ pendientes */
    uint32_t isr = R(VMMIO_INTERRUPT_STATUS);
    if(isr) R(VMMIO_INTERRUPT_ACK) = isr;

    /* Descriptor 0: cabecera */
    vq_desc[0].addr  = (uint64_t)(uintptr_t)&g_hdr;
    vq_desc[0].len   = sizeof(g_hdr);
    vq_desc[0].flags = VIRTQ_DESC_F_NEXT;
    vq_desc[0].next  = 1;

    /* Descriptor 1: buffer de datos (device -> driver) */
    vq_desc[1].addr  = (uint64_t)(uintptr_t)buf;
    vq_desc[1].len   = count * 512u;
    vq_desc[1].flags = VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE;
    vq_desc[1].next  = 2;

    /* Descriptor 2: byte de status (device -> driver) */
    vq_desc[2].addr  = (uint64_t)(uintptr_t)&g_status;
    vq_desc[2].len   = 1;
    vq_desc[2].flags = VIRTQ_DESC_F_WRITE;
    vq_desc[2].next  = 0;

    /* Publicar en ring disponible */
    uint16_t aidx = vq_avail->idx;
    vq_avail->ring[aidx % QNUM] = 0; /* desc 0 */
    __sync_synchronize();
    vq_avail->idx = aidx + 1;
    __sync_synchronize();

    /* Notificar cola 0 */
    R(VMMIO_QUEUE_SEL) = 0;
    __sync_synchronize();
    R(VMMIO_QUEUE_NOTIFY) = 0;
    __sync_synchronize();

    /* Esperar completion en used->idx */
    uint32_t spins = 0;
    const uint32_t maxspins = 100000000;
    while(vq_used->idx == 0 && spins++ < maxspins){
        __sync_synchronize();
    }

    if(vq_used->idx == 0){
        puts("[virtio] timeout en read. used.idx=0 ISR=");
        putu32(R(VMMIO_INTERRUPT_STATUS));
        puts(" STATUS="); putu32(R(VMMIO_STATUS));
        puts("\r\n");
        dbg_regs("[virtio] after timeout");
        return -1;
    }

    /* Limpiar IRQ si se puso */
    isr = R(VMMIO_INTERRUPT_STATUS);
    if(isr) R(VMMIO_INTERRUPT_ACK) = isr;

    if(g_status != 0){
        puts("[virtio] status de blk != 0: ");
        putu32(g_status);
        puts("\r\n");
        return -1;
    }

    puts("[virtio] read OK. used.idx="); putu32(vq_used->idx); puts("\r\n");
    return 0;
}

/* ===== Entry ===== */
void payload_entry(void){
    puts("\r\n[virtio-diag] inicio\r\n");

    if(virtio_blk_init()){
        puts("[virtio-diag] init FAIL\r\n");
        for(;;){}
    }

    uint8_t sec[512];

    puts("[virtio-diag] leyendo LBA2...\r\n");
    if(virtio_blk_read(2, 1, sec)){
        puts("[virtio-diag] read LBA2 FAIL\r\n");
        for(;;){}
    }

    puts("[virtio-diag] read LBA2 OK. Dump primeros 64 bytes:\r\n");
    hexdump(sec, 64);

    puts("[virtio-diag] fin, loop\r\n");
    for(;;){}
}

/* alias de entrada para el loader ELF de CaribeBootX */
void _start(void) __attribute__((alias("payload_entry")));
