# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([switch]$IncludeMessenger)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$env:TEMP=Join-Path $workspace 'tmp'; $env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$baseline=Get-Content -LiteralPath (Join-Path $root 'docs/evidence/syllable-heap-v0.15/rebuild.json') -Raw | ConvertFrom-Json
$kernel=Join-Path $workspace 'xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$paths=@('build/native-cxx-context/eh_globals.o','build/native-cxx-context/eh_alloc.o',
 'build/native-cxx-context/sources.json','build/syllable_cxx_context.o',
 'build/syllable_runtime_looper.o','build/syllable_runtime_handler.o','build/syllable_runtime_filter.o',
 'build/syllable_looper_runtime.o','build/syllable_looper_probe.o',
 'build/libcaribe-syllable-looper.a','build/syllable-looper-runtime/sources.json',
 'build/syllable-looper-probe.elf','build/initrd-looper.img')
if($IncludeMessenger){$paths+=@('build/syllable_messenger.o','build/syllable_delivery_message.o',
 'build/syllable_messenger_probe.o','build/libcaribe-syllable-messenger.a',
 'build/syllable-messenger/sources.json','build/syllable-messenger-probe.elf','build/initrd-messenger.img')}
function Get-Records {
 @($paths | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()} })
}
function Assert-Stable {
 foreach($row in $baseline.after) {
   $path=if($row.path -eq 'xnu'){$kernel}else{Join-Path $root $row.path}
   if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $row.sha256) { throw "Stable v0.15 artifact changed: $($row.path)" }
 }
}
$lock=New-Object Threading.Mutex($false,'Local\CaribeOS-HFS-Graphics')
$owns=$false
try {
 try {$owns=$lock.WaitOne(0)} catch [Threading.AbandonedMutexException] {$owns=$true}
 if(-not $owns){throw 'Another graphics runner owns the rebuild/run lock'}
 if(@(Get-CimInstance Win32_Process -Filter "name='qemu-system-riscv32.exe'" |
     Where-Object {$_.CommandLine -match '(?i)hfsplus\.img'}).Count) {throw 'Finish the active HFS QEMU run before rebuilding'}
 Assert-Stable
 $before=@(Get-Records)
 Push-Location $root
 try {
   $previous=$ErrorActionPreference
   try {
     $ErrorActionPreference='Continue'
     & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native-cxx-context.ps1 *> build/looper-force-gnu.txt
     if($LASTEXITCODE -ne 0){throw 'Original GNU context forced rebuild failed'}
     $arguments=@('-j2','-W','scripts/prepare-syllable-looper-runtime.py','-W','ports/syllable/native/cxx_context.c',
       '-W','ports/syllable/native/looper_runtime.c','-W','userland/syllable_looper_probe.cpp','-W','scripts/make-newc-initrd.py')
     if($IncludeMessenger){$arguments+=@('-W','scripts/prepare-syllable-messenger.py','-W','userland/syllable_messenger_probe.cpp','build/initrd-messenger.img')}
     else {$arguments+='build/initrd-looper.img'}
     & make @arguments *> build/looper-force-runtime.txt
     if($LASTEXITCODE -ne 0){throw 'Original Looper/native context forced rebuild failed'}
   } finally {$ErrorActionPreference=$previous}
 } finally {Pop-Location}
 Assert-Stable
 $after=@(Get-Records)
 $same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
 $record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'});before=$before;after=$after;
   preservedStableArtifacts=$baseline.after.Count;kernelRecompiled=$false;
   forcedGnuUnits=@('eh_globals.cc','eh_alloc.cc');
   forcedRuntimeUnits=@('looper.cpp','handler.cpp','messagefilter.cpp','cxx_context.c','looper_runtime.c','syllable_looper_probe.cpp');
   includesMessenger=[bool]$IncludeMessenger;fullMatrixVerified=$false;scope='Byte-identical experimental userland rebuild; not a desktop promotion'}
 if($IncludeMessenger){$record.forcedRuntimeUnits+=@('messenger.cpp','message.cpp','syllable_messenger_probe.cpp')}
 $receipt=if($IncludeMessenger){'build/dispatch-rebuild.json'}else{'build/looper-rebuild.json'}
 [IO.File]::WriteAllText((Join-Path $root $receipt),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
 if(-not $same){throw 'Experimental Looper rebuild differs; stable v0.15 was not promoted'}
 Write-Host "PASS $($after.Count) experimental Looper artifacts rebuilt byte-identically; $($baseline.after.Count) stable artifacts preserved"
} finally {
 if($owns){$lock.ReleaseMutex()}
 $lock.Dispose()
}
