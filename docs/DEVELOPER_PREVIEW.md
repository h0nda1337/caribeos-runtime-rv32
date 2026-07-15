# Tranche 201 Developer Preview

The preserved QEMU Developer Preview is an experimental, prebuilt validation
package. It is not a production image, installer, macOS distribution, or
general-purpose VM appliance.

## Preserved Artifact

- archive: `caribeos-tranche-201-qemu-developer-preview.zip`;
- SHA-256: `30cfc3089bee97053c262c9278325b16274efdf21c1aa372ebaec2b45f33650d`;
- kernel size: 945,004 bytes;
- kernel SHA-256: `c63fe4bfbaeaf674a4092c1c579cfe472fc433d2e89b4f55307484ed820e595e`.

The archive includes CaribeBootX, HFS+ and initrd images, the kernel copy, a
reference DTB, a PowerShell runner, compact evidence, hashes, and license texts.
It does not include QEMU, OpenSBI firmware, a cross-toolchain, or an Apple SDK.

## Run in an Isolated Directory

Extract the archive into a new directory, verify its SHA-256 and
`SHA256SUMS.txt`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\qemu-rv32-sbi.ps1 `
  -SmokeTest -RequireStage1 -Seconds 60 -Smp 1
```

QEMU 11.0.0 is the preserved reference version. The runner requires
`qemu-system-riscv32` on `PATH` unless an explicit executable path is supplied.

## Evidence Boundary

The package carries selected final logs and semantic summaries. It demonstrates
the preserved Tranche 201 behavior only; it does not prove broad hardware,
security, POSIX, filesystem, or Linux ABI compatibility.

## Redistribution Gate

Public distribution requires the runtime project license, all third-party
notices, and same-place corresponding source for the included GNU Bash/musl
binaries. The original archive and hash are immutable; any public repack must
use a new filename and manifest rather than overwriting it.
