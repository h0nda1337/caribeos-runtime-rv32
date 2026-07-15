# Contributing to CaribeOS Runtime

This repository owns CaribeBootX, boot media construction, RV32 userland,
QEMU runners, and semantic gates. Contributions should preserve the supported
boot chain and make every new claim observable in serial output or artifacts.

## Before Starting

Open a focused issue for substantial changes. State the affected layer, the
expected boot or userspace behavior, UP/SMP impact, and the smallest runner mode
that proves the result. Use the private process in `SECURITY.md` for suspected
vulnerabilities.

Never submit credentials, private host configuration, proprietary SDK content,
firmware without redistributable terms, downloaded third-party build trees, or
generated ELF/image/log output.

## Runtime Invariants

- Keep `OpenSBI -> CaribeBootX -> XNU-CaribeOS` as the supported path.
- Use QEMU `-bios default -kernel build/caribe_rv32.elf`.
- Keep the old direct `-bios build/caribe_rv32.bin` path unsupported.
- Preserve the real `HFSPlusFileRecord` layout, including BSD `special` before
  `userInfo[4]`.
- Keep all third-party versions, URLs, hashes, licenses, and patches explicit.
- Add the project BSD-2-Clause header only to original CaribeOS runtime code
  and classify it in `docs/RUNTIME_LICENSE_SCOPE.json`.
- Never add the project header to third-party, derived, generated, binary,
  data, or mixed/uncertain-provenance material.
- Do not treat a marker-only payload as a complete subsystem implementation.
- Do not move or rewrite `tranche-201-stage2-complete`.

## Validation

Run `git diff --check`, static checks, and the narrowest relevant mode:

| Change | Minimum evidence |
|---|---|
| Documentation/metadata | static documentation checks and secret scan |
| CaribeBootX/HFS+/virtio | `up` plus a focused disk or boot negative test |
| SMP runner or assertions | relevant Gates A-F |
| Process/userland/initrd | focused process gate in UP and SMP when applicable |
| Interactive TTY/Bash | `interactive` with semantic command/exit assertions |
| Release package | isolated extraction, SHA-256 verification, and smoke boot |

Pull requests must list exact commands, PASS markers, artifact hashes, known
limits, and dependency provenance. Retain all existing notices and only submit
material you have the right to distribute under the repository and file-level
terms.
