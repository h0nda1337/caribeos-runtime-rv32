static int printf(const char *fmt, ...){ (void)fmt; return 0; }
/* CaribeBootX - HFS+ RAM-disk + ELF32 (RV32)
 * Lee una imagen HFS+ mapeada en RAM (sin virtio).
 * Suposición: QEMU carga hfsplus.img en HFS_RAM_BASE con:
 *
 *   -device loader,file=/root/caribeos/hfsplus.img,addr=0x88000000,force-raw=on
 *
 * El flujo:
 *   RAM(HFS+) -> HFS+ parser -> Boot.plist -> /kernel.elf + /initrd.img -> ELF loader.
 */

#include <stdint.h>
#include "virtio_blk_legacy.h"

/* Prototipo para hfsplus_dump_root_entries() (debug catálogo HFS+) */
static void hfsplus_debug_cat_first_blocks(void);
static void hfsplus_dump_root_entries(void);


/* Prototipo para poder usar disk_read() antes de su definición */
static int disk_read(uint64_t lba, uint32_t count, void *buf);


static int disk_read_old(uint64_t lba, uint32_t count, void *buf) {
    return virtio_blk_read_blocks(lba, count, buf);
}


/* ===== UART ===== */
#define UART_BASE 0x10000000u
#define UART_THR  (*(volatile uint8_t*)(UART_BASE + 0))
#define UART_LSR  (*(volatile uint8_t*)(UART_BASE + 5))
#define LSR_THRE  0x20

static void putc(char c){
    while ((UART_LSR & LSR_THRE) == 0) {}
    UART_THR = (uint8_t)c;
}
static void puts(const char* s){
    while (*s) putc(*s++);
}
static void puthex32(uint32_t v){
    const char* D = "0123456789abcdef";
    for (int i = 7; i >= 0; i--)
        putc(D[(v >> (i * 4)) & 0xF]);
}
static void putu32(uint32_t v){
    char b[11];
    int i = 10;
    b[i--] = 0;
    if (!v) b[i--] = '0';
    while (v){
        b[i--] = '0' + (v % 10);
        v /= 10;
    }
    puts(&b[i + 1]);
}

/* ===== strings ===== */
static int s_eq(const char* a, const char* b){
    int i = 0;
    for (; a[i] && b[i]; i++)
        if (a[i] != b[i]) return 0;
    return a[i] == 0 && b[i] == 0;
}
static int s_starts(const char* s, const char* p){
    int i = 0;
    for (; p[i]; i++){
        if (!s[i] || s[i] != p[i]) return 0;
    }
    return 1;
}

/* ===== endian helpers ===== */
static uint16_t be16(uint16_t x){
    return (x >> 8) | ((x & 0xFF) << 8);
}
static uint32_t be32(uint32_t x){
    return ((x & 0xFF) << 24)
         | ((x & 0xFF00) << 8)
         | ((x >> 8) & 0xFF00)
         | ((x >> 24) & 0xFF);
}
static uint64_t be64(uint64_t x){
    return ((uint64_t)be32((uint32_t)x) << 32)
         | (uint64_t)be32((uint32_t)(x >> 32));
}

/* ===== Backend de “disco”: RAM-disk HFS+ ===== */

#define HFS_RAM_BASE  0x88000000u   /* donde QEMU mapea hfsplus.img */
#define SECTOR_SIZE   512u

/* Mantengo el nombre virtio_blk_read_sectors para no tocar tanto código,
 * pero ya NO usa virtio: solo copia desde RAM.
 */
static int virtio_blk_read_sectors(uint64_t lba, uint32_t count, void* buf){
    uint8_t* src = (uint8_t*)(HFS_RAM_BASE + (uint32_t)(lba * (uint64_t)SECTOR_SIZE));
    uint8_t* dst = (uint8_t*)buf;
    uint32_t total = count * SECTOR_SIZE;

    for (uint32_t i = 0; i < total; i++)
        dst[i] = src[i];

    return 0; /* siempre OK: RAM no falla :) */
}

