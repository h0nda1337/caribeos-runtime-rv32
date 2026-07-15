# Third-Party Components

| Component | Source/version | License | Role | Local modifications | Binary redistribution |
|---|---|---|---|---|---|
| XNU | [Apple xnu-2050.48.11](https://github.com/apple-oss-distributions/xnu/tree/xnu-2050.48.11) | APSL 2.0 and file notices | Companion kernel | RV32IMACSU CaribeOS port | Kernel may be packaged only with applicable source and notices |
| OpenSBI | QEMU default firmware, observed 1.7; [upstream](https://github.com/riscv-software-src/opensbi) | BSD-2-Clause | M-mode firmware/SBI | None | Not copied from the local QEMU install into Git or preview |
| QEMU | [11.0.0 reference environment](https://www.qemu.org/) | GPL-2.0 and component licenses | RV32 `virt` emulator | None | Not bundled in repository or preview ZIP |
| musl | [1.2.5](https://musl.libc.org/) | MIT-style terms in `COPYRIGHT` | RV32 libc and static userland | Build configuration/wrappers | License text included; corresponding source asset required for the public preview |
| GNU Bash | [5.3 plus official patches 1-5](https://www.gnu.org/software/bash/) | GPL-3.0-or-later | Interactive shell | RV32 static build configuration | License text included; same-place corresponding source required |
| GNU GCC/binutils/make | Local cross toolchain | GPL and exceptions | Build tools | None | Toolchain not redistributed |

The source archives and extracted trees under `third_party/` are local build
inputs and are not committed. `scripts/build-musl-rv32.ps1` and
`scripts/build-bash-rv32.ps1` record upstream URLs and expected hashes.

See `docs/PUBLIC_LICENSE_REVIEW.md` for the currently blocked runtime project
license and Developer Preview redistribution review.
