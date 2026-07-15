# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [string]$QemuPath = "",
  [ValidateRange(1, 2)]
  [int]$Smp = 1,
  [ValidateRange(10, 1800)]
  [int]$Seconds = 120,
  [string]$Append = "process-gate-10",
  [string]$DiskImage = "",
  [ValidateRange(0, 65535)]
  [int]$Port = 0,
  [switch]$RequireSmpGateF
)

$ErrorActionPreference = "Stop"

function Join-NativeArguments {
  param([string[]]$ArgsList)

  ($ArgsList | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '"', '\"') + '"'
    } else {
      $_
    }
  }) -join " "
}

function Resolve-ProjectPath {
  param(
    [string]$Root,
    [string]$Path
  )

  if ([IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $Root $Path
}

function Get-AvailableTcpPort {
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  try {
    $listener.Start()
    return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
  } finally {
    $listener.Stop()
  }
}

function Send-SerialBytes {
  param(
    [Net.Sockets.NetworkStream]$Stream,
    [byte[]]$Bytes
  )

  $Stream.Write($Bytes, 0, $Bytes.Length)
  $Stream.Flush()
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$buildDir = Join-Path $root "build"
$elf = Join-Path $buildDir "caribe_rv32.elf"
$disk = if ($DiskImage) {
  Resolve-ProjectPath -Root $root -Path $DiskImage
} else {
  Join-Path $root "hfsplus.img"
}

foreach ($path in @($elf, $disk)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing required boot artifact: $path"
  }
}

if (-not $QemuPath) {
  $command = Get-Command "qemu-system-riscv32.exe" -ErrorAction SilentlyContinue
  if ($command) {
    $QemuPath = $command.Source
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

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $root)
$pathAdds = @(
  (Split-Path -Parent $QemuPath),
  (Join-Path $workspaceRoot "msys64\ucrt64\bin"),
  (Join-Path $workspaceRoot "msys64\usr\bin")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if ($pathAdds.Count -ne 0) {
  $env:PATH = ($pathAdds -join [IO.Path]::PathSeparator) +
              [IO.Path]::PathSeparator + $env:PATH
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$serial = Join-Path $buildDir "serial.log"
$stdout = Join-Path $buildDir "qemu.stdout.log"
$stderr = Join-Path $buildDir "qemu.stderr.log"
Remove-Item -LiteralPath $serial -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $stdout -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $stderr -Force -ErrorAction SilentlyContinue

if ($Port -eq 0) {
  $Port = Get-AvailableTcpPort
}

$qemuArgs = @(
  "-M", "virt",
  "-smp", "$Smp",
  "-m", "256",
  "-display", "none",
  "-serial", "tcp:127.0.0.1:${Port},server=on,wait=on",
  "-monitor", "none",
  "-no-reboot",
  "-no-shutdown",
  "-bios", "default",
  "-kernel", $elf,
  "-drive", "if=none,file=$disk,format=raw,id=vd0",
  "-device", "virtio-blk-device,drive=vd0"
)
if ($Append) {
  $qemuArgs += @("-append", $Append)
}

$proc = Start-Process `
  -FilePath $QemuPath `
  -ArgumentList (Join-NativeArguments $qemuArgs) `
  -WindowStyle Hidden `
  -PassThru `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr

$client = $null
$stream = $null
$text = ""
$failure = $null
$canonicalSent = $false
$rawSent = $false
$signalPromptSeen = $false
$completed = $false
$buffer = [byte[]]::new(8192)
$canonicalInput = [byte[]](99, 97, 114, 105, 98, 120, 127, 101, 13)
$rawInput = [byte[]](88, 89)

try {
  $connectDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min(15, $Seconds))
  while (-not $client -and [DateTime]::UtcNow -lt $connectDeadline) {
    if ($proc.HasExited) {
      throw "QEMU exited before opening its serial TCP endpoint."
    }
    $candidate = [Net.Sockets.TcpClient]::new()
    try {
      $candidate.Connect("127.0.0.1", $Port)
      $candidate.NoDelay = $true
      $client = $candidate
    } catch {
      $candidate.Dispose()
      Start-Sleep -Milliseconds 100
    }
  }
  if (-not $client) {
    throw "Timed out connecting to QEMU serial TCP port $Port."
  }

  $stream = $client.GetStream()
  $stream.WriteTimeout = 2000
  $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    while ($stream.DataAvailable) {
      $count = $stream.Read($buffer, 0, $buffer.Length)
      if ($count -le 0) {
        break
      }
      $text += [Text.Encoding]::ASCII.GetString($buffer, 0, $count)
    }

    if (-not $canonicalSent -and
        $text.Contains("[process-gate-10] type: ")) {
      Start-Sleep -Milliseconds 200
      Send-SerialBytes -Stream $stream -Bytes $canonicalInput
      $canonicalSent = $true
    }
    if (-not $rawSent -and
        $text.Contains("[process-gate-10] raw VMIN=2: ")) {
      Start-Sleep -Milliseconds 200
      Send-SerialBytes -Stream $stream -Bytes $rawInput
      $rawSent = $true
    }
    if ($text.Contains(
        "[process-gate-10] signal-read: blocking without UART input")) {
      $signalPromptSeen = $true
    }

    $gateReady = $text.Contains(
      "[process-gate-10] Gate 10 real blocking UART TTY PASS")
    $stage1Ready =
      $text.Contains("[stage1-caribed] system ready") -and
      $text.Contains("[gnu-bash] PASS arrays loops arithmetic") -and
      $text.Contains("[ld-caribe] dynamic-loader handoff ok") -and
      $text.Contains("[dynamic-probe] main entry reached via ld-caribe") -and
      $text.Contains("[linux] exit status=0")
    $smpReady = -not $RequireSmpGateF -or $text.Contains(
      "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")
    if ($gateReady -and $stage1Ready -and $smpReady) {
      $completed = $true
      break
    }
    if ($proc.HasExited -and -not $stream.DataAvailable) {
      break
    }
    Start-Sleep -Milliseconds 20
  }

  while ($stream.DataAvailable) {
    $count = $stream.Read($buffer, 0, $buffer.Length)
    if ($count -le 0) {
      break
    }
    $text += [Text.Encoding]::ASCII.GetString($buffer, 0, $count)
  }
} catch {
  $failure = $_.Exception
} finally {
  if ($client) {
    $client.Dispose()
  }
  if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
  }
  $proc.WaitForExit(5000) | Out-Null
  [IO.File]::WriteAllText($serial, $text, [Text.Encoding]::ASCII)
}

Write-Output $text
if ($failure) {
  throw "$($failure.Message) See $serial and $stderr."
}

$required = @(
  "[CaribeBootX-RV32]",
  "[ELF] saltando entry=",
  "[XNU-CaribeOS]",
  "[tty] NS16550 RX IRQ",
  "[process-gate-10] empty O_NONBLOCK read returned EAGAIN PASS",
  "[process-gate-10] canonical echo/backspace partial reads FIONREAD PASS",
  "[process-gate-10] noncanonical VMIN=2 read returned XY PASS",
  "[process-gate-10] noncanonical VMIN=0 VTIME=1 timeout returned 0 PASS",
  "[process-gate-10] SIGUSR1 interrupted blocking read with EINTR PASS",
  "[process-gate-10] Gate 10 real blocking UART TTY PASS",
  "[stage1-caribed] system ready",
  "[gnu-bash] PASS arrays loops arithmetic",
  "[dynamic-probe] main entry reached via ld-caribe",
  "[linux] exit status=0"
)
foreach ($marker in $required) {
  if (-not $text.Contains($marker)) {
    throw "TTY interaction test missing marker '$marker'. See $serial and $stderr."
  }
}
if (-not $canonicalSent -or -not $rawSent -or -not $signalPromptSeen) {
  throw "TTY interaction test did not complete all three controlled input phases. See $serial."
}
if ($RequireSmpGateF -and -not $text.Contains(
    "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
  throw "TTY interaction test did not pass SMP Gate F. See $serial."
}
if (-not $completed) {
  throw "TTY interaction test timed out before complete Gate 10 and stage1 evidence. See $serial."
}
if ($text -match '(?m)(\[process-gate-10\] FAIL|panic\(cpu|scause=|stval=|sepc=)') {
  throw "TTY interaction test saw a Gate 10 failure, panic, or unexpected trap. See $serial."
}

Write-Output "QEMU TTY interaction test OK."