/* ===== HFS+ ===== */
#pragma pack(push,1)
typedef struct {
    uint16_t sig; uint16_t version; uint32_t attrs; uint32_t lastMountedVersion; uint32_t journalInfoBlock;
    uint32_t createDate, modifyDate, backupDate, checkedDate;
    uint32_t fileCount, folderCount; uint32_t blockSize; uint32_t totalBlocks, freeBlocks;
    uint32_t nextAllocation, rsrcClumpSize, dataClumpSize; uint32_t nextCatalogID; uint32_t writeCount;
    uint64_t encodingsBitmap; uint32_t finderInfo[8];
    struct {
        uint64_t logicalSize;
        uint32_t clumpSize, totalBlocks;
        struct { uint32_t startBlock, blockCount; } extents[8];
    } allocationFile, extentsFile, catalogFile, attributesFile, startupFile;
} HFSPlusVolumeHeader;

typedef struct {
    uint32_t fLink, bLink;
    uint8_t  kind;
    uint8_t  height;
    uint16_t numRecords;
    uint16_t reserved;
} BTNodeDescriptor;

typedef struct {
    uint16_t keyLength;
    uint32_t parentID;
    uint16_t nameLen;
} HFSPlusCatalogKey;

typedef struct {
    uint16_t recordType;
    uint16_t flags;
    uint32_t valence;
    uint32_t folderID;
    uint32_t createDate, contentModDate, attributeModDate, accessDate, backupDate;
    uint32_t uid, gid;
    uint32_t permissions;
    uint32_t userInfo[4], finderInfo[4];
    uint32_t textEncoding;
    uint32_t folderCount;
} HFSPlusFolderRecord;

typedef struct {
    uint16_t recordType;
    uint16_t flags;
    uint32_t reserved1;
    uint32_t fileID;
    uint32_t createDate, contentModDate, attributeModDate, accessDate, backupDate;
    uint32_t uid, gid;
    uint32_t permissions;
    uint32_t special;
    uint32_t userInfo[4], finderInfo[4];
    uint32_t textEncoding;
    uint32_t reserved2;
    struct {
        uint64_t logicalSize;
        uint32_t clumpSize, totalBlocks;
        struct { uint32_t startBlock, blockCount; } extents[8];
    } dataFork, rsrcFork;
} HFSPlusFileRecord;
#pragma pack(pop)

typedef struct {
    uint64_t size;
    struct { uint32_t start, count; } ext[8];
} ForkMeta;

static struct {
    uint32_t blockSize;
    uint32_t totalBlocks;
    ForkMeta cat;
} hv;

static uint8_t secbuf[4096];

/* fork_read: recorre los extents del fork (catálogo, archivo, etc.) */
static int fork_read(ForkMeta* fk, uint64_t off, void* dst, uint32_t len){
    uint64_t fsize = fk ? fk->size : 0;
    printf("[fork_read] fk=%p off=%llu len=%u size=%llu ext0={start=%u,count=%u}\n",
            (void*)fk,
            (unsigned long long)off,
            (unsigned)len,
            (unsigned long long)fsize,
            fk ? fk->ext[0].start : 0,
            fk ? fk->ext[0].count : 0);

    uint32_t bs = hv.blockSize;
    uint32_t sectorsPerBlock;
    uint8_t *out = (uint8_t*)dst;

    if (!fk)
        return -1;

    if (!bs)
        bs = 4096;   /* valor por defecto por si el header viene raro */

    sectorsPerBlock = bs / 512;
    if (!sectorsPerBlock)
        sectorsPerBlock = 1;

    if (off >= fk->size)
        return -1;

    /* No leer mas alla del tamano real del fork */
    if (off + len > fk->size)
        len = (uint32_t)(fk->size - off);

    /* Trabajamos con offset de 32 bits para evitar __udivdi3/__umoddi3 */
    uint32_t off32 = (uint32_t)off;

    while (len > 0) {
        /* Bloque logico dentro del fork, en unidades de bs (todo en 32 bits) */
        uint32_t fileBlock = off32 / bs;
        uint32_t inBlock   = off32 % bs;

        /* Bloque fisico en el volumen (solo ext[0] de momento) */
        uint32_t physBlock = fk->ext[0].start + fileBlock;

        /* LBA en sectores de 512 bytes, todo 32 bits */
        uint32_t lba = physBlock * sectorsPerBlock;

        /* Leer el bloque completo al buffer secbuf */
        if (disk_read(lba, sectorsPerBlock, secbuf))
            return -1;

        /* Cuantos bytes podemos copiar de este bloque */
        uint32_t chunk = bs - inBlock;
        if (chunk > len)
            chunk = len;

        /* Copia manual para evitar depender de memcpy */
        uint8_t *src = ((uint8_t*)secbuf) + inBlock;
        for (uint32_t i = 0; i < chunk; ++i)
            out[i] = src[i];

        out   += chunk;
        off32 += chunk;
        len   -= chunk;
    }

    return 0;
}

