param(
  [string]$ZigPath = "",
  [string]$Output = "payload_hfsplus_boot.elf"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir

if (-not $ZigPath) {
  $cmd = Get-Command "zig.exe" -ErrorAction SilentlyContinue
  if ($cmd) {
    $ZigPath = $cmd.Source
  } else {
    $searchRoots = @(
      (Split-Path -Parent $root),
      (Split-Path -Parent (Split-Path -Parent $root))
    )
    foreach ($searchRoot in $searchRoots) {
      $local = Join-Path $searchRoot "tools\python\ziglang\zig.exe"
      if (Test-Path -LiteralPath $local) {
        $ZigPath = $local
        break
      }
    }
  }
}

if (-not $ZigPath -or -not (Test-Path -LiteralPath $ZigPath)) {
  throw "zig.exe was not found. Pass -ZigPath or install the ziglang Python package into ..\tools\python."
}

$outPath = if ([System.IO.Path]::IsPathRooted($Output)) {
  $Output
} else {
  Join-Path $root $Output
}

Push-Location $root
try {
  & $ZigPath cc `
    -target riscv32-freestanding `
    -mabi=ilp32 `
    -fno-sanitize=undefined `
    -fno-stack-protector `
    -nostdlib `
    -ffreestanding `
    -static `
    "-Wl,--gc-sections" `
    "-Wl,-T,rv32_payload.ld" `
    "-Wl,-e,payload_entry" `
    payload_hfsplus_boot.c `
    virtio_blk_legacy.c `
    -o $outPath
} finally {
  Pop-Location
}

Write-Output "Built $outPath"
