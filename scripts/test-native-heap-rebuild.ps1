# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$kernelRoot=Join-Path $workspace 'xnu-2050.48.11'
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$kernel=Join-Path $kernelRoot 'BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$baseline=Get-Content -LiteralPath (Join-Path $root 'docs/evidence/syllable-queue-v0.14/rebuild.json') -Raw | ConvertFrom-Json
$paths=@($baseline.after | Where-Object path -ne 'xnu' | ForEach-Object path)+@(
 'build/native-heap-probe.elf','build/initrd-heap.img','build/musl-heap-rv32-sysroot/usr/lib/libc.a',
 'build/musl-heap-source/sources.json','build/syllable_heap_runtime.o','build/native_heap_lock_probe.o','build/native_heap_probe.o')
function Get-Records {
 @([ordered]@{path='xnu';sha256=(Get-FileHash -LiteralPath $kernel).Hash.ToLowerInvariant()})+
 @($paths | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()} })
}
$before=@(Get-Records)
$previous=$ErrorActionPreference
Push-Location $root
try {
 $ErrorActionPreference='Continue'
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-make-osfmk.ps1') -Target osfmk.filelist -ForceRiscv32Sources 'native_thread,linux_syscall,syscall' *> (Join-Path $root 'build/heap-force-kernel.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native allocator kernel recompilation failed' }
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-link-full-stage0.ps1') -SkipObjectRefresh *> (Join-Path $root 'build/heap-force-link.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native allocator kernel link failed' }
 & bash scripts/test-musl-heap-force.sh *> (Join-Path $root 'build/heap-force-musl.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Genuine musl allocator/lock/VM forced rebuild failed' }
 & make -j2 -W userland/native_heap_probe.cpp -W userland/native_heap_lock_probe.c -W ports/syllable/native/heap_runtime.c -W scripts/make-newc-initrd.py build/initrd-heap.img *> (Join-Path $root 'build/heap-force-probe.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native heap probe/adapter/image forced rebuild failed' }
} finally { $ErrorActionPreference=$previous; Pop-Location }
$kernelLog=Get-Content -LiteralPath (Join-Path $root 'build/heap-force-kernel.txt') -Raw
foreach ($unit in @('native_thread','linux_syscall','syscall')) {
 if ($kernelLog -notmatch "(?m)^CC $unit\.o\r?`$") { throw "No actual kernel recompilation: $unit" }
}
$muslLog=(Get-Content -LiteralPath (Join-Path $root 'build/heap-force-musl.txt') -Raw).Replace('\','/')
foreach ($marker in @('src/malloc/mallocng/malloc.c','src/malloc/mallocng/free.c','src/malloc/mallocng/realloc.c','src/thread/__lock.c','src/mman/mmap.c','src/mman/munmap.c')) {
 if (-not $muslLog.Contains($marker)) { throw "Missing genuine musl rebuild: $marker" }
}
$probeLog=(Get-Content -LiteralPath (Join-Path $root 'build/heap-force-probe.txt') -Raw).Replace('\','/')
foreach ($marker in @('userland/native_heap_probe.cpp -o build/native_heap_probe.o',
 'userland/native_heap_lock_probe.c -o build/native_heap_lock_probe.o','ports/syllable/native/heap_runtime.c -o build/syllable_heap_runtime.o',
 '--wrap=malloc','wrote build/initrd-heap.img:')) {
 if (-not $probeLog.Contains($marker)) { throw "Missing actual heap rebuild: $marker" }
}
$after=@(Get-Records)
$same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
foreach ($row in $baseline.after) {
 if ($row.path -eq 'xnu') { continue }
 if ($row.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $root $row.path)).Hash.ToLowerInvariant()) { throw "Prior v0.14 userland changed: $($row.path)" }
}
$record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'});before=$before;after=$after;
 forcedKernelUnits=@('native_thread','linux_syscall','syscall');
 forcedMuslUnits=@('malloc/mallocng/malloc.c','malloc/mallocng/free.c','malloc/mallocng/realloc.c','thread/__lock.c','mman/mmap.c','mman/munmap.c');
 forcedUserUnits=@('native_heap_probe.cpp','native_heap_lock_probe.c','heap_runtime.c');
 priorQueueArtifactsUnchangedExceptKernel=$true}
[IO.File]::WriteAllText((Join-Path $root 'build/heap-rebuild.json'),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw 'Heap rebuild differs; preserve prior stable checkpoint' }
Write-Host "PASS actual kernel/musl/heap forced rebuild; $($after.Count) artifacts byte-identical; v0.14 userland unchanged"
