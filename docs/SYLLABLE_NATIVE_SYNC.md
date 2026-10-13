# Native Counting Semaphores

This is a progressive native XNU synchronization profile for the authentic
Syllable port. It is **not native GUI threading** and does not enable Linux
CLONE_VM/CLONE_THREAD, pthreads, Looper or the currently excluded Message
delivery methods. User applications remain on CPU0; the existing kernel SMP
tests continue running independently. No Linux kernel, Wayland or X11 is used.

```powershell
.\testproject.ps1 -Mode graphics -Smp 1 -NativeSync -SyncGate A
.\testproject.ps1 -Mode graphics -Smp 2 -NativeSync -SyllableMessage
```

The optional `build/initrd-sync.img` contains the synchronization probe and
existing C++/String/Message probes. `SyncGate` selects the last gate A-E;
unselected gates are not executed or reported as passing. Ordinary images do
not require the additional profile. Each run retains a distinct directory,
per-gate logs, actual artifact hashes and a result that becomes FAIL on error.

## ABI And Lifecycle

The fixed-width, 128-byte ABI uses version 0x10000 and ioctl 0xc0805301 over
the existing `/dev/caribe-ipc` descriptor. It supports 64 bounded counting
objects, generation-tagged positive IDs, 0..INT_MAX credits, atomic multi-unit
acquire/release, info and global diagnostic statistics. Names are bounded to
63 bytes. Invalid ABI, flags, timeout, IDs, zero units and overflow are denied.
Copyout failure on create/acquire/release does not publish an object or consume
or add credits. The header equality gate runs before starting QEMU.

Objects are creator-owned. Local objects are accessible only to their creator
process. `SEM_GLOBAL` allows a process that knows the ID to acquire/release/query,
but only the creator can delete it. This is not a production capability or
authentication policy. Fork does not clone ownership of local semaphores.
Successful exec and exit remove creator-owned objects and wake their waiters;
failed exec leaves the old objects intact. Count and latest-holder identity
remain separate from creator identity. The holder is the process's current
single native user thread, not proof of multiple userspace threads.

Waiters use XNU assert_wait_deadline/thread_block and a stable per-slot event
sequence. Rechecking the sequence after registering the wait closes the
release/delete-before-block window. Slot reuse preserves the event address and
changes the public generation. Deletion after blocking returns EIDRM. Timed
waits return ETIMEDOUT, nonblocking shortage returns EAGAIN, and deliverable
signals return EINTR without consuming credits. Wrapper waits longer than the
kernel's 60-second bound retain an overall monotonic deadline; infinite waits
renew bounded waits. There is no polling in the guest acquire path.

The object lock uses XNU's RV32A CAS and release primitives. Count/object changes
are serialized, publication uses memory barriers, and the lock is dropped
before scheduler blocking. No interrupt handler takes this lock. Wait/wake
counters use RV32A atomics. The current gates do not prove fairness, priority
inheritance, starvation freedom or cross-hart userspace lock contention.
Before adding real shared-task user threads, audit preemption/interrupt nesting
and the thread lifecycle separately; passing kernel SMP F does not do that.

## Gates

- A: counting/multi-unit operations, bounded timeout, overflow and argument
  validation, generation IDs, explicit rejection of unsupported policies,
  measured 32/64-bit relative and monotonic absolute scheduler sleeps.
- B: 64-object capacity, 256 recycle cycles, read-only request-page failures on
  create/acquire/release with no leaked object or lost/added credits.
- C: forked local/global permission checks, owner-only deletion, exit cleanup,
  16 successful exec cleanup cycles and failed-exec preservation.
- D: independently exec'd process, real shared Sv32 pages and 10,000 semaphore
  request/reply rounds; exactly 20,000 acquisitions and releases with actual
  scheduler waits and ordered shared-memory observations.
- E: 16 blocked explicit deletions with immediate slot reuse, 16 owner exit/exec
  deletions waking waiters, SIGUSR1 interrupting acquire without changing count,
  and three interrupted sleeps validating remaining time/absolute-buffer rules.

## Clock Wait Regression

The first owner-lifecycle test exposed an existing successful-return stub in
clock_nanosleep, the path used by RV32 musl nanosleep. The kernel now routes
32-bit and time64 clock sleeps through a real XNU deadline wait loop. Spurious
wakes cannot shorten the sleep, relative EINTR returns actual remaining time,
and absolute monotonic sleeps ignore the remaining buffer. Measurements in the
guest require the requested interval to elapse; status zero alone cannot pass.
SA_RESTART must not silently restart clock sleeps after the test's signal.

Relative REALTIME and MONOTONIC are supported. Absolute MONOTONIC uses the
existing uptime timebase. Absolute REALTIME, CPU-time and BOOTTIME sleep policies
are explicitly unsupported because an adjustable RTC/process-time/suspend clock
is not implemented. This does not claim the older clock_gettime/getres methods
already have complete clock-ID policy or a wall-clock source. Invalid flags,
negative/oversized fields and invalid request pointers are rejected. The older
32-bit nanosleep route shares the real wait helper and retains its preexisting
remaining-buffer initialization behavior, while interrupted remaining time is
now measured rather than always zero.

API contract reference: [Linux man-pages clock_nanosleep](https://man7.org/linux/man-pages/man2/clock_nanosleep.2.html).
The runtime's pinned musl 1.2.5 src/time/clock_nanosleep.c was also inspected;
no musl source was modified or relicensed for this correction.

Existing IPC/areas/private-VM/graphics/input/restart/Bash gates run afterward.
`-SyllableMessage` additionally executes genuine Message/String/GNU C++ gates.
UP, strict RV32IMAC two-hart and SecureSBI cases must be retained before calling
this checkpoint stable. Verification evidence records only completed gates.

## Unsupported Boundaries

The original public Syllable semaphore header is pinned unchanged with its
LGPL-2.0-only notices. Independently written runtime adapters are BSD-2-Clause;
the native XNU implementation is APSL 2.0. Full COPYING.LIB and exact upstream
copies/hashes remain available for corresponding-source obligations.

SEM_RECURSIVE, warning policies, RW locks, sleep_on_sem/wakeup_sem,
unlock_and_suspend, semaphore enumeration and lock-owner/locked-state policy
queries return ENOTSUP. These are explicit failures, never success stubs.
The original Locker still needs its own audited source patch and native
thread/TLS contract. AppServer, Desktop, Dock and FileBrowser remain incomplete.
This update does not publish binary assets or change the Tranche 201 tag.
