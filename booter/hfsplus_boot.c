/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include "include/uapi/bootargs.h"
#include "include/uapi/xnu_bootargs.h"
#include "booter/fdt_min.h"
#include "booter/hfsplus_boot.h"
#include "virtio_blk_legacy.h"

void uart_puts(const char *);
void uart_puthex32(uint32_t v);
void uart_putdec(uintptr_t v);
void caribe_pack_boot_args(caribe_boot_args *ba, uintptr_t dtb);

#define HFS_SECTOR_SIZE          512u
#define HFS_NODE_BUF_SIZE        8192u
#define HFS_KERNEL_LOAD_BUFFER   ((uint8_t *)0x82000000u)
#define HFS_KERNEL_LOAD_CAP      (32u * 1024u * 1024u)
#define HFS_INITRD_LOAD_BUFFER   ((uint8_t *)0x84000000u)
#define HFS_INITRD_LOAD_CAP      (16u * 1024u * 1024u)
#define XNU_EFI_LOADER_CODE      1u
#define XNU_EFI_LOADER_DATA      2u
#define XNU_EFI_CONVENTIONAL     7u
#define XNU_MEMORY_MAP_MAX       16u
#define XNU_OPENSBI_BASE         0x80000000u
/* OpenSBI FW_JUMP owns the complete slot below its 0x80200000 next address. */
#define XNU_OPENSBI_RESERVED     0x00200000u

extern char __caribebootx_start[];
extern char __caribebootx_end[];

typedef struct {
    uint64_t size;
    struct {
        uint32_t start;
        uint32_t count;
    } ext[8];
} ForkMeta;

static struct {
    uint32_t blockSize;
    uint32_t totalBlocks;
    uint16_t catalogNodeSize;
    uint32_t firstLeafNode;
    uint32_t lastLeafNode;
    uint32_t totalCatalogNodes;
    ForkMeta catalog;
} hfs;

static uint8_t secbuf[HFS_NODE_BUF_SIZE] __attribute__((aligned(16)));
static uint8_t plist_buf[16384] __attribute__((aligned(16)));
static riscv32_caribebootx_args_t xnu_boot_args __attribute__((aligned(16)));
static riscv32_xnu_memory_range_t xnu_memory_map[XNU_MEMORY_MAP_MAX]
    __attribute__((aligned(16)));
static char xnu_cmdline[256] __attribute__((aligned(16)));

typedef struct {
    uint32_t start;
    uint32_t end;
    uint32_t type;
} XnuReservedRange;

static void p(const char *s)
{
    uart_puts(s);
}

static void pdec(uint32_t v)
{
    uart_putdec((uintptr_t)v);
}

static void memzero(void *ptr, uint32_t len)
{
    uint8_t *p8 = (uint8_t *)ptr;
    for (uint32_t i = 0; i < len; i++)
        p8[i] = 0;
}

static void memcopy(void *destination, const void *source, uint32_t len)
{
    uint8_t *dst = (uint8_t *)destination;
    const uint8_t *src = (const uint8_t *)source;

    while (len-- != 0u)
        *dst++ = *src++;
}

static uint32_t slen(const char *s)
{
    uint32_t n = 0;
    while (s[n])
        n++;
    return n;
}

static void scopy(char *dst, uint32_t cap, const char *src)
{
    uint32_t i = 0;
    if (cap == 0)
        return;
    while (i + 1 < cap && src[i]) {
        dst[i] = src[i];
        i++;
    }
    dst[i] = 0;
}

static void sappend_token(char *dst, uint32_t cap, const char *src)
{
    uint32_t i;
    uint32_t j = 0;

    if (cap == 0 || src == 0 || src[0] == 0)
        return;
    i = slen(dst);
    if (i + 1 >= cap)
        return;
    if (i != 0 && dst[i - 1] != ' ')
        dst[i++] = ' ';
    while (i + 1 < cap && src[j])
        dst[i++] = src[j++];
    dst[i] = 0;
}

static uint32_t page_down(uint32_t value)
{
    return value & ~4095u;
}

static uint32_t page_up(uint32_t value)
{
    return (value + 4095u) & ~4095u;
}

static void xnu_memory_map_add(uint32_t *count, uint32_t type,
                               uint32_t start, uint32_t end)
{
    riscv32_xnu_memory_range_t *range;

    if (end <= start || *count >= XNU_MEMORY_MAP_MAX)
        return;

    range = &xnu_memory_map[(*count)++];
    memzero(range, (uint32_t)sizeof(*range));
    range->type = type;
    range->physical_start = start;
    range->virtual_start = start;
    range->number_of_pages = (end - start) >> 12;
}

