# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([string]$PythonPath = '', [string]$SecureBios = '')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace = (Resolve-Path (Join-Path $root '../..')).Path
if (-not $PythonPath) {
    $PythonPath = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
}
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw 'Specify -PythonPath with a Python/Pillow runtime' }
if (-not $SecureBios) { $SecureBios = Join-Path $workspace 'securesbi/build/platform/generic/firmware/fw_dynamic.bin' }
if (-not (Test-Path -LiteralPath $SecureBios -PathType Leaf)) { throw 'Verified SecureSBI firmware required; specify -SecureBios' }
function Invoke-CheckedScript {
    param([string]$Path, [string[]]$Arguments)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Matrix stopped at $Path; last stable snapshot is preserved" }
}
function Save-SmpRepeat {
    param([string]$Name)
    $source = Join-Path $root 'build/graphics-tests/opensbi-smp2-imacsu-native-sync-e-native-threads-d-futex-d-freetype-d-syllable-message'
    $record = Get-Content -LiteralPath (Join-Path $source 'result.json') -Raw | ConvertFrom-Json
    if ($record.result -ne 'PASS' -or $record.smp -ne 2 -or $record.baseIsa -ne 'rv32imac') { throw 'Incomplete repeat cannot be saved' }
    $target = Join-Path $root "build/$Name"
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $target -Force
}
$graphics = Join-Path $root 'scripts/qemu-rv32-graphics.ps1'
$common = @('-NativeFutex', '-NativeSync', '-FreeType', '-SyllableMessage',
    '-Cpu', 'rv32,f=false,d=false,h=false,zfa=false', '-PythonPath', $PythonPath)
Push-Location $root
try {
    Invoke-CheckedScript $graphics (@('-Smp', '1') + $common)
    Invoke-CheckedScript $graphics (@('-Smp', '2', '-SkipKernelBuild') + $common)
    Save-SmpRepeat 'futex-smp-repeat-01'
    Invoke-CheckedScript $graphics (@('-Smp', '2', '-SkipKernelBuild') + $common)
    Save-SmpRepeat 'futex-smp-repeat-02'
    Invoke-CheckedScript $graphics (@('-Smp', '2', '-SkipKernelBuild') + $common)
    Invoke-CheckedScript $graphics (@('-Smp', '2', '-SkipKernelBuild', '-Bios', $SecureBios) + $common)
    Invoke-CheckedScript $graphics @('-Smp', '1', '-SkipKernelBuild', '-DisableNativeFutex', '-NativeAreas',
        '-Cpu', 'rv32,f=false,d=false,h=false,zfa=false', '-PythonPath', $PythonPath)
    Invoke-CheckedScript (Join-Path $root 'scripts/test-native-thread-rebuild.ps1') @('-IncludePrivateFutex')
    Invoke-CheckedScript (Join-Path $root 'scripts/test-native-thread-process-regression.ps1') @()
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $PythonPath -m unittest discover -s tests *> (Join-Path $root 'build/native-futex-host-tests.txt')
        if ($LASTEXITCODE -ne 0) { throw 'Host guards failed; evidence not promoted' }
    } finally { $ErrorActionPreference = $previous }
    foreach ($test in @('test_kernel_build_arguments.ps1', 'test_logged_graphics_build.ps1', 'test_graphics_disk_lock.ps1')) {
        Invoke-CheckedScript (Join-Path $root "tests/$test") @()
    }
    & $PythonPath (Join-Path $root 'tools/collect-native-futex-evidence.py')
    if ($LASTEXITCODE -ne 0) { throw 'Evidence collector rejected the matrix' }
} finally { Pop-Location }
Write-Host 'PASS actual private-futex matrix, repeated SMP, rebuild, process regression and host guards'
