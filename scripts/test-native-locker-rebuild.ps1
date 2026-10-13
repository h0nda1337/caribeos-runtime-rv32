# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$kernel=Join-Path $workspace 'xnu-2050.48.11/BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$paths=@('build/caribe_rv32.elf','build/initrd.img','build/initrd-threads.img','build/initrd-futex.img',
    'build/initrd-tcb.img','build/initrd-locker.img','build/native-thread-probe.elf','build/native-futex-probe.elf',
    'build/native-tcb-probe.elf','build/native-locker-probe.elf','build/musl-rv32-sysroot/usr/lib/libc.a',
    'build/freetype-probe.elf','build/freetype-rv32-sysroot/usr/lib/libfreetype.a',
    'build/libcaribe-syllable-native.a','build/libcaribe-syllable-string.a','build/libcaribe-syllable-message.a',
    'build/libcaribe-syllable-locker.a','build/font-sources.json','build/syllable-locker/sources.json')
function Get-Records {
    @([ordered]@{path='xnu'; sha256=(Get-FileHash -LiteralPath $kernel).Hash.ToLowerInvariant()})+
    @($paths | ForEach-Object { [ordered]@{path=$_; sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()} })
}
$before=@(Get-Records)
Push-Location $root
$previous=$ErrorActionPreference
try {
    $ErrorActionPreference='Continue'
    & make -j2 -W scripts/prepare-syllable-locker.py -W userland/native_locker_probe.cpp -W ports/syllable/native/tcb_bootstrap.c -W ports/syllable/native/thread_identity.c -W ports/syllable/native/semaphore.c -W userland/native_tcb_tls.S -W scripts/make-newc-initrd.py build/initrd-locker.img *> (Join-Path $root 'build/native-locker-force-probe.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Forced genuine Locker/adapters compilation or image repack failed' }
} finally { $ErrorActionPreference=$previous; Pop-Location }
$log=(Get-Content -LiteralPath (Join-Path $root 'build/native-locker-force-probe.txt') -Raw).Replace('\','/')
foreach ($marker in @('userland/native_locker_probe.cpp -o build/native_locker_probe.o',
    'ports/syllable/native/tcb_bootstrap.c -o build/syllable_tcb_bootstrap.o',
    'ports/syllable/native/thread_identity.c -o build/syllable_thread_identity.o',
    '-DCARIBE_SYNC_RAW_TCB','-o build/syllable_raw_semaphore.o','-o build/syllable_semaphore.o',
    'userland/native_tcb_tls.S -o build/native_tcb_tls.o',
    'wrote build/initrd.img:','wrote build/initrd-threads.img:','wrote build/initrd-futex.img:',
    'wrote build/initrd-tcb.img:','wrote build/initrd-locker.img:')) {
    if (-not $log.Contains($marker)) { throw "Missing actual forced build marker: $marker" }
}
$after=@(Get-Records)
$same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
$record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'}); before=$before; after=$after; kernelRecompiled=$false;
    forcedUserUnits=@('native_locker_probe.cpp','tcb_bootstrap.c','thread_identity.c','semaphore.c','native_tcb_tls.S');
    recipe='Forced genuine Locker source preparation, probe/adapters/assembly, static links and inherited image repack; kernel unchanged'}
[IO.File]::WriteAllText((Join-Path $root 'build/native-locker-rebuild.json'),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw 'Rebuild differs; preserve v0.11 stable evidence' }
Write-Host "PASS actual Locker source/adapters rebuild; $($after.Count) artifacts byte-identical; no kernel changes"