static void xnu_reserved_insert(XnuReservedRange *ranges, uint32_t *count,
                                uint32_t mem_start, uint32_t mem_end,
                                uint32_t base, uint32_t size, uint32_t type)
{
    XnuReservedRange item;
    uint32_t end;
    uint32_t i;

    if (!base || !size || *count >= XNU_MEMORY_MAP_MAX)
        return;
    end = base + size;
    if (end < base)
        return;

    item.start = page_down(base);
    item.end = page_up(end);
    item.type = type;
    if (item.end <= mem_start || item.start >= mem_end)
        return;
    if (item.start < mem_start)
        item.start = mem_start;
    if (item.end > mem_end)
        item.end = mem_end;
    if (item.end <= item.start)
        return;

    for (i = *count; i > 0 && ranges[i - 1].start > item.start; i--)
        ranges[i] = ranges[i - 1];
    ranges[i] = item;
    (*count)++;
}

static uint32_t xnu_build_memory_map(uint32_t mem_base, uint32_t mem_size,
                                     uint32_t kernel_base,
                                     uint32_t kernel_size,
                                     uint32_t dtb_base, uint32_t dtb_size,
                                     uint32_t initrd_base,
                                     uint32_t initrd_size)
{
    XnuReservedRange reserved[XNU_MEMORY_MAP_MAX];
    uint32_t reserved_count = 0;
    uint32_t map_count = 0;
    uint32_t mem_start = page_up(mem_base);
    uint32_t mem_end = page_down(mem_base + mem_size);
    uint32_t cursor;

    memzero(xnu_memory_map, (uint32_t)sizeof(xnu_memory_map));
    memzero(reserved, (uint32_t)sizeof(reserved));
    if (mem_end <= mem_start)
        return 0;

    xnu_reserved_insert(reserved, &reserved_count, mem_start, mem_end,
                        XNU_OPENSBI_BASE, XNU_OPENSBI_RESERVED,
                        XNU_EFI_LOADER_CODE);
    xnu_reserved_insert(reserved, &reserved_count, mem_start, mem_end,
                        (uint32_t)(uintptr_t)__caribebootx_start,
                        (uint32_t)((uintptr_t)__caribebootx_end -
                                   (uintptr_t)__caribebootx_start),
                        XNU_EFI_LOADER_CODE);
    xnu_reserved_insert(reserved, &reserved_count, mem_start, mem_end,
                        kernel_base, kernel_size, XNU_EFI_LOADER_CODE);
    xnu_reserved_insert(reserved, &reserved_count, mem_start, mem_end,
                        dtb_base, dtb_size, XNU_EFI_LOADER_DATA);
    xnu_reserved_insert(reserved, &reserved_count, mem_start, mem_end,
                        initrd_base, initrd_size, XNU_EFI_LOADER_DATA);

    cursor = mem_start;
    for (uint32_t i = 0; i < reserved_count; i++) {
        uint32_t res_start = reserved[i].start;
        uint32_t res_end = reserved[i].end;

        if (res_end <= cursor)
            continue;
        if (res_start > cursor)
            xnu_memory_map_add(&map_count, XNU_EFI_CONVENTIONAL,
                               cursor, res_start);
        if (res_start < cursor)
            res_start = cursor;
        xnu_memory_map_add(&map_count, reserved[i].type, res_start, res_end);
        cursor = res_end;
    }
    if (cursor < mem_end)
        xnu_memory_map_add(&map_count, XNU_EFI_CONVENTIONAL,
                           cursor, mem_end);

    return map_count;
}

static uint16_t rdbe16(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;
    return (uint16_t)(((uint16_t)b[0] << 8) | b[1]);
}

static uint32_t rdbe32(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;
    return ((uint32_t)b[0] << 24) |
           ((uint32_t)b[1] << 16) |
           ((uint32_t)b[2] << 8) |
           (uint32_t)b[3];
}

static uint64_t rdbe64(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;
    uint32_t hi = rdbe32(b);
    uint32_t lo = rdbe32(b + 4);
    return ((uint64_t)hi << 32) | lo;
}

static int s_eq(const char *a, const char *b)
{
    int i = 0;
    while (a[i] && b[i]) {
        if (a[i] != b[i])
            return 0;
        i++;
    }
    return a[i] == 0 && b[i] == 0;
}

