# Musl TCB and native RV32 ELF TLS dependency gates

This optional profile tests genuine musl 1.2.5 `__copy_tls`, `pthread_self`
and `__errno_location` with the existing CPU0-bound native XNU user threads.
It is not `pthread_create`, a Linux thread-group implementation or a fully
thread-safe libc. It does not enable AppServer, Looper or Desktop yet.

## Contract

- The probe includes the unmodified musl internal ABI headers. No guessed
  `struct pthread`, copied libc implementation or patched third-party source.
- A small original assembly fixture supplies real `.tdata`/`.tbss` and native
  RV32 local-exec TLS relocations. It does not rely on this toolchain's emutls.
- Original musl bootstrap reads the ELF `PT_TLS` via the real auxiliary vector.
  Original `__copy_tls` then copies the real module and creates each DTV.
- Each raw-worker TCB has its own musl `errno` storage, self, locale and canary.
  `TP_ADJ` from musl selects the actual thread pointer, after the TCB on RV32.
- Workers exercise genuine `close(-1)` error translation into their own errno;
  the kernel still rejects that ordinary worker syscall with ENOTSUP (95).
  No worker FD, VM, malloc, stdio, signal or process support is implied.
- These raw TCBs are deliberately not inserted into musl's pthread list and
  do not run `__init_tp`, `set_tid_address`, robust-futex registration,
  clear-tid, TSD destructors or pthread cancellation semantics.
- Sixteen 32-KiB stacks plus independent 4-KiB TLS reserves fit in the existing
  1-MiB private VM bound. Memory is reused/released only after genuine JOIN
  confirms generic XNU reaping. No VM/process cap is enlarged.

## Progressive Gates

A checks the real main TCB, initialized/zero native TLS, sixteen copied
TCBs/DTVs, alignment and bounds. It does not create workers.

B runs sixteen actual workers, 10,000 checks each, independent native TLS and
errno across yields, then private-futex blocking/resume and exact reaping.

C recreates a fresh TCB in the same memory across 64 create/start/join cycles,
then issues sixteen cancellation requests after workers report ready to wait.
The ready marker is not proof that every worker was already asleep at that
instant; no such count is claimed. Gate B's sixteen actual futex wake returns
prove blocking/resume separately. Main TLS/errno remains unchanged and no
waiter survives reaping. Selected A/B/C requires exact 0/16/96 resources.

## Running

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeTcb -NativeSync -FreeType -SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'
```

`-TcbGate A`, `B` or `C` selects the last gate. The TCB option implies native
threads/private futex and rejects disabled dependencies. `initrd-tcb.img` is
separate; the v0.9/v0.10 images and stable snapshots remain available.
The runner validates the real PT_TLS shape, dependency symbols, actual gate
markers, counters, Bash exit and artifact hashes before declaring PASS.
Host fixtures test these validators; they are not guest execution evidence.

The evidence collector also compares nineteen original musl ABI/source and
license files byte for byte with the SHA-256-pinned official 1.2.5 archive,
including the installed public TCB-related headers. No third-party source is
extracted or rewritten by that read-only check.

`scripts/test-native-tcb-matrix.ps1` runs the full UP/OpenSBI SMP/SecureSBI
matrix and two saved SMP repeats, then forces the original C/assembly build
and all inherited image repacks, checks host/PowerShell guards and promotes
only the fully verified v0.11 evidence. It reuses the explicitly identified
v0.10 process regression only if the kernel/dependency hashes are unchanged;
it does not pretend to rerun or recompile that older long kernel suite.

## Remaining Barriers

Real pthread integration still requires thread-group identity, clear-tid,
thread-list locking, supported shared futex semantics, signal/cancellation
and robust lifecycle, allocator/stdio locks, GNU per-thread runtime and
Syllable native thread adapters. Looper/Handler/AppServer must then compile
and execute their original source with genuine native IPC/GUI services.
None is substituted by this TCB-only checkpoint.