static int hfsplus_mount(void){
    /* El VHB suele estar en LBA2 en HFS+ */
    if (disk_read(2, 1, secbuf)) return -1;

    HFSPlusVolumeHeader* vh = (HFSPlusVolumeHeader*)secbuf;
    uint16_t sig = be16(vh->sig);
    if (!(sig == 0x482B || sig == 0x4858)){  /* 'H+' o 'HX' */
        puts("[hfs+] firma invalida\r\n");
        return -1;
    }

    hv.blockSize   = be32(vh->blockSize);
    hv.totalBlocks = be32(vh->totalBlocks);
    hv.cat.size    = be64(vh->catalogFile.logicalSize);

    for (int i = 0; i < 8; i++){
        hv.cat.ext[i].start = be32(vh->catalogFile.extents[i].startBlock);
        hv.cat.ext[i].count = be32(vh->catalogFile.extents[i].blockCount);
    }

    puts("[hfs+] OK bs="); putu32(hv.blockSize);
    puts(" blocks=");      putu32(hv.totalBlocks);
    puts(" cat.size=");    putu32((uint32_t)hv.cat.size);
    puts("\r\n");

    for (int i = 0; i < 8; i++){
        if (!hv.cat.ext[i].count) break;
        puts("[hfs+] cat.ext "); putu32(i);
        puts(": start=");        putu32(hv.cat.ext[i].start);
        puts(" count=");         putu32(hv.cat.ext[i].count);
        puts("\r\n");
    }
    return 0;
}

/* --- utilidades de ruta (UTF-16BE -> ASCII, split, etc) --- */
static int u16be_to_ascii(const uint8_t* u16be, uint16_t n, char* out, int outcap){
    int k = 0;
    for (uint16_t i = 0; i < n; i++){
        uint16_t ch = (u16be[2 * i] << 8) | u16be[2 * i + 1];
        char c = (ch < 128) ? (char)ch : '?';
        if (k + 1 < outcap) out[k++] = c;
        else break;
    }
    out[k] = 0;
    return k;
}

static int split_next(const char* full, int start, char* out){
    int k = 0;
    int i = start;

    while (full[i] == '/') i++;
    if (!full[i]) return -1;

    while (full[i] && full[i] != '/'){
        if (k < 127) out[k++] = full[i];
        i++;
    }
    out[k] = 0;
    while (full[i] == '/') i++;
    return i;
}

static int has_more(const char* full, int start){
    int i = start;
    while (full[i] == '/') i++;
    return full[i] != 0;
}

/* Busca CNID por ruta y opcionalmente llena el fork de datos */
static uint32_t find_cnid_by_path(const char* path, int want_file, ForkMeta* out_fork){
    uint32_t want_parent = 2; /* root CNID */

    if (fork_read(&hv.cat, 0, secbuf, 4096)) return 0;
    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;
    if (nd->kind != 0x01){
        puts("[hfs+] warn: cat header kind=");
        putu32(nd->kind);
        puts("\r\n");
    }

    int idx = 0;
    char comp[128];

    while ((idx = split_next(path, idx, comp)) != -1){
        int found = 0;

        for (uint64_t off = 4096; off < hv.cat.size; off += 4096){
            if (fork_read(&hv.cat, off, secbuf, 4096)) return 0;
            BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;
            if (d->kind != 0xFF) continue;  /* nodos hoja */

            uint16_t num = be16(d->numRecords);
            uint16_t* idxv = (uint16_t*)(secbuf + 4096 - 2 * (num + 1));

            for (int r = 0; r < num; r++){
                uint16_t rec_off = be16(idxv[r]);
                uint8_t* rec = secbuf + rec_off;

                HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;
                uint32_t parent = be32(key->parentID);
                uint16_t nlen   = be16(key->nameLen);

                const uint8_t* uname = rec + 2 + 4 + 2;
                char name[128];
                u16be_to_ascii(uname, nlen, name, 128);

                uint8_t* data  = rec + 2 + be16(key->keyLength);
                uint16_t rtype = be16(*(uint16_t*)data);

                if (parent == want_parent && s_eq(name, comp)){
                    if (rtype == 0x0001){ /* folder */
                        HFSPlusFolderRecord* fr = (HFSPlusFolderRecord*)data;
                        want_parent = be32(fr->folderID);
                        found = 1;
                        goto next_component;
                    } else if (rtype == 0x0002){ /* file */
                        HFSPlusFileRecord* ff = (HFSPlusFileRecord*)data;
                        if (!has_more(path, idx)){
                            uint32_t cnid = be32(ff->fileID);
                            if (out_fork){
                                out_fork->size = be64(ff->dataFork.logicalSize);
                                for (int i = 0; i < 8; i++){
                                    out_fork->ext[i].start = be32(ff->dataFork.extents[i].startBlock);
                                    out_fork->ext[i].count = be32(ff->dataFork.extents[i].blockCount);
                                }
                            }
                            return cnid;
                        }
                    }
                }
            }
        }
        if (!found){
            puts("[hfs+] componente no encontrado: ");
            puts(comp);
            puts("\r\n");
            return 0;
        }
    next_component: ;
    }

    return want_file ? 0 : want_parent;
}

