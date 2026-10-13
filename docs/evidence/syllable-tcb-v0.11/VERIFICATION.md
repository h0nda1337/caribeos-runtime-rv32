# Verified Musl TCB/Native ELF TLS Checkpoint v0.11

Recorded 2026-10-13. This is an authentic libc ABI dependency milestone,
not a complete pthread implementation, Looper, AppServer or Desktop.

## Actual Execution

- Initial progressive UP gates A and B passed before the full matrix.
- Final full ABC matrix passed on OpenSBI UP, OpenSBI SMP and SecureSBI SMP.
  Two additional full SMP runs are retained separately, not overwritten.
- Each full case created/exited/reaped exactly 96 CPU0 user threads, live=0.
- Gate B: sixteen workers, 160,000 independent native TLS/errno checks,
  sixteen actual private-futex waiters woken and resumed, exact reaping.
- Gate C: 64 same-memory recreation cycles and sixteen cancellation requests,
  fresh TLS/errno, main state unchanged and no waiter after reaping.
  Reporting ready does not prove every cancelled worker was already asleep;
  the logs and metadata explicitly do not claim that stronger property.
- Workers call genuine musl `pthread_self`, `__errno_location` and `close`.
  `close(-1)` remains denied by the kernel worker syscall boundary (95),
  and genuine libc error translation updates only that worker's errno.
- All final cases also passed raw-thread ABCD, private-futex ABCD, native
  semaphore ABCDE, IPC/areas, GNU single-thread C++, Syllable String and
  Message data core, FreeType, actual virtio-gpu/input and session restart.
- Bash exits status=0 and PID1 reaps PID2 in every retained case. SMP F and
  SecureSBI privileged-signing denial remain verified where applicable.

## Integrity And Reproduction

- ELF32 static RV32/soft-float, real PT_TLS filesz=4/memsz=20/align=16,
  initialized data and zero TLS, original musl `__copy_tls` and DTV layout.
- Nineteen original musl ABI/source/license files match the official 1.2.5
  archive byte for byte; four installed public headers match too. The
  archive is SHA-256 pinned, not claimed to have an independently verified
  cryptographic signature. [Exact hashes](musl-sources.json).
- Actual forced TCB C/assembly compilation, static link and inherited
  base/thread/futex/TCB image repacking preserve sixteen artifact hashes.
  The existing kernel is unchanged, not newly recompiled by this gate.
- 108/108 actual host unittest guards passed. Host fixtures are not guest
  proof. Three actual PowerShell guard scripts passed; the disk-lock guard
  additionally verifies TCB forwarding and early invalid-profile rejection.
- The public `testproject.ps1 -Mode graphics -Smp 2 -NativeTcb -NativeSync
  -FreeType -SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'`
  entry was also actually executed successfully after the complete matrix.
- Kernel SHA-256 remains
  `f71b4c1ce917e110a10aa5324f3addab099e3ce63481f87eaa44d2a819da7476`.
  Native TCB probe SHA-256:
  `bf309a6066d4153580462ad0097ffd6a0389e00db3b1d9c63e37dab0abb36009`.
  TCB initrd SHA-256:
  `ece23091fa9d2e586c801823a9282ade1f9517442e481fa4c8ac1cf827cdf015`.
- The prior v0.10 fifteen-target process regression is explicitly reused,
  not rerun. The collector requires identical kernel/CBX/dependency and
  original futex-image hashes before accepting that baseline.
- v0.9/v0.10 evidence and stable snapshots are preserved. Only a fully
  validated matrix can replace the separate local v0.11 snapshot.

## Boundaries

No guessed pthread structure, patched musl sources, Linux kernel code,
GNU emutls threading, Linux clone thread groups, musl thread-list insertion,
clear-tid, TSD destructors, full malloc/stdio locking or pthread cancellation
semantics are claimed. No higher VM cap, user CPU migration, new binary
Release, paid service, forced push or technical tag modification.

The next dependency is genuine native Syllable thread/synchronization
integration, then original Locker/Looper/Handler execution. The final goal
remains authentic Syllable Desktop over XNU, without X11 or Wayland.
