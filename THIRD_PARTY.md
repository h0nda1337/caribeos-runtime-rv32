# Third-Party Components

| Component | Source/version | License | Role | Local modifications | Binary redistribution |
|---|---|---|---|---|---|
| XNU | Apple xnu-2050.48.11 | APSL 2.0 and file notices | Companion kernel | RV32IMACSU CaribeOS port | Kernel may be packaged only with applicable notices |
| OpenSBI | QEMU default firmware, observed 1.7 | BSD-2-Clause | M-mode firmware/SBI | None | Not copied from the local QEMU install into Git |
| QEMU | 11.0.0 | GPL-2.0 and component licenses | RV32 `virt` emulator | None | Not bundled in repository or preview ZIP |
| musl | 1.2.5 from musl.libc.org | MIT | RV32 libc and static userland | Build configuration/wrappers | Userland binaries may require accompanying notices |
| GNU Bash | 5.3 plus official patches 1-5 | GPL-3.0-or-later | Interactive shell | RV32 static build configuration | Source-offer/license duties apply to redistributed binary |
| GNU GCC/binutils/make | Local cross toolchain | GPL and exceptions | Build tools | None | Toolchain not redistributed |

The source archives and extracted trees under `third_party/` are local build
inputs and are not committed. `scripts/build-musl-rv32.ps1` and
`scripts/build-bash-rv32.ps1` record upstream URLs and expected hashes.
