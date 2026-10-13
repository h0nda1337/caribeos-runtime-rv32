# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
param([ValidateRange(1, 4)][int]$Jobs = 2)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.Replace('\', '/')
$workspace = (Resolve-Path (Join-Path $root "../..")).Path.Replace('\', '/')
$bin = "$workspace/msys64/ucrt64/bin"
$env:PATH = "$bin;$workspace/msys64/usr/bin;$env:PATH"
$temp = "$root/tmp/freetype"
New-Item -ItemType Directory -Force -Path $temp | Out-Null
$env:TEMP = $env:TMP = $env:TMPDIR = $temp
$python = Join-Path $env:USERPROFILE ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
if (-not (Test-Path -LiteralPath $python)) { $python = (Get-Command python).Source }
& $python "$PSScriptRoot/prepare-font-deps.py"
if ($LASTEXITCODE -ne 0) { throw "Font dependency verification failed" }
$sysroot = "$root/build/musl-rv32-sysroot/usr"
if (-not (Test-Path -LiteralPath "$sysroot/lib/libc.a")) { throw "Build musl RV32 first" }
$source = "$root/third_party/freetype-2.15.0"
$build = "$root/build/freetype-rv32-musl"
$install = "$root/build/freetype-rv32-sysroot/usr"
$flags = "-march=rv32imac_zicsr_zifencei -mabi=ilp32 -fno-stack-protector -nostdinc -isystem $sysroot/include -ffunction-sections -fdata-sections -ffile-prefix-map=$root=."
$args = @("-S", $source, "-B", $build, "-G", "Ninja",
    "-DCMAKE_SYSTEM_NAME=Generic", "-DCMAKE_SYSTEM_PROCESSOR=riscv32",
    "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY", "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_C_COMPILER=$bin/riscv64-unknown-elf-gcc.exe",
    "-DCMAKE_AR=$bin/riscv64-unknown-elf-ar.exe", "-DCMAKE_RANLIB=$bin/riscv64-unknown-elf-ranlib.exe",
    "-DCMAKE_C_FLAGS=$flags", "-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG",
    "-DCMAKE_INSTALL_PREFIX=$install", "-DCMAKE_INSTALL_LIBDIR=lib",
    "-DBUILD_SHARED_LIBS=OFF", "-DFT_DYNAMIC_HARFBUZZ=OFF")
foreach ($name in @("ZLIB", "BZIP2", "PNG", "HARFBUZZ", "BROTLI", "HVF")) { $args += "-DFT_DISABLE_$name=ON" }
& "$bin/cmake.exe" @args
if ($LASTEXITCODE -ne 0) { throw "FreeType cross configuration failed" }
& "$bin/cmake.exe" --build $build --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw "FreeType RV32-musl compilation failed" }
& "$bin/cmake.exe" --install $build
if ($LASTEXITCODE -ne 0) { throw "FreeType sysroot installation failed" }
Write-Host "PASS authentic FreeType static RV32-musl: $install/lib/libfreetype.a"
