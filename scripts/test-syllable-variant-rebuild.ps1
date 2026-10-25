# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([string]$PythonPath='')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$env:TEMP=Join-Path $workspace 'tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
if(-not $PythonPath){$PythonPath=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'}
$stable=Get-Content -LiteralPath (Join-Path $root 'docs/evidence/syllable-heap-v0.15/rebuild.json') -Raw | ConvertFrom-Json
$dispatch=Get-Content -LiteralPath (Join-Path $root 'docs/evidence/syllable-dispatch-v0.16/rebuild.json') -Raw | ConvertFrom-Json
$kernel=Join-Path $workspace 'xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$paths=@('build/syllable_variant.o','build/syllable_variant_message.o','build/syllable_variant_probe.o',
 'build/libcaribe-syllable-variant.a','build/syllable-variant/sources.json','build/syllable-variant-probe.elf','build/initrd-variant.img')
function Get-Records {
 @($paths | ForEach-Object {[ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()}})
}
function Assert-Preserved {
 foreach($row in @($stable.after)+@($dispatch.after)) {
   $path=if($row.path -eq 'xnu'){$kernel}else{Join-Path $root $row.path}
   if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $row.sha256){throw "Previously verified artifact changed: $($row.path)"}
 }
}
$lock=New-Object Threading.Mutex($false,'Local\CaribeOS-HFS-Graphics')
$owns=$false
try {
 try {$owns=$lock.WaitOne(0)} catch [Threading.AbandonedMutexException] {$owns=$true}
 if(-not $owns){throw 'Another graphics runner owns the rebuild/run lock'}
 if(@(Get-CimInstance Win32_Process -Filter "name='qemu-system-riscv32.exe'" |
   Where-Object {$_.CommandLine -match '(?i)hfsplus\.img'}).Count){throw 'Finish the active HFS QEMU run before rebuilding'}
 Assert-Preserved
 $before=@(Get-Records)
 Push-Location $root
 try {
   $previous=$ErrorActionPreference
   try {
     $ErrorActionPreference='Continue'
     & $PythonPath scripts/prepare-syllable-variant.py *> build/variant-force-sources.txt
     if($LASTEXITCODE -ne 0){throw 'Original Variant source revalidation failed'}
     # The preparer is intentionally idempotent, so force its output prerequisite.
     & make -j2 -W build/syllable-variant/sources.json -W userland/syllable_variant_probe.cpp -W scripts/make-newc-initrd.py build/initrd-variant.img *> build/variant-force-runtime.txt
     if($LASTEXITCODE -ne 0){throw 'Original Variant forced rebuild failed'}
   } finally {$ErrorActionPreference=$previous}
 } finally {Pop-Location}
 Assert-Preserved
 $compileLog=(Get-Content -LiteralPath (Join-Path $root 'build/variant-force-runtime.txt') -Raw).Replace('\','/')
 foreach($token in @('-c build/syllable-variant/variant.cpp','-c build/syllable-variant/message.cpp','-c userland/syllable_variant_probe.cpp','wrote build/initrd-variant.img:')){
   if(-not $compileLog.Contains($token)){throw "Missing actual Variant forced compilation: $token"}
 }
 $after=@(Get-Records)
 $same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
 $record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'});before=$before;after=$after;
   preservedStableArtifacts=$stable.after.Count;preservedDispatchArtifacts=$dispatch.after.Count;kernelRecompiled=$false;
   forcedRuntimeUnits=@('variant.cpp','message.cpp','syllable_variant_probe.cpp');
   scope='Byte-identical original typed GUI value rebuild; not a desktop promotion'}
 [IO.File]::WriteAllText((Join-Path $root 'build/variant-rebuild.json'),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
 if(-not $same){throw 'Experimental Variant rebuild differs; stable baseline was not promoted'}
 Write-Host "PASS $($after.Count) Variant artifacts byte-identical; $($stable.after.Count) stable and $($dispatch.after.Count) dispatch artifacts preserved"
} finally {
 if($owns){$lock.ReleaseMutex()}
 $lock.Dispose()
}
