# Genuine musl allocator and worker Message transport

This optional profile removes a concrete dependency barrier for authentic
Syllable Handler/Looper/AppServer. It is not a replacement allocator,
replacement event loop, threaded GNU runtime or complete desktop.

## Verified v0.15 checkpoint

The complete matrix and public runner passed on 2026-10-14 with kernel
`2f6df12958747994e625dd648bd24b013fae2e400025bf59f5eedcd2321e9304`.
The [execution record](evidence/syllable-heap-v0.15/EXECUTION.md) and
[manifest](evidence/syllable-heap-v0.15/manifest.json) retain 12 profiles,
the 38-artifact byte-identical forced rebuild, 15 fresh process targets,
247 host guards and current-hash visual evidence. The prior v0.14 snapshot
and userland are unchanged. This is a verified optional allocator dependency,
not completion of Looper, AppServer or the desktop.

## Validation history

An earlier attempt with kernel
`475651ffb7fc48c96ad9d9d268b98e6d4b8a896b78e45d9bc1ce63dbb96123e8`
passed heap A/B/full UP, three full SMP runs, SecureSBI SMP, unchanged Queue
UP/SMP, disabled thread/futex/heap profiles and the 38-artifact byte-identical
forced rebuild. Fresh process regression stopped after 13 targets at Gate 14:
the actual CPU1 work/exit/reap succeeded, but concurrent multipart UART
records corrupted the exact waitid-option marker. The failed receipt and
full serial/run logs remain local under `build/heap-gate14-failed-20261014/`.

The two colliding exec-argument/waitid-option records now use the existing
IRQ-safe console's single-write format. Kernel
`2f6df12958747994e625dd648bd24b013fae2e400025bf59f5eedcd2321e9304`
compiled, linked and passed the public Gate 14 runner with exact unchanged
markers, CPU1 work/reaping, SMP A/C/D/E/F and Bash exit(0). The entire matrix,
forced rebuild and fresh process suite were then repeated successfully on
this corrected hash before retaining the new snapshot.

An earlier attempt also stopped at the old Thread B timer/semaphore-wait
assertion. Its unchanged repeat and the subsequent UP/SMP profiles passed;
the initial cause is not isolated. No threshold was relaxed. Timing-sensitive
50-us wait registration remains an open diagnostic item, not a claimed fix.

## Implementation

- Separate genuine musl 1.2.5 sysroot; mallocng, locks and public headers
  unchanged. All 2697 upstream regular-file inputs are checked. Only the
  MIT-licensed RV32 syscall-routing patch changes the prepared arch header.
- Original runtime integration sets `libc.need_locks=1` before worker start;
  real musl atomics and private futex waits serialize its shared allocator.
  `libc.threaded`, pthread lists, stdio and GNU exception TLS are not enabled.
- Wrapped malloc/calloc/realloc/free/alignment functions invoke their real
  musl implementations inside nestable native allocator scopes. Outermost
  leave atomically reports pending cancellation without ending the scope;
  the adapter frees an unreturned result and acknowledges safe termination.
- Forced thread cancellation waits for an active allocator scope to finish.
  A five-second grace expiry observed at a user boundary, or a user fault
  inside such a scope, poisons the process heap and aborts the whole process
  rather than allowing reuse.
  Whole-process teardown cancels/reaps workers before dropping the shared VM.
- Native VM ECALL `0x05000004` carries the original VM operation in a6 and
  normal arguments in a0-a5. It requires native-threads/native-futex/native-heap
  boot opt-ins and CPU0/task/pmap identity. Ordinary worker Linux VM/FD calls
  remain denied. Main fork/exec still reject while native workers are live.
- Existing XNU private brk/mmap accounting/backing and caps are reused, not
  bypassed. VM operations serialize with a preemption-safe global lock;
  stack/TCB validation happens inside the lock over page-rounded ranges.
  Non-page-aligned native stacks still reject; a one-byte unmap/protect
  request cannot remove a live stack or registered TCB page.
- Anonymous non-fixed RW maps and bounded brk/unmap/RO-or-RW protect are
  available. File/execute maps, PROT_NONE and advisory VM remain unsupported.
  The legacy shrink-only mremap stub is not exposed as allocator success:
  native mremap returns ENOSYS so genuine realloc uses its real fallback.
  Guard-page support and larger VM capacity remain separate kernel work.

The original Syllable Message/Queue/Thread archives are reused unchanged.
Workers can now allocate and decode genuine Message objects and use the real
ReadPort implementation over native IPC, with preserved TCB/errno/native TLS.
This does not enable unsupported worker stdio, signals, general Linux FD
access, pthread lifecycle or GNU thread exceptions.

## Progressive proof

A: VM boundary, a real 128 KiB worker allocation/free, protected stack/TCB,
invalid stack alignment rejection, one-byte destructive VM requests denied,
and no broadening of ordinary Linux worker permissions.

B: 16 workers, 160,000 calloc/realloc/aligned/free cycles, 10,000 original
worker Message construction/flatten/bounded decode/Queue cycles, independent
TCB/errno/TLS and CPU0, with exact generic reaping.

C: 10,000 typed messages decoded by original worker ReadPort. Also 64
cancelled actual musl-lock futex waiters whose unreturned allocations are
freed before acknowledgement, 8 critical allocator-fault child processes
aborted by SIGSEGV, and 8 owner-exit processes discarding their heap only
after native worker teardown. Exact totals: 163 created/exited/reaped,
72 cancellations, 8 expected faults, 16 abandoned scopes, zero active scopes
and owner futex waiters; entries equal leaves plus aborted scopes.

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -SyllableHeap -NativeSync -FreeType -Cpu rv32,f=false,d=false,h=false,zfa=false
```

Heap A/B/C have independent `-HeapGate` selectors. Dependencies are implied;
disabled dependencies and non-graphics modes reject before disk/kernel work.
`-DisableNativeHeap` checks the new channel remains default-off.

The matrix additionally requires repeated SMP, SecureSBI, old Queue UP/SMP,
default-off thread/futex/heap profiles, actual forced kernel/musl/integration
rebuild, unchanged v0.14 userland and snapshot, and fresh process regression
before retention. Short QMP temporary paths avoid Windows screendump limits
without dropping full case identities, screenshots or pixel validation.

## Remaining desktop requirements

Genuine Handler/Looper, worker-safe stdio and GNU threading/exception/TLS,
AppServer protocols, window management and Desktop/Dock/FileBrowser remain
required. Forced cancellation still cannot automatically release arbitrary
application-owned resources outside allocator scopes. No complete pthread
or production fault-recovery contract is claimed. Native graphics/font
captures are preserved dependencies, not the requested complete desktop.
The cancellation grace check currently runs at user boundaries: a worker
indefinitely blocked inside an allocator scope cannot itself observe that
deadline. Independent kernel-deadline enforcement for stuck allocator waits
remains required before claiming bounded production cancellation.
