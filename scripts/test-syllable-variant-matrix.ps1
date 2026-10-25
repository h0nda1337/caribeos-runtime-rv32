# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([switch]$ReuseVerified,[string]$PythonPath='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
if(-not $PythonPath){$PythonPath=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
$env:TEMP=Join-Path $workspace 'tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
$secure=Join-Path $workspace 'securesbi/build/platform/generic/firmware/fw_dynamic.bin'
if(-not (Test-Path -LiteralPath $secure -PathType Leaf)){throw 'Verified SecureSBI firmware required'}
function Invoke-Checked {
 param([string]$Path,[string[]]$Arguments)
 & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
 if($LASTEXITCODE -ne 0){throw "Variant matrix stopped at $Path; stable baseline was not promoted"}
}
function Test-Reusable {
 param([string]$Case)
 if(-not $ReuseVerified -or -not (Test-Path -LiteralPath "build/graphics-tests/$Case/result.json")){return $false}
 & $PythonPath tools/collect-syllable-variant-evidence.py --check-case $Case | Out-Host
 return $LASTEXITCODE -eq 0
}
Push-Location $root
try {
 foreach($gate in @('A','B')){
   $case="opensbi-smp1-imacsu-native-threads-a-futex-a-tcb-a-locker-a-threadapi-a-queue-a-heap-a-looper-a-messenger-a-variant-$($gate.ToLowerInvariant())-syllable-message"
   if(-not (Test-Reusable $case)){
     Write-Host "[variant matrix] actual progressive UP gate $gate"
     Invoke-Checked (Join-Path $root 'scripts/qemu-rv32-graphics.ps1') @('-SkipKernelBuild','-Smp','1','-SyllableVariant','-VariantGate',$gate,
       '-MessengerGate','A','-LooperGate','A','-HeapGate','A','-QueueGate','A','-SyllableThreadGate','A',
       '-LockerGate','A','-TcbGate','A','-FutexGate','A','-ThreadGate','A','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
   }
 }
 $suffix='imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c-freetype-d-looper-c-messenger-c-variant-c-syllable-message'
 foreach($profile in @(@('opensbi','1','default'),@('opensbi','2','default'),@('securesbi','2',$secure))){
   $case="$($profile[0])-smp$($profile[1])-$suffix"
   if(-not (Test-Reusable $case)){
     Write-Host "[variant matrix] actual full $($profile[0]) harts=$($profile[1])"
     Invoke-Checked (Join-Path $root 'scripts/qemu-rv32-graphics.ps1') @('-SkipKernelBuild','-Smp',$profile[1],'-Bios',$profile[2],
       '-SyllableVariant','-NativeSync','-FreeType','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
   }
 }
 Invoke-Checked (Join-Path $root 'scripts/test-syllable-variant-rebuild.ps1') @('-PythonPath',$PythonPath)
 $previous=$ErrorActionPreference
 try {
   $ErrorActionPreference='Continue'
   & $PythonPath -m unittest discover -s tests *> build/variant-host-tests.txt
   if($LASTEXITCODE -ne 0){throw 'Variant host guards failed'}
 } finally {$ErrorActionPreference=$previous}
 foreach($test in @('test_kernel_build_arguments.ps1','test_logged_graphics_build.ps1','test_graphics_disk_lock.ps1')){
   Invoke-Checked (Join-Path $root "tests/$test") @()
 }
 & $PythonPath tools/collect-syllable-variant-evidence.py
 if($LASTEXITCODE -ne 0){throw 'Variant evidence rejected; incomplete proof was not promoted'}
} finally {Pop-Location}
Write-Host 'PASS original typed GUI value runtime/rebuild matrix; complete Application/AppServer/Desktop remains unfinished'
