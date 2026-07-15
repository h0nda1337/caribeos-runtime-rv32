#include <stdint.h>

#define SV32_PTE_V (1u<<0)
#define SV32_PTE_R (1u<<1)
#define SV32_PTE_W (1u<<2)
#define SV32_PTE_X (1u<<3)
#define SV32_PTE_U (1u<<4)
#define SV32_PTE_G (1u<<5)
#define SV32_PTE_A (1u<<6)
#define SV32_PTE_D (1u<<7)

/* L1 tabla alineada a 4KiB */
static uint32_t l1_tbl[1024] __attribute__((aligned(4096)));

/* Mapea identidad 0x8000_0000..0x8FFF_FFFF con superpáginas de 4MiB */
void sv32_map_identity_256mb(void)
{
  /* 256MiB / 4MiB = 64 entradas L1 */
  for (uint32_t i=0;i<64;i++){
    /* PPN1 = bits [31:22] del PA base de la superpágina.
       Cada superpágina = 4MiB = 1<<22, así que PPN1 = (base>>22).
       En Sv32, un leaf en nivel 1 usa PPN1 (bits 31:22), PPN0 debe ser 0.
    */
    uint32_t base = 0x80000000u + (i<<22); /* i * 4MiB */
    uint32_t ppn1 = (base >> 22) & 0x3FFu;

    uint32_t pte =
      (ppn1 << 20) |           /* PPN1 en bits [31:20] del PTE */
      /* PPN0 = 0 en superpágina nivel-1 */
      SV32_PTE_V | SV32_PTE_R | SV32_PTE_W | SV32_PTE_X /* RWX+V */
      /* | SV32_PTE_A | SV32_PTE_D  <- si prefieres marcarlos 1 desde ya */;
    l1_tbl[i] = pte;
  }
  /* Limpia el resto */
  for (uint32_t i=64;i<1024;i++) l1_tbl[i]=0;

  /* satp.MODE=Sv32 (1), ASID=0, PPN = (l1_tbl >> 12) */
  uint32_t satp = (1u<<31) | ((uint32_t)l1_tbl >> 12);
  __asm__ volatile("csrw satp, %0\nsfence.vma x0, x0\n" :: "r"(satp) : "memory");
}
