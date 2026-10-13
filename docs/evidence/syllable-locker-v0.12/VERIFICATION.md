# Original Syllable Locker checkpoint v0.12

Recorded 2026-10-13 on QEMU `virt` RV32IMACSU, with
`rv32,f=false,d=false,h=false,zfa=false` and 256 MiB RAM.
This is a genuine libsyllable dependency checkpoint, not completed
AppServer, Looper, Desktop, Dock, FileBrowser or pthread lifecycle.

## Actual executions

The retained matrix has seven actual boot cases:

| Case | Selected Locker gates | Actual scheduler waits in B | Result |
|---|---|---:|---|
| Progressive OpenSBI UP | A | Not selected | PASS |
| Progressive OpenSBI UP | A-B | 44,923 | PASS |
| Full OpenSBI UP | A-C | 42,234 | PASS |
| Full OpenSBI SMP repeat 1 | A-C | 43,446 | PASS |
| Full OpenSBI SMP repeat 2 | A-C | 49,661 | PASS |
| Full OpenSBI SMP final, public runner | A-C | 43,025 | PASS |
| Full SecureSBI SMP | A-C | 45,012 | PASS |

Every B execution ran sixteen actual CPU0-bound native workers with genuine
musl TCB/errno/native ELF TLS, 160,000 protected increments, 320,000
recursive acquisitions and zero overlapping owners. C additionally ran
64 immediate try-lock failures with EAGAIN, preserved main ownership and
errno, and confirmed exact 80 create/exit/reap events with zero live
threads/semaphores. B-only required 16 events; A required zero.

The five full cases also passed all existing TCB A-C, private-futex A-D,
raw-thread A-D, native-sync A-E, IPC A-D, area A-E, GNU single-thread C++,
genuine String/Message data core, FreeType, private VM and graphics/input
gates. Actual Bash returned after commands and ultimately exited 0,
reaped by PID1. All SMP cases passed kernel SMP F; SecureSBI discovery and
privileged-signing denial were verified. No userspace ran on CPU1.

Each case retains separate gate logs, result metadata, actual scanout
captures and full-local-UART hashes in [manifest.json](manifest.json).
Host fixtures are not counted as boots or guest locking evidence.

## Source and reproducibility

The preparer checked the two pinned Syllable upstream headers, retained
their LGPL notices and applied only the owner-initialization/unused-include
patch. Full COPYING.LIB and original/adapted sources remain available.
The independent RV32A, identity, raw-semaphore and genuine-TCB adapters are
original BSD-2-Clause runtime code. Musl remains unmodified MIT-style code;
XNU remains APSL 2.0. No third-party code is relicensed or binary Release
published. See [source records](syllable-sources.json).

Forced preparation, C++ probe and C adapter/assembly compilation, static
links, and inherited image repacks produced **20 byte-identical artifacts**.
The dependency matrix did not recompile the kernel. An additional actual
`testproject.ps1 -Mode graphics -Smp 2 -NativeLocker -NativeSync -FreeType
-SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'` invocation
refreshed/relinked the up-to-date kernel objects and passed the complete
SMP profile; its current logs are retained as the final SMP case above.
This is not claimed as a fresh full kernel-source compilation.
All prior v0.11 dependency hashes, including
the default native semaphore archive and TCB initrd, remain unchanged.
The older v0.10 process regression is explicitly reused, not rerun, only
for the identical kernel and dependency hashes.

- Kernel SHA-256: `f71b4c1ce917e110a10aa5324f3addab099e3ce63481f87eaa44d2a819da7476`.
- Locker ELF SHA-256: `e7ca5ad52a632a60a28352cf552df5a16f05b0276ee69deb1754f5d2b63d14f0`.
- Locker initrd SHA-256: `89a0096c86370f1f77be4f05aa43d480b41dcf3fdac5300a51a83ed044b0adf3`.
- Genuine native PT_TLS: initialized 4 bytes, total 20 bytes, alignment 16.
- 136/136 actual Python host guards and all three PowerShell guards passed.
- All 30 tracked PowerShell scripts parsed; staged static/license checks
  and secret scan passed before commit.

The collector validates actual serial markers, exact counts, independent
gate files, source/ELF hashes, snapshots and the complete current matrix
before retaining any evidence. Failed or stale results cannot overwrite
the previous stable checkpoint. The optional new snapshot is in
`build/last-stable-locker-v0.12`; v0.11 and prior snapshots are untouched.

Remaining barriers include the complete native thread API, timed worker
clock access, thread-safe allocator/stdio/GNU runtime and original
Looper/Handler/AppServer integration. This checkpoint does not enable
finite positive worker timeouts, Syllable Gate or userspace migration.
