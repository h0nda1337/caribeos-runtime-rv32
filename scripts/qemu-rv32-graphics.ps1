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
    [switch]$SyllableString,
    [switch]$SyllableMessage,
    [switch]$NativeSync,
    [switch]$FreeType,
    [switch]$NativeThreads,
    [switch]$NativeTcb,
    [ValidateSet("A", "B", "C")][string]$TcbGate = "C",
    [switch]$NativeLocker,
    [ValidateSet("A", "B", "C")][string]$LockerGate = "C",
    [switch]$SyllableThread,
    [ValidateSet("A", "B", "C")][string]$SyllableThreadGate = "C",
    [switch]$NativeFutex,
    [switch]$DisableNativeFutex,
    [ValidateSet("A", "B", "C", "D")][string]$FutexGate = "D",
    [switch]$DisableNativeThreads,
    [ValidateSet("A", "B", "C", "D")][string]$ThreadGate = "D",
    [ValidateSet("A", "B", "C", "D")][string]$FontGate = "D",
    [ValidateSet("A", "B", "C", "D", "E")][string]$SyncGate = "E",
    [string]$Cpu = ""
)
$ErrorActionPreference = "Stop"
if ($SyllableThread -and ($DisableNativeFutex -or $DisableNativeThreads)) { throw "Syllable Thread gates require enabled native threads and private futex" }
$NativeLocker = $NativeLocker -or $SyllableThread
if ($NativeLocker -and ($DisableNativeFutex -or $DisableNativeThreads)) { throw "Locker gates require enabled native threads and private futex" }
$NativeTcb = $NativeTcb -or $NativeLocker
if ($NativeTcb -and ($DisableNativeFutex -or $DisableNativeThreads)) { throw "TCB gates require enabled native threads and private futex" }
$NativeFutex = $NativeFutex -or $NativeTcb
$NativeFutex = $NativeFutex -or $DisableNativeFutex
if ($NativeFutex -and $DisableNativeThreads) { throw "Futex gates require enabled native threads" }
$NativeThreads = $NativeThreads -or $DisableNativeThreads -or $NativeFutex
function Invoke-LoggedBuild {
    param([string]$Program, [string[]]$Parameters, [string]$Log)
    $previous = $ErrorActionPreference
    try {
        # Windows PowerShell otherwise turns harmless native compiler stderr into a terminating error.
        $ErrorActionPreference = "Continue"
        $global:LASTEXITCODE = $null
        & $Program @Parameters *> $Log
        if ($null -eq $global:LASTEXITCODE) { return -1 }
        return $global:LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
}
$root = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent (Split-Path -Parent $root)
$diskLock = New-Object Threading.Mutex($false, 'Local\CaribeOS-HFS-Graphics')
$ownsDiskLock = $false
try {
    try { $ownsDiskLock = $diskLock.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $ownsDiskLock = $true }
    if (-not $ownsDiskLock) { throw "Another graphics runner owns the HFS disk rebuild/run lock. Finish that run first." }
$activeDiskUsers = @(Get-CimInstance Win32_Process -Filter "name='qemu-system-riscv32.exe'" |
    Where-Object { $_.CommandLine -match '(?i)hfsplus\.img' })
if ($activeDiskUsers.Count) {
    throw "Refusing HFS rebuild while QEMU uses hfsplus.img (PIDs: $($activeDiskUsers.ProcessId -join ', ')). Finish that run first."
}
foreach ($path in @("msys64\ucrt64\bin", "msys64\usr\bin")) {
    $candidate = Join-Path $workspace $path
    if (Test-Path -LiteralPath $candidate) { $env:PATH = "$candidate;$env:PATH" }
}
$build = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null
if (-not $SkipKernelBuild) {
    $code = Invoke-LoggedBuild -Program "powershell" -Parameters @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $workspace "xnu-2050.48.11\tools\riscv32-link-full-stage0.ps1")) -Log (Join-Path $build "graphics-kernel-build.txt")
    if ($code -ne 0) { throw "Kernel build failed: build/graphics-kernel-build.txt" }
}
Push-Location $root
try {
    $makeArguments = @("all", "hfs_kernel", "hfs_initrd")
    if ($FreeType -or $NativeThreads) {
        $code = Invoke-LoggedBuild -Program "powershell" -Parameters @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $root "scripts/build-freetype-rv32.ps1")) -Log (Join-Path $build "freetype-build.txt")
        if ($code -ne 0) { throw "FreeType build/source verification failed: build/freetype-build.txt" }
        $makeArguments += $(if ($SyllableThread) { "INITRD_IMG=build/initrd-threadapi.img" } elseif ($NativeLocker) { "INITRD_IMG=build/initrd-locker.img" } elseif ($NativeTcb) { "INITRD_IMG=build/initrd-tcb.img" } elseif ($NativeFutex) { "INITRD_IMG=build/initrd-futex.img" } elseif ($NativeThreads) { "INITRD_IMG=build/initrd-threads.img" } else { "INITRD_IMG=build/initrd-fonts.img" })
    }
    elseif ($NativeSync) { $makeArguments += "INITRD_IMG=build/initrd-sync.img" }
    elseif ($SyllableMessage) { $makeArguments += "INITRD_IMG=build/initrd-message.img" }
    elseif ($SyllableString) { $makeArguments += "INITRD_IMG=build/initrd-syllable.img" }
    elseif ($NativeCxx) { $makeArguments += "INITRD_IMG=build/initrd-cxx.img" }
    $code = Invoke-LoggedBuild -Program "make" -Parameters $makeArguments -Log (Join-Path $build "graphics-runtime-build.txt")
    if ($code -ne 0) { throw "Runtime build failed: build/graphics-runtime-build.txt" }
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
    if ($SyllableString) { $arguments += "--syllable-string" }
    if ($SyllableMessage) { $arguments += "--syllable-message" }
    if ($NativeSync) { $arguments += @("--native-sync", "--sync-gate", $SyncGate.ToUpperInvariant()) }
    if ($FreeType) { $arguments += @("--freetype", "--font-gate", $FontGate.ToUpperInvariant()) }
    if ($NativeThreads) { $arguments += @("--native-threads", "--thread-gate", $ThreadGate.ToUpperInvariant()) }
    if ($DisableNativeThreads) { $arguments += "--native-threads-disabled" }
    if ($NativeFutex) { $arguments += @("--native-futex", "--futex-gate", $FutexGate.ToUpperInvariant()) }
    if ($NativeTcb) { $arguments += @("--native-tcb", "--tcb-gate", $TcbGate.ToUpperInvariant()) }
    if ($NativeLocker) { $arguments += @("--native-locker", "--locker-gate", $LockerGate.ToUpperInvariant()) }
    if ($SyllableThread) { $arguments += @("--syllable-thread", "--syllable-thread-gate", $SyllableThreadGate.ToUpperInvariant()) }
    if ($DisableNativeFutex) { $arguments += "--native-futex-disabled" }
    if ($Live) { $arguments += "--live" }
    & $PythonPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "QEMU graphics gate failed; see build/graphics-tests." }
} finally {
    Pop-Location
}
} finally {
    if ($ownsDiskLock) { $diskLock.ReleaseMutex() }
    $diskLock.Dispose()
}
