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
 if ($LASTEXITCODE -ne 0) { throw "Heap matrix stopped at $Path; prior stable checkpoint preserved" }
}
$suffix='imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c-freetype-d-syllable-message'
function Save-Repeat {
 param([string]$Name)
 $source=Join-Path $root "build/graphics-tests/opensbi-smp2-$suffix"
 $record=Get-Content -LiteralPath (Join-Path $source 'result.json') -Raw | ConvertFrom-Json
 if ($record.result -ne 'PASS' -or $record.smp -ne 2 -or -not $record.nativeHeap.enabled) { throw 'Incomplete heap repeat' }
 $target=Join-Path $root "build/$Name"
 New-Item -ItemType Directory -Force -Path $target | Out-Null
 Get-ChildItem -LiteralPath $source -File | Copy-Item -Destination $target -Force
}
$graphics=Join-Path $root 'scripts/qemu-rv32-graphics.ps1'
$common=@('-SkipKernelBuild','-SyllableHeap','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
Push-Location $root
try {
 if ($ReuseVerifiedUpAndProgressive) {
   & $PythonPath (Join-Path $root 'tools/collect-native-heap-evidence.py') --check-up-progressive
   if ($LASTEXITCODE -ne 0) { throw 'Current-hash heap UP/progressive proof missing' }
 } else {
   foreach ($gate in @('A','B')) {
     Invoke-Checked $graphics (@('-Smp','1','-HeapGate',$gate,'-QueueGate',$gate,'-SyllableThreadGate',$gate,'-LockerGate',$gate,'-TcbGate',$gate,'-FutexGate',$gate,'-ThreadGate',$gate)+$common)
   }
   Invoke-Checked $graphics (@('-Smp','1','-NativeSync','-FreeType')+$common)
 }
 $full=@('-NativeSync','-FreeType')+$common
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Save-Repeat 'heap-smp-repeat-01'
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Save-Repeat 'heap-smp-repeat-02'
 Invoke-Checked $graphics (@('-Smp','2')+$full)
 Invoke-Checked $graphics (@('-Smp','2','-Bios',$SecureBios)+$full)
 foreach ($smp in @('1','2')) {
   Invoke-Checked $graphics @('-SkipKernelBuild','-Smp',$smp,'-SyllableQueue','-NativeSync','-FreeType','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 }
 Invoke-Checked $graphics @('-SkipKernelBuild','-Smp','1','-DisableNativeThreads','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 Invoke-Checked $graphics @('-SkipKernelBuild','-Smp','1','-DisableNativeFutex','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 Invoke-Checked $graphics @('-SkipKernelBuild','-Smp','1','-DisableNativeHeap','-NativeSync','-FreeType','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
 Invoke-Checked (Join-Path $root 'scripts/test-native-heap-rebuild.ps1') @()
 Invoke-Checked (Join-Path $root 'scripts/test-native-thread-process-regression.ps1') @()
 $previous=$ErrorActionPreference
 try {
   $ErrorActionPreference='Continue'
   & $PythonPath -m unittest discover -s tests *> (Join-Path $root 'build/heap-host-tests.txt')
   if ($LASTEXITCODE -ne 0) { throw 'Heap host guards failed' }
 } finally { $ErrorActionPreference=$previous }
 foreach ($test in @('test_kernel_build_arguments.ps1','test_logged_graphics_build.ps1','test_graphics_disk_lock.ps1')) {
   Invoke-Checked (Join-Path $root "tests/$test") @()
 }
 & $PythonPath (Join-Path $root 'tools/collect-native-heap-evidence.py')
 if ($LASTEXITCODE -ne 0) { throw 'Heap collector rejected matrix' }
} finally { Pop-Location }
Write-Host 'PASS genuine worker allocator/Message/ReadPort, deferred cancellation/critical owner teardown, actual full matrix/rebuild/fresh processes'
