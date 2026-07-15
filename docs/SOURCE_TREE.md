# Source Tree Guide

The supported release path is intentionally smaller than the full bring-up
history preserved in Git.

| Path | Role |
|---|---|
| `booter/` | CaribeBootX S-mode platform, DTB, UART, Sv32, traps, HFS+, and boot handoff |
| `include/uapi/` | Shared RV32 boot, register, MMU, SBI, trap, and XNU boot contracts |
| `scripts/` | Maintained build, image, QEMU, and third-party source helpers |
| `userland/` | RV32 init, probes, process gates, stress programs, and stage1 files |
| `tools/` | Backup, restore, and publication-safe repository tooling |
| `Makefile` | Runtime build and semantic QEMU targets |
| `testproject.ps1` | Primary user-facing build/test runner |
| `docs/evidence/tranche-201/` | Compact, non-sensitive evidence for the preserved milestone |

`docs/RUNTIME_LICENSE_SCOPE.json` is the machine-readable boundary for
BSD-2-Clause original CaribeOS code. New code must be classified there; files
of uncertain, mixed, generated, or external provenance remain outside the
project license until reviewed explicitly.

Root-level `payload_*`, `mfw/`, and standalone diagnostic sources are retained
as early bring-up references. They are not the supported release boot chain and
must not be substituted for `OpenSBI -> CaribeBootX -> XNU-CaribeOS`.

One-time self-modifying patch scripts, inspection helpers, timestamped source
backups, and the superseded porting prompt were removed from the current tip
during public preparation. They remain recoverable from Git history and the
preservation bundles.

Generated output belongs under ignored `build/` or `third_party/` paths. ELF,
images, DTBs, logs, archives, caches, editor state, and local configuration must
not be committed. Release artifacts are produced from clean source and carried
separately with hashes and manifests.
