# Private Futex Dependency v0.10

[Actual verification record](evidence/syllable-futex-v0.10/VERIFICATION.md)
retains the final strict-ISA matrix, repeated SMP, regression and rebuild proof.

This is an independently opted-in, native XNU private WAIT/WAKE backend for
the Linux syscall ABI. It is not Linux clone/pthread support, threaded musl,
GNU per-thread TLS, Handler/Looper or the complete Syllable AppServer.
No Wayland, X11 or Linux kernel is introduced.

## Contract

The `native-futex` boot argument enables only `FUTEX_WAIT|FUTEX_PRIVATE_FLAG`
and `FUTEX_WAKE|FUTEX_PRIVATE_FLAG`. The conservative default keeps the
previous main-thread syscall path and denies worker futex calls with ENOTSUP.
Shared, PI, requeue, bitset and other operations return ENOSYS in the new
profile rather than silently pretending private semantics.

Waiters are keyed by the actual process pmap and aligned user virtual word.
The Sv32 U/read permission is validated before obtaining a physical kernel
alias. An aligned RV32A atomic load, expected-value comparison, waiter
publication and XNU `assert_wait_deadline` take the same lock as WAKE. The
wait is armed before releasing that lock, including the wake-before-block
case. A private queue contains at most 64 waiters; allocation pressure returns
EAGAIN. WAKE marks no more than the requested number and returns that count.
Different virtual addresses and different pmaps do not share the private key.

Both syscall 98 (time32) and 422 (time64, used by this RV32 musl) accept
relative WAIT timeouts. Negative/invalid times, unmapped pointers and
unaligned words are rejected. Long valid intervals saturate without wrapping
into the past. XNU timer deadlines implement actual sleeping; periodic
20 ms scheduler deadlines also check main-thread signals and cancellation,
without spinning in userspace or changing the whole Linux process state.

The serialization reference is the upstream Linux
[wait/wake ordering description](https://github.com/torvalds/linux/blob/v6.12/kernel/futex/waitwake.c)
and [UAPI definitions](https://github.com/torvalds/linux/blob/v6.12/include/uapi/linux/futex.h).
This independent backend uses XNU wait queues, not copied Linux kernel code.
Its bounded-count contract explicitly treats WAKE(0) as no wake. Unsupported
operations remain explicit; this is not the entire futex ABI.

RV32's underlying simple locks provide atomic ownership but do not disable
same-hart kernel preemption. The futex, raw-thread registry and native counting
semaphore queue wrappers explicitly suppress preemption before acquiring and
restore it after releasing. Raw-thread process-count updates do the same.
One-time queue initialization likewise cannot preempt its initializing owner
before publication; other harts observe its atomic initialized state.
Sleeping always happens after releasing these locks. This closes a same-hart
lock-owner preemption window; it alone did not resolve the full SMP regression.
The failure's independently captured CPU registers identified CPU0 waiting on
the reaper's thread interlock and CPU1's reaper repeatedly selecting from a
shared runqueue whose runnable threads were bound only to CPU0.

RV32 proto scheduler queue-empty, priority, preemption and count queries now
measure work eligible for the queried CPU under the shared-runqueue lock.
`choose_thread` already honored binding; its urgency accounting is balanced
when dequeuing. The other architectures retain their original paths. The
raw-thread user boundary also services normal AST preemption while preserving
its real trap frame, rather than relying on fake urgency or the unimplemented
generic user continuation. Diagnostic logging alone is not treated as a fix.

The baseline process regression also caught interleaved Gate 14 UART records:
the CPU1 process completed but the strict runner could not validate a pmap
switch line interrupted by CPU0 output. Those records now use the existing
bounded stack-buffer plus one atomic early-console write pattern. No marker
or CPU/pmap assertion is weakened; ordinary users remain CPU0-bound.

Cancellation returns through the real blocked thread, which removes its queue
record before the existing user boundary terminates it. Owner teardown joins
the generic XNU reaper before VM/FD disposal and asserts that no futex waiter
still references the departing pmap. Worker FD, VM and signal operations
remain prohibited. Main VM mutations remain EBUSY while raw threads exist.

## Gates

- A: ABI errors, mismatch EAGAIN, real relative time32/time64 timeouts,
  unsupported shared/bitset operations and huge valid timeout without wrap.
- B: 10,000 scheduler waiters actually woken, exactly 10,000 acknowledgements,
  no lost events and an empty queue after JOIN/reaper.
- C: sixteen simultaneous workers; WAKE(0), WAKE(1), remaining fifteen;
  distinct address isolation and no unintended extra acknowledgement.
- D: 64 blocked cancellations and eight real child-owner exits. Parent WAKE
  cannot reach a child at the same virtual address in a different pmap.
  All 89 created threads must be exited, finally reaped and absent from the
  thread registry. Kernel teardown asserts zero stale owner queue records.
- Off: a real raw worker gets ENOTSUP without `native-futex`; its one thread
  is joined/reaped. This does not fake main-thread futex functionality.

The workers call no libc/C++ routines and retain raw TP markers, not musl
TCBs. Independent real TCB/TLS, clear-tid/list-lock, signal state, allocator
and lifecycle gates are still needed before pthread or original Looper.

## Commands

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -NativeFutex -NativeSync -FreeType -SyllableMessage
.\testproject.ps1 -Mode graphics -Smp 2 -NativeFutex -NativeSync -FreeType -SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'
.\testproject.ps1 -Mode graphics -Smp 1 -NativeFutex -ThreadGate A -FutexGate A
.\testproject.ps1 -Mode graphics -Smp 1 -DisableNativeFutex
.\scripts\test-native-futex-matrix.ps1
```

The futex image is separate (`build/initrd-futex.img`). The earlier thread,
font and base initrds are not replaced. Each progressive gate/profile has
independent logs and artifact hashes. A strict RV32IMACSU matrix uses
`scripts/qemu-rv32-graphics.ps1 -Cpu 'rv32,f=false,d=false,h=false,zfa=false'`.
The normal testproject command uses QEMU's default CPU; the explicit `-Cpu`
option forwards the strict profile for graphics modes. Default-CPU success
is not relabeled as strict-ISA evidence.

The graphics runner holds an exclusive named HFS build/run lock and also
rejects an already-running QEMU using hfsplus.img. It does not stop someone
else's VM. The lock rejection test launches neither a build nor another VM.

The versioned matrix runner executes UP, three independent full SMP boots,
SecureSBI SMP and default-off in sequence. It then forces eleven kernel units
and thirteen artifacts through a byte-identical rebuild, runs the fifteen
baseline process targets and host guards, and invokes the evidence collector.
Any failure stops promotion. The protected v0.9 snapshot is not overwritten.

The probe and runner/host guards are original CaribeOS BSD-2-Clause code.
The kernel backend remains APSL-2.0. No external musl, GNU, Syllable or font
source or license is changed. Existing stable snapshots and the protected
technical tag remain intact; no new binary Release is published.
