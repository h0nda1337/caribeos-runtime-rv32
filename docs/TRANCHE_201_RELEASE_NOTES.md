# CaribeOS Tranche 201: Stage 2 Complete

This developer preview preserves the first validated combination of the full
RV32 process model, interactive Bash, userspace on CPU1, and stable two-hart
kernel scheduling.

## Verified

- UP boot/userland and SMP Gates A-F
- process Gates 1-15
- musl 1.2.5 and GNU Bash 5.3.5
- real task/thread/pmap process lifecycle
- signals and `rt_sigreturn`
- blocking TTY, pipes, pipelines, and selected job control
- Gate 14 with 10,000 CPU1 lifecycles
- Gate 15 in UP and SMP
- corrected `machine_stack_handoff()` reserved-stack ownership
- exact long-run resource baseline
- zero panic, unexpected trap, stale translation, or RV32A lock overlap in the
  preserved validation logs

## Kernel Identity

- Bytes: 945,004
- SHA-256: `c63fe4bfbaeaf674a4092c1c579cfe472fc433d2e89b4f55307484ed820e595e`
- Tag: `tranche-201-stage2-complete`

## Licensing

Original CaribeOS runtime code identified by the project SPDX header is
BSD-2-Clause. XNU remains under APSL 2.0 and its file-level notices, GNU Bash
remains GPL-3.0-or-later, musl retains its MIT-style terms, and OpenSBI, QEMU,
and all other external components retain their own licenses. BSD-2-Clause does
not relicense any external component.

## Public Preview Release

- Tag: `tranche-201-public-preview`
- Release: [CaribeOS Tranche 201 - RV32 Developer Preview](https://github.com/h0nda1337/caribeos-runtime-rv32/releases/tag/tranche-201-public-preview)
- Runtime source: [caribeos-runtime-rv32 at the public-preview tag](https://github.com/h0nda1337/caribeos-runtime-rv32/tree/tranche-201-public-preview)
- XNU source: [caribeos-xnu-rv32 at the public-preview tag](https://github.com/h0nda1337/caribeos-xnu-rv32/tree/tranche-201-public-preview)

The curated Release asset set is:

- `caribeos-tranche-201-qemu-developer-preview.zip`;
- `caribeos-tranche-201-corresponding-source.zip`;
- `SHA256SUMS.txt`;
- `TRANCHE_201_PUBLIC_MANIFEST.json`;
- `RELEASE_NOTES.md`.

The corresponding-source archive contains the exact GNU Bash 5.3 source,
official patches 1-5, musl 1.2.5 source, build-control scripts, applicable
license material, and runtime source snapshots. It must be distributed beside
the Developer Preview. `SHA256SUMS.txt` is the authority for final asset
hashes; this tracked document intentionally does not embed a circular hash of
an archive that contains the tracked source state itself.

## Quick Start

Install QEMU with `qemu-system-riscv32`, download the Developer Preview and
`SHA256SUMS.txt` from the Release, verify the archive hash, extract it into a
new directory, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\qemu-rv32-sbi.ps1 `
  -SmokeTest -RequireStage1 -Seconds 60 -Smp 1
```

The reference environment is QEMU 11.0.0 with QEMU `virt`, 256 MiB RAM, and
OpenSBI supplied by `-bios default`. The preview does not bundle QEMU, OpenSBI,
a cross-toolchain, an Apple SDK, or proprietary firmware.

## Limitations

This is an experimental QEMU-only preview. The Linux personality, IOKit,
drivers, storage, security, and POSIX surface are incomplete. It is not a
production release, is not compatible with macOS, and is not affiliated with,
endorsed by, or supported by Apple Inc. Use it at your own risk.
