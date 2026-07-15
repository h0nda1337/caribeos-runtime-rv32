param(
  [ValidateRange(1, 32)]
  [int]$Jobs = 4,
  [switch]$Clean
)

$ErrorActionPreference = "Stop"

function ConvertTo-MsysPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $full = [IO.Path]::GetFullPath($Path)
  $drive = $full.Substring(0, 1).ToLowerInvariant()
  $tail = $full.Substring(2).Replace('\', '/')
  return "/$drive$tail"
}

function Quote-Msys {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.Contains("'")) {
    throw "MSYS path contains an unsupported apostrophe: $Value"
  }
  return "'$Value'"
}

function Assert-Sha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Expected
  )

  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  if ($actual -ne $Expected) {
    throw "SHA-256 mismatch for $Path`: $actual"
  }
}

function Invoke-MsysLogged {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $logMsys = ConvertTo-MsysPath $LogPath
  & $script:Bash -lc "$Command > $(Quote-Msys $logMsys) 2>&1"
  if ($LASTEXITCODE -ne 0) {
    Write-Host "$Description failed. Last log lines:"
    Get-Content -LiteralPath $LogPath -Tail 100 -ErrorAction SilentlyContinue
    throw "$Description failed with exit code $LASTEXITCODE"
  }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workspaceRoot = (Resolve-Path (Join-Path $projectRoot "..\..")).Path
$toolRoot = Join-Path $workspaceRoot "msys64"
$script:Bash = Join-Path $toolRoot "usr\bin\bash.exe"
$ucrtBin = Join-Path $toolRoot "ucrt64\bin"
$usrBin = Join-Path $toolRoot "usr\bin"

if (-not (Test-Path -LiteralPath $script:Bash)) {
  throw "MSYS2 bash not found at $script:Bash"
}
$env:Path = "$ucrtBin;$usrBin;" + $env:Path

foreach ($command in @("riscv64-unknown-elf-gcc", "riscv64-unknown-elf-ar",
    "riscv64-unknown-elf-ranlib", "make", "patch", "tar")) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required build command not found: $command"
  }
}

$version = "5.3"
$patchLevel = 5
$archiveSha256 = "0D5CD86965F869A26CF64F4B71BE7B96F90A3BA8B3D74E27E8E9D9D5550F31BA"
$patches = @(
  @{ Name = "bash53-001"; Sha256 = "1F608434364AF86B9B45C8B0EA3FB3B165FB830D27697E6CDFC7AC17DEE3287F" },
  @{ Name = "bash53-002"; Sha256 = "E385548A00130765EC7938A56FBDCA52447AB41FABC95A25F19ADE527E282001" },
  @{ Name = "bash53-003"; Sha256 = "F245D9C7DC3F5A20D84B53D249334747940936F09DC97E1DCB89FC3AB37D60ED" },
  @{ Name = "bash53-004"; Sha256 = "9591D245045529F32F0812F94180B9D9CE9023F5A765C039B852E5DFC99747D0" },
  @{ Name = "bash53-005"; Sha256 = "CCA1EF52DBBF433BC98E33269B64B2C814028EFE2538BE1E2C9A377DA90BC99D" }
)

$thirdParty = Join-Path $projectRoot "third_party"
$archive = Join-Path $thirdParty "bash-$version.tar.gz"
$source = Join-Path $thirdParty "bash-$version"
$patchDir = Join-Path $thirdParty "bash-$version-patches"
$build = Join-Path $projectRoot "build\bash-rv32"
$sysroot = Join-Path $projectRoot "build\musl-rv32-sysroot"
$output = Join-Path $build "bash"
$configureLog = Join-Path $build "configure.stdout"
$makeLog = Join-Path $build "make.stdout"

New-Item -ItemType Directory -Force -Path $thirdParty, $patchDir, $build | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $sysroot "usr\lib\libc.a"))) {
  & (Join-Path $PSScriptRoot "build-musl-rv32.ps1") -Jobs $Jobs
  if ($LASTEXITCODE -ne 0) {
    throw "musl bootstrap failed"
  }
}

