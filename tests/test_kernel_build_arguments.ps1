# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
# Exercise the actual build parameter declaration only, without compiling or QEMU.
param([string]$XnuRoot = "")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "../..")).Path
if (-not $XnuRoot) {
  $XnuRoot = Join-Path $workspace "xnu-2050.48.11"
  if (-not (Test-Path -LiteralPath $XnuRoot)) {
    $XnuRoot = Join-Path $root "../xnu"
  }
}
$source = (Resolve-Path -LiteralPath (Join-Path $XnuRoot "tools/riscv32-make-osfmk.ps1")).Path
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Kernel build parameter parse error" }
$body = $ast.ParamBlock.Extent.Text + "`n[pscustomobject]@{Targets = @(`$Target); Forced = `$ForceRiscv32Sources; Shared = `$ForceKernSources}"
$parametersOnly = [scriptblock]::Create($body)
$normal = & $parametersOnly osfmk.filelist
if ($normal.Targets.Count -ne 1 -or $normal.Targets[0] -ne "osfmk.filelist" -or $normal.Forced) { throw "Default positional target regression" }
$multiple = & $parametersOnly pmap.o native_thread.o
if ($multiple.Targets.Count -ne 2 -or $multiple.Forced) { throw "Multiple positional target regression" }
$forced = & $parametersOnly -Target osfmk.filelist -ForceRiscv32Sources "native_thread,trap"
if ($forced.Targets.Count -ne 1 -or $forced.Forced -ne "native_thread,trap") { throw "Named forcing parameter regression" }
$shared = & $parametersOnly -Target osfmk.filelist -ForceRiscv32Sources "native_futex" -ForceKernSources "sched_proto"
if ($shared.Targets.Count -ne 1 -or $shared.Forced -ne "native_futex" -or $shared.Shared -ne "sched_proto") { throw "Shared kernel forcing parameter regression" }
$rejected = $false
try { & $source -ForceKernSources '../pmap' } catch {
  if ($_.Exception.Message -notmatch 'Invalid shared kernel source name') { throw }
  $rejected = $true
}
if (-not $rejected) { throw "Shared source path traversal was not rejected" }
Write-Host "PASS actual kernel default/multiple/forced/shared parameter binding and traversal rejection; no build or QEMU launched"
