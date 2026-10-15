# Experimental Original Looper Runtime

As of 2026-10-15, the complete original Syllable Looper, Handler and
MessageFilter units are linked and running in a separate opt-in RV32 image.
The stable default runtime remains v0.15. This source-only development
checkpoint is not a complete AppServer, Desktop, Dock or FileBrowser.
Full Looper and separate Messenger dependency profiles have passed OpenSBI UP,
OpenSBI SMP and SecureSBI SMP with current hashes. See the
[six-profile evidence](evidence/syllable-dispatch-v0.16/manifest.json).

The unchanged upstream inputs and compilation-only checkpoint are documented
in [source bring-up](SYLLABLE_LOOPER_BRINGUP.md). A separate LGPL-2.0-only
runtime patch preserves the original loop and public interfaces. It adapts
bounded native receives, live timer wakeups, filter dispatch and lifecycle
cleanup. Native filesystem node monitoring is explicitly unsupported.

## Actual Guest Checks

Gate A exercises genuine GNU exception globals in native ELF TLS, with 16
original Syllable Thread workers, 160000 actual throws and unwind destructors,
one shared static initialization and independent exception contexts.
Gate B runs 16 original Loopers and 160000 targeted typed messages through
actual Handler dispatch, followed by graceful native joining and detachment
of externally owned handlers.
Gate C runs 64 live timer/lifecycle iterations: sub-250ms timer wakeups,
64 malformed inputs and 64 unsupported node messages rejected, 64 common
and 64 local filter discards, removal of pending timers with their handlers,
recursive-lock termination and 128 filter destructions. Across A-C, 96 native
threads are created, exited and reaped, with zero faults, cancellations,
active heap scopes or remaining waiters.

The strengthened A-C profile passed both OpenSBI UP and two-hart boots on
2026-10-15 using RV32IMAC without F/D/H/Zfa. Bash returned and exited with
status 0. The existing graphics/input checks also passed. Workers remain
affine to CPU 0; two harts do not imply GUI workers migrate between CPUs.
These runs select gate A of the older worker dependencies. They are not a
substitute for the complete dependency/regression/SecureSBI promotion matrix.
The 264 host tests passed separately; host fixtures are not guest evidence.

The initial C attempt terminated with SIGSEGV after A and B. The original
RemoveCommonFilter global/local condition was inverted, causing the new
cleanup path to leave a freed filter in its list. Its failed transcript is
preserved locally in build/looper-c-initial-failure-20261015. The corrected
run explicitly exercises real common/local discards and removal, not just
filter construction. The runner now fails immediately on a nonzero terminal
SYLLABLE_LOOPER_STATUS instead of waiting for its 900-second timeout.

## GNU Runtime Boundaries

The default GNU archive and default musl are unchanged. The optional image
uses unmodified GNU 15.1.0 eh_globals.cc/eh_alloc.cc, compiled for native ELF
TLS with Clang, plus genuine GNU unwinding and guard algorithms. A native
recursive futex adapter serializes GNU FDE lookup and static guard calls,
with allocator critical scopes around shared state. The supported zero
emergency-pool configuration avoids the default single-thread exception pool.
The probe's exact PT_TLS is filesz=0, memsz=8, align=4; emulated TLS globals
are rejected. Complete GPL/Runtime Library Exception notices are preserved.

This does not implement std::thread, pthreads, generic GNU emulated TLS,
shared exception_ptr/reference-count contracts, general shared stdio or
complete GNU threading. Recursive static-initialization errors, OOM paths,
self-Quit/OkToQuit reentrancy and cross-worker lifecycle control still need
dedicated audit and guest gates. Diagnostic formatting uses a bounded memory
buffer; only the controller flushes it to a Linux file descriptor.

## Reproduction

The public runner supports a separate -SyllableLooper switch. For the bounded
profile verified here:

```powershell
.\testproject.ps1 -Mode graphics -Smp 2 -SyllableLooper -LooperGate C -HeapGate A -QueueGate A -SyllableThreadGate A -LockerGate A -TcbGate A -FutexGate A -ThreadGate A -Cpu rv32,f=false,d=false,h=false,zfa=false
```

Individual gate logs, result.json, UART and actual component scanouts remain
under build/graphics-tests/*-looper-c-syllable-message. The scans are of the
existing decorator component, not the full desktop. The separate
scripts/test-syllable-looper-rebuild.ps1 forces new GNU/runtime units and
compares their hashes while checking all 38 v0.15 artifacts remain unchanged.
It does not rerun or claim the full promotion matrix.

The actual forced rebuild passed on 2026-10-15: 13 experimental artifacts
were byte-identical and all 38 stable artifacts were preserved. Original
GNU context compilation emits compatibility warnings for unsupported GCC
attributes under Clang; neither unit failed. Full static/license/SPDX/NOTICE
and THIRD_PARTY validation including the new working-tree files passed,
39 PowerShell files parsed, and a Gitleaks scan of changed/new text reported
zero findings. The later combined Looper/Messenger forced rebuild has 20
byte-identical artifacts and preserves the same 38 stable artifacts.
The full combined host suite has 280 passing tests, with three PowerShell
guards. These checks do not promote a production runtime or complete the
desktop; the intermittent old Thread B assertion remains documented.
No new binary Release is produced by this source-only development checkpoint.
