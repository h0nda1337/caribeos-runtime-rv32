# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspace = (Resolve-Path (Join-Path $root "../..")).Path
$bin = Join-Path $workspace "msys64/ucrt64/bin"
$env:PATH = "$bin;$(Join-Path $workspace 'msys64/usr/bin');$env:PATH"
$build = (Resolve-Path (Join-Path $root "build/freetype-rv32-musl")).Path
$boundary = (Resolve-Path (Join-Path $root "build")).Path + [IO.Path]::DirectorySeparatorChar
if (-not $build.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe generated build path" }
$paths = @("build/caribe_rv32.elf", "build/initrd.img", "build/initrd-fonts.img", "build/freetype-probe.elf",
    "build/freetype-rv32-sysroot/usr/lib/libfreetype.a", "build/libcaribe-syllable-native.a",
    "build/libcaribe-syllable-string.a", "build/libcaribe-syllable-message.a",
    "build/cxx-rv32-sysroot/usr/lib/rv32imac/ilp32/libstdc++.a", "build/font-sources.json")
function Get-Records {
    @($paths | ForEach-Object { [ordered]@{path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $root $_) -Algorithm SHA256).Hash.ToLowerInvariant()} })
}
$before = @(Get-Records)
Push-Location $root
$previous = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & (Join-Path $bin "cmake.exe") --build $build --clean-first --parallel 2 *> build/freetype-force-build.txt
    if ($LASTEXITCODE -ne 0) { throw "Forced FreeType compilation failed" }
    & (Join-Path $bin "cmake.exe") --install $build *> build/freetype-force-install.txt
    if ($LASTEXITCODE -ne 0) { throw "Forced FreeType installation failed" }
    & make -W userland/freetype_probe.c build/freetype-probe.elf build/initrd-fonts.img *> build/freetype-force-probe.txt
    if ($LASTEXITCODE -ne 0) { throw "Forced probe/initrd compilation failed" }
} finally { $ErrorActionPreference = $previous; Pop-Location }
$compiles = [regex]::Matches((Get-Content -LiteralPath (Join-Path $root "build/freetype-force-build.txt") -Raw), "Building C object").Count
$probeLog = (Get-Content -LiteralPath (Join-Path $root "build/freetype-force-probe.txt") -Raw).Replace('\', '/')
if ($compiles -lt 25 -or -not $probeLog.Contains("userland/freetype_probe.c -o build/freetype_probe.o") -or
    -not $probeLog.Contains("wrote build/initrd-fonts.img:")) { throw "Missing actual forced compile/repack evidence" }
$after = @(Get-Records)
$same = ($before | ConvertTo-Json -Depth 8 -Compress) -ceq ($after | ConvertTo-Json -Depth 8 -Compress)
$record = [ordered]@{result = $(if ($same) {"PASS"} else {"FAIL"}); compiledFreeTypeUnits = $compiles;
    recipe = "CMake clean-first (generated build only), forced C probe recompile, font initrd repack";
    before = $before; after = $after}
[IO.File]::WriteAllText((Join-Path $root "build/freetype-rebuild.json"), ($record | ConvertTo-Json -Depth 8) + "`n", (New-Object Text.UTF8Encoding($false)))
if (-not $same) { throw "Forced FreeType rebuild differs; do not publish stale evidence" }
Write-Host "PASS forced recompilation of $compiles FreeType units; 10 artifacts exactly unchanged"
