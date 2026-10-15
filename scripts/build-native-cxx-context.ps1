# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspace=(Resolve-Path (Join-Path $root '../..')).Path
$python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$clang=Join-Path $workspace 'msys64/ucrt64/bin/clang++.exe'
$gcc=Join-Path $workspace 'msys64/ucrt64/bin/riscv64-unknown-elf-g++.exe'
$temp=Join-Path $workspace 'tmp'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
$env:TEMP=$temp; $env:TMP=$temp; $env:TMPDIR=$temp
Push-Location $root
try {
 & $python scripts/prepare-native-cxx-context.py
 if($LASTEXITCODE -ne 0){throw 'GNU context source verification failed'}
 $compilerInclude=(& $gcc -print-file-name=include).Trim()
 $flags=@('--target=riscv32-unknown-linux-musl','-march=rv32imac_zicsr_zifencei','-mabi=ilp32','-O2','-std=gnu++17',
   '-fno-emulated-tls','-ftls-model=local-exec','-fno-stack-protector','-ffunction-sections','-fdata-sections',
   '-nostdinc','-nostdinc++','-D_GNU_SOURCE','-isystem','build/musl-heap-rv32-sysroot/usr/include',
   '-idirafter',$compilerInclude,'-Ibuild/cxx-rv32-sysroot/usr/include/c++/15.1.0',
   '-Ibuild/cxx-rv32-sysroot/usr/include/c++/15.1.0/riscv32-unknown-linux-musl',
   '-Ithird_party/gcc-15.1.0/libstdc++-v3/libsupc++')
 foreach($unit in @('eh_globals','eh_alloc')){
   $extra=@(); if($unit -eq 'eh_alloc'){$extra=@('-D_GLIBCXX_EH_POOL_STATIC','-D_GLIBCXX_EH_POOL_NOBJS=0')}
   & $clang @flags @extra -c "build/native-cxx-context/$unit.cc" -o "build/native-cxx-context/$unit.o"
   if($LASTEXITCODE -ne 0){throw "Genuine GNU context compilation failed: $unit"}
 }
 Write-Host 'PASS unmodified GNU context units compiled with native ELF TLS; not full GNU threading'
} finally {Pop-Location}
