# Verified Syllable Thread checkpoint v0.13

Actual QEMU RV32IMACSU evidence, recorded 2026-10-13. This builds the original
Syllable Thread class, not Looper/AppServer or a desktop imitation.

- Progressive UP A and B; full UP C.
- Three full OpenSBI SMP runs, separately retained.
- SecureSBI SMP, including the existing privileged-signing denial.
- Default-off raw threads and default-off private futex profiles.
- Full existing graphics/input, IPC/areas, C++/String/Message, semaphore,
  FreeType, raw-thread/futex/TCB/Locker dependency gates.
- Original Thread B: 16 workers, 160,000 protected increments,
  320,000 recursive acquisitions, 640 real native timer sleeps, CPU0.
- Original Thread C: 64 finite timeouts and 64 native cancellations;
  exact 146 create/exit/reap, zero live/fault/semaphore deltas.
- Fresh 15/15 process runner targets for the final kernel hash.
- Actual native_thread kernel compilation/relink plus original Thread,
  adapters, TLS assembly and image repack: 24 byte-identical artifacts.
- 173 host unit tests, three actual PowerShell guard scripts and 32 tracked
  PowerShell files parsed. Host fixtures are not substituted for guest proof.
- The public testproject graphics/SMP/SyllableThread command also completed
  successfully; its kernel hash matches the final matrix.

Final artifact SHA-256:

```text
kernel: db186002f199bbf72ec7568dc7ecb3b276ea455edaec1363c04b47d74089fadc
thread probe: 02d65c7413f53647ef24fb9ac4d0b5b5cf49786012a24d2930ad5583c5bb9452
thread library: 7997660ff08a0c2ddc08e81a57e538fb43007b96ffadc9a35fe9906fad9f5a73
thread initrd: d064a7dd9dde8e3560957dafcda6d77147ac4a2d7bd1a3ffde73a5cd0cc208de
thread source record: cd0910628cbfa2f6126f1765b0a61720e1a476aa68c6177ad8d25ac808ba52ba
```

## Regressions caught during verification

The first forced rebuild did not actually compile thread.cpp because the
source preparer preserves timestamps of unchanged hash records. Its required
compiler-log check failed, preventing promotion. The recipe now explicitly
forces sources.json; the actual cpp compilation and byte equality passed.

A subsequent kernel recompilation changed the binary hash from the early
iteration. The collector rejected the stale progressive/matrix records.
The entire final matrix was rerun with the final kernel above, including
fresh process regression. No hash guard was weakened or skipped.

Windows Git also rejected an overlong retained-evidence path. The collector
now uses short, unique evidenceDirectory slugs while preserving complete
QEMU case identifiers and hashes in the manifest. No binary was changed;
all source/evidence validation was repeated, with a new path-length guard.

## Retained boundary

The machine-readable [manifest](manifest.json), separate gate logs, actual
scanouts, source pins and rebuild/process records identify the evidence.
Full serial/build logs and binary snapshots remain local under build/.
The prior v0.12 evidence and binary snapshot are untouched; its dependency
artifacts remain identical, except for this intentional kernel update.

Original Syllable Thread/headers/patch remain LGPL-2.0-only. Independent
adapters are original runtime BSD code; XNU retains APSL notices. No new
binary Release, main-branch update, technical-tag change, paid service or
visibility change is part of this checkpoint.

Worker allocator/stdio, pthread lifecycle and threaded GNU exceptions are
not implemented here. Looper, AppServer, Desktop, Dock and FileBrowser
remain required for the active full-desktop goal.
