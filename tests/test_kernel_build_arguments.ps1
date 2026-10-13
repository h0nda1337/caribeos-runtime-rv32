# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
# Exercise the actual build parameter declaration only, without compiling or QEMU.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "../..")).Path
$source = Join-Path $workspace "xnu-2050.48.11/tools/riscv32-make-osfmk.ps1"
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Kernel build parameter parse error" }
$body = $ast.ParamBlock.Extent.Text + "`n[pscustomobject]@{Targets = @(`$Target); Forced = `$ForceRiscv32Sources}"
$parametersOnly = [scriptblock]::Create($body)
$normal = & $parametersOnly osfmk.filelist
if ($normal.Targets.Count -ne 1 -or $normal.Targets[0] -ne "osfmk.filelist" -or $normal.Forced) { throw "Default positional target regression" }
$multiple = & $parametersOnly pmap.o native_thread.o
if ($multiple.Targets.Count -ne 2 -or $multiple.Forced) { throw "Multiple positional target regression" }
$forced = & $parametersOnly -Target osfmk.filelist -ForceRiscv32Sources "native_thread,trap"
if ($forced.Targets.Count -ne 1 -or $forced.Forced -ne "native_thread,trap") { throw "Named forcing parameter regression" }
Write-Host "PASS actual kernel default/multiple/forced parameter binding; no build or QEMU launched"
