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
 if($LASTEXITCODE -ne 0){throw "Dispatch matrix stopped at $Path; last stable profile was not promoted"}
}
Push-Location $root
try {
 & $PythonPath tools/collect-syllable-dispatch-evidence.py --check-looper
 if($LASTEXITCODE -ne 0){throw 'Run the full original Looper UP/SMP/SecureSBI cases first; current hashes are required'}
 $suffix='imacsu-native-sync-e-native-threads-d-futex-d-tcb-c-locker-c-threadapi-c-queue-c-heap-c-freetype-d-looper-c-messenger-c-syllable-message'
 foreach($profile in @(@('opensbi','1','default'),@('opensbi','2','default'),@('securesbi','2',$secure))){
   $case="$($profile[0])-smp$($profile[1])-$suffix"
   $reuse=$false
   if($ReuseVerified -and (Test-Path -LiteralPath "build/graphics-tests/$case/result.json")){
     & $PythonPath tools/collect-syllable-dispatch-evidence.py --check-case $case
     $reuse=$LASTEXITCODE -eq 0
   }
   if(-not $reuse){
     Write-Host "[dispatch matrix] actual boot $($profile[0]) harts=$($profile[1])"
     Invoke-Checked (Join-Path $root 'scripts/qemu-rv32-graphics.ps1') @('-SkipKernelBuild','-Smp',$profile[1],'-Bios',$profile[2],'-SyllableMessenger','-NativeSync','-FreeType','-Cpu','rv32,f=false,d=false,h=false,zfa=false','-PythonPath',$PythonPath)
   }
 }
 Invoke-Checked (Join-Path $root 'scripts/test-syllable-looper-rebuild.ps1') @('-IncludeMessenger')
 $previous=$ErrorActionPreference
 try {
   $ErrorActionPreference='Continue'
   & $PythonPath -m unittest discover -s tests *> build/dispatch-host-tests.txt
   if($LASTEXITCODE -ne 0){throw 'Dispatch host guards failed'}
 } finally {$ErrorActionPreference=$previous}
 foreach($test in @('test_kernel_build_arguments.ps1','test_logged_graphics_build.ps1','test_graphics_disk_lock.ps1')){
   Invoke-Checked (Join-Path $root "tests/$test") @()
 }
 & $PythonPath tools/collect-syllable-dispatch-evidence.py
 if($LASTEXITCODE -ne 0){throw 'Dispatch evidence rejected; do not promote incomplete proof'}
} finally {Pop-Location}
Write-Host 'PASS original toolkit dispatch integration/rebuild matrix; complete AppServer/Desktop and production stability remain unfinished'
