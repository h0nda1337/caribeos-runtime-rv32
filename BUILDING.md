# Building CaribeOS

## Prerequisites

The verified host is Windows PowerShell 5.1 with:

- `riscv64-unknown-elf-gcc` and companion binutils, GCC 15.1.0
- `qemu-system-riscv32`, QEMU 11.0.0
- GNU Make 4.4.1
- MSYS2 `bash`, `tar`, and `patch`

The expected workspace layout is:

```text
<workspace>/
  xnu-2050.48.11/
  caribeos-corrected-xnu-rv32imacsu/caribeos/
  msys64/
```

`testproject.ps1` and the build scripts derive these paths from their own
location; they do not require a fixed drive letter.

## Build the Current Kernel and Runtime

The release path is the runner itself:

```powershell
Set-Location <workspace>\caribeos-corrected-xnu-rv32imacsu\caribeos
.\testproject.ps1 -Mode up -Seconds 45
```

It invokes the sibling XNU script
`tools/riscv32-link-full-stage0.ps1`, then the appropriate runtime make target.

Useful direct targets include:

```powershell
make boot_stage1 QEMU_SMOKE_SECONDS=45
make boot_stage1_smp_gate_f QEMU_SMOKE_SECONDS=50
make boot_stage1_process_gate_15 QEMU_SMOKE_SECONDS=90
make boot_stage1_process_gate_15_smp QEMU_SMOKE_SECONDS=90
```

## Build musl and Bash

```powershell
.\scripts\build-musl-rv32.ps1 -Jobs 4
.\scripts\build-bash-rv32.ps1 -Jobs 4
```

The scripts download missing upstream archives, verify SHA-256, extract into
`third_party/`, and build under `build/`. The pinned inputs are musl 1.2.5 and
GNU Bash 5.3 with official patches 1-5. These generated/downloaded directories
are excluded from Git but retained in the raw preservation snapshot.

## Build Outputs

Important generated files include:

- `build/caribe_rv32.elf`: CaribeBootX passed to QEMU with `-kernel`
- `build/initrd.img`: test userland image when selected by the target
- `hfsplus.img` or generated build image: HFS+ system disk
- sibling XNU `BUILD/.../xnu-caribeos-rv32-full-stage0.elf`

Do not commit these files. Use the private release package and its
`SHA256SUMS.txt` for binary distribution.

## Reproducibility Boundary

The exact XNU ELF, fresh GitHub restore, isolated HFS+ update, UP Stage 1 boot,
immutable-preview distinction, and remaining publication blockers are recorded
in the [runtime reproducibility report](docs/REPRODUCIBILITY_REPORT.md).

The verified workflow uses the recorded Windows toolchain. It is not yet a
hermetic container build, and public unauthenticated clone and remote-CI checks
remain pending while the repositories are private.