static int s_starts_at(const char *s, int len, int pos, const char *pat)
{
    int i = 0;
    while (pat[i]) {
        if (pos + i >= len || s[pos + i] != pat[i])
            return 0;
        i++;
    }
    return 1;
}

static int ascii_name_from_utf16be(const uint8_t *src, uint16_t chars,
                                   char *dst, int cap)
{
    int out = 0;
    for (uint16_t i = 0; i < chars; i++) {
        uint16_t ch = (uint16_t)(((uint16_t)src[i * 2] << 8) | src[i * 2 + 1]);
        char c = (ch < 128) ? (char)ch : '?';
        if (out + 1 >= cap)
            break;
        dst[out++] = c;
    }
    dst[out] = 0;
    return out;
}

static int split_next_path_component(const char *path, int start, char *out,
                                     int cap)
{
    int i = start;
    int k = 0;

    while (path[i] == '/')
        i++;
    if (!path[i])
        return -1;

    while (path[i] && path[i] != '/') {
        if (k + 1 < cap)
            out[k++] = path[i];
        i++;
    }
    out[k] = 0;

    while (path[i] == '/')
        i++;
    return i;
}

static int path_has_more(const char *path, int pos)
{
    while (path[pos] == '/')
        pos++;
    return path[pos] != 0;
}

static int disk_read(uint64_t lba, uint32_t count, void *buf)
{
    p("[hfs-disk] read lba=");
    pdec((uint32_t)lba);
    p(" count=");
    pdec(count);
    p("\r\n");
    return virtio_blk_read_blocks(lba, count, buf);
}

static int fork_read(ForkMeta *fk, uint32_t off, void *dst, uint32_t len)
{
    uint32_t bs = hfs.blockSize ? hfs.blockSize : 4096u;
    uint32_t sectorsPerBlock = bs / HFS_SECTOR_SIZE;
    uint8_t *out = (uint8_t *)dst;

    if (!fk || !fk->size)
        return -1;
    if (!sectorsPerBlock)
        sectorsPerBlock = 1;
    if (bs > HFS_NODE_BUF_SIZE) {
        p("[hfs+] blockSize demasiado grande para secbuf\r\n");
        return -1;
    }
    if ((uint64_t)off >= fk->size)
        return -1;
    if ((uint64_t)off + len > fk->size)
        len = (uint32_t)(fk->size - off);

    while (len > 0) {
        uint32_t fileBlock = off / bs;
        uint32_t inBlock = off - (fileBlock * bs);
        uint32_t logical = fileBlock;
        uint32_t physBlock = 0;
        int foundExtent = 0;

        for (int i = 0; i < 8; i++) {
            if (!fk->ext[i].count)
                continue;
            if (logical < fk->ext[i].count) {
                physBlock = fk->ext[i].start + logical;
                foundExtent = 1;
                break;
            }
            logical -= fk->ext[i].count;
        }

        if (!foundExtent) {
            p("[hfs+] extent no encontrado\r\n");
            return -1;
        }

        if (disk_read((uint64_t)(physBlock * sectorsPerBlock),
                      sectorsPerBlock, secbuf))
            return -1;

        uint32_t chunk = bs - inBlock;
        if (chunk > len)
            chunk = len;

        uint8_t *src = secbuf + inBlock;
        for (uint32_t i = 0; i < chunk; i++)
            out[i] = src[i];

        out += chunk;
        off += chunk;
        len -= chunk;
    }

    return 0;
}

#pragma pack(push, 1)
typedef struct {
    uint16_t sig;
    uint16_t version;
    uint32_t attrs;
    uint32_t lastMountedVersion;
    uint32_t journalInfoBlock;
    uint32_t createDate;
    uint32_t modifyDate;
    uint32_t backupDate;
    uint32_t checkedDate;
    uint32_t fileCount;
    uint32_t folderCount;
    uint32_t blockSize;
    uint32_t totalBlocks;
    uint32_t freeBlocks;
    uint32_t nextAllocation;
    uint32_t rsrcClumpSize;
    uint32_t dataClumpSize;
    uint32_t nextCatalogID;
    uint32_t writeCount;
    uint64_t encodingsBitmap;
    uint32_t finderInfo[8];
    struct {
        uint64_t logicalSize;
        uint32_t clumpSize;
        uint32_t totalBlocks;
        struct {
            uint32_t startBlock;
            uint32_t blockCount;
        } extents[8];
    } allocationFile, extentsFile, catalogFile, attributesFile, startupFile;
} HFSPlusVolumeHeader;

