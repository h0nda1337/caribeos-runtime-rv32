# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [string]$QemuPath = "",
  [ValidateSet(11, 12, 13, 14, 15)]
  [int]$Gate = 11,
  [ValidateRange(1, 2)]
  [int]$Smp = 1,
  [ValidateRange(20, 1800)]
  [int]$Seconds = 180,
  [string]$Append = "",
  [string]$DiskImage = "",
  [ValidateRange(0, 65535)]
  [int]$Port = 0,
  [ValidateRange(0, 65535)]
  [int]$MonitorPort = 0,
  [ValidateSet(0, 10, 100, 1000, 10000)]
  [int]$StressRounds = 0,
  [switch]$RequireSmpGateF
)

$ErrorActionPreference = "Stop"

if (-not $Append) {
  $Append = switch ($Gate) {
    12 { "process-gate-11 process-gate-12" }
    13 { "process-gate-11 process-gate-13" }
    14 { "smp-start smp-gate-f process-gate-11 process-gate-14" }
    15 { "process-gate-11 process-gate-15" }
    default { "process-gate-11" }
  }
}
if ($StressRounds -gt 0) {
  if ($Gate -ne 14 -or $Smp -ne 2) {
    throw "Gate 14 stress requires -Gate 14 -Smp 2."
  }
  if ($Append -notmatch 'process-gate-14-stress') {
    $Append += " process-gate-14-stress-$StressRounds"
  }
}

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

function Send-SerialLine {
  param(
    [Net.Sockets.NetworkStream]$Stream,
    [string]$Line
  )

  $bytes = [Text.Encoding]::ASCII.GetBytes($Line + "`r")
  $Stream.Write($bytes, 0, $bytes.Length)
  $Stream.Flush()
}

function Send-SerialByte {
  param(
    [Net.Sockets.NetworkStream]$Stream,
    [ValidateRange(0, 255)]
    [int]$Value
  )

  $bytes = [byte[]]@($Value)
  $Stream.Write($bytes, 0, 1)
  $Stream.Flush()
}

function Send-SerialText {
  param(
    [Net.Sockets.NetworkStream]$Stream,
    [string]$Value
  )

  $bytes = [Text.Encoding]::ASCII.GetBytes($Value)
  for ($offset = 0; $offset -lt $bytes.Length; $offset += 64) {
    $count = [Math]::Min(64, $bytes.Length - $offset)
    $Stream.Write($bytes, $offset, $count)
    $Stream.Flush()
    Start-Sleep -Milliseconds 2
  }
}

function Convert-ResourceSnapshot {
  param([string]$Line)

  $snapshot = [Collections.Generic.Dictionary[string, uint64]]::new()
  foreach ($token in ($Line.Trim() -split ' ')) {
    $parts = $token -split '=', 2
    if ($parts.Count -ne 2 -or $parts[0].Length -eq 0 -or
        $parts[1] -notmatch '^[0-9]+$') {
      throw "Malformed /proc/caribe/resources token '$token'."
    }
    $snapshot.Add($parts[0], [uint64]$parts[1])
  }
  if (-not $snapshot.ContainsKey('version') -or $snapshot['version'] -ne 1) {
    throw "Unsupported /proc/caribe/resources snapshot version."
  }
  return $snapshot
}

