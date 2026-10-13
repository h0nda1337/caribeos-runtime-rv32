# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([ValidateRange(1, 16)][int]$Jobs = 4, [switch]$RecompileRuntimeCore)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "..\..")).Path
$bash = Join-Path $workspace "msys64\usr\bin\bash.exe"
$python = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if (-not (Test-Path -LiteralPath $python)) { $python = (Get-Command python).Source }
& $python (Join-Path $PSScriptRoot "prepare-cxx-deps.py")
if ($LASTEXITCODE -ne 0) { throw "GNU runtime dependency verification failed" }
$script = (Join-Path $PSScriptRoot "build-cxx-rv32.sh").Replace('\', '/')
& $bash $script $Jobs $(if ($RecompileRuntimeCore) { 1 } else { 0 })
if ($LASTEXITCODE -ne 0) { throw "RV32-musl C++ runtime build failed" }