typedef struct {
    uint32_t fLink;
    uint32_t bLink;
    uint8_t kind;
    uint8_t height;
    uint16_t numRecords;
    uint16_t reserved;
} BTNodeDescriptor;

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
    uint8_t btreeType;
    uint8_t keyCompareType;
    uint32_t attributes;
    uint32_t reserved3[16];
} BTHeaderRec;

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
} HFSPlusFolderRecordPrefix;

typedef struct {
    uint16_t recordType;
    uint16_t flags;
    uint32_t reserved1;
    uint32_t fileID;
    uint32_t createDate;
    uint32_t contentModDate;
    uint32_t attributeModDate;
    uint32_t accessDate;
    uint32_t backupDate;
    uint32_t uid;
    uint32_t gid;
    uint32_t permissions;
    uint32_t special;
    uint32_t userInfo[4];
    uint32_t finderInfo[4];
    uint32_t textEncoding;
    uint32_t reserved2;
    struct {
        uint64_t logicalSize;
        uint32_t clumpSize;
        uint32_t totalBlocks;
        struct {
            uint32_t startBlock;
            uint32_t blockCount;
        } extents[8];
    } dataFork, rsrcFork;
} HFSPlusFileRecord;
#pragma pack(pop)

static void fork_from_file_record(const HFSPlusFileRecord *rec, ForkMeta *out)
{
    out->size = rdbe64(&rec->dataFork.logicalSize);
    for (int i = 0; i < 8; i++) {
        out->ext[i].start = rdbe32(&rec->dataFork.extents[i].startBlock);
        out->ext[i].count = rdbe32(&rec->dataFork.extents[i].blockCount);
    }
}

static void fork_from_volume_fork(const void *forkPtr, ForkMeta *out)
{
    const uint8_t *p8 = (const uint8_t *)forkPtr;
    out->size = rdbe64(p8);
    for (int i = 0; i < 8; i++) {
        const uint8_t *ext = p8 + 16 + (i * 8);
        out->ext[i].start = rdbe32(ext);
        out->ext[i].count = rdbe32(ext + 4);
    }
}

static void catalog_range(uint32_t *first, uint32_t *last)
{
    uint32_t nodeSize = hfs.catalogNodeSize ? hfs.catalogNodeSize : 4096u;
    uint32_t total = hfs.totalCatalogNodes;

    if (!total)
        total = (uint32_t)hfs.catalog.size / nodeSize;

    *first = hfs.firstLeafNode;
    *last = hfs.lastLeafNode;

    if (!*first || !*last || *first >= total || *last >= total || *last < *first) {
        if (total > 1) {
            *first = 1;
            *last = total - 1;
        } else {
            *first = 0;
            *last = 0;
        }
    }
}

static int hfsplus_mount(void)
{
    if (disk_read(2, 1, secbuf))
        return -1;

    HFSPlusVolumeHeader *vh = (HFSPlusVolumeHeader *)secbuf;
    uint16_t sig = rdbe16(&vh->sig);
    if (sig != 0x482b && sig != 0x4858) {
        p("[hfs+] firma invalida: ");
        uart_puthex32(sig);
        p("\r\n");
        return -1;
    }

    hfs.blockSize = rdbe32(&vh->blockSize);
    hfs.totalBlocks = rdbe32(&vh->totalBlocks);
    fork_from_volume_fork(&vh->catalogFile, &hfs.catalog);

    hfs.catalogNodeSize = 4096;
    hfs.firstLeafNode = 1;
    hfs.lastLeafNode = 1;
    hfs.totalCatalogNodes = (uint32_t)hfs.catalog.size / hfs.catalogNodeSize;

    if (fork_read(&hfs.catalog, 0, secbuf, 4096) == 0) {
        BTHeaderRec *hdr = (BTHeaderRec *)(secbuf + sizeof(BTNodeDescriptor));
        uint16_t nodeSize = rdbe16(&hdr->nodeSize);
        if (nodeSize && nodeSize <= HFS_NODE_BUF_SIZE)
            hfs.catalogNodeSize = nodeSize;
        hfs.firstLeafNode = rdbe32(&hdr->firstLeafNode);
        hfs.lastLeafNode = rdbe32(&hdr->lastLeafNode);
        hfs.totalCatalogNodes = rdbe32(&hdr->totalNodes);
    }

    p("[hfs+] OK bs=");
    pdec(hfs.blockSize);
    p(" blocks=");
    pdec(hfs.totalBlocks);
    p(" cat.size=");
    pdec((uint32_t)hfs.catalog.size);
    p(" node=");
    pdec(hfs.catalogNodeSize);
    p("\r\n");

    for (int i = 0; i < 8; i++) {
        if (!hfs.catalog.ext[i].count)
            break;
        p("[hfs+] cat.ext ");
        pdec((uint32_t)i);
        p(": start=");
        pdec(hfs.catalog.ext[i].start);
        p(" count=");
        pdec(hfs.catalog.ext[i].count);
        p("\r\n");
    }

    return 0;
}

