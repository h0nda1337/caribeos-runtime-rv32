# Runtime Reproducibility Report

Status: private publication preparation, verified 2026-07-15.

This report covers the CaribeBootX, HFS+, QEMU, and Stage 1 integration used to
validate the path-normalized XNU-CaribeOS RV32 kernel. It does not replace or
rewrite the immutable Tranche 201 Developer Preview.

## Verified Source State

- Runtime integration-input commit:
  `ec855749fce4041b596d2023a3fe3cc354742b66`.
- Runtime Tranche 201 tag target:
  `406f910d06891f30c866d284fbc98bde83f94e35`.
- XNU build-input commit:
  `668db8175562eae35f0e5d862a537f6b45da3e7b`.
- Canonical XNU ELF size: 928,956 bytes.
- Canonical XNU ELF SHA-256:
  `66c176f7b3ce49a233ceb762a99375659cddfbb7921bfd43dd6f0a7a52b58d11`.

Fresh authenticated HTTPS clones of both private repositories passed exact
HEAD and annotated-tag checks, `git fsck --full`, clean-tree checks, static and
documentation validators, workflow linting, YAML parsing, path scans, and
PowerShell parsing.

## Deterministic RV32 Assembly Links

A focused rebuild audit found that rules which passed `.S` files directly to
the GCC link driver embedded random `cc*.o` temporary names in ELF symbol
tables. The executable bytes remained stable, but the complete ELF hashes and
the initrd hash did not. The affected rules now compile named object files
first and link those explicit prerequisites. Negative dynamic-loader fixtures
use separate objects so their preprocessor definitions remain isolated.

The corrected graph passed two normal targeted rebuilds after timestamp-only
source invalidation. The gate restored all source timestamps and verified:

- 28 source inputs invalidated on each pass;
- 33 directly linked RV32 outputs;
- 11 derived ELF or shared-object fixtures;
- 34 deterministic object files;
- 79 of 79 artifacts byte-identical between passes;
- zero random `cc*.o` symbols in the final ELF files;
- `build/initrd.img` size: 3,506,804 bytes;
- `build/initrd.img` SHA-256:
  `9393175b120fc79d210d72da625f233fd17d369970391c394be0528061d017fa`.

A current-source reference build using the former one-step command also
produced the same loadable image as the new two-step rule. This confirms that
the build-graph correction changes non-loadable naming metadata, not RV32 code
or data presented to the kernel.

## Isolated Integration Procedure

The preserved preview ZIP was hash-checked and extracted into a new test
directory. The XNU ELF built from the fresh GitHub clone replaced only the
copied `kernel.elf`. `scripts/update-hfs-kernel.py` then updated `/kernel.elf`
inside the copied HFS+ image without changing the original archive.

The updater recorded:

- payload size: 928,956 bytes;
- HFS+ allocation: 946,176 bytes;
- boot-time HFS+ observation: `/kernel.elf size=928956`.

The copied image was run with QEMU 11.0.0, OpenSBI 1.7, one hart, 256 MiB RAM,
the QEMU `virt` machine, `-bios default`, and CaribeBootX as the QEMU kernel.

## Verified Boot Result

All required integration markers were present:

- OpenSBI entered CaribeBootX in S-mode;
- CaribeBootX read the boot plist and loaded the exact HFS+ kernel size;
- the ELF handoff reached `XNU-CaribeOS`;
- XNU reserved the OpenSBI M-mode range and completed the Sv32 handoff;
- `stage1-caribed` reported the system ready;
- the real musl probe passed;
- GNU Bash passed arrays, loops, arithmetic, functions, conditionals, and case;
- the dynamic loader handed off to the probe's main entry;
- the tested Linux-compatible ABI ended with `exit status=0`;
- the runner emitted `QEMU smoke test OK.`

No panic, `scause`, `stval`, or `sepc` failure marker was present.

## Immutable Preview Boundary

The preserved preview remains unchanged:

- archive SHA-256:
  `30cfc3089bee97053c262c9278325b16274efdf21c1aa372ebaec2b45f33650d`;
- kernel size: 945,004 bytes;
- kernel SHA-256:
  `c63fe4bfbaeaf674a4092c1c579cfe472fc433d2e89b4f55307484ed820e595e`.

The isolated updated HFS+ image is test evidence, not a release asset. Any
future public repack requires a new filename, manifest, and hashes.

## Remaining Limits

- Public, unauthenticated clone behavior and public remote CI remain pending
  while both repositories are private.
- Original CaribeOS runtime code now has an explicit BSD-2-Clause allowlist and
  source-header policy. The header transformation preserves every licensed
  file body exactly relative to the pre-license Git commit.
- The verified corresponding-source archive must be regenerated from the final
  public-preview commit and attached beside the Developer Preview.
- The focused UP integration test did not rerun the long Tranche 201 suites.
  Their preserved 35/35 and 19/19 evidence remains attached to the immutable
  technical milestone.
- The deterministic rebuild gate is focused build evidence. It does not
  replace the preserved boot and restore suites.

See [Building](../BUILDING.md), the
[Developer Preview boundary](DEVELOPER_PREVIEW.md), and
[Testing](../TESTING.md).
