#include <stdint.h>
#include "virtio_blk_legacy.h"

/* ===== UART de debug (independiente del resto del boot) ===== */
#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void v_putc(char c){
    while((UART_LSR & LSR_THRE)==0){}
    UART_THR = (uint8_t)c;
}
static void v_puts(const char* s){
    while(*s) v_putc(*s++);
}
static void v_puthex8(uint8_t v){
    const char* D = "0123456789abcdef";
    v_putc(D[(v >> 4) & 0xF]);
    v_putc(D[v & 0xF]);
}
static void v_puthex32(uint32_t v){
    const char* D = "0123456789abcdef";
    for(int i=7;i>=0;i--)
        v_putc(D[(v>>(i*4))&0xF]);
}
static void v_putu32(uint32_t v){
    char b[11];
    int i = 10;
    b[i--] = 0;
    if(!v) b[i--] = '0';
    while(v){
        b[i--] = '0' + (v % 10);
        v /= 10;
    }
    v_puts(&b[i+1]);
}

/* Pequeño hexdump para ver datos del disco */
static void v_hexdump(const uint8_t* p, uint32_t len){
    for(uint32_t i = 0; i < len; i++){
        if((i % 16) == 0){
            v_putc('\r');
            v_putc('\n');
            v_puthex32(i);
            v_puts(": ");
        }
        v_puthex8(p[i]);
        v_putc(' ');
    }
    v_putc('\r');
    v_putc('\n');
}

/* ===== VIRTIO-MMIO (legacy / transitional) ===== */
#define VIRTIO_MAGIC     0x74726976u
#define VIRTIO_ID_BLOCK  2

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

/* status bits */
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

/* ===== Globals internos ===== */
static volatile uint32_t* mmio = 0;
#define R(off) (*(volatile uint32_t*)((uintptr_t)mmio + (off)))

static uint8_t vr_raw[8192] __attribute__((aligned(4096)));
static struct virtq_desc *vq_desc;
static struct virtq_avail *vq_avail;
static struct virtq_used  *vq_used;

static struct virtio_blk_req g_hdr;
static volatile uint8_t g_status;

static inline uint32_t align_up32(uint32_t x, uint32_t a){
    return (x + a - 1) & ~(a - 1);
}

static void dbg_regs(const char* tag){
    v_puts(tag);
    v_puts(" STATUS="); v_putu32(R(VMMIO_STATUS));
    v_puts(" ISR=");    v_putu32(R(VMMIO_INTERRUPT_STATUS));
    v_puts(" QSEL=");   v_putu32(R(VMMIO_QUEUE_SEL));
    v_puts(" QNUM=");   v_putu32(R(VMMIO_QUEUE_NUM));
    v_puts(" QPFN=");   v_putu32(R(VMMIO_QUEUE_PFN));
    v_puts("\r\n");
}

/* ===== Init virtio-blk (LEGACY MMIO) ===== */
int virtio_blk_init(void){
    /* Buscar dispositivo block en el rango típico de QEMU */
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
        v_puts("[virtio] blk no encontrado\r\n");
        return -1;
    }

    /* Reset + estados básicos */
    R(VMMIO_STATUS) = 0;
    R(VMMIO_STATUS) = VIRTIO_STATUS_ACKNOWLEDGE;
    R(VMMIO_STATUS) |= VIRTIO_STATUS_DRIVER;

    uint32_t ver = R(VMMIO_VERSION);
    v_puts("[virtio] version="); v_putu32(ver); v_puts("\r\n");

    /* Features: nada especial, todo 0 => legacy simple */
    R(VMMIO_DEVICE_FEATURES_SEL) = 0;
    (void)R(VMMIO_DEVICE_FEATURES);

    R(VMMIO_DRIVER_FEATURES_SEL) = 0;
    R(VMMIO_DRIVER_FEATURES) = 0;

    R(VMMIO_STATUS) |= VIRTIO_STATUS_FEATURES_OK;
    if(!(R(VMMIO_STATUS) & VIRTIO_STATUS_FEATURES_OK)){
        v_puts("[virtio] FEATURES_OK rechazado\r\n");
        return -1;
    }

    /* Cola 0 */
    R(VMMIO_QUEUE_SEL) = 0;
    uint32_t qmax = R(VMMIO_QUEUE_NUM_MAX);
    v_puts("[virtio] qmax="); v_putu32(qmax); v_puts("\r\n");
    if(qmax == 0){
        v_puts("[virtio] cola 0 no disponible\r\n");
        return -1;
    }
    if(qmax < QNUM){
        v_puts("[virtio] WARNING: qmax < QNUM, usando qmax\r\n");
        R(VMMIO_QUEUE_NUM) = qmax;
    } else {
        R(VMMIO_QUEUE_NUM) = QNUM;
    }

    /* Layout legacy: desc | avail | [padding] | used */
    uint32_t desc_sz   = sizeof(struct virtq_desc) * QNUM;
    uint32_t avail_off = desc_sz;
    uint32_t avail_sz  = sizeof(uint16_t)*2 + sizeof(uint16_t)*QNUM + sizeof(uint16_t);
    uint32_t used_off  = align_up32(avail_off + avail_sz, 4096);

    for(unsigned i=0;i<sizeof(vr_raw);i++) vr_raw[i] = 0;

    vq_desc  = (struct virtq_desc*)(vr_raw + 0);
    vq_avail = (struct virtq_avail*)(vr_raw + avail_off);
    vq_used  = (struct virtq_used*)(vr_raw + used_off);

    uintptr_t pa = (uintptr_t)vr_raw;

    R(VMMIO_GUEST_PAGE_SIZE) = 4096;
    R(VMMIO_QUEUE_ALIGN)     = 4096;
    R(VMMIO_QUEUE_PFN)       = (uint32_t)(pa >> 12);

    vq_avail->flags = 0;
    vq_avail->idx   = 0;
    vq_used->flags  = 0;
    vq_used->idx    = 0;

    R(VMMIO_STATUS) |= VIRTIO_STATUS_DRIVER_OK;

    v_puts("[virtio] desc@");  v_puthex32((uint32_t)(uintptr_t)vq_desc);
    v_puts(" avail@");         v_puthex32((uint32_t)(uintptr_t)vq_avail);
    v_puts(" used@");          v_puthex32((uint32_t)(uintptr_t)vq_used);
    v_puts("\r\n");

    dbg_regs("[virtio] after init");
    v_puts("[virtio] blk OK @ "); v_puthex32((uint32_t)(uintptr_t)mmio); v_puts("\r\n");
    return 0;
}

