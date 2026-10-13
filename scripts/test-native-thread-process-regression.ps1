# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "../..")).Path
$kernel = Join-Path $workspace "xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
$log = Join-Path $root "build/native-thread-process-regression.txt"
$before = (Get-FileHash -LiteralPath $kernel -Algorithm SHA256).Hash.ToLowerInvariant()
$previous = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $global:LASTEXITCODE = $null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "testproject.ps1") -Mode process-gates *> $log
    $code = $global:LASTEXITCODE
} finally { $ErrorActionPreference = $previous }
$after = (Get-FileHash -LiteralPath $kernel -Algorithm SHA256).Hash.ToLowerInvariant()
$text = Get-Content -LiteralPath $log -Raw
$targets = @([regex]::Matches($text, "(?m)^OK: (\S+)\r?$"))
$same = $null -ne $code -and $code -eq 0 -and $before -ceq $after -and
    $targets.Count -eq 15 -and $text.Contains("testproject.ps1 completed.")
$record = [ordered]@{result = $(if ($same) {"PASS"} else {"FAIL"}); kernelBefore = $before; kernelAfter = $after;
    completedTargets = @($targets | ForEach-Object { $_.Groups[1].Value });
    logSha256 = (Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $root "build/native-thread-process-regression.json"), ($record | ConvertTo-Json -Depth 8) + "`n", (New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw "Process regression failed or changed the kernel; inspect the retained log" }
Write-Host "PASS 15 actual process runner targets; before/after kernel hash unchanged"
