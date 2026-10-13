# Native Synchronization Evidence

Recorded 2026-10-13. Native XNU counting semaphores pass gates A-E on OpenSBI
UP, strict RV32IMAC OpenSBI SMP2 and strict RV32IMAC SecureSBI SMP2. Each case
also passes genuine Syllable Message/String/GNU C++/musl, native IPC/areas,
private VM, real graphics/input/restart and Bash exit zero. Two-hart cases
require kernel SMP F; these user applications remain CPU0-affine.

The profile is not native shared-task user threading, a complete libsyllable
library or Syllable Desktop. AppServer, Desktop, Dock, FileBrowser and the
GNU per-thread TLS boundary remain unfinished. No Wayland/X11 or Linux kernel
is introduced. Six real QMP scanouts per case show the existing decorator and
shared-buffer tests, not a complete desktop.

Counting tests verify capacity 64, 256 recycle cycles, generation IDs,
multi-unit operations, argument/overflow checks, copyout rollback, local/global
permissions and owner-only deletion. Sixteen exec cycles clean owned objects
while failed exec preserves them. Independently exec'd peers complete 10,000
ordered shared-memory exchanges, with exactly 20,000 acquisitions and 20,000
releases and actual scheduler waits. Sixteen blocked deletions with slot reuse
return EIDRM without consuming new-generation credits. Sixteen owner exit/exec
operations wake blocked waiters. Signal interruption preserves semaphore count.

The first owner-wait test correctly failed: musl's clock_nanosleep route still
returned success without sleeping. That old stub is now replaced by a real
XNU deadline wait, not a timing workaround. Guest measurements verify time64
and legacy 32-bit relative/monotonic-absolute sleeps. Three interrupted sleeps
verify remaining time and absolute remaining-buffer preservation, including
SA_RESTART. Missing RTC/process-time/suspend sleep policies are rejected.
See the documented clock scope in SYLLABLE_NATIVE_SYNC.md.

All 15 actual process-regression targets complete with explicit OK markers and
exit code zero. Forced native_sync/linux_exec/linux_syscall and runtime adapter/
probe recompilation, relink and image regeneration reproduce all nine recorded
artifacts byte for byte. The ordinary image and GNU/Message/String libraries
remain byte-identical to the preceding checkpoint. Kernel changes are intentional:
native synchronization, lifecycle cleanup and the real clock-wait correction.

Kernel SHA-256:
`8af38adb36da0b1a5d600037362fdb8363bbbf10c323de692f25a6559b9ecdbd`.
Synchronization probe SHA-256:
`c0488d00ef21907374a98b35255c48d77678462d9daf839228aa2bc58aa9c9cc`.
Native adapter archive SHA-256:
`3c2247c9e71adbb4345d869f571987371d4a908a308873f181ecb8318e06bf6d`.
Selected image SHA-256:
`51cd25afc115c8fcab6eaafe52da259c9aaa93413b1c8cd7b5cb16d6c8d46934`.

Ten host-only source guards verify pins/license retention/unchanged regeneration.
Six host-only runner guards verify early rejection and failure handling, including
the new ABI equality check and immediate guest failure detection. These are not
kernel simulations. Four additional host-only collector guards verify stale
artifacts, missing process completion and nonidentical rebuilds cannot replace
the prior snapshot, and consistent fixture inputs can be retained. The evidence
collector refuses stale/current-artifact
mismatches, incomplete dependency gates, changed scanouts and incomplete process/
rebuild results before modifying the retained snapshot.

The final exact `testproject.ps1 -Mode graphics -Smp 2 -NativeSync -SyllableMessage`
runner also passes after refreshing the kernel; final-runner-result.json records
the fourth run. Its kernel and selected-image hashes match the strict matrix.

Original semaphore headers retain Kurt Skauen's LGPL-2.0-only notices. New
runtime wrappers/ABIs/tests are original BSD-2-Clause; the XNU backend remains
APSL 2.0. No ELF/archive/disk/private key or new binary Release is published,
and the technical Tranche 201 tag remains untouched.
