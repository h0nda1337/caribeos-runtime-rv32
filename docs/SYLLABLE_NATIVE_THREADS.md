# Native Shared-Task Threads v0.9

This checkpoint removes the single-main-thread restriction for a **raw RV32
user-entry profile**. It does not claim pthread, threaded musl, GNU per-thread
TLS, Syllable Looper, a complete AppServer, Desktop or Dock. No Wayland or X11
is part of this native dependency graph. The full Syllable goal remains open.

## Actual Kernel Path

`CARIBE_THREAD_CREATE` calls XNU `thread_create` on the existing owning task.
The new thread shares that task's map/pmap, not a forked process or copied
address space. It has its own XNU thread, saved registers, kernel stack,
user stack, raw `tp`, current-thread identity, wait state and termination.
It is bound to the boot processor. Entry checks the actual active pmap and
CPU before `sret` enters U-mode. `gp` is inherited from the caller's current
user trap, not a stale initial bootstrap register.

Creation is suspended until START. Sixteen generation-tagged slots exist
globally. Positive IDs occupy a separate namespace from Linux PIDs. Owner
checks prevent a different process from starting, cancelling or joining a
thread. Entry requires an executable Sv32 U page; the entire aligned stack
must be writable user memory. Overlapping worker stacks, the main stack and
reuse of the main or another worker's `tp` are rejected. Output validation
precedes allocation; a failed final copyout cancels and reaps the allocation.

EXIT publishes a status and wakes joiners, then performs actual XNU thread
termination. JOIN does not return merely because a userspace flag changed:
it drops the creator reference and waits for the generic thread reaper's
final deallocation notification. The slot and a retained process reference
stay alive through that notification. Process teardown cancels/reaps every
remaining raw thread before closing shared descriptors or releasing VM.

Native counting-semaphore waits use the worker's XNU wait state without
transitioning the main thread's Linux process state. The recorded holder is
the actual generation-tagged worker identity. User timer preemption is enabled
only while the opted-in profile has threads. A worker that never calls the
kernel can therefore be cancelled. A raw-worker user fault terminates that
thread with the fault status instead of fabricating a main-thread signal
frame. Existing whole-process STOP/CONT is respected at worker return
boundaries, but independently delivered thread signals are not implemented.

## Gates

- A: suspended creation, real shared-task U entry, separate stack/TP,
  10,000 shared increments, SELF/CPU identity, join and actual reaper completion;
  malformed, non-executable and read-only output requests have no allocation.
- B: sixteen suspended slots, capacity/overlap rejection, sixteen pre-entry
  cancellations, 256 genuine execution/join/reaper cycles and stale-ID rejection.
- C: 10,000 same-pmap semaphore ping-pongs, exactly 20,000 acquisitions and
  releases, real scheduler waits, correct shared data and distinct holder TID.
- D: noncooperative worker and main-thread timer scheduling, cancellation of
  busy/blocked/suspended workers, illegal-instruction isolation and sixteen
  owner-exit cycles. All 35 allocations in this gate must be finally reaped;
  34 genuine cancellations and one actual user fault are checked separately.
  Sixty-four foreign-process START/CANCEL/INFO/JOIN requests are denied;
  the owning child's running/suspended threads remain intact until its exit.
- Off: without the `native-threads` boot option, CREATE returns ENOTSUP and
  neither the allocation nor live-thread counter changes.

The complete enabled profile creates/reaps 309 actual XNU threads per run.
UP and two-hart OpenSBI, plus two-hart SecureSBI, must retain separate strict
RV32IMACSU logs. Existing GNU/String/Message/native IPC/areas/semaphore,
FreeType/scanout/input/private-VM/Bash and SMP F gates remain selected in the
full matrix. A source/artifact change invalidates older retained results.

## Safe Profile Limits

`CARIBE_THREAD_CALL` is a versioned 128-byte ioctl on `/dev/caribe-ipc`.
Raw workers also use dedicated native ECALLs for thread and semaphore requests;
they do not borrow a descriptor-table access path or libc's `errno`.
Worker Linux syscalls return ENOTSUP, except ordinary thread EXIT.
The raw callback must explicitly invoke EXIT; returning through its unset
return address faults, rather than pretending an exit trampoline is present.
Main fork/exec and VM mutations, including area operations, return EBUSY until
every raw-thread record is joined/reaped. Normal single-main-thread Linux
fork/exec and CPU1 process stress retain their previous paths.

The test workers intentionally call no libc, pthread, libstdc++ or GNU emutls.
Their `tp` is a private raw marker, **not a musl TCB or demonstrated C++ TLS**.
Stacks/markers are user-owned and released after confirmed reaping. No
success-returning Syllable spawn_thread or pthread stub is provided.
Threaded allocation, real libc TCB/TLS setup, GNU gthread/emutls/destructors,
per-thread signal state and less restrictive VM/lifecycle integration remain
required before native Handler/Looper and the full AppServer can be enabled.

## Verified Results

The retained 2026-10-13 matrix passes strict RV32IMACSU runs with OpenSBI
UP, OpenSBI two-hart SMP and SecureSBI two-hart SMP. Each enabled run passes
raw-thread gates A-D, all selected dependency gates, Bash exit(0), and SMP F
when two processors are present. A separate default-off run rejects creation
without allocating a thread. The ordinary `testproject.ps1` entry point also
passes the two-hart enabled profile.

The existing process suite passes all 15 gates with the same kernel. Forced
compilation of eight changed kernel translation units and the user probe
reproduces eleven selected artifacts byte-for-byte. Sixty-two host-only tests
pass; two PowerShell guards separately validate logged build failure handling
and the kernel build's positional/forced-source parameter binding.

Kernel SHA-256:
`dbd1278f738ce02391f43834d516b911de2d2df7af77b8a8b55beb11a6d5598f`.
The complete artifact hashes, gate logs, scanouts and scope limitations are
retained in [the evidence manifest](evidence/syllable-threads-v0.9/manifest.json).
Host tests are not substituted for actual guest execution or libc threading.

## Run and Recover

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeThreads -NativeSync -SyllableMessage -FreeType
.\testproject.ps1 -Mode graphics -Smp 1 -NativeThreads -ThreadGate A
.\testproject.ps1 -Mode graphics -Smp 1 -DisableNativeThreads
```

The normal runner omits `native-threads`; this remains the conservative
default. The mandatory firmware -> CBX ELF -> HFS+ -> XNU chain is unchanged.
The immutable technical `tranche-201-stage2-complete` tag is not moved.
Prior verified font/sync binary snapshots remain in ignored build storage.
Runtime interface/probe/tooling originals retain BSD-2-Clause; XNU additions
and modifications retain APSL-2.0 and their modification notices. No external
Syllable, musl, GNU, FreeType or font source is relicensed by this checkpoint.