/* ===== Leer sectores: wrapper público ===== */
int virtio_blk_read_blocks(uint64_t lba, uint32_t count, void *buf){
    if(count == 0) return 0;

    g_hdr.type   = VIRTIO_BLK_T_IN;
    g_hdr.ioprio = 0;
    g_hdr.sector = lba;
    g_status     = 0xFF;

    /* Limpiar IRQ pendientes */
    uint32_t isr = R(VMMIO_INTERRUPT_STATUS);
    if(isr) R(VMMIO_INTERRUPT_ACK) = isr;

    /* Tomar el idx inicial y el valor esperado tras esta I/O */
    uint16_t used_start = vq_used->idx;
    uint16_t want       = (uint16_t)(used_start + 1);

    /* Desc 0: cabecera */
    vq_desc[0].addr  = (uint64_t)(uintptr_t)&g_hdr;
    vq_desc[0].len   = sizeof(g_hdr);
    vq_desc[0].flags = VIRTQ_DESC_F_NEXT;
    vq_desc[0].next  = 1;

    /* Desc 1: datos (device -> driver) */
    vq_desc[1].addr  = (uint64_t)(uintptr_t)buf;
    vq_desc[1].len   = count * 512u;
    vq_desc[1].flags = VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE;
    vq_desc[1].next  = 2;

    /* Desc 2: status (device -> driver) */
    vq_desc[2].addr  = (uint64_t)(uintptr_t)&g_status;
    vq_desc[2].len   = 1;
    vq_desc[2].flags = VIRTQ_DESC_F_WRITE;
    vq_desc[2].next  = 0;

    /* Publicar en available ring */
    uint16_t aidx = vq_avail->idx;
    vq_avail->ring[aidx % QNUM] = 0; /* desc 0 */
    __sync_synchronize();
    vq_avail->idx = (uint16_t)(aidx + 1);
    __sync_synchronize();

    /* Notificar */
    R(VMMIO_QUEUE_SEL) = 0;
    __sync_synchronize();
    R(VMMIO_QUEUE_NOTIFY) = 0;
    __sync_synchronize();

    /* Esperar a que used->idx avance a 'want' */
    uint32_t spins = 0;
    const uint32_t maxspins = 100000000;
    while(((uint16_t)vq_used->idx) != want && spins++ < maxspins){
        __sync_synchronize();
    }

    if(((uint16_t)vq_used->idx) != want){
        v_puts("[virtio] timeout en read. used.idx=");
        v_putu32(vq_used->idx);
        v_puts(" want=");
        v_putu32(want);
        v_puts(" ISR=");
        v_putu32(R(VMMIO_INTERRUPT_STATUS));
        v_puts(" STATUS=");
        v_putu32(R(VMMIO_STATUS));
        v_puts("\r\n");
        dbg_regs("[virtio] after timeout");
        return -1;
    }

    /* Limpiar IRQ */
    isr = R(VMMIO_INTERRUPT_STATUS);
    if(isr) R(VMMIO_INTERRUPT_ACK) = isr;

    if(g_status != 0){
        v_puts("[virtio] status blk != 0: ");
        v_putu32(g_status);
        v_puts("\r\n");
        return -1;
    }

    v_puts("[virtio] read OK. used.idx=");
    v_putu32(vq_used->idx);
    v_puts("\r\n");

    v_puts("[virtio] data lba=");
    v_putu32((uint32_t)lba);
    v_puts(" count=");
    v_putu32(count);
    v_puts("\r\n");

    /* Dump primeros 64 bytes del buffer */
    v_hexdump((const uint8_t*)buf, 64);

    return 0;
}