/* Lee un archivo completo de HFS+ a memoria */

/* Busca un archivo directamente en la raíz HFS+ (CNID=2) por nombre simple */
static int hfsplus_find_root_file(const char* name, ForkMeta* out_fork){
    uint32_t parent = 2; /* root CNID */

    /* Leer nodo 0 del catalog (header del B-tree) */
    if (fork_read(&hv.cat, 0, secbuf, 4096)) return -1;
    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;

    /* Header del B-tree HFS+ (big-endian) */
    typedef struct {
        uint16_t treeDepth;
        uint32_t rootNode;
        uint32_t leafRecords;
        uint32_t firstLeafNode;
        uint32_t lastLeafNode;
        uint16_t nodeSize;
        uint16_t maxKeyLength;
        uint32_t totalNodes;
        uint32_t freeNodes;
        uint16_t reserved1;
        uint32_t clumpSize;
        uint8_t  btreeType;
        uint8_t  keyCompareType;
        uint32_t attributes;
        uint32_t reserved3[16];
    } __attribute__((packed)) BTHeaderRecLocal;

    BTHeaderRecLocal* hdr = (BTHeaderRecLocal*)(secbuf + sizeof(BTNodeDescriptor));
    uint16_t nodeSize   = be16(hdr->nodeSize);
    uint32_t firstLeaf  = be32(hdr->firstLeafNode);
    uint32_t lastLeaf   = be32(hdr->lastLeafNode);
    uint16_t depth      = be16(hdr->treeDepth);
    uint32_t totalNodes = be32(hdr->totalNodes);

    if (!nodeSize) nodeSize = 4096; /* fallback razonable */

    puts("[hfs+] find_root: depth=");
    putu32(depth);
    puts(" nodeSize=");
    putu32(nodeSize);
    puts(" totalNodes=");
    putu32(totalNodes);
    puts(" firstLeaf=");
    putu32(firstLeaf);
    puts(" lastLeaf=");
    putu32(lastLeaf);
    puts("\r\n");

    /* Si totalNodes viene en 0, lo derivamos del tamaño del fork del catálogo */
    if (!totalNodes) {
    {
        uint32_t cat_bytes = (uint32_t)hv.cat.size;
        if (nodeSize) totalNodes = cat_bytes / (uint32_t)nodeSize;
    }
    }

    /* Si el header no da rango de hojas o da algo fuera de rango, usar 1..totalNodes-1 */
    if ((firstLeaf == 0 && lastLeaf == 0) || firstLeaf >= totalNodes || lastLeaf >= totalNodes) {
        if (totalNodes > 1) {
            firstLeaf = 1;
            lastLeaf  = totalNodes - 1;
        } else {
            firstLeaf = 0;
            lastLeaf  = 0;
        }
    }

    /* Recorremos nodos en el rango [firstLeaf, lastLeaf] */
    for (uint32_t node = firstLeaf; node <= lastLeaf; node++){
        uint64_t off = (uint64_t)node * nodeSize;
        if (fork_read(&hv.cat, off, secbuf, nodeSize)) return -1;
        BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;
        uint16_t num = be16(d->numRecords);

        puts("[hfs+] root-scan node=");
        putu32(node);
        puts(" kind=");
        putu32((uint32_t)(uint8_t)d->kind);
        puts(" num=");
        putu32(num);
        puts("\r\n");

        /* Sólo tiene sentido mirar registros en nodos hoja */
        if ((uint8_t)d->kind != 0xFF || !num) continue;

        uint16_t* idxv = (uint16_t*)(secbuf + nodeSize - 2 * (num + 1));

        for (uint16_t r = 0; r < num; r++){
            uint16_t rec_off = be16(idxv[r]);
            uint8_t* rec = secbuf + rec_off;

            HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;
            uint32_t p_id = be32(key->parentID);
            uint16_t nlen  = be16(key->nameLen);
            const uint8_t* uname = rec + 2 + 4 + 2;
            char tmp[128];
            u16be_to_ascii(uname, nlen, tmp, 128);

            uint8_t* data  = rec + 2 + be16(key->keyLength);
            uint16_t rtype = be16(*(uint16_t*)data);

            if (p_id == parent && rtype == 0x0002 && s_eq(tmp, name)){
                HFSPlusFileRecord* ff = (HFSPlusFileRecord*)data;
                if (out_fork){
                    out_fork->size = be64(ff->dataFork.logicalSize);
                    for (int i = 0; i < 8; i++){
                        out_fork->ext[i].start = be32(ff->dataFork.extents[i].startBlock);
                        out_fork->ext[i].count = be32(ff->dataFork.extents[i].blockCount);
                    }
                }
                return 0;
            }
        }
    }

    return -1;
}

