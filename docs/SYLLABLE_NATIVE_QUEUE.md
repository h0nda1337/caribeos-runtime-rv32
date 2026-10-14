# Original MessageQueue and native worker ports

This is a prerequisite for the authentic Syllable Looper/AppServer route,
not a replacement event loop or a claim that the desktop already runs.
The original MessageQueue source and unmodified public header come from
Syllable commit `579e480a005321cc320e7e355e8dff398b689be8`.
Normalized source hashes, the narrow LGPL patch and full COPYING.LIB are
retained by `scripts/prepare-syllable-queue.py` in build/syllable-queue.

## Runtime boundary

- Original intrusive FIFO/search/count/removal algorithms and genuine Locker.
- Correct previous-node tail on RemoveMessage, including the sole-node case;
  original RemoveMessage still deletes the removed object. Popped links detach.
- Controller preallocates typed original Message objects before worker start.
  Sixteen original Syllable Threads manipulate/read them under the real Locker.
- Native IPC ECALL `0x05000003` reaches the same bounded XNU port backend,
  ownership validation, copyin/out transactions and 128-byte ABI as the FD API.
- Native worker waits use real Mach scheduler deadlines without transitioning
  the Linux controller process to SLEEPING/RUNNABLE. Cancellation observes the
  worker's active state; generation checks reject deleted/replaced ports.
- IPC lock and one-time initialization disable local preemption. RV32A locks
  and sequence fences serialize the shared queues and prevent missed wakeups.
- The raw adapter uses the native monotonic clock, not worker Linux clock/FD
  syscalls. Ordinary worker `close` remains ENOTSUP. Userspace stays on CPU0.
- Queue library/initrd are separate from prior profiles; the normal FD adapter
  and all v0.13 userland artifacts must remain byte-identical.

## Actual progressive gates

A: 100 tail/sole-node removal and append cycles, FIFO/search/destruction and
native IPC malformed-pointer/version guards.

B: 16 original threads, 160,000 protected Queue/typed Message cycles, forced
yield while holding the genuine Locker, independent TCB/errno/native TLS,
zero overlapping owners, exact generic reaping and semaphore cleanup.

C: 10,000 original Message wire-byte exchanges and one 8 KiB exchange between
the controller and native worker. The worker peeks/receives/echoes bytes; only
the controller uses bounded Unflatten and typed validation. Also 64 real finite
port timeouts of at least 2 ms, 16 simultaneously blocked deleted-port waiters,
generation reuse without consuming replacement tokens, and 64 blocked reader/
writer cancellations. Exact totals: 161 created/exited/reaped, 64 cancellations,
zero live/fault deltas, unchanged queued token after writer cancellation,
balanced registered waits/wakeups and restored ports/messages/semaphores.

Run the optional profile through the public runner:

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -SyllableQueue -NativeSync -FreeType -Cpu rv32,f=false,d=false,h=false,zfa=false
```

`-QueueGate A/B/C` selects progressive Queue gates. Dependent Thread/Locker/TCB/
futex/raw-thread gates keep their independent selectors. Disabled dependencies
and non-graphics public modes reject before kernel/disk work.

The separate matrix and collector require actual current-hash UP/SMP/SecureSBI,
two extra SMP repeats, unchanged old-profile UP/SMP, default-off dependencies,
forced kernel/Queue/raw-and-default adapter rebuild, fresh 15-target process
regression and host guards before promotion. Old v0.13 evidence/snapshot are
not overwritten. Retained evidence paths are short for Windows Git.

## Remaining desktop work

No worker malloc/free, Message decode/allocation, stdio, pthread lifecycle or
threaded GNU exceptions are implemented by this gate. Genuine Handler/Looper,
worker-safe allocation, AppServer protocols, windows, Desktop, Dock and
FileBrowser remain required, without X11/Wayland dependencies. Existing
graphics frames are dependency tests, not the requested complete desktop.