static int catalog_scan_child(uint32_t parent, const char *target,
                              uint32_t *folderID, ForkMeta *fileFork,
                              uint16_t *recordType)
{
    uint32_t first;
    uint32_t last;
    uint32_t nodeSize = hfs.catalogNodeSize ? hfs.catalogNodeSize : 4096u;

    if (nodeSize > HFS_NODE_BUF_SIZE)
        return -1;

    catalog_range(&first, &last);

    for (uint32_t node = first; node <= last; node++) {
        uint32_t off = node * nodeSize;
        if (fork_read(&hfs.catalog, off, secbuf, nodeSize))
            return -1;

        BTNodeDescriptor *desc = (BTNodeDescriptor *)secbuf;
        if (desc->kind != 0xff) {
            if (node == last)
                break;
            continue;
        }

        uint16_t num = rdbe16(&desc->numRecords);
        if (!num || (uint32_t)(2u * (num + 1u)) > nodeSize) {
            if (node == last)
                break;
            continue;
        }

        uint8_t *idx = secbuf + nodeSize - (2u * (num + 1u));
        for (uint16_t r = 0; r < num; r++) {
            uint16_t recOff = rdbe16(idx + (r * 2u));
            if (recOff + sizeof(HFSPlusCatalogKey) >= nodeSize)
                continue;

            uint8_t *rec = secbuf + recOff;
            HFSPlusCatalogKey *key = (HFSPlusCatalogKey *)rec;
            uint16_t keyLen = rdbe16(&key->keyLength);
            uint32_t recParent = rdbe32(&key->parentID);
            uint16_t nameLen = rdbe16(&key->nameLen);
            uint32_t dataOff = recOff + 2u + keyLen;

            if (dataOff + 2u > nodeSize)
                continue;

            char name[128];
            ascii_name_from_utf16be(rec + 8, nameLen, name, (int)sizeof(name));
            if (recParent != parent || !s_eq(name, target))
                continue;

            uint8_t *data = secbuf + dataOff;
            uint16_t rtype = rdbe16(data);
            if (recordType)
                *recordType = rtype;

            if (rtype == 0x0001 && folderID) {
                HFSPlusFolderRecordPrefix *fr = (HFSPlusFolderRecordPrefix *)data;
                *folderID = rdbe32(&fr->folderID);
                return 0;
            }

            if (rtype == 0x0002 && fileFork) {
                HFSPlusFileRecord *ff = (HFSPlusFileRecord *)data;
                fork_from_file_record(ff, fileFork);
                return 0;
            }
        }

        if (node == last)
            break;
    }

    return -1;
}

static int hfsplus_read_file(const char *path, uint8_t *dst, uint32_t cap,
                             uint32_t *outSize)
{
    ForkMeta fk;
    uint32_t parent = 2;
    int pos = 0;
    char comp[128];

    if (!path || !path[0])
        return -1;

    while ((pos = split_next_path_component(path, pos, comp, (int)sizeof(comp))) != -1) {
        uint16_t rtype = 0;
        uint32_t folderID = 0;
        int more = path_has_more(path, pos);

        if (more) {
            if (catalog_scan_child(parent, comp, &folderID, 0, &rtype) ||
                rtype != 0x0001) {
                p("[hfs+] carpeta no encontrada: ");
                p(comp);
                p("\r\n");
                return -1;
            }
            parent = folderID;
            continue;
        }

        if (catalog_scan_child(parent, comp, 0, &fk, &rtype) || rtype != 0x0002) {
            p("[hfs+] archivo no encontrado: ");
            p(comp);
            p("\r\n");
            return -1;
        }

        if (fk.size > cap) {
            p("[hfs+] buffer chico para ");
            p(comp);
            p(" size=");
            pdec((uint32_t)fk.size);
            p(" cap=");
            pdec(cap);
            p("\r\n");
            return -1;
        }

        if (fork_read(&fk, 0, dst, (uint32_t)fk.size))
            return -1;

        if (outSize)
            *outSize = (uint32_t)fk.size;
        return 0;
    }

    return -1;
}

