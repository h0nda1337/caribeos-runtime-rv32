# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param(
    [ValidateRange(1, 2)][int]$Smp = 1,
    [string]$Bios = "default",
    [string]$PythonPath = "",
    [switch]$Live,
    [switch]$SkipKernelBuild,
    [switch]$NativeIpc,
    [switch]$NativeAreas,
    [switch]$NativeCxx,
    [string]$Cpu = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent (Split-Path -Parent $root)
foreach ($path in @("msys64\ucrt64\bin", "msys64\usr\bin")) {
    $candidate = Join-Path $workspace $path
    if (Test-Path -LiteralPath $candidate) { $env:PATH = "$candidate;$env:PATH" }
}
$build = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null
if (-not $SkipKernelBuild) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $workspace "xnu-2050.48.11\tools\riscv32-link-full-stage0.ps1") *> (Join-Path $build "graphics-kernel-build.txt")
    if ($LASTEXITCODE -ne 0) { throw "Kernel build failed: build/graphics-kernel-build.txt" }
}
Push-Location $root
try {
    $makeArguments = @("all", "hfs_kernel", "hfs_initrd")
    if ($NativeCxx) { $makeArguments += "INITRD_IMG=build/initrd-cxx.img" }
    & make @makeArguments *> (Join-Path $build "graphics-runtime-build.txt")
    if ($LASTEXITCODE -ne 0) { throw "Runtime build failed: build/graphics-runtime-build.txt" }
    if (-not $PythonPath) {
        $candidates = @(
            (Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"),
            (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
        )
        foreach ($candidate in $candidates) {
            if (-not $candidate -or -not (Test-Path -LiteralPath $candidate)) { continue }
            $previousPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = "Continue"
                & $candidate -c "from PIL import Image, ImageChops" 2>$null
                if ($LASTEXITCODE -eq 0) { $PythonPath = $candidate; break }
            } finally {
                $ErrorActionPreference = $previousPreference
            }
        }
    }
    if (-not $PythonPath) { throw "Python with Pillow required; specify -PythonPath." }
    $arguments = @((Join-Path $root "scripts\test-graphics.py"), "--smp", $Smp, "--bios", $Bios)
    if ($Cpu) { $arguments += @("--cpu", $Cpu) }
    if ($NativeIpc) { $arguments += "--native-ipc" }
    if ($NativeAreas) { $arguments += "--native-areas" }
    if ($NativeCxx) { $arguments += "--native-cxx" }
    if ($Live) { $arguments += "--live" }
    & $PythonPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "QEMU graphics gate failed; see build/graphics-tests." }
} finally {
    Pop-Location
}
