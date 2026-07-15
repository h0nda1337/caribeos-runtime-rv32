# Tranche 201 Build Environment

Captured on 2026-07-14.

| Tool | Version |
|---|---|
| Windows PowerShell | 5.1.26100.8457 |
| Git | 2.54.0.windows.1 |
| RISC-V GCC/G++ | 15.1.0 |
| GNU Make | 4.4.1 |
| QEMU | 11.0.0 |
| OpenSBI from QEMU | 1.7 |
| CMake | 4.3.2 |
| Ninja | 1.13.2 |

Target ISA flags are `rv32imac_zicsr_zifencei` with the ILP32 ABI. The tested
machine is QEMU `virt`, 256 MiB RAM, two harts for SMP gates, OpenSBI via
`-bios default`, and CaribeBootX via `-kernel`.

The repository does not include a toolchain, QEMU installation, downloaded
third-party archives, or proprietary Apple SDK.
