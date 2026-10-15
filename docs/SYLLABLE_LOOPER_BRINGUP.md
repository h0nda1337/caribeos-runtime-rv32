# Authentic event-dispatch compilation bring-up

This document records the published compilation-only checkpoint. The separate
[experimental runtime](SYLLABLE_NATIVE_LOOPER.md) now has initial A-C guest
checks; those do not retroactively change this checkpoint or complete the desktop.

This prepares and actually compiles the complete original Handler,
MessageFilter and Looper units for RV32IMAC with genuine musl/GNU headers.
It does not yet link or execute Looper, implement an AppServer or complete
the desktop. The verified optional runtime remains the v0.15 heap profile.

Ten immutable original source/header inputs are pinned to Syllable commit
579e480a005321cc320e7e355e8dff398b689be8. All original notices and public
Handler/MessageFilter/Looper headers stay intact. The complete original
event loop, handlers, filters, maps and timer algorithm remain present.
No replacement Handler, Looper or successful backend stub is introduced.

The LGPL Handler patch removes obsolete kernel.h, declares the pending native
diagnostic interface and makes token allocation atomic. The LGPL platform
patch uses existing native thread/atomic declarations and genuine musl
filesystem type headers. The historical syllable/messages.h location aliases
the byte-identical original atheos/messages.h. Filesystem declarations do not
provide a filesystem/node-monitor backend or prove its wire ABI.

```powershell
python scripts/audit-syllable-looper-compile.py --native-looper --retain-evidence
```

The auditor explicitly selects the workspace MSYS bash and RISC-V G++, avoiding
WindowsApps/WSL alias resolution. No host compiler or fallback class is used.
Original-only audit modes still expose the missing historical platform headers.

All three native compilation attempts succeeded on 2026-10-14 with ELF32,
little-endian RISC-V outputs. A second actual compilation produced identical
object hashes. [Retained inputs, logs and compiler receipt](evidence/syllable-looper-compilation/compile-audit.json)
record linked=false, runtimeVerified=false and nodeMonitorImplemented=false.
[Unresolved symbols](evidence/syllable-looper-compilation/unresolved-symbols.txt)
are a standalone-unit inventory, not evidence that those backends are implemented.

Before any runtime gate, integrate real diagnostics/rename and library links,
adapt timer wakeup to native port/thread semantics, bound decoding by received
payload length, review self-deletion/handler/filter/message lifetime and SafeLock
timeout behavior, and preserve process-wide signal ownership. Worker GNU
exception/TLS and stdio remain separate unfinished contracts. No running-loop,
node-monitor, GUI, AppServer or desktop completion is claimed here.

The eight host input guards check source tampering, notices, atomic patching,
compiler selection and refusal to retain failed compilation as success. They
are not guest runtime proof. Both patches and all prepared upstream sources
retain LGPL-2.0-only; the preparation/audit/host tools alone are original BSD.