static int extract_named_flag(const char *text, int len, const char *name,
                              char *out, int cap)
{
    int name_len = (int)slen(name);

    if (cap <= 0 || name_len <= 0)
        return -1;

    for (int i = 0; i + name_len < len; i++) {
        if (!s_starts_at(text, len, i, name) ||
            i + name_len >= len ||
            text[i + name_len] != '=')
            continue;

        int j = i + name_len + 1;
        int k = 0;
        while (j < len && k + 1 < cap) {
            char c = text[j];
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n' ||
                c == '<' || c == '"' || c == '\'')
                break;
            out[k++] = c;
            j++;
        }
        out[k] = 0;
        return k ? 0 : -1;
    }
    return -1;
}

static int extract_kernel_flags_string(const char *text, int len, char *out,
                                       int cap)
{
    const char key[] = "Kernel Flags";
    const char open[] = "<string>";
    const char close[] = "</string>";
    int key_pos = -1;
    int open_pos = -1;
    int close_pos = -1;
    int key_len = (int)sizeof(key) - 1;
    int open_len = (int)sizeof(open) - 1;
    int close_len = (int)sizeof(close) - 1;
    int k = 0;

    if (cap <= 0)
        return -1;

    for (int i = 0; i + key_len <= len; i++) {
        if (s_starts_at(text, len, i, key)) {
            key_pos = i;
            break;
        }
    }
    if (key_pos < 0)
        return -1;

    for (int i = key_pos + key_len; i + open_len <= len; i++) {
        if (s_starts_at(text, len, i, open)) {
            open_pos = i + open_len;
            break;
        }
    }
    if (open_pos < 0)
        return -1;

    for (int i = open_pos; i + close_len <= len; i++) {
        if (s_starts_at(text, len, i, close)) {
            close_pos = i;
            break;
        }
    }
    if (close_pos < 0)
        return -1;

    for (int i = open_pos; i < close_pos && k + 1 < cap; i++)
        out[k++] = text[i];
    out[k] = 0;
    return k ? 0 : -1;
}

static int load_boot_plist_paths(char *kernel_out, int kernel_cap,
                                 char *initrd_out, int initrd_cap,
                                 char *cmd_out, int cmd_cap)
{
    uint32_t size = 0;
    kernel_out[0] = 0;
    initrd_out[0] = 0;
    scopy(cmd_out, (uint32_t)cmd_cap, "console=ttyS0 -v");

    if (hfsplus_read_file("com.apple.Boot.plist", plist_buf,
                          (uint32_t)sizeof(plist_buf), &size)) {
        p("[Boot.plist] no encontrado; default /kernel.elf\r\n");
        return -1;
    }

    p("[Boot.plist] ");
    pdec(size);
    p(" bytes\r\n");

    if (extract_kernel_flags_string((const char *)plist_buf, (int)size,
                                    cmd_out, cmd_cap) == 0) {
        p("[Boot.plist] flags=");
        p(cmd_out);
        p("\r\n");
    }

    if (extract_named_flag(cmd_out, (int)slen(cmd_out), "kernel",
                           kernel_out, kernel_cap) == 0) {
        p("[Boot.plist] kernel=");
        p(kernel_out);
        p("\r\n");
    } else {
        p("[Boot.plist] sin flag kernel=; default /kernel.elf\r\n");
    }

    if (extract_named_flag(cmd_out, (int)slen(cmd_out), "initrd",
                           initrd_out, initrd_cap) == 0) {
        p("[Boot.plist] initrd=");
        p(initrd_out);
        p("\r\n");
    }

    return kernel_out[0] ? 0 : -1;
}

static void append_dtb_bootargs(uintptr_t dtb, char *cmd_out, int cmd_cap)
{
    char bootargs[128];

    if (fdt_get_chosen_bootargs((const void *)dtb, bootargs,
                                (uint32_t)sizeof(bootargs)) != 0) {
        return;
    }
    sappend_token(cmd_out, (uint32_t)cmd_cap, bootargs);
    p("[DTB] bootargs=");
    p(bootargs);
    p("\r\n");
}

