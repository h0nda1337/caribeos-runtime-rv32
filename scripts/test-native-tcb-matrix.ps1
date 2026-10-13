# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([string]$PythonPath='', [string]$SecureBios='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
if (-not $PythonPath) { $PythonPath=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' }
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw 'Specify -PythonPath with Python/Pillow' }
if (-not $SecureBios) { $SecureBios=Join-Path $workspace 'securesbi/build/platform/generic/firmware/fw_dynamic.bin' }
if (-not (Test-Path -LiteralPath $SecureBios -PathType Leaf)) { throw 'Verified SecureSBI firmware required' }
function Invoke-Checked {
    param([string]$Path,[string[]]$Arguments)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -ne 0) { throw "TCB matrix stopped at $Path; prior stable snapshots preserved" }
}
function Save-Repeat {
    param([string]$Name)
    $source=Join-Path $root 'build/graphics-tests/opensbi-smp2-imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-freetype-d-syllable-message'
    $record=Get-Content -LiteralPath (Join-Path $source 'result.json') -Raw | ConvertFrom-Json
    if ($record.result -ne 'PASS' -or $record.smp -ne 2 -or $record.nativeTcb.createdReaped -ne 96) { throw 'Incomplete TCB repeat' }
    $target=Join-Path $root "build/$Name"
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $target -Force
}
$graphics=Join-Path $root 'scripts/qemu-rv32-graphics.ps1'
$common=@('-SkipKernelBuild','-NativeTcb','-NativeSync','-FreeType','-SyllableMessage',
    '-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
Push-Location $root
try {
    Invoke-Checked $graphics (@('-Smp','1')+$common)
    Invoke-Checked $graphics (@('-Smp','2')+$common)
    Save-Repeat 'tcb-smp-repeat-01'
    Invoke-Checked $graphics (@('-Smp','2')+$common)
    Save-Repeat 'tcb-smp-repeat-02'
    Invoke-Checked $graphics (@('-Smp','2')+$common)
    Invoke-Checked $graphics (@('-Smp','2','-Bios',$SecureBios)+$common)
    Invoke-Checked (Join-Path $root 'scripts/test-native-tcb-rebuild.ps1') @()
    $previous=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & $PythonPath -m unittest discover -s tests *> (Join-Path $root 'build/native-tcb-host-tests.txt')
        if ($LASTEXITCODE -ne 0) { throw 'TCB host guards failed; evidence not promoted' }
    } finally { $ErrorActionPreference=$previous }
    foreach ($test in @('test_kernel_build_arguments.ps1','test_logged_graphics_build.ps1','test_graphics_disk_lock.ps1')) {
        Invoke-Checked (Join-Path $root "tests/$test") @()
    }
    & $PythonPath (Join-Path $root 'tools/collect-native-tcb-evidence.py')
    if ($LASTEXITCODE -ne 0) { throw 'TCB evidence collector rejected matrix' }
} finally { Pop-Location }
Write-Host 'PASS actual musl TCB/native TLS matrix, repeated SMP, rebuild and host guards; kernel baseline unchanged'