function Get-OccurrenceCount {
  param(
    [string]$Text,
    [string]$Needle
  )

  return [regex]::Matches($Text, [regex]::Escape($Needle)).Count
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
$serialWriter = [IO.StreamWriter]::new(
  $serial, $false, [Text.Encoding]::ASCII, 8192)
$serialWriter.AutoFlush = $true

if ($Port -eq 0) {
  $Port = Get-AvailableTcpPort
}
$monitorTarget = if ($MonitorPort -eq 0) {
  "none"
} else {
  "tcp:127.0.0.1:${MonitorPort},server=on,wait=off"
}

$qemuArgs = @(
  "-M", "virt",
  "-smp", "$Smp",
  "-m", "256",
  "-display", "none",
  "-serial", "tcp:127.0.0.1:${Port},server=on,wait=on",
  "-monitor", $monitorTarget,
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

$gate11Steps = @(
  [pscustomobject]@{
    Command = 'echo hola'
    Patterns = @('(?m)^hola$')
  },
  [pscustomobject]@{
    Command = 'pwd'
    Patterns = @('(?m)^/$')
  },
  [pscustomobject]@{
    Command = 'CARIBE_KEEP=alive'
    Patterns = @()
  },
  [pscustomobject]@{
    Command = 'echo $CARIBE_KEEP'
    Patterns = @('(?m)^alive$')
  },
  [pscustomobject]@{
    Command = 'cd /usr'
    Patterns = @()
  },
  [pscustomobject]@{
    Command = 'pwd'
    Patterns = @('(?m)^/usr$')
  },
  [pscustomobject]@{
    Command = 'true'
    Patterns = @()
  },
  [pscustomobject]@{
    Command = 'false'
    Patterns = @()
  },
  [pscustomobject]@{
    Command = 'echo $?'
    Patterns = @('(?m)^1$')
  },
  [pscustomobject]@{
    Command = '/bin/caribectl'
    Patterns = @(
      '(?m)^\[stage1-caribectl\] execve target reached$',
      '(?m)^\[stage1-caribectl\] clone/wait4 real child task ok$',
      '(?m)^\[stage1-caribectl\] done$'
    )
  },
  [pscustomobject]@{
    Command = 'echo $?'
    Patterns = @('(?m)^0$')
  },
  [pscustomobject]@{
    Command = '/bin/caribectl ; echo terminado'
    Patterns = @(
      '(?m)^\[stage1-caribectl\] done$',
      '(?m)^terminado$'
    )
  }
)

$gate12Steps = @(
  [pscustomobject]@{
    Command = 'echo gate12-ready'
    Patterns = @('(?m)^gate12-ready$')
  },
  [pscustomobject]@{
    Command = '/bin/pipeline-producer | /bin/pipeline-consumer'
    Patterns = @(
      '(?m)^\[pipeline-consumer\] bytes=12288 checksum=1566720 pattern=sequential PASS$'
    )
  },
  [pscustomobject]@{
    Command = 'echo $?'
    Patterns = @('(?m)^0$')
  },
  [pscustomobject]@{
    Command = '/bin/caribectl >/dev/null ; echo sink=$?'
    Patterns = @('(?m)^sink=0$')
  },
  [pscustomobject]@{
    Command = '/bin/pipeline-consumer --text < /usr/lib/caribe.note'
    Patterns = @(
      '(?m)^\[pipeline-consumer\] redirected input bytes=65 PASS$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/pipeline-producer --stderr 2>&1'
    Patterns = @(
      '(?m)^\[pipeline-producer\] stderr redirection PASS$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/pipeline-sigpipe ; echo sigpipe=$?'
    Patterns = @(
      '(?m)^\[pipeline-sigpipe\] default disposition armed PASS$',
      '(?m)^sigpipe=141$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/pipeline-producer | /bin/pipeline-consumer ; echo pipeline-again=$?'
    Patterns = @(
      '(?m)^\[pipeline-consumer\] bytes=12288 checksum=1566720 pattern=sequential PASS$',
      '(?m)^pipeline-again=0$'
    )
  },
  [pscustomobject]@{
    Command = 'echo gate12-finished'
    Patterns = @('(?m)^gate12-finished$')
  }
)

$gate13Steps = @(
  [pscustomobject]@{
    Command = 'echo gate13-ready'
    Patterns = @('(?m)^gate13-ready$')
  },
  [pscustomobject]@{
    Command = '/bin/jobctl-wait'
    Patterns = @(
      '(?m)^\[jobctl-wait\] pid=([0-9]+) pgid=\1 foreground=\1 blocking-read PASS$',
      '\[process-gate-13\] TTY VSUSP -> SIGTSTP foreground-pgid=',
      '\[process-gate-13\] default SIGTSTP stopped pid=',
      '\[process-gate-13\] waitid observed child=.*code=CLD_STOPPED status=20 PASS'
    )
    ControlPattern = '\[jobctl-wait\].*blocking-read PASS'
    ControlByte = 26
  },
  [pscustomobject]@{
    Command = 'jobs'
    Patterns = @('(?m)^\[[0-9]+\].*Stopped.*jobctl-wait.*$')
  },
  [pscustomobject]@{
    Command = 'fg'
    Patterns = @(
      '\[process-gate-13\] SIGCONT resumed pid=',
      '\[process-gate-13\] kill process-group pgid=.*signal=18 targets=1 PASS',
      '\[process-gate-13\] waitid observed child=.*code=CLD_CONTINUED status=18 PASS',
      '(?m)^\[jobctl-wait\] resumed after SIGCONT; blocking-read PASS$',
      '\[process-gate-13\] TTY VINTR -> SIGINT foreground-pgid=',
      '\[process-gate-13\] default SIGINT terminating pid='
    )
    ControlPattern = '\[jobctl-wait\] resumed after SIGCONT; blocking-read PASS'
    ControlByte = 3
  },
  [pscustomobject]@{
    Command = 'echo interrupt-status=$?'
    Patterns = @('(?m)^interrupt-status=130$')
  },
  [pscustomobject]@{
    Command = '/bin/jobctl-wait'
    Patterns = @(
      '(?m)^\[jobctl-wait\] pid=([0-9]+) pgid=\1 foreground=\1 blocking-read PASS$',
      '\[process-gate-13\] TTY VQUIT -> SIGQUIT foreground-pgid=',
      '\[process-gate-13\] default SIGQUIT terminating pid='
    )
    ControlPattern = '\[jobctl-wait\].*blocking-read PASS'
    ControlByte = 28
  },
  [pscustomobject]@{
    Command = 'echo quit-status=$?'
    Patterns = @('(?m)^quit-status=131$')
  },
  [pscustomobject]@{
    Command = 'echo gate13-finished'
    Patterns = @('(?m)^gate13-finished$')
  }
)

$gate14Steps = @(
  [pscustomobject]@{
    Command = 'echo gate14-ready'
    Patterns = @('(?m)^gate14-ready$')
  },
  [pscustomobject]@{
    Command = '/bin/cpu1-probe'
    Patterns = @(
      '\[process-gate-14\] child pid=([0-9]+) parent=2 bound-cpu=1 processor=0x[0-9a-f]+ private-pages=[0-9]+ PASS',
      '\[process-gate-14\] child pid=([0-9]+) entered U-mode cpu=1 active-pmap-mask=0x00000002 trap-stack=per-hart PASS',
      '\[process-gate-14\] exec pid=([0-9]+) cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS',
      '\[process-gate-14\] getcpu pid=([0-9]+) cpu=1 node=0 affinity=1 PASS',
      '(?m)^\[cpu1-probe\] pid=([0-9]+) cpu=1 getcpu-rounds=10000 mmap-rounds=256 checksum=0x[0-9a-f]+ PASS$',
      '\[process-gate-14\] child pid=([0-9]+) exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS',
      '\[process-gate-14\] Bash pid=2 cpu=0 (?:woke/|wait4 )reaped child=([0-9]+) child-last-cpu=1 pmap-release=1 status=0 PASS'
    )
  },
  [pscustomobject]@{
    Command = 'echo cpu1-status=$?'
    Patterns = @('(?m)^cpu1-status=0$')
  },
  [pscustomobject]@{
    Command = 'echo gate14-finished'
    Patterns = @('(?m)^gate14-finished$')
  }
)

$stressCommand = '/bin/gate14-stress {0}; echo gate14-stress-driver-status=$?' -f $StressRounds
$gate14StressSteps = @(
  [pscustomobject]@{
    Command = 'echo gate14-stress-ready'
    Patterns = @('(?m)^gate14-stress-ready$')
  },
  [pscustomobject]@{
    Command = $stressCommand
    Patterns = @(
      ('(?m)^\[process-gate-14-stress\] cycles={0} fork={0} entry={0} exec={0} getcpu={0} exit={0} reap={0} errors=0 PASS$' -f $StressRounds),
      '(?m)^\[process-gate-14-stress\] resource-baseline=stable pmap-create/destroy=[0-9]+/[0-9]+ backing-alloc/free=[0-9]+/[0-9]+ zombies=0 PASS$',
      '(?m)^\[gate14-stress-driver\] fork-exec-exit-wait complete PASS$',
      '(?m)^gate14-stress-driver-status=0$'
    )
  },
  [pscustomobject]@{
    Command = 'echo gate14-stress-finished'
    Patterns = @('(?m)^gate14-stress-finished$')
  }
)

$gate15TtyInputPlan = @()
for ($batch = 0; $batch -lt 10; $batch++) {
  $builder = [Text.StringBuilder]::new()
  for ($line = $batch * 100; $line -lt ($batch + 1) * 100; $line++) {
    [void]$builder.AppendFormat("L{0:D4}`r", $line)
  }
  $gate15TtyInputPlan += [pscustomobject]@{
    Pattern = if ($batch -eq 0) {
      '\[process-gate-15\] tty-ready lines=1000 batch=100'
    } else {
      '\[process-gate-15\] tty-progress=' + ($batch * 100)
    }
    Text = $builder.ToString()
  }
}

$gate15Steps = @(
  [pscustomobject]@{
    Command = 'echo gate15-warmup-start'
    Patterns = @('(?m)^gate15-warmup-start$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-process fork 4 >/dev/null; echo warmup-fork=$?'
    Patterns = @('(?m)^warmup-fork=0$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-process exec 4 >/dev/null; echo warmup-exec=$?'
    Patterns = @('(?m)^warmup-exec=0$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-pipes 10 >/dev/null; echo warmup-pipes=$?'
    Patterns = @('(?m)^warmup-pipes=0$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-signals 10 >/dev/null; echo warmup-signals=$?'
    Patterns = @('(?m)^warmup-signals=0$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-pipelines 1 >/dev/null; echo warmup-pipeline=$?'
    Patterns = @('(?m)^warmup-pipeline=0$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-batches 1 10 >/dev/null; echo warmup-batches=$?'
    Patterns = @('(?m)^warmup-batches=0$')
  },
  [pscustomobject]@{
    Command = 'IFS= read -r R < /proc/caribe/resources; printf "%s\n" "$R"'
    Patterns = @('(?m)^version=1 process_capacity=[0-9]+ .*$')
  },
  [pscustomobject]@{
    Command = '/bin/gate15-process fork 1000; echo gate15-fork-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] fork-only-exit-wait rounds=1000 PASS$',
      '(?m)^gate15-fork-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-process exec 1000; echo gate15-exec-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] fork-exec-exit-wait rounds=1000 PASS$',
      '(?m)^gate15-exec-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-pipes 1000; echo gate15-pipes-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] pipes=1000 bytes=64000 alloc-close/read-write verified PASS$',
      '(?m)^gate15-pipes-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-signals 1000; echo gate15-signals-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] signals=1000 handlers=1000 siginfo=1000 altstack=1000 PASS$',
      '(?m)^gate15-signals-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-pipelines 100; echo gate15-pipelines-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] pipelines=100 processes=200 transfer-bytes=1228800 PASS$',
      '(?m)^gate15-pipelines-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-batches 10 10; echo gate15-batches-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] child-batches=10 batch-width=10 fork-exit-wait=100 zombies=0 PASS$',
      '(?m)^gate15-batches-status=0$'
    )
  },
  [pscustomobject]@{
    Command = '/bin/gate15-tty 1000; echo gate15-tty-status=$?'
    Patterns = @(
      '(?m)^\[process-gate-15\] tty-lines=1000 content=validated canonical-blocking PASS$',
      '(?m)^gate15-tty-status=0$'
    )
    InputPlan = $gate15TtyInputPlan
  },
  [pscustomobject]@{
    Command = 'IFS= read -r R < /proc/caribe/resources; printf "%s\n" "$R"'
    Patterns = @('(?m)^version=1 process_capacity=[0-9]+ .*$')
  },
  [pscustomobject]@{
    Command = 'echo gate15-finished'
    Patterns = @('(?m)^gate15-finished$')
  }
)

if ($StressRounds -gt 0) {
  $steps = $gate14StressSteps
} else {
  $steps = switch ($Gate) {
    12 { $gate12Steps }
    13 { $gate13Steps }
    14 { $gate14Steps }
    15 { $gate15Steps }
    default { $gate11Steps }
  }
}

$proc = Start-Process `
  -FilePath $QemuPath `
  -ArgumentList (Join-NativeArguments $qemuArgs) `
  -WindowStyle Hidden `
  -PassThru `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr

$prompt = 'bash-5.3$ '
$client = $null
$stream = $null
$text = ""
$failure = $null
$initialPromptSeen = $false
$sentSteps = 0
$completedSteps = 0
$expectedPromptCount = 1
$currentStepOffset = 0
$exitSent = $false
$gateComplete = $false
$controlSent = $false
$inputActionIndex = 0
$transcripts = [Collections.Generic.List[string]]::new()
$buffer = [byte[]]::new(8192)

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
      $chunkText = [Text.Encoding]::ASCII.GetString($buffer, 0, $count)
      $text += $chunkText
      $serialWriter.Write($chunkText)
    }

    if ($text.Contains("panic(cpu ") -or
        $text.Contains("panic: We are hanging here...") -or
        $text.Contains("[linux] fatal user signal=")) {
      throw "Guest panic or fatal user signal detected during interactive test."
    }

    $promptCount = Get-OccurrenceCount -Text $text -Needle $prompt
	if ($initialPromptSeen -and -not $exitSent -and
	    $sentSteps -gt $completedSteps) {
	  $activeStep = $steps[$completedSteps]
	  $controlPatternProperty =
	    $activeStep.PSObject.Properties['ControlPattern']
	  $controlByteProperty = $activeStep.PSObject.Properties['ControlByte']
	  if (-not $controlSent -and $controlPatternProperty -and
	      $controlByteProperty -and
	      $text.Length -gt $currentStepOffset) {
	    $activeSegment = $text.Substring($currentStepOffset) -replace "`r", ""
	    if ([regex]::IsMatch($activeSegment,
	        [string]$controlPatternProperty.Value)) {
	      Send-SerialByte -Stream $stream -Value ([int]$controlByteProperty.Value)
	      $controlSent = $true
	    }
	  }
	  $inputPlanProperty = $activeStep.PSObject.Properties['InputPlan']
	  if ($inputPlanProperty -and
	      $inputActionIndex -lt @($inputPlanProperty.Value).Count -and
	      $text.Length -gt $currentStepOffset) {
	    $inputAction = @($inputPlanProperty.Value)[$inputActionIndex]
	    $activeSegment = $text.Substring($currentStepOffset) -replace "`r", ""
	    if ([regex]::IsMatch($activeSegment, [string]$inputAction.Pattern)) {
	      Send-SerialText -Stream $stream -Value ([string]$inputAction.Text)
	      $inputActionIndex++
	    }
	  }
	}
    if (-not $initialPromptSeen -and $promptCount -ge 1) {
      $initialPromptSeen = $true
      $expectedPromptCount = 2
      $currentStepOffset = $text.Length
      Send-SerialLine -Stream $stream -Line $steps[0].Command
      $sentSteps = 1
    } elseif ($initialPromptSeen -and -not $exitSent -and
        $sentSteps -gt $completedSteps -and
        $promptCount -ge $expectedPromptCount) {
      $promptOffset = $text.LastIndexOf($prompt)
      if ($promptOffset -lt $currentStepOffset) {
        throw "Interactive transcript prompt ordering is invalid."
      }
      $segment = $text.Substring(
        $currentStepOffset, $promptOffset - $currentStepOffset)
      $transcripts.Add($segment)
      $step = $steps[$completedSteps]
      $normalized = $segment -replace "`r", ""
	  $stepInputPlan = $step.PSObject.Properties['InputPlan']
	  if ($stepInputPlan -and
	      $inputActionIndex -ne @($stepInputPlan.Value).Count) {
	    throw "Command '$($step.Command)' completed before all serial input batches were sent."
	  }
      foreach ($pattern in @($step.Patterns)) {
        if (-not [regex]::IsMatch($normalized, $pattern)) {
          throw "Command '$($step.Command)' did not match '$pattern'."
        }
      }
      $completedSteps++

      if ($completedSteps -eq $steps.Count) {
        Send-SerialLine -Stream $stream -Line 'exit 0'
        $exitSent = $true
      } else {
        $currentStepOffset = $text.Length
        Send-SerialLine -Stream $stream -Line $steps[$completedSteps].Command
        $sentSteps++
        $expectedPromptCount++
		$controlSent = $false
		$inputActionIndex = 0
      }
    }

    $smpReady = -not $RequireSmpGateF -or $text.Contains(
      "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")
	$gateEvidenceReady = switch ($Gate) {
	  12 { $text.Contains(
	      "[process-gate-12] blocking pipeline lifecycle index=2") }
	  13 { $text.Contains(
	      "[process-gate-13] default SIGINT terminating pid=") }
	  14 {
	    if ($StressRounds -gt 0) {
	      $text.Contains(
	        "[process-gate-14-stress] cycles=$StressRounds fork=$StressRounds")
	    } else {
	      $text.Contains("[process-gate-14] Bash pid=2 cpu=0")
	    }
	  }
	  15 { $text.Contains("gate15-finished") }
	  default { $true }
	}
	if (-not $exitSent -and $text.Contains(
	    "[process-gate-11] Gate 11 persistent interactive Bash PASS")) {
	  throw "Bash exited before the interactive command sequence completed."
	}
    if ($exitSent -and $smpReady -and $gateEvidenceReady -and $text.Contains(
        "[process-gate-11] Gate 11 persistent interactive Bash PASS")) {
      $gateComplete = $true
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
    $chunkText = [Text.Encoding]::ASCII.GetString($buffer, 0, $count)
    $text += $chunkText
    $serialWriter.Write($chunkText)
  }
} catch {
  $failure = $_.Exception
} finally {
  if ($serialWriter) {
    $serialWriter.Dispose()
  }
  if ($client) {
    $client.Dispose()
  }
  if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
    Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
  }
  $proc.WaitForExit(5000) | Out-Null
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
  "[process-gate-11] PID1 interactive argv/env stack PASS",
  "[stage1-init] exec /sbin/interactive-init",
  "[process-gate-11] PID 1 interactive init started tty=1 pgid=1 sid=1 PASS",
  "CaribeOS login shell",
  "[process-gate-11] Bash child pid=2 affinity=cpu0 PASS",
  "[linux-exec] execve path=/bin/bash transactional commit pid=2",
  "[process-gate-11] pselect6 blocking on TTY without polling PASS",
  "[process-gate-11] pselect6 woke for TTY readiness PASS",
  "[process-gate-11] fork child-first rendezvous armed PASS",
  "[process-gate-11] child U-mode rendezvous pid=",
  "[process-gate-11] waitid job-control options=0x0000000e accepted PASS",
  "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
  "[process-gate-11] Gate 11 persistent interactive Bash PASS"
)
if ($Gate -eq 14) {
  $required = @($required | Where-Object {
    $_ -ne "[process-gate-11] fork child-first rendezvous armed PASS" -and
    $_ -ne "[process-gate-11] child U-mode rendezvous pid="
  })
}
$required += switch ($Gate) {
  12 { @(
    "[process-gate-12] pipe id=",
    "capacity=4096 created PASS",
    "[process-gate-12] pipe writer pid=",
    "blocking on full pipe without polling PASS",
    "[process-gate-12] pipe reader pid=",
    "blocking on empty pipe without polling PASS",
    "observed EOF after final writer close PASS",
    "[process-gate-12] blocking pipeline lifecycle index=2",
    "transfer=12288 EOF=1 no-lost-wakeup=1 resources=0 PASS",
    "[pipeline-consumer] redirected input bytes=65 PASS",
    "[pipeline-producer] stderr redirection PASS",
    "[process-gate-12] SIGPIPE queued pid=",
    "after final reader close PASS",
    "[process-gate-12] default SIGPIPE terminating pid=",
    "at syscall return PASS",
    "[linux] exit signal=13"
  ) }
  13 { @(
    "[jobctl-wait] pid=",
    "blocking-read PASS",
    "[process-gate-13] TTY VSUSP -> SIGTSTP foreground-pgid=",
    "[process-gate-13] default SIGTSTP stopped pid=",
    "code=CLD_STOPPED status=20 PASS",
    "[process-gate-13] SIGCONT resumed pid=",
    "[process-gate-13] kill process-group pgid=",
    "signal=18 targets=1 PASS",
    "code=CLD_CONTINUED status=18 PASS",
    "[jobctl-wait] resumed after SIGCONT; blocking-read PASS",
    "[process-gate-13] TTY VINTR -> SIGINT foreground-pgid=",
    "targets=1 PASS",
    "[process-gate-13] default SIGINT terminating pid=",
    "at syscall return PASS",
    "[linux] exit signal=2",
    "interrupt-status=130"
    "[process-gate-13] TTY VQUIT -> SIGQUIT foreground-pgid=",
    "[process-gate-13] default SIGQUIT terminating pid=",
    "[linux] exit signal=3",
    "quit-status=131"
  ) }
  14 { @(
    if ($StressRounds -gt 0) {
      "[process-gate-14-stress] driver pid="
      "parent=2 bound-cpu=0"
      "[process-gate-14-stress] driver exec pid="
      "[process-gate-14-stress] baseline processes=3 zombies=0"
      "[process-gate-14-stress] cycles=$StressRounds fork=$StressRounds entry=$StressRounds exec=$StressRounds getcpu=$StressRounds exit=$StressRounds reap=$StressRounds errors=0 PASS"
      "[process-gate-14-stress] resource-baseline=stable"
      "[gate14-stress-driver] fork-exec-exit-wait complete PASS"
      "gate14-stress-driver-status=0"
      "gate14-stress-finished"
    } else {
      "[process-gate-14] child pid="
      "parent=2 bound-cpu=1"
      "entered U-mode cpu=1 active-pmap-mask=0x00000002"
      "trap-stack=per-hart PASS"
      "cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS"
      "cpu=1 node=0 affinity=1 PASS"
      "[cpu1-probe] pid="
      "getcpu-rounds=10000 mmap-rounds=256"
      "exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS"
      "child-last-cpu=1 pmap-release=1 status=0 PASS"
      "cpu1-status=0"
      "gate14-finished"
    }
  ) }
  15 { @(
    "[process-gate-15] fork-only-exit-wait rounds=1000 PASS"
    "[process-gate-15] fork-exec-exit-wait rounds=1000 PASS"
    "[process-gate-15] pipes=1000 bytes=64000 alloc-close/read-write verified PASS"
    "[process-gate-15] signals=1000 handlers=1000 siginfo=1000 altstack=1000 PASS"
    "[process-gate-15] pipelines=100 processes=200 transfer-bytes=1228800 PASS"
    "[process-gate-15] child-batches=10 batch-width=10 fork-exit-wait=100 zombies=0 PASS"
    "[process-gate-15] tty-lines=1000 content=validated canonical-blocking PASS"
    "gate15-finished"
  ) }
  default { @(
    "[process-gate-11] exec argv/env collected argc=1 envc=12 PASS",
    "[stage1-caribectl] clone/wait4 real child task ok"
  ) }
}
foreach ($marker in $required) {
  if (-not $text.Contains($marker)) {
    throw "Interactive Bash test missing marker '$marker'. See $serial and $stderr."
  }
}

if (-not $initialPromptSeen -or $completedSteps -ne $steps.Count -or
    -not $exitSent -or -not $gateComplete) {
  throw "Interactive Bash test did not complete every prompt/command phase. See $serial."
}
if ((Get-OccurrenceCount -Text $text -Needle $prompt) -lt
    ($steps.Count + 1)) {
  throw "Interactive Bash did not return to its prompt after every command. See $serial."
}
$cloneAffinity = if ($Gate -eq 14) { 'cpu1' } else { 'cpu0' }
$cloneMatches = [regex]::Matches($text,
  "\[linux-clone\] real task/thread child pid=([0-9]+) parent=2 affinity=$cloneAffinity")
$rendezvousArmed = Get-OccurrenceCount -Text $text -Needle `
  "[process-gate-11] fork child-first rendezvous armed PASS"
$rendezvousComplete = [regex]::Matches($text,
  '\[process-gate-11\] child U-mode rendezvous pid=([0-9]+) PASS')
if ($Gate -eq 11) {
  $execMatches = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/caribectl transactional commit pid=([0-9]+)')
  $argvEnv = Get-OccurrenceCount -Text $text -Needle `
    "[process-gate-11] exec argv/env collected argc=1 envc=12 PASS"
  if ((Get-OccurrenceCount -Text $text -Needle `
      "[stage1-caribectl] done") -ne 2) {
    throw "Interactive Bash did not complete exactly two caribectl executions. See $serial."
  }
  if ($cloneMatches.Count -lt 2 -or $execMatches.Count -ne 2 -or
      $rendezvousArmed -ne 2 -or $rendezvousComplete.Count -ne 2 -or
      $argvEnv -ne 2) {
    throw "Interactive Bash did not complete exactly two real fork/exec rendezvous cycles. See $serial."
  }
  if ($rendezvousComplete[0].Groups[1].Value -eq
      $rendezvousComplete[1].Groups[1].Value) {
    throw "Interactive Bash reused a child PID across distinct command cycles. See $serial."
  }
} elseif ($Gate -eq 12) {
  $producerExecs = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/pipeline-producer transactional commit pid=([0-9]+)')
  $consumerExecs = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/pipeline-consumer transactional commit pid=([0-9]+)')
  $sigpipeExecs = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/pipeline-sigpipe transactional commit pid=([0-9]+)')
  $pipelineResults = Get-OccurrenceCount -Text $text -Needle `
    "[pipeline-consumer] bytes=12288 checksum=1566720 pattern=sequential PASS"
  $pipeCreates = [regex]::Matches($text,
    '\[process-gate-12\] pipe id=([0-9]+) read-fd=([0-9]+) write-fd=([0-9]+) capacity=4096 created PASS')
  $pipeReleases = [regex]::Matches($text,
    '\[process-gate-12\] pipe id=([0-9]+) released readers/writers=0/0 bytes=12288/12288 blocks/wakeups=([0-9]+)/([0-9]+)\+([0-9]+)/([0-9]+) PASS')
  $allPipeReleases = [regex]::Matches($text,
    '\[process-gate-12\] pipe id=([0-9]+) released readers/writers=0/0 bytes=([0-9]+)/([0-9]+) blocks/wakeups=([0-9]+)/([0-9]+)\+([0-9]+)/([0-9]+) PASS')
  $lifecycles = [regex]::Matches($text,
    '\[process-gate-12\] blocking pipeline lifecycle index=([0-9]+) transfer=12288 EOF=1 no-lost-wakeup=1 resources=0 PASS')
  if ($cloneMatches.Count -ne 8 -or $rendezvousArmed -ne 8 -or
      $rendezvousComplete.Count -ne 8 -or $producerExecs.Count -ne 3 -or
      $consumerExecs.Count -ne 3 -or $sigpipeExecs.Count -ne 1 -or
      $pipelineResults -ne 2 -or $pipeCreates.Count -ne 9 -or
      $allPipeReleases.Count -ne 9 -or
      $pipeReleases.Count -ne 2 -or $lifecycles.Count -ne 2) {
    throw "Gate 12 did not prove the expected process and pipe lifecycle counts. See $serial."
  }
  foreach ($release in $pipeReleases) {
    $readBlocks = [uint32]$release.Groups[2].Value
    $readWakeups = [uint32]$release.Groups[3].Value
    $writeBlocks = [uint32]$release.Groups[4].Value
    $writeWakeups = [uint32]$release.Groups[5].Value
    if ($readBlocks -eq 0 -or $readBlocks -ne $readWakeups -or
        $writeBlocks -eq 0 -or $writeBlocks -ne $writeWakeups) {
      throw "Gate 12 pipe block/wakeup counters are not balanced. See $serial."
    }
  }
  if ($lifecycles[0].Groups[1].Value -ne "1" -or
      $lifecycles[1].Groups[1].Value -ne "2") {
    throw "Gate 12 pipeline lifecycle indices are not monotonic. See $serial."
  }
} elseif ($Gate -eq 13) {
  $jobExecs = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/jobctl-wait transactional commit pid=([0-9]+)')
  $jobMarkers = [regex]::Matches($text,
    '\[jobctl-wait\] pid=([0-9]+) pgid=([0-9]+) foreground=([0-9]+) blocking-read PASS')
  $ttySignals = [regex]::Matches($text,
    '\[process-gate-13\] TTY VINTR -> SIGINT foreground-pgid=([0-9]+) targets=1 PASS')
  $ttyQuits = [regex]::Matches($text,
    '\[process-gate-13\] TTY VQUIT -> SIGQUIT foreground-pgid=([0-9]+) targets=1 PASS')
  $defaultQuits = [regex]::Matches($text,
    '\[process-gate-13\] default SIGQUIT terminating pid=([0-9]+) at syscall return PASS')
  $ttyStops = [regex]::Matches($text,
    '\[process-gate-13\] TTY VSUSP -> SIGTSTP foreground-pgid=([0-9]+) targets=1 PASS')
  $stopped = [regex]::Matches($text,
    '\[process-gate-13\] default SIGTSTP stopped pid=([0-9]+) pgid=([0-9]+) signal=20 PASS')
  $continued = [regex]::Matches($text,
    '\[process-gate-13\] SIGCONT resumed pid=([0-9]+) pgid=([0-9]+) PASS')
  $groupContinues = [regex]::Matches($text,
    '\[process-gate-13\] kill process-group pgid=([0-9]+) signal=18 targets=1 PASS')
  $stopWaits = [regex]::Matches($text,
    '\[process-gate-13\] waitid observed child=([0-9]+) code=CLD_STOPPED status=20 PASS')
  $continueWaits = [regex]::Matches($text,
    '\[process-gate-13\] waitid observed child=([0-9]+) code=CLD_CONTINUED status=18 PASS')
  if ($cloneMatches.Count -ne 2 -or $rendezvousArmed -ne 2 -or
      $rendezvousComplete.Count -ne 2 -or $jobExecs.Count -ne 2 -or
      $jobMarkers.Count -ne 2 -or $ttySignals.Count -ne 1 -or
      $ttyQuits.Count -ne 1 -or $defaultQuits.Count -ne 1 -or
      $ttyStops.Count -ne 1 -or $stopped.Count -ne 1 -or
      $continued.Count -ne 1 -or $groupContinues.Count -ne 1 -or
      $stopWaits.Count -ne 1 -or $continueWaits.Count -ne 1 -or
      $jobMarkers[0].Groups[1].Value -ne $jobMarkers[0].Groups[2].Value -or
      $jobMarkers[0].Groups[1].Value -ne $jobMarkers[0].Groups[3].Value -or
      $jobMarkers[0].Groups[1].Value -ne $ttySignals[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $ttyStops[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $stopped[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $stopped[0].Groups[2].Value -or
      $jobMarkers[0].Groups[1].Value -ne $continued[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $continued[0].Groups[2].Value -or
      $jobMarkers[0].Groups[1].Value -ne $groupContinues[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $stopWaits[0].Groups[1].Value -or
      $jobMarkers[0].Groups[1].Value -ne $continueWaits[0].Groups[1].Value) {
    throw "Gate 13 did not prove one stop/continue/interrupt foreground lifecycle. See $serial."
  }
  if ($jobMarkers[1].Groups[1].Value -eq $jobMarkers[0].Groups[1].Value -or
      $jobMarkers[1].Groups[1].Value -ne $ttyQuits[0].Groups[1].Value -or
      $jobMarkers[1].Groups[1].Value -ne $defaultQuits[0].Groups[1].Value) {
    throw "Gate 13 did not route SIGQUIT to a distinct foreground child. See $serial."
  }
} elseif ($Gate -eq 15) {
  $resourceLines = [regex]::Matches($text,
    '(?m)^version=1 process_capacity=[0-9]+[^\r\n]*')
  $forkOnly = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] fork-only-exit-wait rounds=1000 PASS\r?$')
  $forkExec = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] fork-exec-exit-wait rounds=1000 PASS\r?$')
  $pipeRun = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] pipes=1000 bytes=64000 alloc-close/read-write verified PASS\r?$')
  $signalRun = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] signals=1000 handlers=1000 siginfo=1000 altstack=1000 PASS\r?$')
  $pipelineRun = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] pipelines=100 processes=200 transfer-bytes=1228800 PASS\r?$')
  $batchRun = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] child-batches=10 batch-width=10 fork-exit-wait=100 zombies=0 PASS\r?$')
  $ttyRun = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] tty-lines=1000 content=validated canonical-blocking PASS\r?$')
  $ttyProgress = [regex]::Matches($text,
    '(?m)^\[process-gate-15\] tty-progress=([0-9]+)\r?$')
  if ($resourceLines.Count -ne 2 -or $forkOnly.Count -ne 1 -or
      $forkExec.Count -ne 1 -or $pipeRun.Count -ne 1 -or
      $signalRun.Count -ne 1 -or $pipelineRun.Count -ne 1 -or
      $batchRun.Count -ne 1 -or $ttyRun.Count -ne 1 -or
      $ttyProgress.Count -ne 10) {
    throw "Gate 15 workload evidence counts are incomplete. See $serial."
  }
  for ($index = 0; $index -lt $ttyProgress.Count; $index++) {
    if ([uint32]$ttyProgress[$index].Groups[1].Value -ne
        [uint32](($index + 1) * 100)) {
      throw "Gate 15 TTY progress is not ordered in 100-line batches. See $serial."
    }
  }

  $baselineResources = Convert-ResourceSnapshot $resourceLines[0].Value
  $finalResources = Convert-ResourceSnapshot $resourceLines[1].Value
  $stableFields = @(
    'process_capacity', 'process_entries', 'process_live', 'zombies',
    'tasks', 'threads', 'pmaps', 'pt_pages', 'kernel_pt_pages',
    'user_pages', 'exec_arenas', 'fd_refs', 'ofds', 'pipes',
    'signal_frames', 'free_pages', 'wired_pages',
    'kernel_stacks_active', 'kernel_stacks_total', 'zones',
    'zone_active', 'zone_bytes'
  )
  foreach ($field in $stableFields) {
    if (-not $baselineResources.ContainsKey($field) -or
        -not $finalResources.ContainsKey($field) -or
        $baselineResources[$field] -ne $finalResources[$field]) {
      throw "Gate 15 live resource '$field' drifted across the stress matrix. See $serial."
    }
  }
  foreach ($field in @('zombies', 'pipes', 'signal_frames')) {
    if ($finalResources[$field] -ne 0) {
      throw "Gate 15 final resource '$field' is not zero. See $serial."
    }
  }

  $cumulativeFields = @(
    'process_created', 'process_removed', 'process_exited', 'process_reaped',
    'pmap_created', 'pmap_destroyed', 'pt_alloc', 'pt_free',
    'backing_alloc', 'backing_free', 'ofd_alloc', 'ofd_free',
    'ofd_retain', 'ofd_release', 'pipe_alloc', 'pipe_release',
    'reserved_stack_handoffs',
    'pipe_read_bytes', 'pipe_write_bytes', 'pipe_read_blocks',
    'pipe_read_wakeups', 'pipe_write_blocks', 'pipe_write_wakeups',
    'signal_queued', 'signal_discarded', 'signal_delivered',
    'signal_returned', 'signal_failures', 'tty_lines', 'tty_overruns',
    'tty_reads', 'tty_read_blocks', 'tty_read_wakeups'
  )
  $delta = [Collections.Generic.Dictionary[string, uint64]]::new()
  foreach ($field in $cumulativeFields) {
    if (-not $baselineResources.ContainsKey($field) -or
        -not $finalResources.ContainsKey($field) -or
        $finalResources[$field] -lt $baselineResources[$field]) {
      throw "Gate 15 cumulative resource '$field' regressed or is missing. See $serial."
    }
    $delta[$field] = $finalResources[$field] - $baselineResources[$field]
  }
  if ($delta['process_created'] -lt 2307 -or
      $delta['process_created'] -ne $delta['process_removed'] -or
      $delta['process_created'] -ne $delta['process_exited'] -or
      $delta['process_created'] -ne $delta['process_reaped']) {
    throw "Gate 15 process create/exit/reap accounting is not balanced. See $serial."
  }
  if ($delta['pmap_created'] -ne $delta['pmap_destroyed'] -or
      $delta['pt_alloc'] -ne $delta['pt_free'] -or
      $delta['backing_alloc'] -ne $delta['backing_free']) {
    throw "Gate 15 VM allocation accounting is not balanced. See $serial."
  }
  if ($delta['ofd_alloc'] -ne $delta['ofd_free'] -or
      $delta['ofd_release'] -ne
      ($delta['ofd_retain'] + $delta['ofd_alloc'])) {
    throw "Gate 15 descriptor/OFD accounting is not balanced. See $serial."
  }
  # The seven external matrix commands each add one zero-byte Bash
  # synchronization pipe in addition to the 1,100 workload pipes.
  if ($delta['pipe_alloc'] -ne 1107 -or
      $delta['pipe_release'] -ne 1107 -or
      $delta['pipe_read_bytes'] -ne 1292800 -or
      $delta['pipe_write_bytes'] -ne 1292800 -or
      $delta['pipe_read_blocks'] -eq 0 -or
      $delta['pipe_read_blocks'] -ne $delta['pipe_read_wakeups'] -or
      $delta['pipe_write_blocks'] -eq 0 -or
      $delta['pipe_write_blocks'] -ne $delta['pipe_write_wakeups']) {
    throw "Gate 15 pipe lifecycle, transfer, or wakeup accounting is invalid. See $serial."
  }
  if ($delta['signal_delivered'] -lt 1000 -or
      $delta['signal_delivered'] -ne $delta['signal_returned'] -or
      $delta['signal_failures'] -ne 0) {
    throw "Gate 15 signal-frame accounting is not balanced. See $serial."
  }
  if ($delta['tty_lines'] -lt 1000 -or $delta['tty_overruns'] -ne 0 -or
      $delta['tty_read_blocks'] -eq 0 -or
      $delta['tty_read_blocks'] -ne $delta['tty_read_wakeups']) {
    throw "Gate 15 TTY line or blocking-wakeup accounting is invalid. See $serial."
  }
} elseif ($StressRounds -gt 0) {
  $driver = [regex]::Matches($text,
    '\[process-gate-14-stress\] driver pid=([0-9]+) parent=2 bound-cpu=0 processor=0x([0-9a-f]+) private-pages=([0-9]+) PASS')
  $driverExec = [regex]::Matches($text,
    '\[process-gate-14-stress\] driver exec pid=([0-9]+) cpu=0 active-pmap-mask=0x00000001 switch-coherent PASS')
  $bound = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) parent=([0-9]+) bound-cpu=1 processor=0x([0-9a-f]+) private-pages=([0-9]+) PASS')
  $entered = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) entered U-mode cpu=1 active-pmap-mask=0x00000002 trap-stack=per-hart PASS')
  $execs = [regex]::Matches($text,
    '\[process-gate-14\] exec pid=([0-9]+) cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS')
  $getcpu = [regex]::Matches($text,
    '\[process-gate-14\] getcpu pid=([0-9]+) cpu=1 node=0 affinity=1 PASS')
  $exits = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS')
  $waits = [regex]::Matches($text,
    '\[process-gate-14\] driver pid=([0-9]+) cpu=0 (?:woke/|wait4 )reaped child=([0-9]+) child-last-cpu=1 pmap-release=1 status=0 PASS')
  $final = [regex]::Matches($text,
    ('\[process-gate-14-stress\] cycles={0} fork={0} entry={0} exec={0} getcpu={0} exit={0} reap={0} errors=0 PASS' -f $StressRounds))
  $resource = [regex]::Matches($text,
    '\[process-gate-14-stress\] resource-baseline=stable pmap-create/destroy=([0-9]+)/([0-9]+) backing-alloc/free=([0-9]+)/([0-9]+) zombies=0 PASS')
  $baseline = [regex]::Matches($text,
    '\[process-gate-14-stress\] baseline processes=3 zombies=0 .* PASS')
  $progress = [regex]::Matches($text,
    '\[process-gate-14-stress\] progress=([0-9]+)/([0-9]+) cpu1-lifecycles resources=baseline PASS')
  $ofd = [regex]::Matches($text,
    '\[process-gate-14-stress\] ofd-retain/release=([0-9]+)/([0-9]+) rates=([0-9]+)/([0-9]+) live=([0-9]+) references=([0-9]+) PASS')
  $userPt = [regex]::Matches($text,
    '\[process-gate-14-stress\] user-pt-baseline=([0-9]+)/([0-9]+) kernel-pt-growth=([0-9]+) kernel-l0-growth=([0-9]+) last-kernel-l0-va=0x([0-9a-f]+) PASS')
  $physical = [regex]::Matches($text,
    '\[process-gate-14-stress\] physical-baseline free-pages=([0-9]+)/([0-9]+) wired-pages=([0-9]+)/([0-9]+) kernel-stacks-active=([0-9]+)/([0-9]+) kernel-stacks-total=([0-9]+)/([0-9]+) PASS')
  $strictBaseline = [regex]::Matches($text,
    '\[process-gate-14-stress\] strict-baseline cycle=1 zones=([0-9]+) active=([0-9]+) bytes=([0-9]+) no-warmup PASS')
  $zones = [regex]::Matches($text,
    '\[process-gate-14-stress\] zone-baseline zones=([0-9]+)/([0-9]+) active=([0-9]+)/([0-9]+) bytes=([0-9]+)/([0-9]+) PASS')
  $driverDone = [regex]::Matches($text,
    '(?m)^\[gate14-stress-driver\] fork-exec-exit-wait complete PASS\r?$')
  $driverStatus = [regex]::Matches($text,
    '(?m)^gate14-stress-driver-status=0\r?$')
  $interval = if ($StressRounds -ge 10000) { 1000 } elseif (
      $StressRounds -ge 1000) { 100 } else { 10 }
  $expectedDetails = [int]($StressRounds / $interval) + 1
  if ($bound.Count -ne $expectedDetails -or
      $entered.Count -ne $expectedDetails -or
      $execs.Count -ne $expectedDetails -or
      $getcpu.Count -ne $expectedDetails -or
      $exits.Count -ne $expectedDetails -or
      $waits.Count -ne $expectedDetails -or
      $progress.Count -ne ($expectedDetails - 1) -or
      $driver.Count -ne 1 -or $driverExec.Count -ne 1 -or
      $baseline.Count -ne 1 -or $final.Count -ne 1 -or
      $resource.Count -ne 1 -or $ofd.Count -ne 1 -or
      $userPt.Count -ne 1 -or $physical.Count -ne 1 -or
      $strictBaseline.Count -ne 1 -or $zones.Count -ne 1 -or
      $driverDone.Count -ne 1 -or $driverStatus.Count -ne 1) {
    throw "Gate 14 stress evidence counts are incomplete. See $serial."
  }
  $driverPid = $driver[0].Groups[1].Value
  if ($driverExec[0].Groups[1].Value -ne $driverPid -or
      [Convert]::ToUInt32($driver[0].Groups[2].Value, 16) -eq 0 -or
      [uint32]$driver[0].Groups[3].Value -eq 0) {
    throw "Gate 14 stress CPU0 driver identity is invalid. See $serial."
  }
  $seenPids = [Collections.Generic.HashSet[string]]::new()
  for ($index = 0; $index -lt $expectedDetails; $index++) {
    $childPid = $bound[$index].Groups[1].Value
    if (-not $seenPids.Add($childPid) -or
        $bound[$index].Groups[2].Value -ne $driverPid -or
        $entered[$index].Groups[1].Value -ne $childPid -or
        $execs[$index].Groups[1].Value -ne $childPid -or
        $getcpu[$index].Groups[1].Value -ne $childPid -or
        $exits[$index].Groups[1].Value -ne $childPid -or
        $waits[$index].Groups[1].Value -ne $driverPid -or
        $waits[$index].Groups[2].Value -ne $childPid -or
        [Convert]::ToUInt32($bound[$index].Groups[3].Value, 16) -eq 0 -or
        [uint32]$bound[$index].Groups[4].Value -eq 0) {
      throw "Gate 14 stress mixed or invalid sampled CPU1 lifecycles. See $serial."
    }
  }
  $privatePages = [uint64]$bound[0].Groups[4].Value
  $expectedPmaps = [uint64](2 * ($StressRounds - 1))
  $expectedBacking = [uint64]($StressRounds - 1) * $privatePages
  if ([uint64]$resource[0].Groups[1].Value -ne $expectedPmaps -or
      [uint64]$resource[0].Groups[2].Value -ne $expectedPmaps -or
      [uint64]$resource[0].Groups[3].Value -ne $expectedBacking -or
      [uint64]$resource[0].Groups[4].Value -ne $expectedBacking) {
    throw "Gate 14 stress resource deltas do not match completed lifecycles. See $serial."
  }
  $kernelPtGrowth = [uint64]$userPt[0].Groups[3].Value
  $kernelL0Growth = [uint64]$userPt[0].Groups[4].Value
  if ([uint64]$userPt[0].Groups[1].Value -eq 0 -or
      [uint64]$userPt[0].Groups[1].Value -ne
      [uint64]$userPt[0].Groups[2].Value -or
      $kernelPtGrowth -ne $kernelL0Growth -or
      ($kernelPtGrowth -ne 0 -and
      [Convert]::ToUInt32($userPt[0].Groups[5].Value, 16) -eq 0)) {
    throw "Gate 14 stress user/kernel page-table ownership is inconsistent. See $serial."
  }
  for ($index = 1; $index -le 8; $index += 2) {
    if ($physical[0].Groups[$index].Value -ne
        $physical[0].Groups[$index + 1].Value) {
      throw "Gate 14 stress physical memory or kernel-stack baseline drifted. See $serial."
    }
  }
  for ($index = 1; $index -le 6; $index += 2) {
    if ($zones[0].Groups[$index].Value -ne
        $zones[0].Groups[$index + 1].Value) {
      throw "Gate 14 stress zone baseline drifted. See $serial."
    }
  }
  if ($strictBaseline[0].Groups[1].Value -ne $zones[0].Groups[1].Value -or
      $strictBaseline[0].Groups[2].Value -ne $zones[0].Groups[3].Value -or
      $strictBaseline[0].Groups[3].Value -ne $zones[0].Groups[5].Value) {
    throw "Gate 14 stress strict allocator baseline changed. See $serial."
  }
  $ofdRetainRate = [uint64]$ofd[0].Groups[3].Value
  $ofdReleaseRate = [uint64]$ofd[0].Groups[4].Value
  if ([uint64]$ofd[0].Groups[1].Value -ne
      ([uint64]($StressRounds - 1) * $ofdRetainRate) -or
      [uint64]$ofd[0].Groups[2].Value -ne
      ([uint64]($StressRounds - 1) * $ofdReleaseRate) -or
      [uint64]$ofd[0].Groups[5].Value -eq 0 -or
      [uint64]$ofd[0].Groups[6].Value -eq 0) {
    throw "Gate 14 stress OFD accounting is not proportional or live. See $serial."
  }
  foreach ($sample in $progress) {
    if ([uint32]$sample.Groups[2].Value -ne $StressRounds) {
      throw "Gate 14 stress progress used the wrong target. See $serial."
    }
  }
} else {
  $bound = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) parent=2 bound-cpu=1 processor=0x([0-9a-f]+) private-pages=([0-9]+) PASS')
  $entered = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) entered U-mode cpu=1 active-pmap-mask=0x00000002 trap-stack=per-hart PASS')
  $execs = [regex]::Matches($text,
    '\[process-gate-14\] exec pid=([0-9]+) cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS')
  $getcpu = [regex]::Matches($text,
    '\[process-gate-14\] getcpu pid=([0-9]+) cpu=1 node=0 affinity=1 PASS')
  $probe = [regex]::Matches($text,
    '\[cpu1-probe\] pid=([0-9]+) cpu=1 getcpu-rounds=10000 mmap-rounds=256 checksum=0x([0-9a-f]+) PASS')
  $exits = [regex]::Matches($text,
    '\[process-gate-14\] child pid=([0-9]+) exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS')
  $waits = [regex]::Matches($text,
    '\[process-gate-14\] Bash pid=2 cpu=0 (?:woke/|wait4 )reaped child=([0-9]+) child-last-cpu=1 pmap-release=1 status=0 PASS')
  $execCommits = [regex]::Matches($text,
    '\[linux-exec\] execve path=/bin/cpu1-probe transactional commit pid=([0-9]+)')
  if ($cloneMatches.Count -ne 1 -or $bound.Count -ne 1 -or
      $entered.Count -ne 1 -or $execs.Count -ne 1 -or
      $getcpu.Count -ne 1 -or $probe.Count -ne 1 -or
      $exits.Count -ne 1 -or $waits.Count -ne 1 -or
      $execCommits.Count -ne 1) {
    throw "Gate 14 did not prove exactly one complete CPU1 process lifecycle. See $serial."
  }
  $childPid = $cloneMatches[0].Groups[1].Value
  foreach ($observed in @(
      $bound[0].Groups[1].Value,
      $entered[0].Groups[1].Value,
      $execs[0].Groups[1].Value,
      $getcpu[0].Groups[1].Value,
      $probe[0].Groups[1].Value,
      $exits[0].Groups[1].Value,
      $waits[0].Groups[1].Value,
      $execCommits[0].Groups[1].Value)) {
    if ($observed -ne $childPid) {
      throw "Gate 14 mixed lifecycle evidence from different PIDs. See $serial."
    }
  }
  if ([Convert]::ToUInt32($bound[0].Groups[2].Value, 16) -eq 0 -or
      [uint32]$bound[0].Groups[3].Value -eq 0) {
    throw "Gate 14 did not bind a real processor or clone user pages. See $serial."
  }
}
if (-not $text.Contains("[linux-waitid] parent=1 blocking") -or
    -not $text.Contains("without polling")) {
  throw "Interactive init did not prove a blocking wait for Bash. See $serial."
}
if ($RequireSmpGateF -and -not $text.Contains(
    "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
  throw "Interactive Bash test did not pass SMP Gate F. See $serial."
}
if ($text -match '(?m)(\[process-gate-(?:11|12|13|14|15)\] FAIL|\[(?:pipeline-(?:consumer|sigpipe)|jobctl-wait|cpu1-probe|gate14-stress-driver|gate15-[^]]+)\] FAIL|panic\(cpu|scause=|stval=|sepc=|Linux user backing page pool exhausted|destroying active user pmap|double free in Sv32|userspace trap violated CPU affinity)') {
  throw "Interactive Bash test saw a process-gate failure, panic, or unexpected trap. See $serial."
}

if ($StressRounds -gt 0) {
  Write-Output "QEMU persistent interactive Bash Gate 14 stress ($StressRounds cycles) test OK."
} else {
  Write-Output "QEMU persistent interactive Bash Gate $Gate test OK."
}
