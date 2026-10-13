# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([switch]$IncludePrivateFutex)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "../..")).Path
$kernelRoot = Join-Path $workspace "xnu-2050.48.11"
$env:PATH = "$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$paths = @("build/caribe_rv32.elf", "build/initrd.img", "build/initrd-threads.img", "build/native-thread-probe.elf",
    "build/freetype-probe.elf", "build/freetype-rv32-sysroot/usr/lib/libfreetype.a", "build/libcaribe-syllable-native.a",
    "build/libcaribe-syllable-string.a", "build/libcaribe-syllable-message.a", "build/font-sources.json")
if ($IncludePrivateFutex) { $paths += @("build/native-futex-probe.elf", "build/initrd-futex.img") }
$profile = $(if ($IncludePrivateFutex) { "native-futex" } else { "native-thread" })
$kernel = Join-Path $kernelRoot "BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf"
function Get-Records {
    @([ordered]@{path = "xnu"; sha256 = (Get-FileHash -LiteralPath $kernel -Algorithm SHA256).Hash.ToLowerInvariant()}) +
    @($paths | ForEach-Object { [ordered]@{path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $root $_) -Algorithm SHA256).Hash.ToLowerInvariant()} })
}
$before = @(Get-Records)
$units = @("native_thread", "native_sync", "linux_syscall", "linux_process", "pmap", "riscv32_thread", "syscall", "trap")
if ($IncludePrivateFutex) { $units += @("native_futex", "linux_exec") }
$sharedUnits = @()
if ($IncludePrivateFutex) { $sharedUnits += "sched_proto" }
$forceArguments = @("-ForceRiscv32Sources", ($units -join ','))
if ($sharedUnits.Count) { $forceArguments += @("-ForceKernSources", ($sharedUnits -join ',')) }
$previous = $ErrorActionPreference
Push-Location $root
try {
    $ErrorActionPreference = "Continue"
    # A separate PowerShell process keeps the existing build script's exit local.
    $global:LASTEXITCODE = $null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot "tools/riscv32-make-osfmk.ps1") -Target osfmk.filelist @forceArguments *> (Join-Path $root "build/$profile-force-kernel.txt")
    if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -ne 0) { throw "Forced kernel object compilation failed" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot "tools/riscv32-link-full-stage0.ps1") -SkipObjectRefresh *> (Join-Path $root "build/$profile-force-link.txt")
    if ($LASTEXITCODE -ne 0) { throw "Forced kernel link failed" }
    $targets = @("-W", "userland/native_thread_probe.c", "build/native-thread-probe.elf", "build/initrd-threads.img")
    if ($IncludePrivateFutex) { $targets += @("-W", "userland/native_futex_probe.c", "build/native-futex-probe.elf", "build/initrd-futex.img") }
    & make @targets *> (Join-Path $root "build/$profile-force-probe.txt")
    if ($LASTEXITCODE -ne 0) { throw "Forced raw-thread probe/initrd compilation failed" }
} finally { $ErrorActionPreference = $previous; Pop-Location }
$kernelLog = Get-Content -LiteralPath (Join-Path $root "build/$profile-force-kernel.txt") -Raw
foreach ($unit in ($units + $sharedUnits)) { if ($kernelLog -notmatch "(?m)^CC $unit\.o\r?$") { throw "No actual recompilation for $unit" } }
$probeLog = (Get-Content -LiteralPath (Join-Path $root "build/$profile-force-probe.txt") -Raw).Replace('\', '/')
if (-not $probeLog.Contains("userland/native_thread_probe.c -o build/native_thread_probe.o") -or
    -not $probeLog.Contains("wrote build/initrd-threads.img:")) { throw "No actual probe recompilation/repack" }
if ($IncludePrivateFutex -and (-not $probeLog.Contains("userland/native_futex_probe.c -o build/native_futex_probe.o") -or
    -not $probeLog.Contains("wrote build/initrd-futex.img:"))) { throw "No actual futex probe recompilation/repack" }
$after = @(Get-Records)
$same = ($before | ConvertTo-Json -Depth 8 -Compress) -ceq ($after | ConvertTo-Json -Depth 8 -Compress)
$record = [ordered]@{result = $(if ($same) {"PASS"} else {"FAIL"}); forcedKernelUnits = @($units + $sharedUnits);
    recipe = "GNU make -W for $($units.Count + $sharedUnits.Count) selected kernel C units, kernel relink, forced raw-thread C probe/initrd and selected private-futex probe/initrd";
    before = $before; after = $after}
[IO.File]::WriteAllText((Join-Path $root "build/$profile-rebuild.json"), ($record | ConvertTo-Json -Depth 8) + "`n", (New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw "Forced thread rebuild differs; retained evidence is invalid" }
Write-Host "PASS forced $($units.Count + $sharedUnits.Count)-unit kernel/probe compilation and repack; $($after.Count) artifacts byte-identical"