static int hfsplus_read_file(const char* path, uint8_t* dst, uint32_t cap, uint32_t* out_sz){
    ForkMeta fk;
    uint32_t cnid = 0;

    /* Si la ruta es un nombre simple sin '/', probar primero en la raíz HFS+ */
    int simple = 1;
    const char* p = path;
    if (!p || !*p) simple = 0;
    for (; *p; ++p) {
        if (*p == '/') { simple = 0; break; }
    }
    if (simple) {
        if (hfsplus_find_root_file(path, &fk) == 0) {
            cnid = 1; /* valor no-cero arbitrario: indica éxito */
        }
    }

    if (!cnid)
        cnid = find_cnid_by_path(path, 1, &fk);

    if (!cnid){
        puts("[hfs+] no se resolvio: ");
        puts(path);
        puts("\r\n");
        return -1;
    }
    if (fk.size > cap){
        puts("[hfs+] buffer chico\r\n");
        return -1;
    }
    if (fork_read(&fk, 0, dst, (uint32_t)fk.size)) return -1;
    if (out_sz) *out_sz = (uint32_t)fk.size;
    return 0;
}
/* ===== ELF ===== */
typedef struct {
    uint32_t e_magic;
    uint8_t  e_class;
    uint8_t  e_data;
    uint8_t  e_version;
    uint8_t  e_osabi;
    uint64_t e_pad;
    uint16_t e_type;
    uint16_t e_machine;
    uint32_t e_version2;
    uint32_t e_entry;
    uint32_t e_phoff;
    uint32_t e_shoff;
    uint32_t e_flags;
    uint16_t e_ehsize;
    uint16_t e_phentsize;
    uint16_t e_phnum;
    uint16_t e_shentsize;
    uint16_t e_shnum;
    uint16_t e_shstrndx;
} __attribute__((packed)) Elf32_Ehdr;

typedef struct {
    uint32_t p_type;
    uint32_t p_offset;
    uint32_t p_vaddr;
    uint32_t p_paddr;
    uint32_t p_filesz;
    uint32_t p_memsz;
    uint32_t p_flags;
    uint32_t p_align;
} __attribute__((packed)) Elf32_Phdr;

static int elf32_load_and_jump(uint8_t* img, uint32_t sz, uint32_t dtb){
    (void)sz;
    Elf32_Ehdr* eh = (Elf32_Ehdr*)img;

    if (eh->e_magic != 0x464C457Fu){
        puts("[ELF] magic invalido\r\n");
        return -1;
    }
    if (eh->e_class != 1 || eh->e_data != 1){
        puts("[ELF] clase/dato no soportado\r\n");
        return -1;
    }

    Elf32_Phdr* ph = (Elf32_Phdr*)(img + eh->e_phoff);
    for (int i = 0; i < eh->e_phnum; i++){
        if (ph[i].p_type != 1) continue; /* PT_LOAD */
        uint8_t* src = img + ph[i].p_offset;
        uint8_t* dst = (uint8_t*)(ph[i].p_vaddr);
        for (uint32_t k = 0; k < ph[i].p_filesz; k++)
            dst[k] = src[k];
        for (uint32_t k = ph[i].p_filesz; k < ph[i].p_memsz; k++)
            dst[k] = 0;
    }

    void (*entry)(uint32_t, uint32_t, uint32_t) = (void*)(eh->e_entry);
    puts("[ELF] saltando a ");
    puthex32(eh->e_entry);
    puts(" a1=dtb=");
    putu32(dtb);
    puts("\r\n");
    entry(0, dtb, 0);
    return 0;
}

