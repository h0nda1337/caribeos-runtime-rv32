#pragma once
#include <stdint.h>

#define RISCV32_CARIBEBOOTX_MAGIC   0x31425843u
#define RISCV32_CARIBEBOOTX_ACK_MAGIC 0x584e5541u
#define RISCV32_CARIBEBOOTX_MIN_VERSION 1u
#define RISCV32_CARIBEBOOTX_VERSION 2u

typedef struct riscv32_xnu_memory_range {
    uint32_t type;
    uint32_t pad;
    uint64_t physical_start;
    uint64_t virtual_start;
    uint64_t number_of_pages;
    uint64_t attribute;
} riscv32_xnu_memory_range_t;

typedef struct riscv32_caribebootx_args {
    uint32_t magic;
    uint32_t version;
    uint32_t flags;
    uint32_t hartid;
    uint32_t dtb_paddr;
    uint32_t dtb_size;
    uint32_t mem_base;
    uint32_t mem_size;
    uint32_t uart_base;
    uint32_t plic_base;
    uint32_t aclint_base;
    uint32_t kernel_base;
    uint32_t kernel_size;
    uint32_t initrd_base;
    uint32_t initrd_size;
    uint32_t command_line_paddr;
    uint32_t command_line_size;
    uint32_t memory_map_paddr;
    uint32_t memory_map_count;
    uint32_t memory_map_desc_size;
    uint32_t reserved[12];
} riscv32_caribebootx_args_t;