if (-not (Test-Path -LiteralPath $archive)) {
  Write-Host "Downloading GNU Bash $version..."
  Invoke-WebRequest -Uri "https://ftp.gnu.org/pub/gnu/bash/bash-$version.tar.gz" `
    -OutFile $archive
}
Assert-Sha256 $archive $archiveSha256

foreach ($patchInfo in $patches) {
  $patchPath = Join-Path $patchDir $patchInfo.Name
  if (-not (Test-Path -LiteralPath $patchPath)) {
    Invoke-WebRequest `
      -Uri "https://ftp.gnu.org/pub/gnu/bash/bash-$version-patches/$($patchInfo.Name)" `
      -OutFile $patchPath
  }
  Assert-Sha256 $patchPath $patchInfo.Sha256
}
Write-Host "GNU Bash source and patches verified."

if (-not (Test-Path -LiteralPath (Join-Path $source "configure"))) {
  if (Test-Path -LiteralPath $source) {
    throw "Incomplete Bash source directory: $source"
  }
  & tar -xzf $archive -C $thirdParty
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract GNU Bash"
  }
}

$patchHeader = Join-Path $source "patchlevel.h"
$patchText = Get-Content -LiteralPath $patchHeader -Raw
$patchMatch = [regex]::Match($patchText, '(?m)^#define\s+PATCHLEVEL\s+(\d+)')
if (-not $patchMatch.Success) {
  throw "Cannot determine Bash patch level"
}
$currentPatchLevel = [int]$patchMatch.Groups[1].Value
if ($currentPatchLevel -gt $patchLevel) {
  throw "Bash source has unexpected patch level $currentPatchLevel"
}

$sourceMsys = ConvertTo-MsysPath $source
for ($level = $currentPatchLevel + 1; $level -le $patchLevel; $level++) {
  $name = "bash53-{0:D3}" -f $level
  $patchMsys = ConvertTo-MsysPath (Join-Path $patchDir $name)
  Write-Host "Applying $name..."
  & $script:Bash -lc "cd $(Quote-Msys $sourceMsys) && patch -p0 --forward < $(Quote-Msys $patchMsys)"
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply $name"
  }
}

$projectMsys = ConvertTo-MsysPath $projectRoot
$buildMsys = ConvertTo-MsysPath $build
$toolMsys = ConvertTo-MsysPath $toolRoot
$ccMsys = "$projectMsys/scripts/riscv32-musl-gcc.sh"
$hostCcMsys = "$projectMsys/scripts/bash-host-gcc.sh"
$pathPrefix = "export PATH=$toolMsys/ucrt64/bin:$toolMsys/usr/bin:`$PATH; "

& $script:Bash -lc "chmod +x $(Quote-Msys $ccMsys) $(Quote-Msys $hostCcMsys)"
if ($LASTEXITCODE -ne 0) {
  throw "Failed to prepare compiler wrappers"
}

if (-not (Test-Path -LiteralPath (Join-Path $build "Makefile"))) {
  $configureCommand = $pathPrefix +
    "cd $(Quote-Msys $buildMsys); " +
    "CC=$(Quote-Msys $ccMsys) CC_FOR_BUILD=$(Quote-Msys $hostCcMsys) " +
    "AR=riscv64-unknown-elf-ar RANLIB=riscv64-unknown-elf-ranlib " +
    "STRIP=riscv64-unknown-elf-strip " +
    "CFLAGS='-Os -ffunction-sections -fdata-sections' " +
    "$(Quote-Msys "$sourceMsys/configure") " +
    "--build=x86_64-pc-msys --host=riscv32-linux-musl " +
    "--prefix=/usr --bindir=/bin --enable-static-link " +
    "--without-bash-malloc --disable-nls --disable-net-redirections"
  Invoke-MsysLogged $configureCommand $configureLog "GNU Bash configure"
}

if ($Clean) {
  $cleanLog = Join-Path $build "clean.stdout"
  Invoke-MsysLogged ($pathPrefix + "cd $(Quote-Msys $buildMsys); make clean") `
    $cleanLog "GNU Bash clean"
}

$builtins = Join-Path $build "builtins"
New-Item -ItemType Directory -Force -Path $builtins | Out-Null
$pipeHeader = Join-Path $PSScriptRoot "bash-rv32-pipesize.h"
$pipeAux = Join-Path $builtins "psize.aux"
$pipeTarget = Join-Path $builtins "pipesize.h"
Copy-Item -LiteralPath $pipeHeader -Destination $pipeAux -Force
$stamp = Get-Date
(Get-Item -LiteralPath $pipeAux).LastWriteTime = $stamp
Copy-Item -LiteralPath $pipeHeader -Destination $pipeTarget -Force
(Get-Item -LiteralPath $pipeTarget).LastWriteTime = $stamp.AddSeconds(2)

$makeCommand = $pathPrefix +
  "cd $(Quote-Msys $buildMsys); " +
  "make -j$Jobs bash CC=$(Quote-Msys $ccMsys) " +
  "CC_FOR_BUILD=$(Quote-Msys $hostCcMsys) " +
  "AR=riscv64-unknown-elf-ar RANLIB=riscv64-unknown-elf-ranlib"
Invoke-MsysLogged $makeCommand $makeLog "GNU Bash build"

if (-not (Test-Path -LiteralPath $output)) {
  throw "GNU Bash build completed without $output"
}

$readelf = Join-Path $ucrtBin "riscv64-unknown-elf-readelf.exe"
$sizeTool = Join-Path $ucrtBin "riscv64-unknown-elf-size.exe"
& $sizeTool $output
$elfHeader = (& $readelf -h $output) -join "`n"
if ($elfHeader -notmatch 'Class:\s+ELF32' -or
    $elfHeader -notmatch 'Machine:\s+RISC-V' -or
    $elfHeader -notmatch 'Type:\s+EXEC') {
  throw "Unexpected GNU Bash ELF format"
}

$outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash
$drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($projectRoot).Substring(0, 1))
Write-Host "GNU Bash $version.$patchLevel RV32 ready: $output"
Write-Host "SHA-256: $outputHash"
Write-Host ("{0}: free {1:N2} GB" -f $drive.Name, ($drive.Free / 1GB))