typedef struct {
    uint32_t e_magic;
    uint8_t e_class;
    uint8_t e_data;
    uint8_t e_version;
    uint8_t e_osabi;
    uint8_t e_abiversion;
    uint8_t e_pad[7];
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

#define CARIBE_ELF32_MAX_PHDRS 16u

static int elf32_load_and_jump(uint8_t *img, uint32_t size,
                               uint32_t hartid, uint32_t dtb,
                               uint32_t initrd_base,
                               uint32_t initrd_size)
{
    Elf32_Ehdr header;
    Elf32_Phdr ph[CARIBE_ELF32_MAX_PHDRS];

    if (size < sizeof(Elf32_Ehdr)) {
        p("[ELF] imagen demasiado chica\r\n");
        return -1;
    }

    memcopy(&header, img, (uint32_t)sizeof(header));
    Elf32_Ehdr *eh = &header;
    if (eh->e_magic != 0x464c457fu || eh->e_class != 1 || eh->e_data != 1) {
        p("[ELF] formato no soportado\r\n");
        return -1;
    }
    if (eh->e_phentsize != sizeof(Elf32_Phdr)) {
        p("[ELF] phentsize inesperado\r\n");
        return -1;
    }
    if (eh->e_phnum == 0u || eh->e_phnum > CARIBE_ELF32_MAX_PHDRS) {
        p("[ELF] demasiados program headers\r\n");
        return -1;
    }
    if (eh->e_phoff > size ||
        ((uint32_t)eh->e_phnum * sizeof(Elf32_Phdr)) > size - eh->e_phoff) {
        p("[ELF] program headers fuera de rango\r\n");
        return -1;
    }

    memcopy(ph, img + eh->e_phoff,
            (uint32_t)eh->e_phnum * (uint32_t)sizeof(Elf32_Phdr));
    p("[ELF] metadata snapshotted before overlapping LOADs\r\n");
    uint32_t load_low = 0xffffffffu;
    uint32_t load_high = 0;
    for (uint16_t i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type != 1)
            continue;
        if (ph[i].p_memsz < ph[i].p_filesz ||
            ph[i].p_offset > size ||
            ph[i].p_filesz > size - ph[i].p_offset) {
            p("[ELF] segmento invalido\r\n");
            return -1;
        }
        uint32_t seg_end = ph[i].p_vaddr + ph[i].p_memsz;
        if (seg_end < ph[i].p_vaddr) {
            p("[ELF] segmento envuelve direccion\r\n");
            return -1;
        }
        if (ph[i].p_vaddr < load_low)
            load_low = ph[i].p_vaddr;
        if (seg_end > load_high)
            load_high = seg_end;

        uint8_t *src = img + ph[i].p_offset;
        uint8_t *dst = (uint8_t *)(uintptr_t)ph[i].p_vaddr;
        for (uint32_t k = 0; k < ph[i].p_filesz; k++)
            dst[k] = src[k];
        for (uint32_t k = ph[i].p_filesz; k < ph[i].p_memsz; k++)
            dst[k] = 0;

        p("[ELF] LOAD vaddr=");
        uart_puthex32(ph[i].p_vaddr);
        p(" filesz=");
        pdec(ph[i].p_filesz);
        p(" memsz=");
        pdec(ph[i].p_memsz);
        p("\r\n");
    }
    if (load_low == 0xffffffffu || load_high <= load_low) {
        p("[ELF] sin segmentos LOAD\r\n");
        return -1;
    }

    __asm__ volatile("fence.i" ::: "memory");

    caribe_boot_args ba;
    caribe_pack_boot_args(&ba, (uintptr_t)dtb);
    memzero(&xnu_boot_args, (uint32_t)sizeof(xnu_boot_args));
    if (xnu_cmdline[0] == 0)
        scopy(xnu_cmdline, (uint32_t)sizeof(xnu_cmdline), "console=ttyS0 -v");

    xnu_boot_args.magic = RISCV32_CARIBEBOOTX_MAGIC;
    xnu_boot_args.version = RISCV32_CARIBEBOOTX_VERSION;
    xnu_boot_args.hartid = hartid;
    xnu_boot_args.dtb_paddr = dtb;
    xnu_boot_args.dtb_size = dtb ?
        rdbe32((const void *)(uintptr_t)(dtb + 4u)) : 0;
    xnu_boot_args.mem_base = 0x80000000u;
    xnu_boot_args.mem_size = ba.mem_mb * 1024u * 1024u;
    xnu_boot_args.uart_base = (uint32_t)ba.uart_base;
    xnu_boot_args.plic_base = (uint32_t)ba.plic_base;
    xnu_boot_args.aclint_base = (uint32_t)ba.aclint_base;
    xnu_boot_args.kernel_base = load_low;
    xnu_boot_args.kernel_size = load_high - load_low;
    xnu_boot_args.initrd_base = initrd_base;
    xnu_boot_args.initrd_size = initrd_size;
    xnu_boot_args.command_line_paddr = (uint32_t)(uintptr_t)xnu_cmdline;
    xnu_boot_args.command_line_size = slen(xnu_cmdline) + 1u;
    xnu_boot_args.memory_map_count = xnu_build_memory_map(
        xnu_boot_args.mem_base, xnu_boot_args.mem_size,
        xnu_boot_args.kernel_base, xnu_boot_args.kernel_size,
        xnu_boot_args.dtb_paddr, xnu_boot_args.dtb_size,
        xnu_boot_args.initrd_base, xnu_boot_args.initrd_size);
    if (xnu_boot_args.memory_map_count != 0) {
        xnu_boot_args.memory_map_paddr =
            (uint32_t)(uintptr_t)xnu_memory_map;
        xnu_boot_args.memory_map_desc_size =
            (uint32_t)sizeof(xnu_memory_map[0]);
    }

    p("[ELF] saltando entry=");
    uart_puthex32(eh->e_entry);
    p(" hart=");
    pdec(hartid);
    p(" dtb=");
    uart_puthex32(dtb);
    p(" args=");
    uart_puthex32((uint32_t)(uintptr_t)&xnu_boot_args);
    p(" mmap=");
    pdec(xnu_boot_args.memory_map_count);
    p("\r\n");

    void (*entry)(uint32_t, uint32_t, riscv32_caribebootx_args_t *) =
        (void (*)(uint32_t, uint32_t, riscv32_caribebootx_args_t *))
        (uintptr_t)eh->e_entry;
    entry(hartid, dtb, &xnu_boot_args);
    return 0;
}

