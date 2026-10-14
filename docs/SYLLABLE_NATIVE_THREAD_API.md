# Original Syllable Thread on native XNU

This opt-in v0.13 dependency profile builds the genuine LGPL Syllable
`os::Thread` implementation at commit `579e480a005321cc320e7e355e8dff398b689be8`.
It is not a replacement Thread class and does not mean that Looper, AppServer,
Desktop, Dock or FileBrowser already run. No X11/Wayland is introduced.

## Source and ownership

The preparer verifies the original cpp plus unchanged public Thread,
exceptions and time headers. Original author/license notices and COPYING.LIB
survive. `thread.cpp` has no file banner: corresponding `thread.h` explicitly
credits Henrik Isaksson (2002) and LGPL version 2. The component/header basis
is recorded in `build/syllable-thread/sources.json`. The narrow LGPL patch
preserves virtual Run/_Entry and connects lifecycle to native XNU operations.
Independent runtime adapters/probes remain BSD, not a relicensing of Syllable.

`Terminate()` cannot send Linux SIGKILL to a native thread ID: the namespaces
are different. It now cancels the actual XNU thread and waits for generic
reaping. `WaitFor()` invalidates its member ID only after successful native
join. Start, Stop, priority and info operations propagate actual failures;
unsupported operations never report success or return uninitialized info.

## Implemented boundary

- Controller-only creation/resume/join/cancel. All workers remain CPU0-bound.
  A worker cannot create/control workers or alter the Linux process model.
- Native workers have genuine musl __copy_tls TCBs, independent errno and
  native ELF TLS, sharing their owner's actual XNU task/pmap.
- Sixteen slots, each a 32-KiB stack plus 4-KiB TCB reserve. The bounded arena
  is mapped before workers start and released only after every generic reap.
  Requested stacks between 16 and 32 KiB use the reserved 32-KiB stack; zero
  selects that platform default. Other sizes/priorities are rejected.
- Original constructor, virtual Run, Start, WaitFor, Initialize, Terminate,
  GetThreadId/GetProcessId and protected Delay run against native operations.
  This is not a claim that the complete Syllable thread API is implemented.
- Native CLOCK returns monotonic nanoseconds in two output words. The existing
  128-byte wire ABI is unchanged; all reserved words still must be zero on
  input. Native SLEEP uses genuine Mach scheduler deadline waits for workers,
  at most 60 seconds per request. Main snooze still uses its normal nanosleep.
- A separate semaphore variant uses native time for finite positive waits.
  The v0.12 raw Locker archive and ordinary FD/ioctl archive stay separate.
- Normal worker Linux FD/VM/clock/signals remain denied. Suspend, priority
  changes and complete thread_info/name enumeration remain ENOTSUP.
- No worker allocator/stdio, pthread list, clear_tid, TSD, robust futex,
  pthread cancellation or threaded GNU runtime is enabled. GNU exceptions
  exercised here run only in the controller; worker Run never throws or
  allocates. The existing single-thread GNU configuration is not relabeled.

## Progressive gates

A verifies native suspended creation, no early entry, resume, full 32-bit
exit status, actual join/reaping and stale ID rejection; original C++ entry
and unsupported-error exceptions; native 64-bit clock bracketed by the main
Linux monotonic clock; malformed requests and main-only sleep rejection.

B uses sixteen original Thread instances with genuine Locker contention:
160,000 protected increments, 320,000 recursive acquisitions, zero overlaps,
independent TLS/errno and 640 sleeps whose measured elapsed times are at
least 50 microseconds. A positive real semaphore-wait count and at least
640 native timer thread_block calls are required, not just PASS strings.

C verifies 64 finite Locker timeouts with elapsed time at least 2,000
microseconds and real native timeout counters. It then uses original
Initialize/Terminate for 64 cancellations after each worker has registered
a native deadline wait (instrumented thread_block path). It requires exact
146 create/exit/reap, 64 cancel, zero fault/live/semaphore deltas and pool
release. These are native cancellations, not pthread cancellation semantics.

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -SyllableThread -NativeSync -FreeType -SyllableMessage -Cpu 'rv32,f=false,d=false,h=false,zfa=false'
```

`-SyllableThreadGate A`, `B` or `C` selects the last gate. Disabled thread/futex
dependencies and non-graphics modes fail before kernel build/HFS writes/QEMU.
The separate `initrd-threadapi.img` preserves the older dependency profiles.

`scripts/test-syllable-thread-matrix.ps1` runs progressive UP A/B, full UP,
three SMP runs, SecureSBI SMP, default-off thread/futex checks, forced
native_thread compilation/relink and original Thread/adapters/TLS/image
rebuild. Because the kernel changed, all 15 existing process runner targets
must run again for the exact new kernel hash; old regression is not reused.
`-ReuseVerifiedUpAndProgressive` first validates current-hash actual UP records.

The collector promotes only after every gate, artifact, source, rebuild and
fresh process check passes. v0.12 retained evidence/snapshots stay untouched.
Local binary snapshots are not new published binary Releases.

## Next integration barrier

The next optional [Queue profile](SYLLABLE_NATIVE_QUEUE.md) compiles genuine
MessageQueue and adds native port operations from workers, preserving this
checkpoint's artifacts. Genuine Handler/Looper, safe worker allocation/stdio
and the GNU thread runtime remain requirements before original AppServer/
Desktop integration; dependency gates do not shrink the desktop objective.
