# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([ValidateRange(1,4)][int]$Jobs=2)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$temp=Join-Path $workspace 'tmp'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
$env:TMP=$temp; $env:TEMP=$temp; $env:TMPDIR=$temp
Push-Location $root
try {
 & python (Join-Path $PSScriptRoot 'prepare-musl-heap.py')
 if ($LASTEXITCODE -ne 0) { throw 'Musl heap source verification failed' }
 & bash 'scripts/build-musl-heap-rv32.sh' $Jobs
 if ($LASTEXITCODE -ne 0) { throw 'Separate musl heap build failed' }
 if (-not (Test-Path -LiteralPath 'build/musl-heap-rv32-sysroot/usr/lib/libc.a')) { throw 'Missing genuine musl heap archive' }
 Write-Host 'PASS separate genuine musl RV32 heap sysroot; default source/archive untouched'
} finally { Pop-Location }
