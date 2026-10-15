# Original Toolkit Dispatch Development Checkpoint

Verified on 2026-10-15 on QEMU virt RV32, 256 MiB, RV32IMAC without
F/D/H/Zfa. Six complete current-hash profiles passed: original Looper
and original Messenger, each on OpenSBI UP, OpenSBI SMP and SecureSBI SMP.
Every profile includes the full older native IPC/area/String/Message,
thread/futex/TCB/Locker/Thread/Queue/heap/sync/font dependencies, actual
graphics/input/restart checks and a return to Bash followed by exit(0).

The [manifest](manifest.json) records exact artifacts, original source
records and complete-local-UART hashes. Individual gate logs, actual
component scanouts and selected unmodified UART lines are retained by
profile. These images show the existing decorator component, not a full
AppServer or desktop. No kernel build, kernel architecture change, firmware
modification, technical tag move or new binary Release occurred here.

The new genuine native-TLS GNU exception units and original toolkit runtime
were actually recompiled: 20 experimental artifacts were byte-identical.
All 38 v0.15 stable artifacts, including the kernel, default libraries,
older probes and initrd variants, remain byte-identical. The unchanged
long kernel/process suites were not reexecuted; their prior evidence is
not represented as a fresh run. The stable default profile remains v0.15.

The combined suite passed 280 host tests and the three existing PowerShell
argument/logging/disk-ownership guards. Host fixtures are not guest proof.
Some negative host fixtures intentionally emit failed-patch diagnostics;
the actual suite exits successfully. GNU source compilation under Clang
emits compatibility warnings, not errors or substitute implementations.

## Real New Behavior

Original Looper A-C verifies independent genuine GNU exception TLS,
160000 throws/destructors, one shared static initialization, 160000 typed
Handler dispatches, live timers, bounded malformed-input rejection,
common/local filters and real lifecycle cleanup.

Original Messenger A-C verifies 10000 synchronous requests, 10000 async
Handler replies, 64 reply-to-reply handshakes, temporary-port exhaustion,
real send/reply timeouts and failure-state cleanup. A separate fork/exec
process runs an original Looper service for 10000 cross-address-space
request/replies. Its remote worker is denied receive access to the client's
private reply port; it exits and is reaped with status 0. Userspace workers
remain on CPU 0, including in two-hart boots.

## Failed Attempts And Remaining Risk

The retained failed attempts are part of this checkpoint, not discarded
green-only history. The initial Looper C SIGSEGV exposed an inverted
upstream common-filter removal condition. It was fixed and the real
filter/timer/recursive-termination gates strengthened and passed.

Two Messenger C attempts timed out at sequence 0 because the dependency
test omitted original SetDefaultHandler registration. Instrumentation
proved the real Looper started; its default routing correctly went to
the Looper rather than the attached service. Correct registration and
actual Started readiness resolved this without increasing reply deadlines.

One full SMP attempt failed before Messenger in the old unchanged Thread B
timer/semaphore counter assertion. An unchanged repeat passed with 640
timer waits and 68312 semaphore scheduler waits; further complete UP/SMP/
SecureSBI runs passed. The intermittent counter failure is not fully
isolated. No assertion, threshold, old probe or kernel was changed to hide
it. This remains a stability issue and prevents production-readiness claims.

Complete GNU threading/shared stdio, Variant, broader target/lifecycle/error
contracts, Application, the actual AppServer and original Desktop/Dock/
FileBrowser remain unfinished. See the [authentic server boundary](../../SYLLABLE_APPSERVER_BOUNDARY.md).
The active complete-desktop goal is not achieved by this checkpoint.
