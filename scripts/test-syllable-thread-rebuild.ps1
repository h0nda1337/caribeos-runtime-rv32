# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$kernelRoot=Join-Path $workspace 'xnu-2050.48.11'
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$kernel=Join-Path $kernelRoot 'BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$paths=@('build/caribe_rv32.elf','build/initrd.img','build/initrd-threads.img','build/initrd-futex.img',
 'build/initrd-tcb.img','build/initrd-locker.img','build/initrd-threadapi.img',
 'build/native-thread-probe.elf','build/native-futex-probe.elf','build/native-tcb-probe.elf',
 'build/native-locker-probe.elf','build/syllable-thread-probe.elf','build/musl-rv32-sysroot/usr/lib/libc.a',
 'build/freetype-probe.elf','build/freetype-rv32-sysroot/usr/lib/libfreetype.a',
 'build/libcaribe-syllable-native.a','build/libcaribe-syllable-string.a','build/libcaribe-syllable-message.a',
 'build/libcaribe-syllable-locker.a','build/libcaribe-syllable-thread.a',
 'build/font-sources.json','build/syllable-locker/sources.json','build/syllable-thread/sources.json')
function Get-Records {
 @([ordered]@{path='xnu';sha256=(Get-FileHash -LiteralPath $kernel).Hash.ToLowerInvariant()})+
 @($paths | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()} })
}
$before=@(Get-Records)
$previous=$ErrorActionPreference
Push-Location $root
try {
 $ErrorActionPreference='Continue'
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-make-osfmk.ps1') -Target osfmk.filelist -ForceRiscv32Sources native_thread *> (Join-Path $root 'build/threadapi-force-kernel.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native clock/sleep kernel recompilation failed' }
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-link-full-stage0.ps1') -SkipObjectRefresh *> (Join-Path $root 'build/threadapi-force-link.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native clock/sleep kernel link failed' }
 & make -j2 -W scripts/prepare-syllable-thread.py -W build/syllable-thread/sources.json -W userland/syllable_thread_probe.cpp -W ports/syllable/native/thread_runtime.c -W ports/syllable/native/tcb_bootstrap.c -W ports/syllable/native/thread_identity.c -W ports/syllable/native/semaphore.c -W userland/native_tcb_tls.S -W scripts/make-newc-initrd.py build/initrd-threadapi.img *> (Join-Path $root 'build/threadapi-force-probe.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Original Thread/adapters forced rebuild failed' }
} finally { $ErrorActionPreference=$previous; Pop-Location }
$kernelLog=Get-Content -LiteralPath (Join-Path $root 'build/threadapi-force-kernel.txt') -Raw
if ($kernelLog -notmatch '(?m)^CC native_thread\.o\r?$') { throw 'No actual native_thread recompilation' }
$probeLog=(Get-Content -LiteralPath (Join-Path $root 'build/threadapi-force-probe.txt') -Raw).Replace('\','/')
foreach ($marker in @('build/syllable-thread/thread.cpp -o build/syllable_thread.o',
 'userland/syllable_thread_probe.cpp -o build/syllable_thread_probe.o',
 'ports/syllable/native/thread_runtime.c -o build/syllable_thread_runtime.o',
 '-DCARIBE_SYNC_NATIVE_CLOCK','-o build/syllable_thread_semaphore.o',
 'userland/native_tcb_tls.S -o build/native_tcb_tls.o','wrote build/initrd-threadapi.img:')) {
 if (-not $probeLog.Contains($marker)) { throw "Missing actual Thread rebuild marker: $marker" }
}
$after=@(Get-Records)
$same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
$record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'});before=$before;after=$after;
 forcedKernelUnits=@('native_thread');forcedUserUnits=@('thread.cpp','syllable_thread_probe.cpp','thread_runtime.c','tcb_bootstrap.c','thread_identity.c','semaphore.c','native_tcb_tls.S');
 recipe='Actual native_thread kernel compilation/relink and original Thread/adapters/TLS/image rebuild; dependency and kernel artifacts byte-identical'}
[IO.File]::WriteAllText((Join-Path $root 'build/threadapi-rebuild.json'),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw 'Thread rebuild differs; preserve last stable checkpoint' }
Write-Host "PASS original Thread and native kernel clock/sleep forced rebuild; $($after.Count) artifacts byte-identical"
