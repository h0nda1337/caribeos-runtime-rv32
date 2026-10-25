# Original Typed GUI Values Checkpoint

The actual guest runs were performed on 2026-10-15 and revalidated against
the current local artifacts on 2026-10-25. Revalidation is not a new boot.
Five required profiles passed: progressive A/B with bounded older gates,
then full A-C on OpenSBI UP, OpenSBI SMP and SecureSBI SMP. All used QEMU
virt RV32, 256 MiB and RV32IMAC without F/D/H/Zfa. An additional progressive
C boot also passed locally; it is not counted in the five retained cases.

The original Variant class has its real 16-byte RV32 ABI, 19 tested type
families, 76 unaligned exact roundtrips and legacy INT8/INT16 wire sizes.
The data path uses the original Message typed methods and real native
Looper/Messenger transport. A fork/exec service performs 10000 typed
request/replies, and 16 native workers perform 160000 typed value cycles.
Every full case also passes the older dispatch/heap/thread/sync/font,
native IPC/shared-area and graphics/input/restart gates, then Bash exit(0).
These scanouts show the existing decorator component, not a new full GUI.

Guarded decoder tests execute all 253 truncated golden prefixes, 4096
deterministic mutations, one combined nesting budget of 16 and five actual
array-allocation failures. Non-null local pointer values are not accepted
as serialized Variant addresses. Failure keeps prior Variant/Message state.
The test-only allocation wrapper is not installed in production libraries.

The actual forced rebuild recompiles variant.cpp, message.cpp and the new
probe, relinks the ELF and regenerates the initrd. All seven experimental
artifact hashes remain identical. The 38 v0.15 stable and 20 v0.16 dispatch
artifact records remain unchanged, including XNU and all older images.
No kernel rebuild, long kernel/process suite rerun, technical tag movement,
stable-default promotion or new binary Release is claimed.

The host suite passed 298 tests and three PowerShell binding/logging/disk
ownership guards. These are host checks, not substitutes for the guest runs.
See manifest.json for current hashes, raw UART hashes and case directories.

## Failed Attempts And Limits

The initial B probe tried PROT_NONE through the limited allocator VM
channel. That channel correctly returned ENOTSUP. The probe was fixed to
prepare its guard through the existing Linux controller syscall, with zero
live workers. Kernel/allocator permissions were not relaxed. Its original
failed UART excerpt and complete-local-log hash are retained.

The first rebuild check found byte-identical files but the idempotent
preparer had not caused recompilation of every new object. The collector
rejected that attempt because compile commands were missing. The rebuild
now forces the output prerequisite and both the script and collector check
actual compile/image commands, including Windows separator normalization.
The retained successful rebuild is from the corrected path.

The old intermittent Thread B counter assertion remains an unresolved
stability risk documented in v0.16, even though these full runs passed.
Broader GNU threading, shared stdio, node monitoring and lifecycle/error
contracts remain unfinished. Application/Window/View runtime, the genuine
AppServer, Desktop, Dock and FileBrowser are not completed by this gate.

## Next Client Frontier

A separate compilation-only audit verifies original source Git blobs and
headers, and compiles complete original Invoker, Window, View and Control
translation units into RV32 soft-float objects. They are not linked or run.
Application and Font still fail at obsolete platform include paths; the
audit reports INCOMPLETE and exits 1 rather than asserting GUI success.
See ../syllable-client-frontier-20261015/audit.json and the versioned client
auditor. No fake Application singleton or decorator Layer adapter is used.