/* ===== Boot.plist (simple) ===== */
#ifndef DTB_ADDR
#define DTB_ADDR 0x8fe00000u
#endif

void payload_entry(void){
    puts("\r\n[CaribeBootX HFS+ RAM] init\r\n");
    if (virtio_blk_init() != 0) {
        puts("[boot] virtio_blk_init FAIL\r\n");
        for(;;){}
    }


    puts("[ramdisk] probe LBA2...\r\n");
    if (disk_read(2, 1, secbuf)){
        puts("[ramdisk] read LBA2 FAIL\r\n");
        for(;;){}
    }
    puts("[ramdisk] read LBA2 OK, sig=");
    putc(secbuf[0]);
    putc(secbuf[1]);
    puts("\r\n");

    if (hfsplus_mount()){
        puts("[boot] hfs+ mount FAIL\r\n");
        for(;;){}
    }

    hfsplus_dump_root_entries();

    static uint8_t plist[8192];
    uint32_t psz = 0;
    char flags[256];
    char kernel_path[128];
    flags[0] = 0;
    kernel_path[0] = 0;

    if (!hfsplus_read_file("com.apple.Boot.plist", plist, sizeof plist, &psz)){
        puts("[Boot.plist] ");
        putu32(psz);
        puts(" bytes\r\n");

        const char* f = (const char*)plist;
        int len = (int)psz;

        if (len > 0){
            const char* key = "Kernel Flags";
            for (int i = 0; i + 12 < len; i++){
                if (f[i] == 'K' && i + 12 < len && s_starts(&f[i], key)){
                    const char* p  = &f[i];
                    const char* s1 = 0;
                    const char* s2 = 0;

                    for (; p < f + len - 8; p++){
                        if (*p == '<' && s_starts(p, "<string>")){
                            s1 = p + 8;
                            break;
                        }
                    }
                    if (s1){
                        for (p = s1; p < f + len - 9; p++){
                            if (*p == '<' && s_starts(p, "</string>")){
                                s2 = p;
                                break;
                            }
                        }
                    }
                    if (s1 && s2){
                        int L = (int)(s2 - s1);
                        if (L >= (int)sizeof(flags)) L = sizeof(flags) - 1;
                        for (int k = 0; k < L; k++) flags[k] = s1[k];
                        flags[L] = 0;
                    }
                    break;
                }
            }
            if (flags[0]){
                puts("  Flags: '");
                puts(flags);
                puts("'\r\n");

                for (int i = 0; flags[i]; i++){
                    if (flags[i] == 'k' && s_starts(&flags[i], "kernel=")){
                        i += 7;
                        int k = 0;
                        while (flags[i] && flags[i] != ' ' && k + 1 < (int)sizeof(kernel_path)){
                            kernel_path[k++] = flags[i++];
                        }
                        kernel_path[k] = 0;
                        break;
                    }
                }
                if (kernel_path[0]){
                    puts("  Kernel: '");
                    puts(kernel_path);
                    puts("'\r\n");
                }
            }
        }
    } else {
        puts("[Boot.plist] no encontrado (ok)\r\n");
    }

    const char* kpath = (kernel_path[0] ? kernel_path : "kernel.elf");

    static uint8_t kimg[8 * 1024 * 1024];
    uint32_t ksz = 0;
    if (hfsplus_read_file(kpath, kimg, sizeof kimg, &ksz)){
        puts("[boot] fallo leyendo kernel: ");
        puts(kpath);
        puts("\r\n");
        for(;;){}
    }
    puts("[boot] kernel ");
    puts(kpath);
    puts(" size=");
    putu32(ksz);
    puts("\r\n");

    static uint8_t initrd[16 * 1024 * 1024];
    uint32_t rsz = 0;
    if (!hfsplus_read_file("/initrd.img", initrd, sizeof initrd, &rsz)){
        puts("[boot] initrd size=");
        putu32(rsz);
        puts("\r\n");
    }

    uint32_t dtb = (uint32_t)DTB_ADDR;
    elf32_load_and_jump(kimg, ksz, dtb);

    puts("[boot] regreso del kernel (no esperado)\r\n");
    for(;;){}
}

