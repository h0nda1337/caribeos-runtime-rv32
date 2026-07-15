/*
 * Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include "include/uapi/xnu_bootargs.h"

#define UART_DEFAULT_BASE 0x10000000u
#define UART_THR          0x00u
#define UART_LSR          0x05u
#define UART_LSR_THRE     0x20u

#define FDT_MAGIC          0xd00dfeedu
#define FDT_BEGIN_NODE     1u
#define FDT_END_NODE       2u
#define FDT_PROP           3u
#define FDT_NOP            4u
#define FDT_END            9u

#define VIRTIO_MMIO_MAGIC_VALUE        0x000u
#define VIRTIO_MMIO_VERSION            0x004u
#define VIRTIO_MMIO_DEVICE_ID          0x008u
#define VIRTIO_MMIO_VENDOR_ID          0x00cu
#define VIRTIO_MMIO_DEVICE_FEATURES    0x010u
#define VIRTIO_MMIO_DEVICE_FEATURES_SEL 0x014u
#define VIRTIO_MMIO_DRIVER_FEATURES    0x020u
#define VIRTIO_MMIO_DRIVER_FEATURES_SEL 0x024u
#define VIRTIO_MMIO_GUEST_PAGE_SIZE    0x028u
#define VIRTIO_MMIO_QUEUE_SEL          0x030u
#define VIRTIO_MMIO_QUEUE_NUM_MAX      0x034u
#define VIRTIO_MMIO_QUEUE_NUM          0x038u
#define VIRTIO_MMIO_QUEUE_ALIGN        0x03cu
#define VIRTIO_MMIO_QUEUE_PFN          0x040u
#define VIRTIO_MMIO_QUEUE_NOTIFY       0x050u
#define VIRTIO_MMIO_INTERRUPT_STATUS   0x060u
#define VIRTIO_MMIO_INTERRUPT_ACK      0x064u
#define VIRTIO_MMIO_STATUS             0x070u
#define VIRTIO_MMIO_CONFIG             0x100u
#define VIRTIO_MMIO_MAGIC              0x74726976u
#define VIRTIO_ID_BLOCK                2u

#define VIRTIO_STATUS_ACKNOWLEDGE      1u
#define VIRTIO_STATUS_DRIVER           2u
#define VIRTIO_STATUS_DRIVER_OK        4u
#define VIRTIO_STATUS_FEATURES_OK      8u

#define VIRTQ_DESC_F_NEXT              1u
#define VIRTQ_DESC_F_WRITE             2u
#define VIRTIO_BLK_QNUM                8u
#define VIRTIO_BLK_SECTOR_SIZE         512u
#define VIRTIO_BLK_T_IN                0u

#define HFSPLUS_VOLUME_HEADER_LBA      2u
#define HFSPLUS_SIGNATURE              0x482bu
#define HFSX_SIGNATURE                 0x4858u
#define HFSPLUS_ROOT_FOLDER_ID         2u
#define HFSPLUS_RECORD_FILE            2u
#define HFSPLUS_LEAF_NODE_KIND         0xffu
#define HFSPLUS_MAX_BLOCK_SIZE         4096u
#define HFSPLUS_MAX_EXTENTS            8u
#define HFSPLUS_MAX_NAME               128u
#define HFSPLUS_OFF_SIGNATURE          0u
#define HFSPLUS_OFF_VERSION            2u
#define HFSPLUS_OFF_BLOCK_SIZE         40u
#define HFSPLUS_OFF_TOTAL_BLOCKS       44u
#define HFSPLUS_OFF_CATALOG_FILE       272u
#define HFSPLUS_FORK_OFF_LOGICAL_SIZE  0u
#define HFSPLUS_FORK_OFF_TOTAL_BLOCKS  12u
#define HFSPLUS_FORK_OFF_EXTENTS       16u
#define HFSPLUS_BT_HEADER_OFF          14u
#define HFSPLUS_BT_OFF_FIRST_LEAF      10u
#define HFSPLUS_BT_OFF_LAST_LEAF       14u
#define HFSPLUS_BT_OFF_NODE_SIZE       18u
#define HFSPLUS_BT_OFF_TOTAL_NODES     22u
#define HFSPLUS_FILE_DATA_FORK_OFF     88u
#define HFSPLUS_FILE_ID_OFF            8u

#define SCAUSE_INTERRUPT               0x80000000u
#define SCAUSE_CODE_MASK               0x00000fffu
#define IRQ_S_TIMER                    5u
#define SIE_STIE                       0x00000020u
#define SSTATUS_SIE                    0x00000002u
#define SSTATUS_SUM                    0x00040000u
#define SCAUSE_ECALL_U                 8u

#define PTE_V                          0x001u
#define PTE_R                          0x002u
#define PTE_W                          0x004u
#define PTE_X                          0x008u
#define PTE_U                          0x010u
#define PTE_G                          0x020u
#define PTE_A                          0x040u
#define PTE_D                          0x080u

#define XNU_STAGE0_USER_BASE           0x81000000u
#define XNU_STAGE0_USER_STACK_TOP      0x81002000u
#define XNU_STAGE0_USER_REGION_SIZE    0x00400000u
#define XNU_STAGE0_KERNEL_STACK_SIZE   4096u
#define LINUX_SYS_GETCWD               17u
#define LINUX_SYS_STATFS64             43u
#define LINUX_SYS_FSTATFS64            44u
#define LINUX_SYS_FACCESSAT            48u
#define LINUX_SYS_OPENAT               56u
#define LINUX_SYS_CLOSE                57u
#define LINUX_SYS_GETDENTS64           61u
#define LINUX_SYS_READ                 63u
#define LINUX_SYS_WRITE                64u
#define LINUX_SYS_WRITEV               66u
#define LINUX_SYS_PPOLL                73u
#define LINUX_SYS_READLINKAT           78u
#define LINUX_SYS_FSTATAT64            79u
#define LINUX_SYS_FSTAT64              80u
#define LINUX_SYS_EXIT                 93u
#define LINUX_SYS_EXIT_GROUP           94u
#define LINUX_SYS_SET_TID_ADDRESS      96u
#define LINUX_SYS_FUTEX                98u
#define LINUX_SYS_NANOSLEEP            101u
#define LINUX_SYS_CLOCK_GETTIME        113u
#define LINUX_SYS_CLOCK_GETRES         114u
#define LINUX_SYS_CLOCK_NANOSLEEP      115u
#define LINUX_SYS_SCHED_SETAFFINITY    122u
#define LINUX_SYS_SCHED_GETAFFINITY    123u
#define LINUX_SYS_SCHED_YIELD          124u
#define LINUX_SYS_RT_SIGACTION         134u
#define LINUX_SYS_RT_SIGPROCMASK       135u
#define LINUX_SYS_TIMES                153u
#define LINUX_SYS_UNAME                160u
#define LINUX_SYS_GETRUSAGE            165u
#define LINUX_SYS_UMASK                166u
#define LINUX_SYS_GETCPU               168u
#define LINUX_SYS_GETTIMEOFDAY         169u
#define LINUX_SYS_GETPID               172u
#define LINUX_SYS_GETPPID              173u
#define LINUX_SYS_GETUID               174u
#define LINUX_SYS_GETEUID              175u
#define LINUX_SYS_GETGID               176u
#define LINUX_SYS_GETEGID              177u
#define LINUX_SYS_GETTID               178u
#define LINUX_SYS_SYSINFO              179u
#define LINUX_SYS_BRK                  214u
#define LINUX_SYS_MUNMAP               215u
#define LINUX_SYS_MREMAP               216u
#define LINUX_SYS_MMAP                 222u
#define LINUX_SYS_MPROTECT             226u
#define LINUX_SYS_MADVISE              233u
#define LINUX_SYS_PRLIMIT64            261u
#define LINUX_SYS_GETRANDOM            278u
#define LINUX_SYS_STATX                291u
#define LINUX_SYS_CLOCK_GETTIME64      403u
#define LINUX_SYS_CLOCK_GETRES_TIME64  406u
#define LINUX_SYS_PPOLL_TIME64         414u
#define LINUX_SYS_FUTEX_TIME64         422u

#define LINUX_AT_FDCWD                 0xffffff9cu
#define LINUX_EBADF                    9u
#define LINUX_EAGAIN                   11u
#define LINUX_EFAULT                   14u
#define LINUX_EINVAL                   22u
#define LINUX_ENOMEM                   12u
#define LINUX_ENOENT                   2u
#define LINUX_ERANGE                   34u
#define LINUX_UTS_FIELD_SIZE           65u
#define XNU_STAGE0_LINUX_PID           42u
#define XNU_STAGE0_LINUX_PPID          1u
#define XNU_STAGE0_LINUX_UID           0u
#define XNU_STAGE0_LINUX_GID           0u
#define XNU_STAGE0_LINUX_BRK           0x81003000u
#define XNU_STAGE0_PROC_FD             3u
#define XNU_STAGE0_PROC_DIR_FD         4u
#define XNU_STAGE0_PROC_FILE_VERSION   1u
#define XNU_STAGE0_PROC_FILE_CPUINFO   2u
#define XNU_STAGE0_PROC_FILE_MEMINFO   3u
#define XNU_STAGE0_PROC_FILE_CARIBEOS  4u
#define XNU_STAGE0_PROC_FILE_UPTIME    5u
#define XNU_STAGE0_PROC_FILE_STAT      6u
#define XNU_STAGE0_TIMEBASE_FALLBACK   10000000u
#define XNU_STAGE0_MMAP_BASE           0x81004000u
#define XNU_STAGE0_MMAP_LIMIT          0x81400000u
#define XNU_STAGE0_PAGE_SIZE           4096u
#define LINUX_STATX_BASIC_STATS        0x07ffu
#define LINUX_STATFS64_SIZE            88u
#define LINUX_SYSINFO_SIZE             64u
#define LINUX_RUSAGE_SIZE              72u
#define LINUX_CPUSET_WORD_SIZE         4u
#define LINUX_RLIMIT_STACK             3u
#define LINUX_RLIMIT_NOFILE            7u
#define LINUX_RUSAGE_SELF              0u
#define LINUX_HFSPLUS_SUPER_MAGIC      0x482bu
#define LINUX_FUTEX_WAIT               0u
#define LINUX_FUTEX_WAKE               1u
#define LINUX_FUTEX_CMD_MASK           0x7fu
#define LINUX_MODE_IFDIR               0040000u
#define LINUX_MODE_IFREG               0100000u
#define LINUX_MODE_IFLNK               0120000u
#define LINUX_MODE_0644                0644u
#define LINUX_MODE_0755                0755u
#define LINUX_DT_DIR                   4u
#define LINUX_DT_REG                   8u
#define LINUX_DT_LNK                   10u

#define XNU_EFI_LOADER_CODE            1u
#define XNU_EFI_LOADER_DATA            2u
#define XNU_EFI_CONVENTIONAL           7u
#define XNU_STAGE0_MEMORY_MAP_MAX      16u

#define SBI_LEGACY_SET_TIMER           0u
#define SBI_EXT_BASE                   0x10u
#define SBI_BASE_GET_SPEC_VERSION      0u
#define SBI_BASE_GET_IMPL_ID           1u
#define SBI_BASE_GET_IMPL_VERSION      2u

typedef struct virtq_desc {
    uint64_t addr;
    uint32_t len;
    uint16_t flags;
    uint16_t next;
} __attribute__((packed)) virtq_desc_t;

typedef struct virtq_avail {
    uint16_t flags;
    uint16_t idx;
    uint16_t ring[VIRTIO_BLK_QNUM];
    uint16_t used_event;
} __attribute__((packed)) virtq_avail_t;

typedef struct virtq_used_elem {
    uint32_t id;
    uint32_t len;
} __attribute__((packed)) virtq_used_elem_t;

typedef struct virtq_used {
    uint16_t flags;
    uint16_t idx;
    virtq_used_elem_t ring[VIRTIO_BLK_QNUM];
    uint16_t avail_event;
} __attribute__((packed)) virtq_used_t;

typedef struct virtio_blk_req {
    uint32_t type;
    uint32_t ioprio;
    uint64_t sector;
} __attribute__((packed)) virtio_blk_req_t;

typedef struct hfs_extent {
    uint32_t start_block;
    uint32_t block_count;
} hfs_extent_t;

typedef struct hfs_file {
    uint32_t found;
    uint32_t file_id;
    uint64_t logical_size;
    hfs_extent_t extents[HFSPLUS_MAX_EXTENTS];
} hfs_file_t;

typedef struct xnu_stage0_info {
    uint32_t hartid;
    uint32_t dtb;
    uint32_t dtb_size;
    uint32_t timebase_hz;
    uint32_t cpu_count;
    uint32_t mem_base;
    uint32_t mem_size;
    uint32_t uart_base;
    uint32_t plic_base;
    uint32_t aclint_base;
    uint32_t kernel_base;
    uint32_t kernel_size;
    uint32_t virtio_count;
    uint32_t blk_base;
    uint32_t blk_sectors_lo;
    uint32_t memory_map_count;
    uint32_t memory_map_desc_size;
    uint32_t memory_map_paddr;
    uint32_t memory_conventional_pages;
    uint32_t memory_reserved_pages;
    uint32_t memory_first_free;
    uint32_t memory_max_end;
    uint32_t memory_overlaps;
    const riscv32_caribebootx_args_t *args;
} xnu_stage0_info_t;

typedef struct xnu_stage0_user_frame {
    uint32_t ra;
    uint32_t gp;
    uint32_t tp;
    uint32_t t0;
    uint32_t t1;
    uint32_t t2;
    uint32_t s0;
    uint32_t s1;
    uint32_t a0;
    uint32_t a1;
    uint32_t a2;
    uint32_t a3;
    uint32_t a4;
    uint32_t a5;
    uint32_t a6;
    uint32_t a7;
    uint32_t user_sp;
    uint32_t sepc;
    uint32_t scause;
    uint32_t stval;
} xnu_stage0_user_frame_t;

typedef struct xnu_stage0_iovec32 {
    uint32_t base;
    uint32_t len;
} xnu_stage0_iovec32_t;

static xnu_stage0_info_t g_info;
static uint32_t g_stage0_l1[1024] __attribute__((aligned(4096)));
static uint8_t g_stage0_user_kstack[XNU_STAGE0_KERNEL_STACK_SIZE]
    __attribute__((aligned(16)));
static uint8_t g_virtq[8192] __attribute__((aligned(4096)));
static virtq_desc_t *g_desc;
static virtq_avail_t *g_avail;
static virtq_used_t *g_used;
static virtio_blk_req_t g_blk_req;
static volatile uint8_t g_blk_status;
static uint8_t g_sector[VIRTIO_BLK_SECTOR_SIZE] __attribute__((aligned(4)));
static uint8_t g_block[HFSPLUS_MAX_BLOCK_SIZE] __attribute__((aligned(4)));
static uint8_t g_node[HFSPLUS_MAX_BLOCK_SIZE] __attribute__((aligned(4)));
static hfs_extent_t g_catalog_extents[HFSPLUS_MAX_EXTENTS];
static uint32_t g_hfs_block_size;
static uint32_t g_hfs_first_leaf;
static uint32_t g_hfs_last_leaf;
static uint32_t g_hfs_total_nodes;
static uint32_t g_hfs_node_size;
static uint32_t g_hfs_catalog_blocks;
static uint64_t g_hfs_catalog_size;
static volatile uint32_t g_stage0_timer_ticks;
static volatile uint32_t g_stage0_trap_unhandled;
static volatile uint32_t g_stage0_last_scause;
static volatile uint32_t g_stage0_last_sepc;
static volatile uint32_t g_stage0_last_stval;
static uint32_t g_stage0_timer_delta;
static volatile uint32_t g_stage0_umode_syscalls;
static volatile uint32_t g_stage0_umode_writes;
static volatile uint32_t g_stage0_umode_exits;
static volatile uint32_t g_stage0_umode_last_syscall;
static uint32_t g_stage0_proc_open;
static uint32_t g_stage0_proc_offset;
static uint32_t g_stage0_proc_file;
static uint32_t g_stage0_proc_dir_open;
static uint32_t g_stage0_proc_dir_offset;
static uint32_t g_stage0_mmap_next;
static uint32_t g_stage0_umask = 022u;
static const char g_stage0_proc_version[] =
    "Linux version 0.0.1-caribe (XNU-CaribeOS stage0) rv32imac_zicsr_zifencei\n";
static const char g_stage0_proc_cpuinfo[] =
    "processor\t: 0\n"
    "hart\t\t: 0\n"
    "isa\t\t: rv32imac_zicsr_zifencei\n"
    "mmu\t\t: sv32\n"
    "uarch\t\t: qemu-virt\n"
    "firmware\t: OpenSBI\n"
    "bootloader\t: CaribeBootX\n"
    "kernel\t\t: XNU-CaribeOS stage0\n";
static const char g_stage0_proc_meminfo[] =
    "MemTotal:        262144 kB\n"
    "MemFree:         131072 kB\n"
    "MemAvailable:    131072 kB\n";
static const char g_stage0_proc_uptime[] =
    "0.00 0.00\n";
static const char g_stage0_proc_stat[] =
    "cpu  0 0 0 0 0 0 0 0 0 0\n"
    "cpu0 0 0 0 0 0 0 0 0 0 0\n"
    "intr 0\n"
    "ctxt 0\n"
    "btime 0\n"
    "processes 1\n"
    "procs_running 1\n"
    "procs_blocked 0\n"
    "softirq 0 0 0 0 0 0 0 0 0 0 0\n";
static const char g_stage0_proc_caribeos[] =
    "bootloader\t: CaribeBootX\n"
    "cbx_version\t: 1\n"
    "opensbi_impl\t: OpenSBI\n"
    "sbi_runtime\t: reset=yes debug_console=yes ipi=yes rfence=yes\n"
    "fdt_model\t: riscv-virtio,qemu\n"
    "fdt_compatible\t: riscv-virtio\n"
    "active_mem\t: 0x80000000+0x10000000\n"
    "total_mem_kb\t: 262144\n"
    "ram_banks\t: 1\n"
    "mem_pages\t: total=65536 usable=32768 reserved=0\n";

extern void xnu_stage0_trap_vector(void);
extern void xnu_stage0_user_trap_vector(void);
extern void xnu_stage0_enter_user(uint32_t pc, uint32_t sp,
    uint32_t kernel_sp);
extern uint8_t xnu_stage0_umode_payload_start[];
extern uint8_t xnu_stage0_umode_payload_end[];

static uint8_t uart_read(uint32_t offset)
{
    return *(volatile uint8_t *)(uintptr_t)(g_info.uart_base + offset);
}

static void uart_write(uint32_t offset, uint8_t value)
{
    *(volatile uint8_t *)(uintptr_t)(g_info.uart_base + offset) = value;
}

static void putc(char c)
{
    if (c == '\n') {
        putc('\r');
    }
    while ((uart_read(UART_LSR) & UART_LSR_THRE) == 0) {
    }
    uart_write(UART_THR, (uint8_t)c);
}

static void puts(const char *s)
{
    while (s != 0 && *s != '\0') {
        putc(*s++);
    }
}

static void puthex32(uint32_t v)
{
    static const char hex[] = "0123456789abcdef";

    for (int i = 7; i >= 0; i--) {
        putc(hex[(v >> (i * 4)) & 0xfu]);
    }
}

static void puthex64(uint64_t v)
{
    puthex32((uint32_t)(v >> 32));
    puthex32((uint32_t)v);
}

static void putdec(uint32_t v)
{
    char buf[10];
    int i = 0;

    if (v == 0) {
        putc('0');
        return;
    }
    while (v != 0 && i < (int)sizeof(buf)) {
        buf[i++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    while (i > 0) {
        putc(buf[--i]);
    }
}

static uint32_t csr_read_sstatus(void)
{
    uint32_t v;

    __asm__ volatile("csrr %0, sstatus" : "=r"(v));
    return v;
}

static uint32_t csr_read_sie(void)
{
    uint32_t v;

    __asm__ volatile("csrr %0, sie" : "=r"(v));
    return v;
}

static uint32_t csr_read_stvec(void)
{
    uint32_t v;

    __asm__ volatile("csrr %0, stvec" : "=r"(v));
    return v;
}

static uint32_t csr_read_satp(void)
{
    uint32_t v;

    __asm__ volatile("csrr %0, satp" : "=r"(v));
    return v;
}

static uint64_t csr_read_time(void)
{
    uint32_t hi1;
    uint32_t hi2;
    uint32_t lo;

    do {
        __asm__ volatile("csrr %0, timeh" : "=r"(hi1));
        __asm__ volatile("csrr %0, time" : "=r"(lo));
        __asm__ volatile("csrr %0, timeh" : "=r"(hi2));
    } while (hi1 != hi2);

    return ((uint64_t)hi1 << 32) | lo;
}

static void csr_write_stvec(uint32_t v)
{
    __asm__ volatile("csrw stvec, %0" :: "r"(v) : "memory");
}

static void csr_set_sie(uint32_t mask)
{
    __asm__ volatile("csrs sie, %0" :: "r"(mask) : "memory");
}

static void csr_clear_sie(uint32_t mask)
{
    __asm__ volatile("csrc sie, %0" :: "r"(mask) : "memory");
}

static void csr_set_sstatus(uint32_t mask)
{
    __asm__ volatile("csrs sstatus, %0" :: "r"(mask) : "memory");
}

static void csr_write_satp(uint32_t v)
{
    __asm__ volatile("csrw satp, %0" :: "r"(v) : "memory");
    __asm__ volatile("sfence.vma zero, zero" ::: "memory");
}

static uint32_t sbi_base_value(uint32_t fid)
{
    register uint32_t a0 __asm__("a0") = 0;
    register uint32_t a1 __asm__("a1") = 0;
    register uint32_t a6 __asm__("a6") = fid;
    register uint32_t a7 __asm__("a7") = SBI_EXT_BASE;

    __asm__ volatile("ecall"
        : "+r"(a0), "+r"(a1)
        : "r"(a6), "r"(a7)
        : "memory");
    return a0 == 0 ? a1 : 0xffffffffu;
}

static void sbi_set_timer(uint64_t deadline)
{
    register uint32_t a0 __asm__("a0") = (uint32_t)deadline;
    register uint32_t a1 __asm__("a1") = (uint32_t)(deadline >> 32);
    register uint32_t a7 __asm__("a7") = SBI_LEGACY_SET_TIMER;

    __asm__ volatile("ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a7)
        : "memory");
}

void xnu_stage0_trap_dispatch(uint32_t scause, uint32_t sepc, uint32_t stval)
{
    g_stage0_last_scause = scause;
    g_stage0_last_sepc = sepc;
    g_stage0_last_stval = stval;

    if ((scause & SCAUSE_INTERRUPT) != 0 &&
        (scause & SCAUSE_CODE_MASK) == IRQ_S_TIMER) {
        g_stage0_timer_ticks++;
        if (g_stage0_timer_ticks < 3) {
            sbi_set_timer(csr_read_time() + g_stage0_timer_delta);
        }
        return;
    }

    g_stage0_trap_unhandled++;
}

static void linux_print_user_buf(uint32_t addr, uint32_t len)
{
    const char *buf = (const char *)(uintptr_t)addr;

    if (len > 512u) {
        len = 512u;
    }
    for (uint32_t i = 0; i < len; i++) {
        char c = buf[i];

        putc((c >= 32 && c < 127) || c == '\n' ? c : '.');
    }
}

static void linux_print_user_cstr(uint32_t addr, uint32_t max_len)
{
    const char *buf = (const char *)(uintptr_t)addr;

    for (uint32_t i = 0; i < max_len && buf[i] != '\0'; i++) {
        char c = buf[i];

        putc((c >= 32 && c < 127) ? c : '.');
    }
}

static uint32_t linux_strlen(const char *s)
{
    uint32_t len = 0;

    while (s[len] != '\0') {
        len++;
    }
    return len;
}

static int linux_user_streq(uint32_t addr, const char *text)
{
    const char *buf = (const char *)(uintptr_t)addr;
    uint32_t i = 0;

    for (;; i++) {
        if (i > 128u) {
            return 0;
        }
        if (buf[i] != text[i]) {
            return 0;
        }
        if (text[i] == '\0') {
            return 1;
        }
    }
}

static uint32_t linux_copy_to_user(uint32_t addr, const char *src,
    uint32_t len)
{
    uint8_t *dst = (uint8_t *)(uintptr_t)addr;

    for (uint32_t i = 0; i < len; i++) {
        dst[i] = (uint8_t)src[i];
    }
    return len;
}

static uint32_t linux_errno(uint32_t err)
{
    return 0u - err;
}

static void linux_store32(uint32_t addr, uint32_t value)
{
    *(uint32_t *)(uintptr_t)addr = value;
}

static void linux_store8(uint32_t addr, uint8_t value)
{
    *(uint8_t *)(uintptr_t)addr = value;
}

static void linux_store16(uint32_t addr, uint16_t value)
{
    linux_store8(addr + 0u, (uint8_t)value);
    linux_store8(addr + 1u, (uint8_t)(value >> 8));
}

static void linux_store64(uint32_t addr, uint32_t lo, uint32_t hi)
{
    linux_store32(addr + 0u, lo);
    linux_store32(addr + 4u, hi);
}

static uint32_t linux_load32(uint32_t addr)
{
    return *(const uint32_t *)(uintptr_t)addr;
}

static void linux_zero_user(uint32_t addr, uint32_t len)
{
    for (uint32_t i = 0; i < len; i++) {
        linux_store8(addr + i, 0);
    }
}

static uint32_t linux_copy_cstr_to_user(uint32_t addr, const char *text,
    uint32_t max_len, uint32_t include_nul)
{
    uint32_t len = linux_strlen(text);
    uint32_t need = len + (include_nul != 0 ? 1u : 0u);

    if (addr == 0 || max_len < need) {
        return UINT32_MAX;
    }
    linux_copy_to_user(addr, text, len);
    if (include_nul != 0) {
        linux_store8(addr + len, 0);
    }
    return need;
}

static int linux_known_path(uint32_t addr)
{
    return linux_user_streq(addr, "/") ||
        linux_user_streq(addr, "/kernel.elf") ||
        linux_user_streq(addr, "/proc") ||
        linux_user_streq(addr, "/proc/cpuinfo") ||
        linux_user_streq(addr, "/proc/meminfo") ||
        linux_user_streq(addr, "/proc/uptime") ||
        linux_user_streq(addr, "/proc/stat") ||
        linux_user_streq(addr, "/proc/caribeos") ||
        linux_user_streq(addr, "/proc/version") ||
        linux_user_streq(addr, "/proc/self") ||
        linux_user_streq(addr, "/proc/self/exe");
}

static int linux_path_metadata(uint32_t addr, uint32_t *mode,
    uint32_t *size, uint32_t *ino)
{
    if (linux_user_streq(addr, "/") ||
        linux_user_streq(addr, "/proc") ||
        linux_user_streq(addr, "/proc/self")) {
        *mode = LINUX_MODE_IFDIR | LINUX_MODE_0755;
        *size = 0;
        *ino = 5;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/self/exe")) {
        *mode = LINUX_MODE_IFLNK | LINUX_MODE_0755;
        *size = 11u;
        *ino = 7;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/version")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_version);
        *ino = 8;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/cpuinfo")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_cpuinfo);
        *ino = 9;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/meminfo")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_meminfo);
        *ino = 10;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/uptime")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_uptime);
        *ino = 12;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/stat")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_stat);
        *ino = 13;
        return 1;
    }
    if (linux_user_streq(addr, "/proc/caribeos")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = linux_strlen(g_stage0_proc_caribeos);
        *ino = 11;
        return 1;
    }
    if (linux_user_streq(addr, "/kernel.elf")) {
        *mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        *size = g_info.kernel_size;
        *ino = 17;
        return 1;
    }
    return 0;
}

static void linux_copyout_statx(uint32_t addr, uint32_t mode,
    uint32_t size, uint32_t ino)
{
    linux_zero_user(addr, 256u);
    linux_store32(addr + 0u, LINUX_STATX_BASIC_STATS);
    linux_store32(addr + 4u, 4096u);
    linux_store32(addr + 16u, 1u);
    *(uint16_t *)(uintptr_t)(addr + 28u) = (uint16_t)mode;
    linux_store32(addr + 32u, ino);
    linux_store32(addr + 40u, size);
    linux_store32(addr + 56u, LINUX_STATX_BASIC_STATS);
    linux_store32(addr + 140u, 1u);
    linux_store32(addr + 144u, 1u);
}

static void linux_copyout_stat64(uint32_t addr, uint32_t mode,
    uint32_t size, uint32_t ino)
{
    linux_zero_user(addr, 104u);
    linux_store64(addr + 0u, 1u, 0);
    linux_store64(addr + 8u, ino, 0);
    linux_store32(addr + 16u, mode);
    linux_store32(addr + 20u, 1u);
    linux_store64(addr + 48u, size, 0);
    linux_store32(addr + 56u, 4096u);
    linux_store64(addr + 64u, size == 0 ? 0u : 1u, 0);
}

static void linux_copyout_statfs64(uint32_t addr)
{
    uint32_t blocks = (256u * 1024u * 1024u) / XNU_STAGE0_PAGE_SIZE;

    linux_zero_user(addr, LINUX_STATFS64_SIZE);
    linux_store32(addr + 0u, LINUX_HFSPLUS_SUPER_MAGIC);
    linux_store32(addr + 4u, XNU_STAGE0_PAGE_SIZE);
    linux_store64(addr + 8u, blocks, 0);
    linux_store64(addr + 16u, blocks / 2u, 0);
    linux_store64(addr + 24u, blocks / 2u, 0);
    linux_store64(addr + 32u, 1024u, 0);
    linux_store64(addr + 40u, 512u, 0);
    linux_store32(addr + 56u, 127u);
    linux_store32(addr + 60u, XNU_STAGE0_PAGE_SIZE);
}

static void linux_time_now(uint32_t *sec, uint32_t *nsec);

static void linux_copyout_sysinfo(uint32_t addr)
{
    uint32_t sec;
    uint32_t nsec;

    linux_time_now(&sec, &nsec);
    (void)nsec;
    linux_zero_user(addr, LINUX_SYSINFO_SIZE);
    linux_store32(addr + 0u, sec);
    linux_store32(addr + 16u, 256u * 1024u * 1024u);
    linux_store32(addr + 20u, 128u * 1024u * 1024u);
    linux_store16(addr + 40u, 1u);
    linux_store32(addr + 52u, 1u);
}

static void linux_copyout_rlimit64(uint32_t addr, uint32_t cur, uint32_t max)
{
    linux_store64(addr + 0u, cur, 0);
    linux_store64(addr + 8u, max, 0);
}

static uint32_t linux_align8(uint32_t value)
{
    return (value + 7u) & ~7u;
}

static uint32_t linux_page_align(uint32_t value)
{
    return (value + XNU_STAGE0_PAGE_SIZE - 1u) &
        ~(XNU_STAGE0_PAGE_SIZE - 1u);
}

static int linux_user_range(uint32_t addr, uint32_t len)
{
    if (addr < XNU_STAGE0_USER_BASE || len > XNU_STAGE0_USER_REGION_SIZE) {
        return 0;
    }
    return addr <= XNU_STAGE0_USER_BASE + XNU_STAGE0_USER_REGION_SIZE - len;
}

static int linux_proc_dir_entry(uint32_t index, const char **name,
    uint32_t *ino, uint32_t *type)
{
    switch (index) {
    case 0:
        *name = ".";
        *ino = 5;
        *type = LINUX_DT_DIR;
        return 1;
    case 1:
        *name = "..";
        *ino = 2;
        *type = LINUX_DT_DIR;
        return 1;
    case 2:
        *name = "self";
        *ino = 6;
        *type = LINUX_DT_DIR;
        return 1;
    case 3:
        *name = "cpuinfo";
        *ino = 9;
        *type = LINUX_DT_REG;
        return 1;
    case 4:
        *name = "meminfo";
        *ino = 10;
        *type = LINUX_DT_REG;
        return 1;
    case 5:
        *name = "caribeos";
        *ino = 11;
        *type = LINUX_DT_REG;
        return 1;
    case 6:
        *name = "version";
        *ino = 8;
        *type = LINUX_DT_REG;
        return 1;
    case 7:
        *name = "uptime";
        *ino = 12;
        *type = LINUX_DT_REG;
        return 1;
    case 8:
        *name = "stat";
        *ino = 13;
        *type = LINUX_DT_REG;
        return 1;
    default:
        return 0;
    }
}

static const char *linux_proc_file_content(uint32_t file, uint32_t *size)
{
    switch (file) {
    case XNU_STAGE0_PROC_FILE_VERSION:
        *size = linux_strlen(g_stage0_proc_version);
        return g_stage0_proc_version;
    case XNU_STAGE0_PROC_FILE_CPUINFO:
        *size = linux_strlen(g_stage0_proc_cpuinfo);
        return g_stage0_proc_cpuinfo;
    case XNU_STAGE0_PROC_FILE_MEMINFO:
        *size = linux_strlen(g_stage0_proc_meminfo);
        return g_stage0_proc_meminfo;
    case XNU_STAGE0_PROC_FILE_UPTIME:
        *size = linux_strlen(g_stage0_proc_uptime);
        return g_stage0_proc_uptime;
    case XNU_STAGE0_PROC_FILE_STAT:
        *size = linux_strlen(g_stage0_proc_stat);
        return g_stage0_proc_stat;
    case XNU_STAGE0_PROC_FILE_CARIBEOS:
        *size = linux_strlen(g_stage0_proc_caribeos);
        return g_stage0_proc_caribeos;
    default:
        *size = 0;
        return "";
    }
}

static uint32_t linux_copyout_dirent64(uint32_t addr, uint32_t ino,
    uint32_t off, uint32_t type, const char *name)
{
    uint32_t name_len = linux_strlen(name);
    uint32_t reclen = linux_align8(19u + name_len + 1u);

    linux_zero_user(addr, reclen);
    linux_store64(addr + 0u, ino, 0);
    linux_store64(addr + 8u, off, 0);
    linux_store16(addr + 16u, (uint16_t)reclen);
    linux_store8(addr + 18u, (uint8_t)type);
    linux_copy_to_user(addr + 19u, name, name_len);
    linux_store8(addr + 19u + name_len, 0);
    return reclen;
}

static void linux_time_now(uint32_t *sec, uint32_t *nsec)
{
    uint32_t hz = g_info.timebase_hz != 0 ?
        g_info.timebase_hz : XNU_STAGE0_TIMEBASE_FALLBACK;
    uint32_t ticks = (uint32_t)csr_read_time();
    uint32_t ns_per_tick = hz != 0 ? (1000000000u / hz) : 100u;

    if (ns_per_tick == 0) {
        ns_per_tick = 1;
    }
    *sec = hz != 0 ? ticks / hz : 0;
    *nsec = hz != 0 ? (ticks % hz) * ns_per_tick : 0;
}

static void linux_copy_uts_field(uint8_t *uts, uint32_t field,
    const char *text)
{
    uint8_t *dst = uts + field * LINUX_UTS_FIELD_SIZE;
    uint32_t i = 0;

    for (; i + 1u < LINUX_UTS_FIELD_SIZE && text[i] != '\0'; i++) {
        dst[i] = (uint8_t)text[i];
    }
    for (; i < LINUX_UTS_FIELD_SIZE; i++) {
        dst[i] = 0;
    }
}

static void linux_fill_uname(uint32_t addr)
{
    uint8_t *uts = (uint8_t *)(uintptr_t)addr;

    linux_copy_uts_field(uts, 0, "Linux");
    linux_copy_uts_field(uts, 1, "caribeos-rv32");
    linux_copy_uts_field(uts, 2, "0.0.1-caribe");
    linux_copy_uts_field(uts, 3, "XNU-CaribeOS stage0");
    linux_copy_uts_field(uts, 4, "riscv32");
    linux_copy_uts_field(uts, 5, "localdomain");
}

void xnu_stage0_user_trap_dispatch(xnu_stage0_user_frame_t *frame)
{
    g_stage0_umode_syscalls++;
    g_stage0_umode_last_syscall = frame->a7;
    g_stage0_last_scause = frame->scause;
    g_stage0_last_sepc = frame->sepc;
    g_stage0_last_stval = frame->stval;

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_GETPID) {
        puts("[riscv32] linux getpid() -> ");
        putdec(XNU_STAGE0_LINUX_PID);
        puts("\n");
        frame->a0 = XNU_STAGE0_LINUX_PID;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_GETPPID ||
        frame->a7 == LINUX_SYS_GETTID ||
        frame->a7 == LINUX_SYS_GETUID ||
        frame->a7 == LINUX_SYS_GETEUID ||
        frame->a7 == LINUX_SYS_GETGID ||
        frame->a7 == LINUX_SYS_GETEGID)) {
        const char *name = "getid";
        uint32_t ret = 0;

        switch (frame->a7) {
        case LINUX_SYS_GETPPID:
            name = "getppid";
            ret = XNU_STAGE0_LINUX_PPID;
            break;
        case LINUX_SYS_GETTID:
            name = "gettid";
            ret = XNU_STAGE0_LINUX_PID;
            break;
        case LINUX_SYS_GETUID:
            name = "getuid";
            ret = XNU_STAGE0_LINUX_UID;
            break;
        case LINUX_SYS_GETEUID:
            name = "geteuid";
            ret = XNU_STAGE0_LINUX_UID;
            break;
        case LINUX_SYS_GETGID:
            name = "getgid";
            ret = XNU_STAGE0_LINUX_GID;
            break;
        case LINUX_SYS_GETEGID:
            name = "getegid";
            ret = XNU_STAGE0_LINUX_GID;
            break;
        default:
            break;
        }

        puts("[riscv32] linux ");
        puts(name);
        puts("() -> ");
        putdec(ret);
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_SET_TID_ADDRESS) {
        puts("[riscv32] linux set_tid_address(addr=0x");
        puthex32(frame->a0);
        puts(") -> ");
        putdec(XNU_STAGE0_LINUX_PID);
        puts("\n");
        frame->a0 = XNU_STAGE0_LINUX_PID;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_FUTEX ||
        frame->a7 == LINUX_SYS_FUTEX_TIME64)) {
        uint32_t cmd = frame->a1 & LINUX_FUTEX_CMD_MASK;
        uint32_t ret = 0;

        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_FUTEX_TIME64 ? "futex_time64" : "futex");
        puts("(uaddr=0x");
        puthex32(frame->a0);
        puts(", op=");
        putdec(cmd);
        puts(", val=");
        putdec(frame->a2);
        puts(") -> ");
        if (frame->a0 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (cmd == LINUX_FUTEX_WAIT) {
            ret = linux_errno(LINUX_EAGAIN);
            puts("-EAGAIN");
        } else if (cmd == LINUX_FUTEX_WAKE) {
            ret = 0;
            putdec(ret);
        } else {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_RT_SIGACTION) {
        uint32_t ret = 0;

        puts("[riscv32] linux rt_sigaction(sig=");
        putdec(frame->a0);
        puts(", act=0x");
        puthex32(frame->a1);
        puts(", oldact=0x");
        puthex32(frame->a2);
        puts(") -> ");
        if (frame->a0 == 0 || frame->a0 >= 65u) {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        } else {
            if (frame->a2 != 0) {
                linux_zero_user(frame->a2, 16u);
            }
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_RT_SIGPROCMASK) {
        puts("[riscv32] linux rt_sigprocmask(how=");
        putdec(frame->a0);
        puts(", set=0x");
        puthex32(frame->a1);
        puts(", oldset=0x");
        puthex32(frame->a2);
        puts(") -> 0\n");
        if (frame->a2 != 0) {
            linux_zero_user(frame->a2, frame->a3 < 8u ? frame->a3 : 8u);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_SCHED_GETAFFINITY) {
        uint32_t ret = LINUX_CPUSET_WORD_SIZE;

        puts("[riscv32] linux sched_getaffinity(pid=");
        putdec(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(") -> ");
        if (frame->a0 > 1u || frame->a1 < LINUX_CPUSET_WORD_SIZE ||
            frame->a2 == 0) {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        } else {
            linux_store32(frame->a2, 1u);
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_SCHED_SETAFFINITY) {
        uint32_t ret = 0;

        puts("[riscv32] linux sched_setaffinity(pid=");
        putdec(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(") -> ");
        if (frame->a0 > 1u || frame->a1 < LINUX_CPUSET_WORD_SIZE ||
            frame->a2 == 0 || (linux_load32(frame->a2) & 1u) == 0) {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        } else {
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_GETCPU) {
        puts("[riscv32] linux getcpu(cpu=0x");
        puthex32(frame->a0);
        puts(", node=0x");
        puthex32(frame->a1);
        puts(") -> 0\n");
        if (frame->a0 != 0) {
            linux_store32(frame->a0, 0);
        }
        if (frame->a1 != 0) {
            linux_store32(frame->a1, 0);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_CLOCK_GETRES ||
        frame->a7 == LINUX_SYS_CLOCK_GETRES_TIME64)) {
        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_CLOCK_GETRES_TIME64 ?
            "clock_getres_time64" : "clock_getres");
        puts("(clock=");
        putdec(frame->a0);
        puts(", tp=0x");
        puthex32(frame->a1);
        puts(") -> 0\n");
        if (frame->a1 != 0) {
            linux_store32(frame->a1 + 0u, 0);
            linux_store32(frame->a1 + 4u, 0);
            if (frame->a7 == LINUX_SYS_CLOCK_GETRES_TIME64) {
                linux_store32(frame->a1 + 8u, 1u);
                linux_store32(frame->a1 + 12u, 0);
            } else {
                linux_store32(frame->a1 + 4u, 1u);
            }
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_NANOSLEEP) {
        puts("[riscv32] linux nanosleep(req=0x");
        puthex32(frame->a0);
        puts(", rem=0x");
        puthex32(frame->a1);
        puts(") -> 0\n");
        if (frame->a1 != 0) {
            linux_zero_user(frame->a1, 8u);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_CLOCK_NANOSLEEP) {
        puts("[riscv32] linux clock_nanosleep(clock=");
        putdec(frame->a0);
        puts(", req=0x");
        puthex32(frame->a2);
        puts(", rem=0x");
        puthex32(frame->a3);
        puts(") -> 0\n");
        if (frame->a3 != 0) {
            linux_zero_user(frame->a3, 8u);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_SCHED_YIELD) {
        puts("[riscv32] linux sched_yield() -> 0\n");
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_PPOLL ||
        frame->a7 == LINUX_SYS_PPOLL_TIME64)) {
        uint32_t ret = 0;

        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_PPOLL_TIME64 ? "ppoll_time64" : "ppoll");
        puts("(fds=0x");
        puthex32(frame->a0);
        puts(", nfds=");
        putdec(frame->a1);
        puts(") -> ");
        if (frame->a0 == 0 && frame->a1 == 0) {
            putdec(ret);
        } else {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_GETRUSAGE) {
        puts("[riscv32] linux getrusage(who=");
        putdec(frame->a0);
        puts(", usage=0x");
        puthex32(frame->a1);
        puts(") -> ");
        if (frame->a1 == 0) {
            frame->a0 = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else {
            linux_zero_user(frame->a1, LINUX_RUSAGE_SIZE);
            frame->a0 = 0;
            putdec(frame->a0);
        }
        puts("\n");
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_TIMES) {
        uint32_t sec;
        uint32_t nsec;
        uint32_t ticks;

        linux_time_now(&sec, &nsec);
        ticks = sec * 100u + (nsec / 10000000u);
        puts("[riscv32] linux times(tms=0x");
        puthex32(frame->a0);
        puts(") -> ticks=");
        putdec(ticks);
        puts("\n");
        if (frame->a0 != 0) {
            linux_zero_user(frame->a0, 16u);
        }
        frame->a0 = ticks;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_UMASK) {
        uint32_t old = g_stage0_umask;

        g_stage0_umask = frame->a0 & 0777u;
        puts("[riscv32] linux umask(mask=");
        putdec(g_stage0_umask);
        puts(") -> ");
        putdec(old);
        puts("\n");
        frame->a0 = old;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_BRK) {
        puts("[riscv32] linux brk(0x");
        puthex32(frame->a0);
        puts(") -> 0x");
        puthex32(XNU_STAGE0_LINUX_BRK);
        puts("\n");
        frame->a0 = XNU_STAGE0_LINUX_BRK;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_MMAP) {
        uint32_t len = linux_page_align(frame->a1);
        uint32_t ret = linux_errno(LINUX_ENOMEM);

        puts("[riscv32] linux mmap(addr=0x");
        puthex32(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(", prot=0x");
        puthex32(frame->a2);
        puts(", flags=0x");
        puthex32(frame->a3);
        puts(") -> ");
        if (len != 0 && len <= XNU_STAGE0_MMAP_LIMIT - g_stage0_mmap_next) {
            ret = g_stage0_mmap_next;
            g_stage0_mmap_next += len;
            linux_zero_user(ret, len);
            puts("0x");
            puthex32(ret);
        } else {
            puts("-ENOMEM");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_MREMAP) {
        uint32_t ret = linux_errno(LINUX_ENOMEM);

        puts("[riscv32] linux mremap(old=0x");
        puthex32(frame->a0);
        puts(", old_size=");
        putdec(frame->a1);
        puts(", new_size=");
        putdec(frame->a2);
        puts(") -> ");
        if (frame->a1 != 0 && !linux_user_range(frame->a0, frame->a1)) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (frame->a2 <= frame->a1) {
            ret = frame->a0;
            puts("0x");
            puthex32(ret);
        } else {
            puts("-ENOMEM");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_MADVISE) {
        uint32_t ret = 0;

        puts("[riscv32] linux madvise(addr=0x");
        puthex32(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(", advice=");
        putdec(frame->a2);
        puts(") -> ");
        if (frame->a1 != 0 && !linux_user_range(frame->a0, frame->a1)) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else {
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_MUNMAP ||
        frame->a7 == LINUX_SYS_MPROTECT)) {
        uint32_t ret = 0;

        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_MUNMAP ? "munmap" : "mprotect");
        puts("(addr=0x");
        puthex32(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(") -> ");
        if (frame->a1 != 0 && !linux_user_range(frame->a0, frame->a1)) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else {
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_UNAME) {
        puts("[riscv32] linux uname(buf=0x");
        puthex32(frame->a0);
        puts(") -> Linux/caribeos-rv32/riscv32\n");
        if (frame->a0 != 0) {
            linux_fill_uname(frame->a0);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_GETCWD) {
        uint32_t ret = linux_copy_cstr_to_user(frame->a0, "/", frame->a1, 1u);

        puts("[riscv32] linux getcwd(buf=0x");
        puthex32(frame->a0);
        puts(", size=");
        putdec(frame->a1);
        puts(") -> ");
        if (ret == UINT32_MAX) {
            puts("-ERANGE");
            frame->a0 = linux_errno(LINUX_ERANGE);
        } else {
            puts("\"/\"");
            frame->a0 = ret;
        }
        puts("\n");
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_SYSINFO) {
        puts("[riscv32] linux sysinfo(info=0x");
        puthex32(frame->a0);
        puts(") -> ");
        if (frame->a0 == 0) {
            frame->a0 = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else {
            linux_copyout_sysinfo(frame->a0);
            frame->a0 = 0;
            putdec(frame->a0);
        }
        puts("\n");
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_PRLIMIT64) {
        uint32_t cur = 0xffffffffu;
        uint32_t max = 0xffffffffu;
        uint32_t ret = 0;

        puts("[riscv32] linux prlimit64(pid=");
        putdec(frame->a0);
        puts(", resource=");
        putdec(frame->a1);
        puts(", old=0x");
        puthex32(frame->a3);
        puts(") -> ");
        if (frame->a2 != 0) {
            ret = linux_errno(LINUX_EINVAL);
            puts("-EINVAL");
        } else if (frame->a1 == LINUX_RLIMIT_STACK) {
            cur = 8u * 1024u * 1024u;
            max = 8u * 1024u * 1024u;
        } else if (frame->a1 == LINUX_RLIMIT_NOFILE) {
            cur = 16u;
            max = 16u;
        }
        if (ret == 0) {
            if (frame->a3 != 0) {
                linux_copyout_rlimit64(frame->a3, cur, max);
            }
            putdec(ret);
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_STATFS64) {
        uint32_t ret = linux_errno(LINUX_ENOENT);

        puts("[riscv32] linux statfs64(path=\"");
        if (frame->a0 != 0) {
            linux_print_user_cstr(frame->a0, 96u);
        }
        puts("\") -> ");
        if (frame->a1 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (frame->a0 != 0 && linux_known_path(frame->a0)) {
            linux_copyout_statfs64(frame->a1);
            ret = 0;
            putdec(ret);
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_FACCESSAT) {
        uint32_t ret = linux_errno(LINUX_ENOENT);

        puts("[riscv32] linux faccessat(dirfd=");
        if (frame->a0 == LINUX_AT_FDCWD) {
            puts("AT_FDCWD");
        } else {
            putdec(frame->a0);
        }
        puts(", path=\"");
        if (frame->a1 != 0) {
            linux_print_user_cstr(frame->a1, 96u);
        }
        puts("\") -> ");
        if (frame->a1 != 0 && linux_known_path(frame->a1)) {
            ret = 0;
            putdec(ret);
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_READLINKAT) {
        uint32_t ret = linux_errno(LINUX_ENOENT);

        puts("[riscv32] linux readlinkat(path=\"");
        if (frame->a1 != 0) {
            linux_print_user_cstr(frame->a1, 96u);
        }
        puts("\", size=");
        putdec(frame->a3);
        puts(") -> ");
        if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/self/exe")) {
            ret = linux_copy_cstr_to_user(frame->a2, "/kernel.elf",
                frame->a3, 0u);
            if (ret == UINT32_MAX) {
                ret = linux_errno(LINUX_ERANGE);
                puts("-ERANGE");
            } else {
                puts("\"/kernel.elf\"");
            }
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_FSTATAT64) {
        uint32_t mode;
        uint32_t size;
        uint32_t ino;
        uint32_t ret = linux_errno(LINUX_ENOENT);

        puts("[riscv32] linux fstatat64(dirfd=");
        if (frame->a0 == LINUX_AT_FDCWD) {
            puts("AT_FDCWD");
        } else {
            putdec(frame->a0);
        }
        puts(", path=\"");
        if (frame->a1 != 0) {
            linux_print_user_cstr(frame->a1, 96u);
        }
        puts("\") -> ");

        if (frame->a2 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (frame->a1 != 0 &&
            linux_path_metadata(frame->a1, &mode, &size, &ino)) {
            linux_copyout_stat64(frame->a2, mode, size, ino);
            ret = 0;
            putdec(ret);
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_STATX) {
        uint32_t mode = LINUX_MODE_IFREG | LINUX_MODE_0644;
        uint32_t size = 0;
        uint32_t ino = 8;
        uint32_t ret = linux_errno(LINUX_ENOENT);

        puts("[riscv32] linux statx(dirfd=");
        if (frame->a0 == LINUX_AT_FDCWD) {
            puts("AT_FDCWD");
        } else {
            putdec(frame->a0);
        }
        puts(", path=\"");
        if (frame->a1 != 0) {
            linux_print_user_cstr(frame->a1, 96u);
        }
        puts("\", mask=0x");
        puthex32(frame->a3);
        puts(") -> ");

        if (frame->a1 != 0 && frame->a4 != 0 && linux_known_path(frame->a1)) {
            if (linux_user_streq(frame->a1, "/") ||
                linux_user_streq(frame->a1, "/proc") ||
                linux_user_streq(frame->a1, "/proc/self")) {
                mode = LINUX_MODE_IFDIR | LINUX_MODE_0755;
                ino = 5;
            } else if (linux_user_streq(frame->a1, "/proc/self/exe")) {
                mode = LINUX_MODE_IFLNK | LINUX_MODE_0755;
                size = 11u;
                ino = 7;
            } else if (linux_user_streq(frame->a1, "/proc/version")) {
                size = linux_strlen(g_stage0_proc_version);
                ino = 8;
            } else if (linux_user_streq(frame->a1, "/proc/cpuinfo")) {
                size = linux_strlen(g_stage0_proc_cpuinfo);
                ino = 9;
            } else if (linux_user_streq(frame->a1, "/proc/meminfo")) {
                size = linux_strlen(g_stage0_proc_meminfo);
                ino = 10;
            } else if (linux_user_streq(frame->a1, "/proc/uptime")) {
                size = linux_strlen(g_stage0_proc_uptime);
                ino = 12;
            } else if (linux_user_streq(frame->a1, "/proc/stat")) {
                size = linux_strlen(g_stage0_proc_stat);
                ino = 13;
            } else if (linux_user_streq(frame->a1, "/proc/caribeos")) {
                size = linux_strlen(g_stage0_proc_caribeos);
                ino = 11;
            } else if (linux_user_streq(frame->a1, "/kernel.elf")) {
                size = g_info.kernel_size;
                ino = 17;
            }
            linux_copyout_statx(frame->a4, mode, size, ino);
            ret = 0;
            putdec(ret);
        } else if (frame->a4 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_CLOCK_GETTIME ||
        frame->a7 == LINUX_SYS_CLOCK_GETTIME64)) {
        uint32_t sec;
        uint32_t nsec;

        linux_time_now(&sec, &nsec);
        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_CLOCK_GETTIME64 ?
            "clock_gettime64" : "clock_gettime");
        puts("(clock=");
        putdec(frame->a0);
        puts(", tp=0x");
        puthex32(frame->a1);
        puts(") -> sec=");
        putdec(sec);
        puts(" nsec=");
        putdec(nsec);
        puts("\n");
        if (frame->a1 != 0) {
            if (frame->a7 == LINUX_SYS_CLOCK_GETTIME64) {
                linux_store32(frame->a1 + 0u, sec);
                linux_store32(frame->a1 + 4u, 0);
                linux_store32(frame->a1 + 8u, nsec);
                linux_store32(frame->a1 + 12u, 0);
            } else {
                linux_store32(frame->a1 + 0u, sec);
                linux_store32(frame->a1 + 4u, nsec);
            }
            frame->a0 = 0;
        } else {
            frame->a0 = linux_errno(LINUX_EFAULT);
        }
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_GETTIMEOFDAY) {
        uint32_t sec;
        uint32_t nsec;

        linux_time_now(&sec, &nsec);
        puts("[riscv32] linux gettimeofday(tv=0x");
        puthex32(frame->a0);
        puts(") -> sec=");
        putdec(sec);
        puts(" usec=");
        putdec(nsec / 1000u);
        puts("\n");
        if (frame->a0 != 0) {
            linux_store32(frame->a0 + 0u, sec);
            linux_store32(frame->a0 + 4u, nsec / 1000u);
        }
        if (frame->a1 != 0) {
            linux_store32(frame->a1 + 0u, 0);
            linux_store32(frame->a1 + 4u, 0);
        }
        frame->a0 = 0;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_GETRANDOM) {
        uint32_t len = frame->a1;

        if (len > 32u) {
            len = 32u;
        }
        puts("[riscv32] linux getrandom(buf=0x");
        puthex32(frame->a0);
        puts(", len=");
        putdec(frame->a1);
        puts(") -> ");
        if (frame->a0 == 0) {
            puts("-EFAULT\n");
            frame->a0 = linux_errno(LINUX_EFAULT);
        } else {
            for (uint32_t i = 0; i < len; i++) {
                linux_store8(frame->a0 + i,
                    (uint8_t)(0xa5u ^ (i * 73u) ^ frame->a2));
            }
            putdec(len);
            puts(" deterministic bytes\n");
            frame->a0 = len;
        }
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_OPENAT) {
        uint32_t ret = 0xfffffffeu;

        puts("[riscv32] linux openat(dirfd=");
        if (frame->a0 == LINUX_AT_FDCWD) {
            puts("AT_FDCWD");
        } else {
            putdec(frame->a0);
        }
        puts(", path=\"");
        if (frame->a1 != 0) {
            linux_print_user_cstr(frame->a1, 96u);
        }
        puts("\") -> ");

        if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/version")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_VERSION;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/cpuinfo")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_CPUINFO;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/meminfo")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_MEMINFO;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/uptime")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_UPTIME;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/stat")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_STAT;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc/caribeos")) {
            g_stage0_proc_open = 1;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = XNU_STAGE0_PROC_FILE_CARIBEOS;
            ret = XNU_STAGE0_PROC_FD;
        } else if (frame->a1 != 0 &&
            linux_user_streq(frame->a1, "/proc")) {
            g_stage0_proc_dir_open = 1;
            g_stage0_proc_dir_offset = 0;
            ret = XNU_STAGE0_PROC_DIR_FD;
        }
        if ((ret & 0x80000000u) == 0) {
            putdec(ret);
        } else {
            puts("-ENOENT");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        frame->a7 == LINUX_SYS_GETDENTS64) {
        uint32_t ret = linux_errno(LINUX_EBADF);
        uint32_t total = 0;
        const char *name;
        uint32_t ino;
        uint32_t type;

        puts("[riscv32] linux getdents64(fd=");
        putdec(frame->a0);
        puts(", count=");
        putdec(frame->a2);
        puts(")");

        if (frame->a0 == XNU_STAGE0_PROC_DIR_FD &&
            g_stage0_proc_dir_open != 0 && frame->a1 != 0) {
            while (linux_proc_dir_entry(g_stage0_proc_dir_offset, &name,
                &ino, &type)) {
                uint32_t reclen = linux_align8(19u + linux_strlen(name) + 1u);

                if (reclen > frame->a2 - total) {
                    break;
                }
                linux_copyout_dirent64(frame->a1 + total, ino,
                    g_stage0_proc_dir_offset + 1u, type, name);
                puts("\n  [dirent] name=");
                puts(name);
                puts(" ino=");
                putdec(ino);
                puts(" type=");
                putdec(type);
                total += reclen;
                g_stage0_proc_dir_offset++;
            }
            ret = total;
        } else if (frame->a1 == 0) {
            ret = linux_errno(LINUX_EFAULT);
        }
        puts("\n[riscv32] linux getdents64 -> ");
        if ((ret & 0x80000000u) == 0) {
            putdec(ret);
        } else if (ret == linux_errno(LINUX_EFAULT)) {
            puts("-EFAULT");
        } else {
            puts("-EBADF");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_FSTATFS64) {
        uint32_t ret = linux_errno(LINUX_EBADF);

        puts("[riscv32] linux fstatfs64(fd=");
        putdec(frame->a0);
        puts(") -> ");
        if (frame->a1 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (frame->a0 <= 2u ||
            (frame->a0 == XNU_STAGE0_PROC_FD && g_stage0_proc_open != 0) ||
            (frame->a0 == XNU_STAGE0_PROC_DIR_FD &&
            g_stage0_proc_dir_open != 0)) {
            linux_copyout_statfs64(frame->a1);
            ret = 0;
            putdec(ret);
        } else {
            puts("-EBADF");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_FSTAT64) {
        uint32_t ret = linux_errno(LINUX_EBADF);

        puts("[riscv32] linux fstat64(fd=");
        putdec(frame->a0);
        puts(") -> ");
        if (frame->a1 == 0) {
            ret = linux_errno(LINUX_EFAULT);
            puts("-EFAULT");
        } else if (frame->a0 == XNU_STAGE0_PROC_FD &&
            g_stage0_proc_open != 0) {
            uint32_t size;
            linux_proc_file_content(g_stage0_proc_file, &size);
            linux_copyout_stat64(frame->a1,
                LINUX_MODE_IFREG | LINUX_MODE_0644,
                size, g_stage0_proc_file == XNU_STAGE0_PROC_FILE_CARIBEOS ?
                11 : (g_stage0_proc_file == XNU_STAGE0_PROC_FILE_MEMINFO ?
                10 : (g_stage0_proc_file == XNU_STAGE0_PROC_FILE_UPTIME ?
                12 : (g_stage0_proc_file == XNU_STAGE0_PROC_FILE_STAT ?
                13 : (g_stage0_proc_file == XNU_STAGE0_PROC_FILE_CPUINFO ?
                9 : 8)))));
            ret = 0;
            putdec(ret);
        } else if (frame->a0 == XNU_STAGE0_PROC_DIR_FD &&
            g_stage0_proc_dir_open != 0) {
            linux_copyout_stat64(frame->a1,
                LINUX_MODE_IFDIR | LINUX_MODE_0755, 0, 5);
            ret = 0;
            putdec(ret);
        } else {
            puts("-EBADF");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_READ) {
        uint32_t ret = 0xfffffff7u;

        puts("[riscv32] linux read(fd=");
        putdec(frame->a0);
        puts(", count=");
        putdec(frame->a2);
        puts(") -> ");

        if (frame->a0 == XNU_STAGE0_PROC_FD && g_stage0_proc_open != 0 &&
            frame->a1 != 0) {
            uint32_t size;
            const char *content = linux_proc_file_content(g_stage0_proc_file,
                &size);
            uint32_t left = g_stage0_proc_offset < size ?
                size - g_stage0_proc_offset : 0;
            uint32_t n = frame->a2;

            if (n > left) {
                n = left;
            }
            linux_copy_to_user(frame->a1,
                content + g_stage0_proc_offset, n);
            g_stage0_proc_offset += n;
            ret = n;
        }
        if ((ret & 0x80000000u) == 0) {
            putdec(ret);
        } else {
            puts("-EBADF");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_CLOSE) {
        uint32_t ret = 0xfffffff7u;

        puts("[riscv32] linux close(fd=");
        putdec(frame->a0);
        puts(") -> ");
        if (frame->a0 == XNU_STAGE0_PROC_FD && g_stage0_proc_open != 0) {
            g_stage0_proc_open = 0;
            g_stage0_proc_offset = 0;
            g_stage0_proc_file = 0;
            ret = 0;
        } else if (frame->a0 == XNU_STAGE0_PROC_DIR_FD &&
            g_stage0_proc_dir_open != 0) {
            g_stage0_proc_dir_open = 0;
            g_stage0_proc_dir_offset = 0;
            ret = 0;
        }
        if ((ret & 0x80000000u) == 0) {
            putdec(ret);
        } else {
            puts("-EBADF");
        }
        puts("\n");
        frame->a0 = ret;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_WRITE) {
        g_stage0_umode_writes++;

        puts("[riscv32] linux write(fd=");
        putdec(frame->a0);
        puts(", len=");
        putdec(frame->a2);
        puts(") -> ");
        linux_print_user_buf(frame->a1, frame->a2);
        frame->a0 = frame->a2;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U && frame->a7 == LINUX_SYS_WRITEV) {
        xnu_stage0_iovec32_t *iov =
            (xnu_stage0_iovec32_t *)(uintptr_t)frame->a1;
        uint32_t total = 0;
        uint32_t count = frame->a2;

        if (count > 4u) {
            count = 4u;
        }
        g_stage0_umode_writes++;
        puts("[riscv32] linux writev(fd=");
        putdec(frame->a0);
        puts(", iovcnt=");
        putdec(frame->a2);
        puts(")\n");
        for (uint32_t i = 0; i < count; i++) {
            puts("  [iov] base=0x");
            puthex32(iov[i].base);
            puts(" len=");
            putdec(iov[i].len);
            puts(" -> ");
            linux_print_user_buf(iov[i].base, iov[i].len);
            total += iov[i].len;
        }
        frame->a0 = total;
        frame->sepc += 4u;
        return;
    }

    if (frame->scause == SCAUSE_ECALL_U &&
        (frame->a7 == LINUX_SYS_EXIT || frame->a7 == LINUX_SYS_EXIT_GROUP)) {
        g_stage0_umode_exits++;
        puts("[riscv32] linux ");
        puts(frame->a7 == LINUX_SYS_EXIT_GROUP ? "exit_group" : "exit");
        puts("(status=");
        putdec(frame->a0);
        puts(") syscalls=");
        putdec(g_stage0_umode_syscalls);
        puts(" writes=");
        putdec(g_stage0_umode_writes);
        puts("\n");
        puts("[XNU-CaribeOS] kernel_bootstrap parked after umode proof\n");
        for (;;) {
            __asm__ volatile("wfi");
        }
    }

    puts("[riscv32] unexpected user trap scause=0x");
    puthex32(frame->scause);
    puts(" sepc=0x");
    puthex32(frame->sepc);
    puts(" stval=0x");
    puthex32(frame->stval);
    puts(" syscall=");
    putdec(frame->a7);
    puts("\n");
    for (;;) {
        __asm__ volatile("wfi");
    }
}

static void memzero(void *ptr, uint32_t len)
{
    uint8_t *p = (uint8_t *)ptr;

    for (uint32_t i = 0; i < len; i++) {
        p[i] = 0;
    }
}

static void memcopy(void *dst, const void *src, uint32_t len)
{
    uint8_t *d = (uint8_t *)dst;
    const uint8_t *s = (const uint8_t *)src;

    for (uint32_t i = 0; i < len; i++) {
        d[i] = s[i];
    }
}

static const char *xnu_memory_type_name(uint32_t type)
{
    switch (type) {
    case XNU_EFI_LOADER_CODE:
        return "LoaderCode";
    case XNU_EFI_LOADER_DATA:
        return "LoaderData";
    case XNU_EFI_CONVENTIONAL:
        return "Conventional";
    default:
        return "Other";
    }
}

static void stage0_print_memory_map(void)
{
    const riscv32_caribebootx_args_t *args = g_info.args;
    const uint8_t *base;
    uint32_t count;
    uint64_t conventional_pages = 0;
    uint64_t reserved_pages = 0;
    uint64_t previous_end = 0;
    uint32_t overlaps = 0;

    puts("[XNU-CaribeOS] CBX memory map\n");
    if (args == 0 || args->magic != RISCV32_CARIBEBOOTX_MAGIC ||
        args->version < 2u || g_info.memory_map_paddr == 0 ||
        g_info.memory_map_count == 0 ||
        g_info.memory_map_desc_size < sizeof(riscv32_xnu_memory_range_t)) {
        puts("[riscv32] mmap unavailable; fallback RAM span will be used\n");
        return;
    }

    puts("[riscv32] mmap paddr=0x");
    puthex32(g_info.memory_map_paddr);
    puts(" count=");
    putdec(g_info.memory_map_count);
    puts(" desc=");
    putdec(g_info.memory_map_desc_size);
    puts("\n");

    count = g_info.memory_map_count;
    if (count > XNU_STAGE0_MEMORY_MAP_MAX) {
        count = XNU_STAGE0_MEMORY_MAP_MAX;
    }

    base = (const uint8_t *)(uintptr_t)g_info.memory_map_paddr;
    for (uint32_t i = 0; i < count; i++) {
        const riscv32_xnu_memory_range_t *range =
            (const riscv32_xnu_memory_range_t *)(const void *)
            &base[i * g_info.memory_map_desc_size];
        uint64_t start = range->physical_start;
        uint64_t pages = range->number_of_pages;
        uint64_t end = start + (pages << 12);

        if (i != 0 && start < previous_end) {
            overlaps++;
        }
        previous_end = end;
        if (range->type == XNU_EFI_CONVENTIONAL) {
            conventional_pages += pages;
            if (g_info.memory_first_free == 0) {
                g_info.memory_first_free = (uint32_t)start;
            }
        } else {
            reserved_pages += pages;
        }
        if (end > g_info.memory_max_end) {
            g_info.memory_max_end = (uint32_t)end;
        }

        puts("  [mem ");
        putdec(i);
        puts("] type=");
        putdec(range->type);
        puts("(");
        puts(xnu_memory_type_name(range->type));
        puts(") start=0x");
        puthex64(start);
        puts(" end=0x");
        puthex64(end);
        puts(" pages=");
        putdec((uint32_t)pages);
        puts("\n");
    }
    if (g_info.memory_map_count > count) {
        puts("[riscv32] mmap truncated entries=");
        putdec(g_info.memory_map_count - count);
        puts("\n");
    }

    puts("[riscv32] mmap summary conventional_pages=");
    putdec((uint32_t)conventional_pages);
    puts(" reserved_pages=");
    putdec((uint32_t)reserved_pages);
    puts(" overlaps=");
    putdec(overlaps);
    puts("\n");

    g_info.memory_conventional_pages = (uint32_t)conventional_pages;
    g_info.memory_reserved_pages = (uint32_t)reserved_pages;
    g_info.memory_overlaps = overlaps;
    puts("[riscv32] vm seed first_free=0x");
    puthex32(g_info.memory_first_free);
    puts(" max_end=0x");
    puthex32(g_info.memory_max_end);
    puts(" free_bytes=0x");
    puthex32(g_info.memory_conventional_pages << 12);
    puts("\n");
}

static uint32_t pte_super_stage0(uint32_t pa, uint32_t flags)
{
    return ((pa >> 12) << 10) | flags | PTE_V;
}

static void stage0_map_super(uint32_t va, uint32_t pa, uint32_t flags)
{
    uint32_t idx = (va >> 22) & 0x3ffu;

    g_stage0_l1[idx] = pte_super_stage0(pa, flags);
}

static void stage0_install_umode_mmu(void)
{
    uint32_t ram_start = g_info.mem_base;
    uint32_t ram_end = g_info.mem_base + g_info.mem_size;
    uint32_t kernel_flags = PTE_R | PTE_W | PTE_X | PTE_A | PTE_D | PTE_G;
    uint32_t user_flags = kernel_flags | PTE_U;
    uint32_t io_flags = PTE_R | PTE_W | PTE_A | PTE_D | PTE_G;
    uint32_t old_satp = csr_read_satp();
    uint32_t new_satp;

    memzero(g_stage0_l1, sizeof(g_stage0_l1));

    for (uint32_t va = ram_start; va < ram_end; va += XNU_STAGE0_USER_REGION_SIZE) {
        uint32_t flags = va == XNU_STAGE0_USER_BASE ? user_flags : kernel_flags;

        stage0_map_super(va, va, flags);
    }
    stage0_map_super(0x10000000u, 0x10000000u, io_flags);
    stage0_map_super(g_info.plic_base, g_info.plic_base, io_flags);
    stage0_map_super(g_info.aclint_base, g_info.aclint_base, io_flags);

    new_satp = 0x80000000u | ((uint32_t)(uintptr_t)g_stage0_l1 >> 12);
    puts("[riscv32] Sv32 remap for umode old_satp=0x");
    puthex32(old_satp);
    puts(" new_satp=0x");
    puthex32(new_satp);
    puts(" user=0x");
    puthex32(XNU_STAGE0_USER_BASE);
    puts("+0x");
    puthex32(XNU_STAGE0_USER_REGION_SIZE);
    puts("\n");
    csr_write_satp(new_satp);
}

static int streq(const char *a, const char *b)
{
    while (*a != '\0' && *b != '\0') {
        if (*a != *b) {
            return 0;
        }
        a++;
        b++;
    }
    return *a == *b;
}

static int streq_len(const char *entry, uint32_t len, const char *needle)
{
    uint32_t i;

    for (i = 0; i < len; i++) {
        if (needle[i] == '\0' || entry[i] != needle[i]) {
            return 0;
        }
    }
    return needle[len] == '\0';
}

static uint16_t be16(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;

    return (uint16_t)(((uint16_t)b[0] << 8) | b[1]);
}

static uint32_t be32(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;

    return ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) |
        ((uint32_t)b[2] << 8) | (uint32_t)b[3];
}

static uint64_t be64(const void *ptr)
{
    const uint8_t *b = (const uint8_t *)ptr;

    return ((uint64_t)be32(&b[0]) << 32) | be32(&b[4]);
}

static uint32_t align4(uint32_t v)
{
    return (v + 3u) & ~3u;
}

static void print_cmdline(void)
{
    const riscv32_caribebootx_args_t *args = g_info.args;
    const char *cmd;
    uint32_t size;

    if (args == 0 || args->command_line_paddr == 0 ||
        args->command_line_size == 0) {
        return;
    }

    cmd = (const char *)(uintptr_t)args->command_line_paddr;
    size = args->command_line_size;
    puts("  boot-args=\"");
    for (uint32_t i = 0; i < size && cmd[i] != '\0'; i++) {
        char c = cmd[i];

        putc((c >= 32 && c < 127) ? c : '.');
    }
    puts("\"\n");
}

static void fdt_probe(uint32_t dtb_addr)
{
    const uint8_t *dtb = (const uint8_t *)(uintptr_t)dtb_addr;
    const char *strings;
    uint32_t total;
    uint32_t off_struct;
    uint32_t off_strings;
    uint32_t size_struct;
    uint32_t size_strings;
    uint32_t off;
    uint32_t end;

    if (dtb_addr == 0 || be32(dtb) != FDT_MAGIC) {
        return;
    }

    total = be32(dtb + 4);
    off_struct = be32(dtb + 8);
    off_strings = be32(dtb + 12);
    size_strings = be32(dtb + 32);
    size_struct = be32(dtb + 36);
    strings = (const char *)(const void *)(dtb + off_strings);
    off = off_struct;
    end = size_struct != 0 ? off_struct + size_struct : total;
    g_info.dtb_size = total;

    while (off + 4 <= end) {
        uint32_t token = be32(dtb + off);
        off += 4;

        if (token == FDT_BEGIN_NODE) {
            while (off < end && dtb[off] != 0) {
                off++;
            }
            off = align4(off + 1);
        } else if (token == FDT_END_NODE || token == FDT_NOP) {
            continue;
        } else if (token == FDT_PROP) {
            uint32_t len;
            uint32_t nameoff;
            const char *name;
            const uint8_t *data;

            if (off + 8 > end) {
                break;
            }
            len = be32(dtb + off);
            nameoff = be32(dtb + off + 4);
            off += 8;
            if (off + len > end || nameoff >= size_strings) {
                break;
            }
            name = strings + nameoff;
            data = dtb + off;

            if (streq(name, "timebase-frequency") && len >= 4) {
                g_info.timebase_hz = be32(data);
            } else if (streq(name, "device_type") && len >= 3 &&
                streq_len((const char *)data, 3, "cpu")) {
                g_info.cpu_count++;
            }
            off = align4(off + len);
        } else if (token == FDT_END) {
            break;
        } else {
            break;
        }
    }
}

static volatile uint32_t *mmio_reg(uint32_t base, uint32_t offset)
{
    return (volatile uint32_t *)(uintptr_t)(base + offset);
}

static uint32_t mmio_read(uint32_t base, uint32_t offset)
{
    return *mmio_reg(base, offset);
}

static void mmio_write(uint32_t base, uint32_t offset, uint32_t value)
{
    *mmio_reg(base, offset) = value;
}

static uint64_t mmio_read64(uint32_t base, uint32_t offset)
{
    uint32_t lo = mmio_read(base, offset);
    uint32_t hi = mmio_read(base, offset + 4u);

    return ((uint64_t)hi << 32) | lo;
}

static void barrier(void)
{
    __sync_synchronize();
}

static void virtio_mmio_scan(void)
{
    puts("[XNU-CaribeOS] virtio-mmio scan\n");

    for (uint32_t i = 0; i < 8; i++) {
        uint32_t base = 0x10001000u + i * 0x1000u;
        uint32_t magic = mmio_read(base, VIRTIO_MMIO_MAGIC_VALUE);
        uint32_t version;
        uint32_t device;
        uint32_t vendor;

        if (magic != VIRTIO_MMIO_MAGIC) {
            continue;
        }

        version = mmio_read(base, VIRTIO_MMIO_VERSION);
        device = mmio_read(base, VIRTIO_MMIO_DEVICE_ID);
        vendor = mmio_read(base, VIRTIO_MMIO_VENDOR_ID);
        g_info.virtio_count++;

        puts("[riscv32] virtio-mmio base=0x");
        puthex32(base);
        puts(" dev=");
        putdec(device);
        puts(" version=");
        putdec(version);
        puts(" vendor=0x");
        puthex32(vendor);
        puts("\n");

        if (device == VIRTIO_ID_BLOCK && g_info.blk_base == 0) {
            g_info.blk_base = base;
        }
    }
}

static uint64_t phys(const void *ptr)
{
    return (uint64_t)(uintptr_t)ptr;
}

static uint32_t align_up(uint32_t value, uint32_t align)
{
    return (value + align - 1u) & ~(align - 1u);
}

static int virtio_blk_init(void)
{
    uint32_t base = g_info.blk_base;
    uint32_t qmax;
    uint32_t desc_sz;
    uint32_t avail_sz;
    uint32_t avail_off;
    uint32_t used_off;
    uint32_t status;
    uint64_t capacity;

    if (base == 0) {
        puts("[riscv32] virtio-blk not found\n");
        return -1;
    }

    mmio_write(base, VIRTIO_MMIO_STATUS, 0);
    status = VIRTIO_STATUS_ACKNOWLEDGE;
    mmio_write(base, VIRTIO_MMIO_STATUS, status);
    status |= VIRTIO_STATUS_DRIVER;
    mmio_write(base, VIRTIO_MMIO_STATUS, status);

    mmio_write(base, VIRTIO_MMIO_DRIVER_FEATURES_SEL, 0);
    mmio_write(base, VIRTIO_MMIO_DRIVER_FEATURES, 0);
    mmio_write(base, VIRTIO_MMIO_DRIVER_FEATURES_SEL, 1);
    mmio_write(base, VIRTIO_MMIO_DRIVER_FEATURES, 0);
    mmio_write(base, VIRTIO_MMIO_DRIVER_FEATURES_SEL, 0);

    status |= VIRTIO_STATUS_FEATURES_OK;
    mmio_write(base, VIRTIO_MMIO_STATUS, status);
    if ((mmio_read(base, VIRTIO_MMIO_STATUS) &
        VIRTIO_STATUS_FEATURES_OK) == 0) {
        return -1;
    }

    capacity = mmio_read64(base, VIRTIO_MMIO_CONFIG);
    g_info.blk_sectors_lo = (uint32_t)capacity;

    mmio_write(base, VIRTIO_MMIO_QUEUE_SEL, 0);
    qmax = mmio_read(base, VIRTIO_MMIO_QUEUE_NUM_MAX);
    if (qmax < 3) {
        return -1;
    }
    if (qmax > VIRTIO_BLK_QNUM) {
        qmax = VIRTIO_BLK_QNUM;
    }
    mmio_write(base, VIRTIO_MMIO_QUEUE_NUM, qmax);

    desc_sz = sizeof(virtq_desc_t) * VIRTIO_BLK_QNUM;
    avail_off = desc_sz;
    avail_sz = sizeof(uint16_t) * 2u +
        sizeof(uint16_t) * VIRTIO_BLK_QNUM + sizeof(uint16_t);
    used_off = align_up(avail_off + avail_sz, 4096u);

    memzero(g_virtq, sizeof(g_virtq));
    g_desc = (virtq_desc_t *)(g_virtq + 0);
    g_avail = (virtq_avail_t *)(g_virtq + avail_off);
    g_used = (virtq_used_t *)(g_virtq + used_off);

    mmio_write(base, VIRTIO_MMIO_GUEST_PAGE_SIZE, 4096u);
    mmio_write(base, VIRTIO_MMIO_QUEUE_ALIGN, 4096u);
    mmio_write(base, VIRTIO_MMIO_QUEUE_PFN, (uint32_t)(phys(g_virtq) >> 12));

    status |= VIRTIO_STATUS_DRIVER_OK;
    mmio_write(base, VIRTIO_MMIO_STATUS, status);

    puts("[riscv32] virtio-blk sectors=");
    putdec(g_info.blk_sectors_lo);
    puts(" queue=");
    putdec(qmax);
    puts(" ring=0x");
    puthex32((uint32_t)(uintptr_t)g_virtq);
    puts("\n");
    return 0;
}

static int virtio_blk_read(uint32_t lba, uint32_t count, void *buf)
{
    uint32_t base = g_info.blk_base;
    uint16_t avail_idx;
    uint16_t want_used;
    uint32_t spins = 0;
    uint32_t isr;

    if (count == 0) {
        return 0;
    }
    if (base == 0 || g_desc == 0 || g_avail == 0 || g_used == 0) {
        return -1;
    }

    g_blk_req.type = VIRTIO_BLK_T_IN;
    g_blk_req.ioprio = 0;
    g_blk_req.sector = lba;
    g_blk_status = 0xffu;

    isr = mmio_read(base, VIRTIO_MMIO_INTERRUPT_STATUS);
    if (isr != 0) {
        mmio_write(base, VIRTIO_MMIO_INTERRUPT_ACK, isr);
    }

    want_used = (uint16_t)(g_used->idx + 1u);

    g_desc[0].addr = phys(&g_blk_req);
    g_desc[0].len = sizeof(g_blk_req);
    g_desc[0].flags = VIRTQ_DESC_F_NEXT;
    g_desc[0].next = 1;

    g_desc[1].addr = phys(buf);
    g_desc[1].len = count * VIRTIO_BLK_SECTOR_SIZE;
    g_desc[1].flags = VIRTQ_DESC_F_NEXT | VIRTQ_DESC_F_WRITE;
    g_desc[1].next = 2;

    g_desc[2].addr = phys((const void *)&g_blk_status);
    g_desc[2].len = sizeof(g_blk_status);
    g_desc[2].flags = VIRTQ_DESC_F_WRITE;
    g_desc[2].next = 0;

    avail_idx = g_avail->idx;
    g_avail->ring[avail_idx % VIRTIO_BLK_QNUM] = 0;
    barrier();
    g_avail->idx = (uint16_t)(avail_idx + 1u);
    barrier();

    mmio_write(base, VIRTIO_MMIO_QUEUE_SEL, 0);
    barrier();
    mmio_write(base, VIRTIO_MMIO_QUEUE_NOTIFY, 0);
    barrier();

    while (g_used->idx != want_used && spins++ < 100000000u) {
        barrier();
    }
    if (g_used->idx != want_used) {
        return -1;
    }

    isr = mmio_read(base, VIRTIO_MMIO_INTERRUPT_STATUS);
    if (isr != 0) {
        mmio_write(base, VIRTIO_MMIO_INTERRUPT_ACK, isr);
    }
    return g_blk_status == 0 ? 0 : -1;
}

static void hfs_read_extents(const uint8_t *src, hfs_extent_t *extents)
{
    for (uint32_t i = 0; i < HFSPLUS_MAX_EXTENTS; i++) {
        extents[i].start_block = be32(src + i * 8u);
        extents[i].block_count = be32(src + i * 8u + 4u);
    }
}

static int hfs_read_block(uint32_t block, void *buf)
{
    uint32_t sectors_per_block;

    if (g_hfs_block_size == 0 ||
        g_hfs_block_size > HFSPLUS_MAX_BLOCK_SIZE ||
        (g_hfs_block_size % VIRTIO_BLK_SECTOR_SIZE) != 0) {
        return -1;
    }
    sectors_per_block = g_hfs_block_size / VIRTIO_BLK_SECTOR_SIZE;
    return virtio_blk_read(block * sectors_per_block, sectors_per_block, buf);
}

static int hfs_read_catalog_node(uint32_t node)
{
    uint32_t nodes_per_block;
    uint32_t logical_block;
    uint32_t physical_block = 0;
    uint32_t logical;

    if (g_hfs_node_size == 0 || g_hfs_block_size == 0 ||
        g_hfs_node_size > HFSPLUS_MAX_BLOCK_SIZE ||
        g_hfs_node_size != g_hfs_block_size) {
        return -1;
    }

    nodes_per_block = g_hfs_block_size / g_hfs_node_size;
    if (nodes_per_block == 0) {
        return -1;
    }

    logical_block = node / nodes_per_block;
    logical = logical_block;
    for (uint32_t i = 0; i < HFSPLUS_MAX_EXTENTS; i++) {
        if (g_catalog_extents[i].block_count == 0) {
            continue;
        }
        if (logical < g_catalog_extents[i].block_count) {
            physical_block = g_catalog_extents[i].start_block + logical;
            break;
        }
        logical -= g_catalog_extents[i].block_count;
    }
    if (physical_block == 0) {
        return -1;
    }
    return hfs_read_block(physical_block, g_node);
}

static int hfs_ascii_name(const uint8_t *src, uint16_t chars,
    char *dst, uint32_t cap)
{
    uint32_t out = 0;

    if (cap == 0) {
        return 0;
    }
    for (uint16_t i = 0; i < chars; i++) {
        uint16_t ch = be16(src + i * 2u);
        char c = ch < 128u ? (char)ch : '?';

        if (out + 1u >= cap) {
            break;
        }
        dst[out++] = c;
    }
    dst[out] = '\0';
    return (int)out;
}

static int hfs_find_root_file(const char *name, hfs_file_t *file)
{
    uint32_t first = g_hfs_first_leaf;
    uint32_t last = g_hfs_last_leaf;

    memzero(file, sizeof(*file));
    if (first == 0 || last == 0 || last < first) {
        first = 1;
        last = g_hfs_total_nodes != 0 ? g_hfs_total_nodes - 1u : 1u;
    }

    for (uint32_t node = first; node <= last; node++) {
        uint16_t records;
        uint32_t node_size = g_hfs_node_size;

        if (hfs_read_catalog_node(node) != 0) {
            return -1;
        }
        if (g_node[8] != HFSPLUS_LEAF_NODE_KIND) {
            if (node == last) {
                break;
            }
            continue;
        }

        records = be16(g_node + 10);
        if (records == 0 || (uint32_t)(2u * (records + 1u)) > node_size) {
            continue;
        }

        for (uint32_t r = 0; r < records; r++) {
            uint32_t idx_off = node_size - 2u * (records + 1u) + r * 2u;
            uint32_t rec_off = be16(g_node + idx_off);
            uint16_t key_len;
            uint32_t parent;
            uint16_t name_len;
            uint32_t data_off;
            uint16_t record_type;
            char entry_name[HFSPLUS_MAX_NAME];

            if (rec_off + 8u >= node_size) {
                continue;
            }

            key_len = be16(g_node + rec_off);
            parent = be32(g_node + rec_off + 2u);
            name_len = be16(g_node + rec_off + 6u);
            data_off = rec_off + 2u + key_len;
            if (data_off + HFSPLUS_FILE_DATA_FORK_OFF + 80u > node_size ||
                rec_off + 8u + (uint32_t)name_len * 2u > node_size) {
                continue;
            }

            hfs_ascii_name(g_node + rec_off + 8u, name_len,
                entry_name, sizeof(entry_name));
            if (parent != HFSPLUS_ROOT_FOLDER_ID || !streq(entry_name, name)) {
                continue;
            }

            record_type = be16(g_node + data_off);
            if (record_type == HFSPLUS_RECORD_FILE) {
                const uint8_t *fork =
                    g_node + data_off + HFSPLUS_FILE_DATA_FORK_OFF;

                file->found = 1;
                file->file_id = be32(g_node + data_off + HFSPLUS_FILE_ID_OFF);
                file->logical_size = be64(fork);
                hfs_read_extents(fork + HFSPLUS_FORK_OFF_EXTENTS,
                    file->extents);
                return 0;
            }
        }
    }
    return -1;
}

static void hfs_probe_root(void)
{
    const uint8_t *catalog;
    const uint8_t *bt;
    hfs_file_t kernel_file;
    uint16_t sig;
    uint16_t version;
    uint32_t total_blocks;
    uint32_t first_lba;
    uint32_t head = 0;

    puts("[XNU-CaribeOS] HFS+ root probe\n");
    if (virtio_blk_read(HFSPLUS_VOLUME_HEADER_LBA, 1, g_sector) != 0) {
        puts("[riscv32] HFS+ volume header read failed\n");
        return;
    }

    sig = be16(g_sector + HFSPLUS_OFF_SIGNATURE);
    if (sig != HFSPLUS_SIGNATURE && sig != HFSX_SIGNATURE) {
        puts("[riscv32] HFS+ sig invalid=0x");
        puthex32(sig);
        puts("\n");
        return;
    }

    version = be16(g_sector + HFSPLUS_OFF_VERSION);
    g_hfs_block_size = be32(g_sector + HFSPLUS_OFF_BLOCK_SIZE);
    total_blocks = be32(g_sector + HFSPLUS_OFF_TOTAL_BLOCKS);

    catalog = g_sector + HFSPLUS_OFF_CATALOG_FILE;
    g_hfs_catalog_size = be64(catalog + HFSPLUS_FORK_OFF_LOGICAL_SIZE);
    g_hfs_catalog_blocks = be32(catalog + HFSPLUS_FORK_OFF_TOTAL_BLOCKS);
    hfs_read_extents(catalog + HFSPLUS_FORK_OFF_EXTENTS,
        g_catalog_extents);

    if (hfs_read_block(g_catalog_extents[0].start_block, g_block) != 0) {
        puts("[riscv32] HFS+ catalog header read failed\n");
        return;
    }

    bt = g_block + HFSPLUS_BT_HEADER_OFF;
    g_hfs_first_leaf = be32(bt + HFSPLUS_BT_OFF_FIRST_LEAF);
    g_hfs_last_leaf = be32(bt + HFSPLUS_BT_OFF_LAST_LEAF);
    g_hfs_node_size = be16(bt + HFSPLUS_BT_OFF_NODE_SIZE);
    g_hfs_total_nodes = be32(bt + HFSPLUS_BT_OFF_TOTAL_NODES);

    puts("[riscv32] HFS+ sig=0x");
    puthex32(sig);
    puts(" version=0x");
    puthex32(version);
    puts(" block=");
    putdec(g_hfs_block_size);
    puts(" blocks=");
    putdec(total_blocks);
    puts(" catNode=");
    putdec(g_hfs_node_size);
    puts("\n");
    puts("[riscv32] HFS+ catalog ext0=");
    putdec(g_catalog_extents[0].start_block);
    puts("+");
    putdec(g_catalog_extents[0].block_count);
    puts(" logical=0x");
    puthex32((uint32_t)g_hfs_catalog_size);
    puts("\n");

    if (hfs_find_root_file("kernel.elf", &kernel_file) != 0 ||
        kernel_file.found == 0) {
        puts("[riscv32] /kernel.elf not found from XNU side\n");
        return;
    }

    first_lba = kernel_file.extents[0].start_block *
        (g_hfs_block_size / VIRTIO_BLK_SECTOR_SIZE);
    if (virtio_blk_read(first_lba, 1, g_sector) == 0) {
        head = be32(g_sector);
    }

    puts("[riscv32] /kernel.elf size=");
    putdec((uint32_t)kernel_file.logical_size);
    puts(" fileid=");
    putdec(kernel_file.file_id);
    puts(" ext0=");
    putdec(kernel_file.extents[0].start_block);
    puts("+");
    putdec(kernel_file.extents[0].block_count);
    puts(" head=0x");
    puthex32(head);
    puts("\n");
}

static void stage0_trap_timer_smoke(void)
{
    uint32_t before_stvec = csr_read_stvec();
    uint32_t before_sie = csr_read_sie();
    uint32_t before_sstatus = csr_read_sstatus();
    uint32_t spec = sbi_base_value(SBI_BASE_GET_SPEC_VERSION);
    uint32_t impl = sbi_base_value(SBI_BASE_GET_IMPL_ID);
    uint32_t impl_version = sbi_base_value(SBI_BASE_GET_IMPL_VERSION);
    uint32_t spins = 0;

    puts("[XNU-CaribeOS] SBI/trap/timer smoke\n");
    puts("[riscv32] SBI spec=0x");
    puthex32(spec);
    puts(" impl=");
    putdec(impl);
    puts(" impl_version=0x");
    puthex32(impl_version);
    puts("\n");
    puts("[riscv32] csr before stvec=0x");
    puthex32(before_stvec);
    puts(" sie=0x");
    puthex32(before_sie);
    puts(" sstatus=0x");
    puthex32(before_sstatus);
    puts("\n");

    g_stage0_timer_ticks = 0;
    g_stage0_trap_unhandled = 0;
    g_stage0_last_scause = 0;
    g_stage0_last_sepc = 0;
    g_stage0_last_stval = 0;
    g_stage0_timer_delta = g_info.timebase_hz / 100u;
    if (g_stage0_timer_delta < 1000u) {
        g_stage0_timer_delta = 1000u;
    }

    csr_write_stvec((uint32_t)(uintptr_t)xnu_stage0_trap_vector);
    sbi_set_timer(csr_read_time() + g_stage0_timer_delta);
    csr_set_sie(SIE_STIE);
    csr_set_sstatus(SSTATUS_SIE);

    while (g_stage0_timer_ticks < 2 && spins++ < 1000000u) {
        __asm__ volatile("wfi");
    }

    csr_clear_sie(SIE_STIE);
    sbi_set_timer(UINT64_MAX);

    puts("[riscv32] timer ticks=");
    putdec(g_stage0_timer_ticks);
    puts(" unhandled=");
    putdec(g_stage0_trap_unhandled);
    puts(" scause=0x");
    puthex32(g_stage0_last_scause);
    puts(" sepc=0x");
    puthex32(g_stage0_last_sepc);
    puts(" stval=0x");
    puthex32(g_stage0_last_stval);
    puts("\n");
    puts("[riscv32] csr after stvec=0x");
    puthex32(csr_read_stvec());
    puts(" sie=0x");
    puthex32(csr_read_sie());
    puts(" sstatus=0x");
    puthex32(csr_read_sstatus());
    puts("\n");
}

static void stage0_umode_linux_smoke(void)
{
    uint32_t payload_size = (uint32_t)(xnu_stage0_umode_payload_end -
        xnu_stage0_umode_payload_start);
    uint32_t kernel_stack_top = (uint32_t)(uintptr_t)
        (g_stage0_user_kstack + sizeof(g_stage0_user_kstack));

    puts("[XNU-CaribeOS] Linux personality umode smoke\n");
    puts("[riscv32] copying user payload size=");
    putdec(payload_size);
    puts(" text=0x");
    puthex32(XNU_STAGE0_USER_BASE);
    puts(" stack=0x");
    puthex32(XNU_STAGE0_USER_STACK_TOP);
    puts(" kstack=0x");
    puthex32(kernel_stack_top);
    puts("\n");

    memzero((void *)(uintptr_t)XNU_STAGE0_USER_BASE, 8192u);
    memcopy((void *)(uintptr_t)XNU_STAGE0_USER_BASE,
        xnu_stage0_umode_payload_start, payload_size);
    memzero(g_stage0_user_kstack, sizeof(g_stage0_user_kstack));

    g_stage0_umode_syscalls = 0;
    g_stage0_umode_writes = 0;
    g_stage0_umode_exits = 0;
    g_stage0_umode_last_syscall = 0;
    g_stage0_proc_open = 0;
    g_stage0_proc_offset = 0;
    g_stage0_proc_file = 0;
    g_stage0_proc_dir_open = 0;
    g_stage0_proc_dir_offset = 0;
    g_stage0_mmap_next = XNU_STAGE0_MMAP_BASE;

    stage0_install_umode_mmu();
    csr_write_stvec((uint32_t)(uintptr_t)xnu_stage0_user_trap_vector);
    csr_set_sstatus(SSTATUS_SUM);
    puts("[riscv32] entering U-mode sepc=0x");
    puthex32(XNU_STAGE0_USER_BASE);
    puts(" stvec=0x");
    puthex32(csr_read_stvec());
    puts(" sstatus=0x");
    puthex32(csr_read_sstatus());
    puts("\n");

    xnu_stage0_enter_user(XNU_STAGE0_USER_BASE, XNU_STAGE0_USER_STACK_TOP,
        kernel_stack_top);

    puts("[riscv32] ERROR: returned from U-mode enter\n");
}

static void stage0_init(uint32_t hartid, uint32_t dtb,
    const riscv32_caribebootx_args_t *args)
{
    memzero(&g_info, sizeof(g_info));
    g_info.hartid = hartid;
    g_info.dtb = dtb;
    g_info.timebase_hz = 10000000u;
    g_info.cpu_count = 1;
    g_info.mem_base = 0x80000000u;
    g_info.mem_size = 256u * 1024u * 1024u;
    g_info.uart_base = UART_DEFAULT_BASE;
    g_info.plic_base = 0x0c000000u;
    g_info.aclint_base = 0x02000000u;
    g_info.args = args;

    if (args != 0 && args->magic == RISCV32_CARIBEBOOTX_MAGIC &&
        args->version >= RISCV32_CARIBEBOOTX_MIN_VERSION) {
        g_info.hartid = args->hartid;
        g_info.dtb = args->dtb_paddr != 0 ? args->dtb_paddr : dtb;
        g_info.dtb_size = args->dtb_size;
        g_info.mem_base = args->mem_base;
        g_info.mem_size = args->mem_size;
        g_info.uart_base = args->uart_base != 0 ?
            args->uart_base : UART_DEFAULT_BASE;
        g_info.plic_base = args->plic_base;
        g_info.aclint_base = args->aclint_base;
        g_info.kernel_base = args->kernel_base;
        g_info.kernel_size = args->kernel_size;
        g_info.memory_map_paddr = args->memory_map_paddr;
        g_info.memory_map_count = args->memory_map_count;
        g_info.memory_map_desc_size = args->memory_map_desc_size;
    }

    fdt_probe(g_info.dtb);
    if (g_info.cpu_count == 0) {
        g_info.cpu_count = 1;
    }
}

void _start(uint32_t hartid, uint32_t dtb,
    riscv32_caribebootx_args_t *args)
{
    stage0_init(hartid, dtb, args);

    puts("\n[XNU-CaribeOS] riscv32_kernel_entry\n");
    puts("  hart=");
    putdec(g_info.hartid);
    puts(" cpus=");
    putdec(g_info.cpu_count);
    puts(" dtb=0x");
    puthex32(g_info.dtb);
    puts("+0x");
    puthex32(g_info.dtb_size);
    puts(" timebase=");
    putdec(g_info.timebase_hz);
    puts("\n  mem=0x");
    puthex32(g_info.mem_base);
    puts("+0x");
    puthex32(g_info.mem_size);
    puts(" kernel=0x");
    puthex32(g_info.kernel_base);
    puts("+0x");
    puthex32(g_info.kernel_size);
    puts("\n  uart=0x");
    puthex32(g_info.uart_base);
    puts(" plic=0x");
    puthex32(g_info.plic_base);
    puts(" aclint=0x");
    puthex32(g_info.aclint_base);
    puts("\n");
    stage0_print_memory_map();
    print_cmdline();

    puts("[XNU-CaribeOS] PE_init_platform early\n");
    puts("[XNU-CaribeOS] pmap bootstrap identity window\n");
    virtio_mmio_scan();
    if (virtio_blk_init() == 0) {
        hfs_probe_root();
    }
    stage0_trap_timer_smoke();
    puts("[XNU-CaribeOS] kernel_early_bootstrap pending full Mach handoff\n");
    stage0_umode_linux_smoke();
    puts("[XNU-CaribeOS] kernel_bootstrap parked after storage proof\n");

    for (;;) {
        __asm__ volatile("wfi");
    }
}
