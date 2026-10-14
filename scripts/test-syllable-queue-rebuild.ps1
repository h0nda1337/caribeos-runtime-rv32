# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$kernelRoot=Join-Path $workspace 'xnu-2050.48.11'
$env:PATH="$(Join-Path $workspace 'msys64/ucrt64/bin');$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$kernel=Join-Path $kernelRoot 'BUILD/obj/RELEASE_RISCV32/osfmk/RELEASE/xnu-caribeos-rv32-full-stage0.elf'
$baseline=Get-Content -LiteralPath (Join-Path $root 'docs/evidence/syllable-thread-v0.13/rebuild.json') -Raw | ConvertFrom-Json
$paths=@($baseline.after | Where-Object path -ne 'xnu' | ForEach-Object path)+@(
 'build/syllable_queue.o','build/syllable_raw_msgport.o','build/syllable_msgport.o',
 'build/syllable-queue-probe.elf','build/libcaribe-syllable-queue.a','build/initrd-queue.img','build/syllable-queue/sources.json')
function Get-Records {
 @([ordered]@{path='xnu';sha256=(Get-FileHash -LiteralPath $kernel).Hash.ToLowerInvariant()})+
 @($paths | ForEach-Object { [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()} })
}
$before=@(Get-Records)
$previous=$ErrorActionPreference
Push-Location $root
try {
 $ErrorActionPreference='Continue'
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-make-osfmk.ps1') -Target osfmk.filelist -ForceRiscv32Sources 'native_ipc,syscall' *> (Join-Path $root 'build/queue-force-kernel.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native IPC/syscall kernel recompilation failed' }
 & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kernelRoot 'tools/riscv32-link-full-stage0.ps1') -SkipObjectRefresh *> (Join-Path $root 'build/queue-force-link.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Native IPC kernel link failed' }
 & make -j2 -W scripts/prepare-syllable-queue.py -W build/syllable-queue/sources.json -W userland/syllable_queue_probe.cpp -W ports/syllable/native/msgport.c -W scripts/make-newc-initrd.py build/initrd-queue.img *> (Join-Path $root 'build/queue-force-probe.txt')
 if ($LASTEXITCODE -ne 0) { throw 'Original Queue/native adapter/default adapter rebuild failed' }
} finally { $ErrorActionPreference=$previous; Pop-Location }
$kernelLog=Get-Content -LiteralPath (Join-Path $root 'build/queue-force-kernel.txt') -Raw
foreach ($unit in @('native_ipc','syscall')) {
 if ($kernelLog -notmatch "(?m)^CC $unit\.o\r?`$") { throw "No actual kernel recompilation: $unit" }
}
$probeLog=(Get-Content -LiteralPath (Join-Path $root 'build/queue-force-probe.txt') -Raw).Replace('\','/')
foreach ($marker in @('build/syllable-queue/messagequeue.cpp -o build/syllable_queue.o',
 'userland/syllable_queue_probe.cpp -o build/syllable_queue_probe.o','-o build/syllable_raw_msgport.o',
 '-o build/syllable_msgport.o','-DCARIBE_IPC_RAW_THREAD','wrote build/initrd-queue.img:')) {
 if (-not $probeLog.Contains($marker)) { throw "Missing actual Queue rebuild marker: $marker" }
}
$after=@(Get-Records)
$same=($before | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress)
foreach ($row in $baseline.after) {
 if ($row.path -eq 'xnu') { continue }
 if ($row.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $root $row.path)).Hash.ToLowerInvariant()) { throw "Prior v0.13 dependency changed: $($row.path)" }
}
$record=[ordered]@{result=$(if($same){'PASS'}else{'FAIL'});before=$before;after=$after;
 forcedKernelUnits=@('native_ipc','syscall');forcedUserUnits=@('messagequeue.cpp','syllable_queue_probe.cpp','msgport.c');
 priorThreadArtifactsUnchangedExceptKernel=$true;
 recipe='Actual IPC/syscall compile/relink, original MessageQueue and raw/default adapters rebuild; byte-identical current artifacts and preserved v0.13 userland'}
[IO.File]::WriteAllText((Join-Path $root 'build/queue-rebuild.json'),($record | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw 'Queue rebuild differs; preserve last stable checkpoint' }
Write-Host "PASS original Queue and IPC kernel forced rebuild; $($after.Count) artifacts byte-identical; v0.13 userland preserved"
