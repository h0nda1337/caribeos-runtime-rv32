# Genuine Syllable Locker on native XNU workers

This optional profile compiles the original inline `os::Locker` from
Syllable commit `579e480a005321cc320e7e355e8dff398b689be8`. It is an
actual libsyllable dependency, not a replacement implementation or a claim
that Looper, Handler, AppServer, Desktop, Dock or FileBrowser already run.

## Source and API boundary

- Original `util/locker.h` normalized SHA-256:
  `55743b5932e41f4b2041359229185961bb8b2691c0cc2bec29c0d549c243a74e`.
- Original `atheos/threads.h` normalized SHA-256:
  `4d0cf6a5ecf996208dd85d002ea25238acd12bc38057ac62758623931c2d9988`.
- The LGPL source patch only initializes `m_nOwner=-1` and removes an unused
  obsolete debug header. Original notices and locking algorithms survive.
- An independently written RV32A adapter implements the public atomic API
  with sequentially consistent GCC atomics. In particular,
  `atomic_inc_and_read` returns the **old** value, required for the fast path.
- `get_thread_id(NULL)` reads actual native XNU identity. Name lookup and
  the rest of Syllable's thread API are not implemented by this small adapter.
- Each worker has a genuine musl TCB prepared using unmodified internal ABI,
  `__copy_tls` and `TP_ADJ`. Native ELF TLS and errno remain independent.
  No fabricated pthread layout or insertion into musl's thread list.
- A separate `libcaribe-syllable-locker.a` uses existing native-thread
  semaphore ECALLs. It does not replace the older FD/ioctl semaphore archive.
  Workers do not require ordinary Linux FD, VM or clock syscalls.
- Supported worker paths here are infinite waits and immediate `Lock(0)`.
  Finite positive timed waits still need a native clock adapter. Recursive
  Syllable `Gate`, reader/writer locks and the complete semaphore API are
  not claimed. There are no success-returning stubs for those features.
- All workers remain CPU0-bound, sharing the actual owner task/pmap. The
  kernel's second hart continues kernel work. No userspace migration, new
  clone/process model, signals, worker allocator/stdio or threaded GNU
  runtime is enabled. The existing 1-MiB private VM bound is unchanged.

## Gates

A exercises the genuine constructor, native owner, recursive fast path,
unlock and old-value/CAS/exchange atomic contract. No workers are created.

B runs sixteen native workers, 10,000 protected increments each, taking
the original Locker twice recursively per iteration. Yielding while held
forces real contention. Exact 160,000 increments, 320,000 recursive
acquisitions, zero overlapping owners, independent errno/TLS and a positive
native scheduler-wait count are required. All sixteen workers are joined
and genuinely reaped; no semaphore survives scope exit.

C keeps the main thread as owner while recreating a fresh worker TCB across
64 immediate try-lock/join cycles. Every `Lock(0)` must fail with EAGAIN
without stealing ownership or modifying main errno. Final create/exit/reap
counts are exactly 0/16/80 for selected A/B/C, with zero live resources.
Memory is released only after all joins/reaping complete.

## Running and evidence

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeLocker -NativeSync -FreeType -SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'
```

`-LockerGate A`, `B` or `C` selects the last gate. This profile implies the
existing TCB/thread/private-futex dependency gates; disabled dependencies
and non-graphics modes are rejected before any build, HFS write or QEMU.
The separate `initrd-locker.img` leaves the v0.11 TCB image available.

`scripts/test-native-locker-matrix.ps1` tests UP, OpenSBI SMP three times,
and SecureSBI SMP with all existing dependency/graphics gates and actual
Bash exit. It forces source preparation, new adapter/assembly compilation,
static links and image repacks, requiring byte-identical artifacts and
unchanged prior dependency hashes. Host fixtures test validators only.
The collector promotes v0.12 separately, preserving v0.11 evidence and
snapshots. The kernel is not recompiled by this dependency matrix; its
prior process regression is explicitly reused only for identical hashes.

The original header and patch remain LGPL-2.0-only. Complete licenses,
upstream/adapted sources, application objects and separate archives are
retained locally for future corresponding-source/relink packaging.
No new binary Release is created and no existing technical tag is moved.
