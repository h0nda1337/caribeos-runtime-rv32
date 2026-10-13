# Private Futex v0.10 Verification

Recorded 2026-10-13 on the F: workspace, using actual QEMU and GNU RV32
compilations. This checkpoint is a dependency for authentic Syllable, not
AppServer/Desktop completion, pthread compatibility or threaded GNU TLS.

## Actual Results

- Strict RV32IMACSU OpenSBI UP: all private futex A-D and dependency gates PASS.
- Strict OpenSBI SMP2: three independent full boots PASS, retained separately.
- Strict SecureSBI SMP2: all gates PASS, including privileged signing denial.
- Default-off UP: a real worker receives ENOTSUP, exits and is finally reaped.
- Each enabled futex run: 10,000 actual wakes and acknowledgements, sixteen
  simultaneous waiters with zero/one/fifteen bounded wakes, 64 blocked
  cancellations, eight owner exits and exactly 89 created/exited/reaped threads.
- Raw-thread A-D, native semaphore A-E, genuine String/Message data cores,
  IPC/areas/GNU C++/FreeType dependencies, real scanout/input and Bash exit(0)
  remain verified in each full profile. SMP runs also retain real kernel F.
- Eleven kernel C units forcibly compiled, kernel relinked and both thread
  probes/initrds forcibly rebuilt: thirteen artifacts byte-identical.
- Fifteen baseline process runner targets PASS with unchanged kernel hash.
  The old explicit CPU1 process Gate 14 remains an isolated test exception;
  Bash and the new raw workers remain CPU0-bound.
- 85 actual host unittest guards PASS; these are not guest execution proof.
- Three PowerShell guards PASS, including actual second-runner disk-lock
  rejection without a build, HFS write or second QEMU.

Kernel SHA-256:
`f71b4c1ce917e110a10aa5324f3addab099e3ce63481f87eaa44d2a819da7476`.
Private initrd SHA-256:
`ad7b0bec7bf4c761c9ce803a943bbd2a5a5a447eb97e8327abd0b523767e93be`.
Futex probe SHA-256:
`a79bd9ff5c9646e6f1eb3dbe84976b3f26880262d1027a75c6c1f56d5e00d7c2`.

The manifest binds every retained run to its artifacts and full local serial
hash. The collector checks completion, counters, final reap, dependency gates,
scanouts, actual forced compilation and process regression before modifying
retained evidence or copying the ignored stable binary snapshot.

## Regressions Found And Fixed

The sixteen-waiter full SMP profile exposed a real scheduler livelock: CPU0
waited on the reaper interlock while CPU1's reaper retried a shared runqueue
containing only CPU0-bound work. Independent per-CPU QMP register snapshots
identified both paths. RV32 proto queue queries now honor binding; dequeue
urgency is balanced. Normal raw-user AST preemption preserves the trap frame.
Native queue ownership and one-time initialization also suppress same-hart
preemption. The global lock implementation and other architectures are intact.

The subsequent baseline Gate 14 caught interleaved UART records. The CPU1
child succeeded, but its pmap-switch record was split by CPU0 logging and the
strict runner correctly rejected it. Those records now follow the existing
bounded-buffer/single-atomic-console-write pattern. Assertions and required
markers were not relaxed. Gate 14 and the entire fifteen-target suite passed
again before the new kernel was promoted.

## Boundaries

Only private WAIT/WAKE is implemented. Shared, PI, bitset and requeue operations
remain explicit ENOSYS. No Linux kernel futex source is incorporated. Real
musl TCB/TLS, clear-tid/list-lock, allocator/signal/lifecycle integration and
original Locker/Handler/Looper/AppServer/Desktop remain subsequent work.
No Wayland/X11, full pthread claim, fake Looper or alternate boot chain exists.

The runtime additions are original BSD-2-Clause code; native XNU changes remain
APSL-2.0. External sources/notices and the protected technical tag are unchanged.
No new binary Release, LFS upload or paid service is enabled.
