#include <stdint.h>
#include "include/uapi/mmu.h"

static uint32_t __attribute__((aligned(4096))) l1[1024];

static inline void sfence_vma_all(void){
  __asm__ volatile("sfence.vma zero, zero" ::: "memory");
}

void mmu_sv32_install_identity(uint32_t ram_start, uint32_t ram_size_mb,
                               uint32_t mmio0, uint32_t mmio1, uint32_t mmio2)
{
  for(int i=0;i<1024;i++) l1[i]=0;

  const uint32_t flags_ram = PTE_R|PTE_W|PTE_X|PTE_A|PTE_D|PTE_G;
  uint32_t va = ram_start;
  uint32_t end = ram_start + (ram_size_mb << 20);
  for(; va < end; va += 0x400000){
    uint32_t idx = (va >> 22) & 0x3FF;
    l1[idx] = pte_super(va, flags_ram);
  }

  const uint32_t flags_io = PTE_R|PTE_W|PTE_A|PTE_D|PTE_G;
  uint32_t mmios[3] = { mmio0, mmio1, mmio2 };
  for(int k=0;k<3;k++){
    uint32_t base = mmios[k];
    if(!base) continue;
    uint32_t idx = (base >> 22) & 0x3FF;
    l1[idx] = pte_super(base, flags_io);
  }

  sfence_vma_all();
}

void mmu_sv32_enable(void){
  uintptr_t ppn = ((uintptr_t)l1) >> 12;
  uint32_t satp = (1u<<31) | (uint32_t)ppn;
  __asm__ volatile("csrw satp, %0" :: "r"(satp) : "memory");
  __asm__ volatile("sfence.vma zero, zero" ::: "memory");
}