/* alias */
void _start(void) __attribute__((alias("payload_entry")));

/* === Pequeño hexdump para depurar lo que llega de disco en HFS+ === */
static void hfs_hexdump(const uint8_t* p, uint32_t len){
    const char *D = "0123456789abcdef";
    for(uint32_t i=0;i<len;i++){
        if((i % 16)==0){
            puts("\r\n");
        }
        uint8_t v = p[i];
        putc(D[(v>>4)&0xF]);
        putc(D[v&0xF]);
        putc(' ');
    }
    puts("\r\n");
}


/* === Override: backend de lectura de bloques usando virtio-blk legacy === */
static int disk_read_base(uint64_t lba, uint32_t count, void *buf)
{
    /* Todo acceso a disco HFS+ pasa ahora por virtio_blk_legacy */
    return virtio_blk_read_blocks(lba, count, buf);
}


/* === Disco debug: todas las lecturas que haga HFS+ pasan por aquí === */
/* === Override: backend de lectura de bloques usando virtio-blk legacy (con log) === */

/* === Nuevo backend de lectura de bloques para HFS+: usa virtio-blk legacy === */
static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    puts("[disk_read] lba=");
    putu32((uint32_t)lba);
    puts(" count=");
    putu32(count);
    puts("\r\n");

    return virtio_blk_read_blocks(lba, count, buf);
}


/* === Debug: hexdump directo de lo que ve HFS+ en sec[] === */
static void hfs_hexdump2(const uint8_t* p, uint32_t len){
    const char *D = "0123456789abcdef";
    for (uint32_t i = 0; i < len; i++){
        if ((i % 16) == 0){
            puts("\r\n");
        }
        uint8_t v = p[i];
        putc(D[(v >> 4) & 0xF]);
        putc(D[v & 0xF]);
        putc(' ');
    }
    puts("\r\n");
}

/* Debug: volcar entradas del catálogo HFS+ (nombre, parent, tipo) */
static void hfsplus_dump_root_entries(void){
    hfsplus_debug_cat_first_blocks();
    if (fork_read(&hv.cat, 0, secbuf, 4096)){
        puts("[hfs+] dump_root: fork_read header FAIL\r\n");
        return;
    }
    BTNodeDescriptor* nd = (BTNodeDescriptor*)secbuf;
    puts("[hfs+] dump_root: header kind=");
    putu32(nd->kind);
    puts("\r\n");

    puts("[hfs+] dump_root: inicio\r\n");
    for (uint64_t off = 4096; off < hv.cat.size; off += 4096){
        if (fork_read(&hv.cat, off, secbuf, 4096)){
            puts("[hfs+] dump_root: fork_read FAIL\r\n");
            return;
        }
        BTNodeDescriptor* d = (BTNodeDescriptor*)secbuf;
        if (d->kind != 0xFF) continue;  /* sólo nodos hoja */

        uint16_t num = be16(d->numRecords);
        uint16_t* idxv = (uint16_t*)(secbuf + 4096 - 2 * (num + 1));

        for (int r = 0; r < num; r++){
            uint16_t rec_off = be16(idxv[r]);
            uint8_t* rec = secbuf + rec_off;

            HFSPlusCatalogKey* key = (HFSPlusCatalogKey*)rec;
            uint32_t parent = be32(key->parentID);
            uint16_t nlen   = be16(key->nameLen);
            const uint8_t* uname = rec + 2 + 4 + 2;
            char name[128];
            u16be_to_ascii(uname, nlen, name, 128);

            uint8_t* data  = rec + 2 + be16(key->keyLength);
            uint16_t rtype = be16(*(uint16_t*)data);

            puts("[hfs+] cat entry: parent=");
            putu32(parent);
            puts(" name='");
            puts(name);
            puts("' type=");
            putu32((uint32_t)rtype);
            puts("\r\n");
        }
    }
    puts("[hfs+] dump_root: fin\r\n");
}

