# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([string]$PythonPath='', [string]$SecureBios='', [switch]$ReuseVerifiedUpAndProgressive)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
if (-not $PythonPath) { $PythonPath=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' }
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw 'Specify Python/Pillow' }
if (-not $SecureBios) { $SecureBios=Join-Path $workspace 'securesbi/build/platform/generic/firmware/fw_dynamic.bin' }
if (-not (Test-Path -LiteralPath $SecureBios -PathType Leaf)) { throw 'Verified SecureSBI firmware required' }
function Invoke-Checked {
 param([string]$Path,[string[]]$Arguments)
 & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
 if ($LASTEXITCODE -ne 0) { throw "Thread matrix stopped at $Path; stable checkpoint preserved" }
}
$fullName='imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-freetype-d-syllable-message'
function Save-Repeat {
 param([string]$Name)
 $source=Join-Path $root "build/graphics-tests/opensbi-smp2-$fullName"
 $record=Get-Content -LiteralPath (Join-Path $source 'result.json') -Raw | ConvertFrom-Json
 if ($record.result -ne 'PASS' -or $record.smp -ne 2 -or $record.syllableThread.createdReaped -ne 146) { throw 'Incomplete Thread repeat' }
 $target=Join-Path $root "build/$Name"
 New-Item -ItemType Directory -Force -Path $target | Out-Null
 Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $target -Force
}
$graphics=Join-Path $root 'scripts/qemu-rv32-graphics.ps1'
$common=@('-SkipKernelBuild','-SyllableThread','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
Push-Location $root
try {
 if ($ReuseVerifiedUpAndProgressive) {
   & $PythonPath (Join-Path $root 'tools/collect-syllable-thread-evidence.py') --check-up-progressive
   if ($LASTEXITCODE -ne 0) { throw 'Current-hash UP/progressive evidence missing' }
 } else {
   foreach ($gate in @('A','B')) {
     Invoke-Checked $graphics (@('-Smp','1','-SyllableThreadGate',$gate,'-LockerGate',$gate,'-TcbGate',$gate,'-FutexGate',$gate,'-ThreadGate',$gate)+$common)
   }
   Invoke-Checked $graphics (@('-Smp','1','-NativeSync','-FreeType','-SyllableMessage')+$common)
 }
 $full=@('-NativeSync','-FreeType','-SyllableMessage')+$common
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Save-Repeat 'threadapi-smp-repeat-01'
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Save-Repeat 'threadapi-smp-repeat-02'
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Invoke-Checked $graphics (@('-Smp','2','-Bios',$SecureBios)+$full)
 Invoke-Checked $graphics @('-SkipKernelBuild','-Smp','1','-DisableNativeThreads','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 Invoke-Checked $graphics @('-SkipKernelBuild','-Smp','1','-DisableNativeFutex','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 Invoke-Checked (Join-Path $root 'scripts/test-syllable-thread-rebuild.ps1') @()
 Invoke-Checked (Join-Path $root 'scripts/test-native-thread-process-regression.ps1') @()
 $previous=$ErrorActionPreference
 try {
   $ErrorActionPreference='Continue'
   & $PythonPath -m unittest discover -s tests *> (Join-Path $root 'build/threadapi-host-tests.txt')
   if ($LASTEXITCODE -ne 0) { throw 'Thread host guards failed' }
 } finally { $ErrorActionPreference=$previous }
 foreach ($test in @('test_kernel_build_arguments.ps1','test_logged_graphics_build.ps1','test_graphics_disk_lock.ps1')) {
   Invoke-Checked (Join-Path $root "tests/$test") @()
 }
 & $PythonPath (Join-Path $root 'tools/collect-syllable-thread-evidence.py')
 if ($LASTEXITCODE -ne 0) { throw 'Thread collector rejected matrix' }
} finally { Pop-Location }
Write-Host 'PASS original Syllable Thread actual UP/SMP/SecureSBI, progressive/default-off, kernel rebuild and fresh process regression'
