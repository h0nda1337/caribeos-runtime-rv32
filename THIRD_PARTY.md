# Third-Party Components

| Component | Source/version | License | Role | Local modifications | Binary redistribution |
|---|---|---|---|---|---|
| XNU | [Apple xnu-2050.48.11](https://github.com/apple-oss-distributions/xnu/tree/xnu-2050.48.11) | APSL 2.0 and file notices | Companion kernel | RV32IMACSU CaribeOS port | Kernel may be packaged only with applicable source and notices |
| OpenSBI | QEMU default firmware, observed 1.7; [upstream](https://github.com/riscv-software-src/opensbi) | BSD-2-Clause | M-mode firmware/SBI | None | Not copied from the local QEMU install into Git or preview |
| QEMU | [11.0.0 reference environment](https://www.qemu.org/) | GPL-2.0 and component licenses | RV32 `virt` emulator | None | Not bundled in repository or preview ZIP |
| musl | [1.2.5](https://musl.libc.org/) | MIT-style terms in `COPYRIGHT` | RV32 libc and static userland | Build configuration/wrappers | License text included; corresponding source asset required for the public preview |
| GNU Bash | [5.3 plus official patches 1-5](https://www.gnu.org/software/bash/) | GPL-3.0-or-later | Interactive shell | RV32 static build configuration | License text included; same-place corresponding source required |
| GNU GCC/binutils/make | Local cross toolchain | GPL and exceptions | Build tools | None | Toolchain not redistributed |
| GNU libstdc++/libsupc++ | [GCC 15.1.0 source](https://gcc.gnu.org/pub/gcc/releases/gcc-15.1.0/) | GPL-3.0-or-later with GCC Runtime Library Exception 3.1 where stated by file | Optional real RV32-musl C++ runtime | No upstream source changes; generic locale and single-thread static configuration | Not published as a new binary asset; future packages need exact sources and applicable notices |
| SecureSBI | OpenSBI v1.9, `cbf9f6734dd85a982c63e3cb5db7ffe09da839ca` | OpenSBI file licenses, primarily BSD-2-Clause | Optional modified M-mode firmware | CaribeSSBI discovery, guest denial, Windows LLVM build fix | Separate source tree; not bundled in the Tranche 201 assets |
| Monocypher | [4.0.2](https://github.com/LoupVaillant/Monocypher/tree/4.0.2), `0d85f98c9d9b0227e42cf795cb527dff372b40a4` | BSD-2-Clause OR CC0-1.0; BSD option used | Standard Ed25519 verifier including optional Ed25519 module | None | Any new CBX binary must retain the upstream BSD notice |
| Mbed TLS | [3.6.5](https://github.com/Mbed-TLS/mbedtls/tree/v3.6.5), `e185d7fd85499c8ce5ca2a54f5cf8fe7dbe3f8df` | Apache-2.0 OR GPL-2.0-or-later; Apache option used | SHA-256 only, original CaribeOS zeroization adapter | None to upstream sources | Any new CBX binary must include Apache-2.0 and applicable upstream notices |
| Python cryptography | [43.0.3 reference host environment](https://cryptography.io/) | Apache-2.0 OR BSD-3-Clause and bundled dependency notices | Host-only developer Ed25519 signing | None | Not shipped in firmware, repository, or preview |
| LLVM/Clang/lld | Local LLVM 22.1.4 | Apache-2.0 with LLVM exceptions | SecureSBI RV32 PIE build on Windows | None | Toolchain not redistributed |
| Syllable AppServer | [SyllableOS source](https://github.com/SyllableOS/Syllable/tree/579e480a005321cc320e7e355e8dff398b689be8) | LGPL-2.0-only for the four selected decorator files | Real software-rendered window decorator | Bounded title and max helper; Layer adapter | Future binaries require exact sources, changes, full license, and application objects/relink instructions |
| font8x8 | [Pinned source](https://github.com/dhepper/font8x8/tree/8e279d2d864e79128e96188a6b9526cfa3fbfef9) | Public domain, upstream notices preserved | Temporary bitmap font, not Syllable's full font engine | None | Preserve upstream attribution |
| Pillow | Host Python library | HPND and upstream component notices | QEMU screenshot verification only | None | Not bundled |
| FreeType | [2.15.0 official mirror](https://github.com/freetype/freetype/tree/37515cf56ba3349656049edbed89ffc6f6466f2d) | FTL chosen; upstream per-file BDF/PCF, zlib and embedded HarfBuzz exceptions preserved | Static RV32-musl font rasterization dependency | None | Complete upstream notices and FreeType Team acknowledgment required; no new binary Release |
| Bitstream Vera | [1.10 GNOME distribution](https://download.gnome.org/sources/ttf-bitstream-vera/1.10/) | Bitstream Vera font terms, not BSD | Three unmodified TrueType font test inputs | None | Complete COPYRIGHT.TXT bundled; fonts not sold alone; modified fonts must be renamed |

Original CaribeOS build wrappers, configuration headers, and integration
scripts that mention or invoke Bash, musl, OpenSBI, QEMU, or the toolchain are
BSD-2-Clause only when they carry the CaribeOS SPDX header and appear in
`docs/RUNTIME_LICENSE_SCOPE.json`. They are not copies of those projects and do
not change any upstream license.

The source archives and extracted trees under `third_party/` are local build
inputs and are not committed. `scripts/build-musl-rv32.ps1` and
`scripts/build-bash-rv32.ps1` record upstream URLs and expected hashes.

The font preparer verifies the official FreeType tag/commit and every original
Git blob (allowing only checkout CRLF normalization). It does not claim GPG
verification. Vera's archive is pinned to the GNOME publisher's SHA-256
`3a84126ce11ef404d1453438e35450b9e0838220d262059e56cd8496ac6f5d15`.
Complete notices are retained in local sources and bundled with the optional
font initrd, including [the acknowledgment](ports/freetype/NOTICE.md).
The source trees and font binaries are not committed or relicensed BSD.
No proprietary host fonts are used. This dependency is not a replacement
implementation of Syllable Font or a claim of completed AppServer/Desktop.

The BSD-2-Clause license in this repository applies only to original CaribeOS
runtime code. It does not relicense XNU, GNU Bash, musl, OpenSBI, QEMU, the
toolchain, generated data, or any other external component.

Native Syllable IPC/areas use the unchanged LGPL-2.0-only `atheos/msgport.h`
and `atheos/areas.h` from
commit `579e480a005321cc320e7e355e8dff398b689be8`. The native dependency
preparer verifies SHA-256, preserves exact upstream copies and records audited
Message sources separately from compiled inputs. Its musl type and
XNU port/area adapters are independently written CaribeOS code, not copies of the
AtheOS kernel. The complete LGPL text remains in `ports/syllable/COPYING.LIB`.
Any later binary package must carry the exact new dependency sources, notices
and applicable relink material; the old Tranche 201 source asset is insufficient.

The C++ preparer pins GNU's published SHA-512, retains the full GCC source
archive locally and extracts only runtime/build inputs, preserving COPYING3,
COPYING.RUNTIME and per-file notices. Compiler headers, CRT and libgcc are
from the installed matching GCC 15.1.0 toolchain, not copied into Git. The
libstdc++ build does not use the installed newlib library or newlib FILE/errno
structures. The runtime is currently single-threaded; GCC's --disable-tls
configuration uses its emulated TLS support rather than an ELF PT_TLS segment.
This is not a claim of POSIX/native GUI thread support or full library syscall
coverage. No GNU/third-party input is added to the CaribeOS BSD allowlist.

The public-preview Release includes the same-place asset
`caribeos-tranche-201-corresponding-source.zip`. It contains the exact Bash 5.3
archive, official patches 1-5, musl 1.2.5 archive, maintained build-control
scripts, applicable license texts, runtime source snapshots, and a
cryptographic manifest. See `docs/PUBLIC_LICENSE_REVIEW.md` for the technical
review and exact upstream hashes.

The native Syllable String profile compiles the authentic libsyllable
implementation at the same pinned Syllable revision, retaining LGPL-2.0-only.
The public String header is unchanged after LF normalization. A versioned
LGPL source patch fixes reverse-trim underflow, ctype argument handling and
va_list formatting. The existing Font byte-length helper is isolated with
its original notices; no Font engine is implemented by that extraction.
Upstream/adapted hashes, full COPYING.LIB, application objects and a separate
String archive are retained for future corresponding-source/relink packages.
See [patch provenance](ports/syllable/patches/README.md). The original
preparer/test are BSD-2-Clause; neither relicenses these library inputs.
No new binary asset is released and the older source asset is not represented
as corresponding source for this new profile.

The genuine Message data-core profile compiles additional pinned libsyllable
Message, Flattenable/typecode and geometry interfaces under LGPL-2.0-only.
An auditable LGPL source/header patch adds bounded RV32 serialization and
explicitly omits unported Looper/Handler/Variant methods, without fake stubs.
The original exact-byte-count receive adapter and tests are BSD-2-Clause,
but do not relicense Message or its interfaces. Full notices and COPYING.LIB,
exact upstream/adapted source hashes, application objects and separate library
archives are retained for future corresponding-source/relink packaging.
See [Message core](docs/SYLLABLE_MESSAGE_CORE.md). No new binary Release is
published and the old source asset does not cover these new dependencies.

Native counting semaphores additionally consume unchanged
`atheos/semaphore.h` at the same Syllable revision. Its normalized SHA-256 is
`804102b669523edd9b18e1642f08199ee8e7ad42ad227420a3a41ea772d307f1`.
The preparer preserves the original LGPL-2.0-only notices and complete
COPYING.LIB. The independently written musl/RV32 API/type adapters and tests
are BSD-2-Clause, not copied Syllable semaphore kernel code. The backend is
native XNU/APSL 2.0. No third-party header enters the BSD source allowlist,
and no new binary package is published. See [counting profile](docs/SYLLABLE_NATIVE_SYNC.md).

The native raw-thread UAPI/probe and evidence tooling are original CaribeOS
BSD-2-Clause code. Their XNU backend retains APSL 2.0. The raw worker profile
does not modify or relicense musl, GNU emutls, Syllable or any other external
component, and is not a threaded libc/GNU compatibility claim. See
[thread boundary and gates](docs/SYLLABLE_NATIVE_THREADS.md).

Security sources are pinned by [security/dependencies.json](security/dependencies.json)
and obtained by `scripts/prepare-security-deps.py`. They remain unmodified,
ignored build inputs under `third_party/`. Monocypher and Mbed TLS upstream
trees include their complete license texts. This change publishes source and
wrappers only, not a new binary Release. The preserved Tranche 201 source
asset does not cover these new dependencies; future binary packaging must
include the exact new sources and notices rather than reusing that old asset.
