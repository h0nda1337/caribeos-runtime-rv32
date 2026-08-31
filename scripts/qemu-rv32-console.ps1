# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [string]$QemuPath = "",
  [ValidateRange(1, 2)]
  [int]$Smp = 1,
  [ValidateRange(64, 2048)]
  [int]$MemoryMiB = 256,
  [string]$Append = "",
  [string]$DiskImage = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
  param(
    [string]$Root,
    [string]$Path
  )

  if ([IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $Root $Path
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$elf = Join-Path $root "build\caribe_rv32.elf"
$disk = if ($DiskImage) {
  Resolve-ProjectPath -Root $root -Path $DiskImage
} else {
  Join-Path $root "hfsplus.img"
}

foreach ($path in @($elf, $disk)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing required boot artifact: $path"
  }
}

if (-not $QemuPath) {
  $command = Get-Command "qemu-system-riscv32.exe" -ErrorAction SilentlyContinue
  if (-not $command) {
    $command = Get-Command "qemu-system-riscv32" -ErrorAction SilentlyContinue
  }
  if ($command) {
    $QemuPath = $command.Source
  }
}
if (-not $QemuPath) {
  $fallback = "C:\Program Files\qemu\qemu-system-riscv32.exe"
  if (Test-Path -LiteralPath $fallback -PathType Leaf) {
    $QemuPath = $fallback
  }
}
if (-not $QemuPath -or -not (Test-Path -LiteralPath $QemuPath -PathType Leaf)) {
  throw "qemu-system-riscv32 was not found. Pass -QemuPath or add QEMU to PATH."
}

if (-not $Append) {
  $Append = if ($Smp -eq 2) {
    "smp-start smp-gate-f process-gate-11"
  } else {
    "process-gate-11"
  }
}

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $root)
$pathAdds = @(
  (Split-Path -Parent $QemuPath),
  (Join-Path $workspaceRoot "msys64\ucrt64\bin"),
  (Join-Path $workspaceRoot "msys64\usr\bin")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
if ($pathAdds.Count -ne 0) {
  $env:PATH = ($pathAdds -join [IO.Path]::PathSeparator) +
              [IO.Path]::PathSeparator + $env:PATH
}

$qemuArgs = @(
  "-M", "virt",
  "-smp", "$Smp",
  "-m", "$MemoryMiB",
  "-nographic",
  "-no-reboot",
  "-no-shutdown",
  "-bios", "default",
  "-kernel", $elf,
  "-drive", "if=none,file=$disk,format=raw,id=vd0",
  "-device", "virtio-blk-device,drive=vd0",
  "-append", $Append
)

Write-Host "Starting CaribeOS persistent serial console."
Write-Host "Boot chain: OpenSBI -> CaribeBootX -> XNU-CaribeOS -> GNU Bash"
Write-Host "Wait for: bash-5.3$"
Write-Host "Quit QEMU: press Ctrl+A, release both keys, then press X."
Write-Host "Command line: $QemuPath $($qemuArgs -join ' ')"
Write-Host ""

& $QemuPath @qemuArgs
$code = $LASTEXITCODE
if ($code -ne 0) {
  throw "QEMU console exited with status $code."
}
