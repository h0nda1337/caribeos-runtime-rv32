param(
  [string]$QemuPath = "",
  [string]$Kernel = "build\caribe_rv32.elf",
  [string]$DiskImage = "hfsplus.img",
  [string]$Payload = "payload_virtio_diag.elf",
  [string]$PayloadAddress = "0x88000000",
  [string]$RequireContains = "[virtio-diag]",
  [string]$RequireContains2 = "[virtio] read OK",
  [int]$Port = 5610,
  [int]$PromptTimeoutSeconds = 8,
  [int]$AfterCommandSeconds = 8
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$buildDir = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

function Resolve-ProjectPath([string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $root $Path
}

$kernelPath = Resolve-ProjectPath $Kernel
$diskPath = Resolve-ProjectPath $DiskImage
$payloadPath = Resolve-ProjectPath $Payload

foreach ($path in @($kernelPath, $diskPath, $payloadPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required file: $path"
  }
}

if (-not $QemuPath) {
  $cmd = Get-Command "qemu-system-riscv32.exe" -ErrorAction SilentlyContinue
  if ($cmd) {
    $QemuPath = $cmd.Source
  } else {
    $fallback = "C:\Program Files\qemu\qemu-system-riscv32.exe"
    if (Test-Path -LiteralPath $fallback) {
      $QemuPath = $fallback
    }
  }
}

if (-not $QemuPath -or -not (Test-Path -LiteralPath $QemuPath)) {
  throw "qemu-system-riscv32.exe was not found. Pass -QemuPath or add QEMU to PATH."
}

$stdout = Join-Path $buildDir "disk-smoke.stdout.log"
$stderr = Join-Path $buildDir "disk-smoke.stderr.log"
$serialCapture = Join-Path $buildDir "disk-smoke.serial.log"
Remove-Item -LiteralPath $stdout -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $stderr -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $serialCapture -Force -ErrorAction SilentlyContinue

$qemuArgs = @(
  "-M", "virt",
  "-m", "256",
  "-display", "none",
  "-serial", "tcp:127.0.0.1:$Port,server=on,wait=on",
  "-monitor", "none",
  "-no-reboot",
  "-no-shutdown",
  "-bios", "default",
  "-kernel", $kernelPath,
  "-device", "loader,file=$payloadPath,addr=$PayloadAddress,force-raw=on",
  "-drive", "if=none,file=$diskPath,format=raw,id=vd0",
  "-device", "virtio-blk-device,drive=vd0"
)

$proc = Start-Process `
  -FilePath $QemuPath `
  -ArgumentList $qemuArgs `
  -WindowStyle Hidden `
  -PassThru `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr

$client = $null
$text = ""

try {
  Start-Sleep -Milliseconds 500

  $client = [System.Net.Sockets.TcpClient]::new()
  $client.Connect("127.0.0.1", $Port)
  $stream = $client.GetStream()
  $stream.ReadTimeout = 500
  $stream.WriteTimeout = 500
  $buf = [byte[]]::new(8192)

  $deadline = (Get-Date).AddSeconds($PromptTimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    while ($stream.DataAvailable) {
      $n = $stream.Read($buf, 0, $buf.Length)
      if ($n -gt 0) {
        $text += [Text.Encoding]::ASCII.GetString($buf, 0, $n)
      }
    }
    if ($text -match ">\s*$") {
      break
    }
    Start-Sleep -Milliseconds 100
  }

  $command = "bootelf $PayloadAddress`r`n"
  $bytes = [Text.Encoding]::ASCII.GetBytes($command)
  $stream.Write($bytes, 0, $bytes.Length)

  $deadline = (Get-Date).AddSeconds($AfterCommandSeconds)
  while ((Get-Date) -lt $deadline) {
    while ($stream.DataAvailable) {
      $n = $stream.Read($buf, 0, $buf.Length)
      if ($n -gt 0) {
        $text += [Text.Encoding]::ASCII.GetString($buf, 0, $n)
      }
    }
    Start-Sleep -Milliseconds 100
  }
} finally {
  if ($client) {
    $client.Close()
  }
  if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
  }
}

Set-Content -LiteralPath $serialCapture -Value $text -Encoding ASCII
Write-Output $text

if ($RequireContains -and -not $text.Contains($RequireContains)) {
  throw "Serial output did not contain '$RequireContains'. See $serialCapture and $stderr."
}

if ($RequireContains2 -and -not $text.Contains($RequireContains2)) {
  throw "Serial output did not contain '$RequireContains2'. See $serialCapture and $stderr."
}

Write-Output "QEMU disk smoke test OK."