int caribe_hfsplus_boot(uint32_t hartid, uintptr_t dtb)
{
    char kernelPath[128];
    char initrdPath[128];
    uint32_t kernelSize = 0;
    uint32_t initrdSize = 0;
    const char *path;
    const char *initrd_path;

    p("\r\n[CaribeBootX] HFS+ native boot via virtio-blk\r\n");

    if (virtio_blk_init()) {
        p("[boot] virtio-blk no disponible\r\n");
        return -1;
    }

    if (hfsplus_mount()) {
        p("[boot] mount HFS+ fallo\r\n");
        return -2;
    }

    load_boot_plist_paths(kernelPath, (int)sizeof(kernelPath),
                          initrdPath, (int)sizeof(initrdPath),
                          xnu_cmdline, (int)sizeof(xnu_cmdline));
    append_dtb_bootargs(dtb, xnu_cmdline, (int)sizeof(xnu_cmdline));
    path = kernelPath[0] ? kernelPath : "/kernel.elf";

    p("[boot] cargando ");
    p(path);
    p(" en ");
    uart_puthex32((uint32_t)(uintptr_t)HFS_KERNEL_LOAD_BUFFER);
    p("\r\n");

    if (hfsplus_read_file(path, HFS_KERNEL_LOAD_BUFFER,
                          HFS_KERNEL_LOAD_CAP, &kernelSize)) {
        p("[boot] fallo leyendo kernel desde HFS+\r\n");
        return -3;
    }

    p("[boot] kernel size=");
    pdec(kernelSize);
    p("\r\n");

    initrd_path = initrdPath[0] ? initrdPath : "/initrd.img";
    if (hfsplus_read_file(initrd_path, HFS_INITRD_LOAD_BUFFER,
                          HFS_INITRD_LOAD_CAP, &initrdSize) == 0) {
        p("[boot] initrd cargado ");
        p(initrd_path);
        p(" @");
        uart_puthex32((uint32_t)(uintptr_t)HFS_INITRD_LOAD_BUFFER);
        p(" size=");
        pdec(initrdSize);
        p("\r\n");
    } else {
        initrdSize = 0;
        p("[boot] sin initrd opcional\r\n");
    }

    if (elf32_load_and_jump(HFS_KERNEL_LOAD_BUFFER, kernelSize,
                            hartid, (uint32_t)dtb,
                            initrdSize ?
                            (uint32_t)(uintptr_t)HFS_INITRD_LOAD_BUFFER : 0,
                            initrdSize)) {
        p("[boot] ELF invalido o no ejecutable\r\n");
        return -4;
    }

    p("[boot] regreso del kernel; consola fallback\r\n");
    return -5;
}
