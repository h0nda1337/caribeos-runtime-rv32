# Public License Review

**Technical review status: BLOCKED**

This document records a technical license and redistribution review prepared
on 2026-07-14. It is not legal advice and does not guarantee compliance in
every jurisdiction or distribution scenario.

CaribeOS is an independent experimental project. It is not affiliated with,
endorsed by, or supported by Apple Inc.

## Blocking Project-License Decision

The current runtime tree has no top-level `LICENSE` or `COPYING` file. An audit
of runtime commit `b8a4213be04cb5d78a0836139162a1eacdcb9e87` identified 120
tracked source-like files and no explicit project license signal in those
files. No public reuse license may be inferred from repository visibility,
third-party dependencies, or the companion XNU license.

Public visibility is blocked until the project owner explicitly selects the
license for original CaribeOS runtime material, the repository carries the
complete license text, and source headers/policy are made consistent. This
review does not select that license on the owner's behalf.

## Material Classes

| Class | Current treatment |
|---|---|
| Original CaribeOS runtime code | Booter, image tooling, runners, tests, and userland source; project license unresolved and blocking |
| XNU-CaribeOS kernel | Separate companion repository derived from Apple XNU 2050.48.11; APSL 2.0 and file-level notices apply |
| GNU Bash 5.3 patches 1-5 | GPL-3.0-or-later; binary included in the preview initrd, source not tracked in Git |
| musl 1.2.5 | MIT-style terms in musl `COPYRIGHT`; statically linked userland included in the preview |
| OpenSBI | BSD-2-Clause; supplied by QEMU `-bios default`, not bundled |
| QEMU | GPL-2.0 and component terms; emulator is not bundled |
| GCC/binutils and MSYS2 tools | Build tools under their own licenses and exceptions; not bundled |
| XNU kernel binary in preview | Must be distributed with applicable XNU source/notices and without implying Apple affiliation |

## Source Inputs

The maintained scripts pin and verify these upstream inputs:

- GNU Bash 5.3 archive SHA-256
  `0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba`;
- official Bash patches 1-5 with hashes recorded in
  `scripts/build-bash-rv32.ps1`;
- musl 1.2.5 archive SHA-256
  `a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4`.

Downloaded archives, extracted trees, and build products under `third_party/`
and `build/` are intentionally not tracked.

## Developer Preview

The preserved preview SHA-256 is
`30cfc3089bee97053c262c9278325b16274efdf21c1aa372ebaec2b45f33650d`.
A structured audit found 40 ZIP entries and a valid `cpio-newc` initrd with 50
entries, including one GNU Bash ELF. The package includes APSL, Bash GPL v3,
and musl license texts. It does not bundle QEMU or OpenSBI.

The preview does not contain corresponding Bash/musl source. Before public
release, an additional same-place source asset must include the exact Bash and
musl archives, all five Bash patches, required build/control scripts, licenses,
and a hash manifest. The preserved preview ZIP must not be overwritten.

## Conditions to Clear This Review

- explicit owner selection of the runtime project license;
- top-level license text and consistent source/header policy;
- updated `NOTICE.md`, `THIRD_PARTY.md`, README, and release notes;
- verified same-place Bash/musl corresponding-source asset;
- final source and preview secret/large-file/license scan;
- qualified legal review where appropriate for the distributor.

Until each condition is met, `license_review_passed` must remain false and both
repositories and the preview release must remain private.
