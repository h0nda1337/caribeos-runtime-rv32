# Original GUI Typed Values

The opt-in Variant profile builds the complete original `os::Variant` class
and enables the original `Message::AddVariant` / `FindVariant` interface.
Inputs are pinned at Syllable revision
`579e480a005321cc320e7e355e8dff398b689be8`, with their original LGPL notices.
These are actual dependencies of original `gui/control.cpp`: its private
state contains a Variant, and Invoke adds that value to its Message. Button,
CheckBox and color-selection controls also use this interface. Implementing
the data dependency does not implement those controls or their View backend.

## Integration

`build/libcaribe-syllable-variant.a` contains a separately adapted Variant
and Message provider. Its include path and link order are opt-in; the older
Message-core and Messenger binaries/images remain separate. The existing
genuine Looper/Messenger, GNU native exception contexts, musl allocator and
native thread backends are reused, not replaced with a new toolkit.

Original public method signatures and the RV32 16-byte Variant class layout
are retained. The derived LGPL patch repairs unaligned header access,
missing RAW/Message length prefixes, the success return status, self/alias
assignment and allocation/decoding lifetime failures. It preserves the
legacy four-byte payload for INT8/INT16 and their signed ranges. Local
non-null pointer Variants still work, but serializing a non-null pointer
returns ENOTSUP rather than exposing a meaningless address to another task.

The transport is bounded to 8192 bytes and one combined Message/Variant
nesting budget of 16, including the enclosing Message on typed insertion.
Malformed encodings are rejected before mutating the destination. A failed
allocation preserves the previous Variant or Message. This does not claim
that every original numeric conversion/comparison has been modernized.

## Execution Gates

- A: 19 type families, explicit ABI/size/selected byte goldens, four buffer
  alignments, 76 exact roundtrips, deep copies, alias/self assignment and
  portable genuine int64 text conversions without F/D instructions.
- B: every one of 253 truncated golden prefixes against a real PROT_NONE
  page, 4096 deterministic mutations, alternating nested Message/Variant
  limits and five real array-allocation failures. A test-only linker wrapper
  injects bad_alloc; production libraries do not replace operator new.
- C: a separately forked/executed original Looper/Messenger service handles
  10000 typed request/replies across address spaces. Then 16 genuine native
  workers execute 160000 typed Variant/Message cycles with exact reaping,
  CPU0 affinity, no new faults/cancellations and no remaining heap scopes.

The bounded allocator channel intentionally rejects PROT_NONE. Gate B runs
with zero live workers and creates its guard using the existing controller
Linux mprotect syscall; it does not extend allocator/kernel permissions.
The initial failed setup is retained, not presented as a successful gate.

Run progressive A/B before full C on OpenSBI UP/SMP and SecureSBI SMP:

```powershell
.\scripts\test-syllable-variant-matrix.ps1 -ReuseVerified
```

The matrix stops on failure, checks current artifact hashes before reusing
any case, forces an actual byte-identical rebuild and preserves all 38
v0.15 stable and 20 v0.16 dispatch artifacts. Host fixtures alone cannot
create retained runtime success evidence. Refer to the evidence manifest
only after it exists and all its case/artifact checks pass.

An individual experimental run is available through the public runner:

```powershell
.\testproject.ps1 -Mode graphics -SyllableVariant -Smp 2
```

## Remaining Work

This is a toolkit data dependency, not Application, Window, View, AppServer,
Desktop, Dock or FileBrowser. Full GNU threading, shared stdio, node
monitoring and the previously observed intermittent old Thread B counter
assertion remain separate unfinished contracts. Userspace remains on CPU0.
The stable default is not promoted by enabling this experimental profile.
See [the authentic AppServer boundary](SYLLABLE_APPSERVER_BOUNDARY.md).

## Licenses

The original Variant implementation/header and the derived four-file
adaptation remain LGPL-2.0-only, with full original notices and COPYING.LIB.
Independent preparer, probe, runner, verifier and host tests alone are
original runtime BSD-2-Clause code, explicitly classified in the scope
manifest. Syllable, GNU, musl and XNU are not relicensed. No new binary
Release is created; future binary publication needs exact corresponding
source, notices and relink materials.
