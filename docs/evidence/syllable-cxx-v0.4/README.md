# GNU RV32-Musl C++ Evidence

Recorded 2026-10-13. Kernel SHA-256 remains
`bef8795f430f4a27cb6e76052b2c8e703690d4d089ea384f195422bcd53aac1f`.
No new kernel feature is implied by this userland/runtime checkpoint.

GNU libstdc++ SHA-256:
`058d0a82fbd3132b59d7e5d57eb2291f80ad490ba15468d02f1603119621ef03`.
C++ probe SHA-256:
`00e02537e8443e98684048b6fd5fa9f4c9899e9010ae88a1bd71319d1792dcb4`.
Selected C++ initrd SHA-256:
`424b07e560ea0551f16e89fc6e60e5ff67b7fac150c0a7efaff6370e79d1893a`.
The ordinary initrd remains byte-identical to the v0.3 area milestone.

Each QEMU result verifies C++ A-D plus native IPC A-D, shared areas A-E,
private VM, graphics/input A-E, session restart and clean Bash exit. Cases
include OpenSBI UP, OpenSBI SMP2 without F/D/H and SecureSBI SMP2. These tests
use actual musl and a newly compiled GNU library, not the decorator's minimal
fallbacks or an incompatible newlib stdlib.

C++ coverage: string/vector/map/sort/streams, allocator, RTTI/dynamic_cast,
10,000 throws and 10,000 unwind destructors, out_of_range, global constructor
and real exit destructor, 16 fork/exec cycles, heap isolation and thread_local
preservation/reset. **The TLS model is GNU emulated TLS, single-thread** because
the installed compiler disables native TLS/threads. Neither native POSIX/GUI
threads nor complete libstdc++ syscall coverage is claimed.

The runner checks RV32 ELF32, soft-float, static execution, presence of the
actual TLS implementation and source/compiler version. Each result records
15 hashes, including the selected initrd, library, probe and matching GCC
crtbegin/crtend/libgcc inputs, plus six actual QMP scanouts. The scans still
show the shared-area test and authentic Syllable decorators, not a complete
AppServer/Desktop. X11/Wayland are not involved.

Forced recompilation of GNU EH allocator, new and string instantiation code,
library reassembly/reinstallation, C++ probe relink and initrd regeneration
reproduced all four hashes in rebuild.json. This is incremental rebuild
evidence, not a fresh-host compiler/runtime rebuild. The source manifest pins
the GNU archive and unchanged selected inputs; complete GNU license texts
remain in the retained ignored source archive/tree. No ELF/archive binary,
disk image, private key or new Release asset is published here.

Three host-only runner guard tests verify that a bad ELF, hard-float profile
or missing TLS runtime is rejected before QEMU starts, and that a previous
PASS is replaced with FAIL. These do not simulate or validate kernel behavior.
The v0.3 kernel's full process/security regression evidence remains separate.
Syllable Message/Looper/AppServer/Desktop/Dock/FileBrowser are still not built.
