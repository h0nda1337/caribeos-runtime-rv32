# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [ValidateRange(1, 32)]
  [int]$Jobs = 4
)

$ErrorActionPreference = "Stop"

function ConvertTo-MsysPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $full = [IO.Path]::GetFullPath($Path)
  $drive = $full.Substring(0, 1).ToLowerInvariant()
  $tail = $full.Substring(2).Replace('\', '/')
  return "/$drive$tail"
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceRoot = (Resolve-Path (Join-Path $projectRoot "..\..")).Path
$toolRoot = Join-Path $workspaceRoot "msys64"
$bash = Join-Path $toolRoot "usr\bin\bash.exe"
$ucrtBin = Join-Path $toolRoot "ucrt64\bin"
$usrBin = Join-Path $toolRoot "usr\bin"

if (-not (Test-Path -LiteralPath $bash)) {
  throw "MSYS2 bash not found at $bash"
}

$env:Path = "$ucrtBin;$usrBin;" + $env:Path
foreach ($command in @("riscv64-unknown-elf-gcc", "riscv64-unknown-elf-ar",
    "riscv64-unknown-elf-ranlib", "make", "tar")) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required build command not found: $command"
  }
}

$version = "1.2.5"
$expectedSha256 = "A9A118BBE84D8764DA0EA0D28B3AB3FAE8477FC7E4085D90102B8596FC7C75E4"
$thirdParty = Join-Path $projectRoot "third_party"
$archive = Join-Path $thirdParty "musl-$version.tar.gz"
$source = Join-Path $thirdParty "musl-$version"
$build = Join-Path $projectRoot "build\musl-rv32"
$sysroot = Join-Path $projectRoot "build\musl-rv32-sysroot"

New-Item -ItemType Directory -Force -Path $thirdParty, $build, $sysroot | Out-Null

if (-not (Test-Path -LiteralPath $archive)) {
  Write-Host "Downloading musl $version from musl.libc.org..."
  Invoke-WebRequest -Uri "https://musl.libc.org/releases/musl-$version.tar.gz" `
    -OutFile $archive
}

$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
if ($actualSha256 -ne $expectedSha256) {
  throw "musl archive SHA-256 mismatch: $actualSha256"
}
Write-Host "musl archive verified: $actualSha256"

if (-not (Test-Path -LiteralPath (Join-Path $source "configure"))) {
  & tar -xzf $archive -C $thirdParty
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract musl source"
  }
}

$projectMsys = ConvertTo-MsysPath $projectRoot
$buildMsys = ConvertTo-MsysPath $build
$toolMsys = ConvertTo-MsysPath $toolRoot
$commonPrefix = "export PATH=$toolMsys/ucrt64/bin:$toolMsys/usr/bin:`$PATH; cd $buildMsys; "

if (-not (Test-Path -LiteralPath (Join-Path $build "config.mak"))) {
  $configure = $commonPrefix +
    "CC='riscv64-unknown-elf-gcc -march=rv32imac_zicsr_zifencei -mabi=ilp32' " +
    "$projectMsys/third_party/musl-$version/configure " +
    "--target=riscv32-linux-musl --disable-shared --prefix=/usr --syslibdir=/lib"
  & $bash -lc $configure
  if ($LASTEXITCODE -ne 0) {
    throw "musl configure failed"
  }
}

$archiveTool = "bash ../../scripts/riscv32-ar-response.sh"
$makeCommand = $commonPrefix +
  "make -j$Jobs AR='$archiveTool' RANLIB=riscv64-unknown-elf-ranlib"
& $bash -lc $makeCommand
if ($LASTEXITCODE -ne 0) {
  throw "musl build failed"
}

$installCommand = $commonPrefix +
  "make install DESTDIR=../musl-rv32-sysroot " +
  "AR='$archiveTool' RANLIB=riscv64-unknown-elf-ranlib"
& $bash -lc $installCommand
if ($LASTEXITCODE -ne 0) {
  throw "musl install failed"
}

$libc = Join-Path $sysroot "usr\lib\libc.a"
if (-not (Test-Path -LiteralPath $libc)) {
  throw "musl build completed without $libc"
}

$size = (Get-Item -LiteralPath $libc).Length
Write-Host "RV32 musl sysroot ready: $sysroot"
Write-Host "libc.a: $size bytes"
