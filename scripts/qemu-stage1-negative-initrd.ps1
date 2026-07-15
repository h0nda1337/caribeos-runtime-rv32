# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [Parameter(Mandatory = $true)]
  [string]$BadInitrd,
  [string]$GoodInitrd = "build/initrd.img",
  [string]$DiskImage = "hfsplus.img",
  [string]$ExpectedPattern = "",
  [int]$ExpectedStatus = 127,
  [int]$Seconds = 45,
  [string]$EvidenceLog = "build/qemu-negative-serial.log",
  [string]$RunLog = "build/qemu-negative-run.log"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir

function Resolve-RootPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return (Join-Path $root $Path)
}

$badInitrdPath = Resolve-RootPath $BadInitrd
$goodInitrdPath = Resolve-RootPath $GoodInitrd
$diskPath = Resolve-RootPath $DiskImage
$evidencePath = Resolve-RootPath $EvidenceLog
$runLogPath = Resolve-RootPath $RunLog
$serialPath = Join-Path $root "build\serial.log"
$qemuScript = Join-Path $scriptDir "qemu-rv32-sbi.ps1"
$hfsUpdater = Join-Path $scriptDir "update-hfs-kernel.py"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $evidencePath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $runLogPath) | Out-Null

if (-not (Test-Path -LiteralPath $badInitrdPath)) {
  throw "Missing bad initrd: $badInitrdPath"
}
if (-not (Test-Path -LiteralPath $goodInitrdPath)) {
  throw "Missing good initrd: $goodInitrdPath"
}
if (-not (Test-Path -LiteralPath $diskPath)) {
  throw "Missing HFS+ disk image: $diskPath"
}

try {
  & python $hfsUpdater $diskPath $badInitrdPath --path //initrd.img --allow-grow | Out-File -LiteralPath $runLogPath -Encoding utf8

  $savedErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & powershell -ExecutionPolicy Bypass -File $qemuScript -SmokeTest -RequireStage1 -Seconds $Seconds -DiskImage $diskPath *> $runLogPath
  $qemuCode = $LASTEXITCODE
  $ErrorActionPreference = $savedErrorActionPreference

  if (Test-Path -LiteralPath $serialPath) {
    Copy-Item -LiteralPath $serialPath -Destination $evidencePath -Force
  }

  $serialText = if (Test-Path -LiteralPath $evidencePath) {
    Get-Content -LiteralPath $evidencePath -Raw
  } else {
    ""
  }

  if ($qemuCode -eq 0) {
    throw "Negative boot unexpectedly passed"
  }
  if ($serialText -notmatch "\[linux\] exit status=$ExpectedStatus") {
    throw "Negative boot did not report expected exit status $ExpectedStatus"
  }
  if ($ExpectedPattern -and $serialText -notmatch $ExpectedPattern) {
    throw "Negative boot did not match expected pattern: $ExpectedPattern"
  }
  if ($serialText -match "(?m)(panic|scause=|stval=|sepc=)") {
    throw "Negative boot saw trap/panic signature"
  }

  Write-Output "QEMU negative stage1 test OK."
  Write-Output "Evidence: $evidencePath"
} finally {
  if (Test-Path -LiteralPath $goodInitrdPath) {
    & python $hfsUpdater $diskPath $goodInitrdPath --path //initrd.img --allow-grow | Out-Null
  }
}