/* Debug extra: volcar los primeros bloques del catálogo HFS+ */
static void hfsplus_debug_cat_first_blocks(void){
    puts("[hfs+] debug_cat: size=");
    putu32((uint32_t)hv.cat.size);
    puts(" ext0.start=");
    putu32(hv.cat.ext[0].start);
    puts(" ext0.count=");
    putu32(hv.cat.ext[0].count);
    puts("\r\n");

    for (uint32_t i = 0; i < 4; i++){
        uint64_t off = (uint64_t)i * 4096;
        if (off >= hv.cat.size) break;
        if (fork_read(&hv.cat, off, secbuf, 4096)){
            puts("[hfs+] debug_cat: fork_read FAIL at off=");
            putu32((uint32_t)off);
            puts("\r\n");
            break;
        }
        puts("[hfs+] debug_cat: block#");
        putu32(i);
        puts("\r\n");
        hfs_hexdump(secbuf, 64);
    }
}

/* ======================================================================== */
/*  Búsqueda lineal en el directorio raíz para un archivo por nombre        */
/*  hfs_find_root_file_linear()                                             */
/* ======================================================================== */

/*
 * OJO:
 * - Ajusta los nombres de tipos si en tu código se llaman distinto:
 *     - struct hfs_volume          -> el que ya uses (volumen HFS+)
 *     - HFSPlusCatalogKey          -> tu struct de clave de catálogo
 *     - HFSPlusCatalogFile         -> tu struct de archivo de catálogo
 *     - BTNodeDescriptor           -> descriptor de nodo BTree
 * - Esta versión asume:
 *     v->catHeader, v->catNodeBuf, v->nodeSize, cat_read_node()
 *     kBTLeafNode, kHFSPlusFileRecord, be16toh/be32toh/be64toh, etc.
 */

#if 0
static int hfs_find_root_file_linear(struct hfs_volume *v,
                                     const char *target_name,
                                     HFSPlusCatalogFile *outFile)
{
    const uint32_t firstLeaf = v->catHeader.firstLeafNode;
    const uint32_t lastLeaf  = v->catHeader.lastLeafNode;

    for (uint32_t node = firstLeaf; node <= lastLeaf; ++node) {
        uint8_t *buf = v->catNodeBuf;

        if (cat_read_node(v, node, buf) != 0) {
            printf("[hfs+] error leyendo nodo cat #%u\n", node);
            return -1;
        }

        BTNodeDescriptor *nd = (BTNodeDescriptor *)buf;
        if (nd->kind != kBTLeafNode) {
            continue;
        }

        uint16_t *offsets = (uint16_t *)(buf + v->nodeSize);
        int numRecords = be16toh(nd->numRecords);

        for (int i = 0; i < numRecords; ++i) {
            uint16_t recOffset = be16toh(offsets[-1 - i]);
            uint8_t *rec = buf + recOffset;

            HFSPlusCatalogKey *key = (HFSPlusCatalogKey *)rec;
            uint16_t keyLen = be16toh(key->keyLength);
            (void)keyLen; // evita warning si no lo usas

            uint32_t parentID = be32toh(key->parentID);

            int nameLen = be16toh(key->nodeName.length);
            const uint16_t *uni = key->nodeName.unicode;

            char nameAscii[256];
            int j;
            for (j = 0; j < nameLen && j < 255; ++j) {
                uint16_t ch = be16toh(uni[j]);
                nameAscii[j] = (ch < 128) ? (char)ch : '?';
            }
            nameAscii[j] = '\0';

            uint8_t *recData = rec + 2 + keyLen;
            uint16_t recType = be16toh(*(uint16_t *)recData);

            if (parentID == 2 &&
                recType == kHFSPlusFileRecord &&
                strcmp(nameAscii, target_name) == 0)
            {
                HFSPlusCatalogFile *fileRec = (HFSPlusCatalogFile *)recData;
                *outFile = *fileRec;

                printf("[hfs+] encontrado '%s' CNID=%u size=%llu blocks=%u\n",
                       nameAscii,
                       (unsigned)be32toh(fileRec->fileID),
                       (unsigned long long)be64toh(fileRec->dataFork.logicalSize),
                       (unsigned)be32toh(fileRec->dataFork.totalBlocks));

                return 0;
            }
        }
    }

    printf("[hfs+] root: archivo '%s' no encontrado\n", target_name);
    return -1;
}
#endif

/* Fin de hfs_find_root_file_linear()                                       */
/* ======================================================================== */
