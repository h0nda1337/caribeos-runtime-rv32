param(
  [string]$QemuPath = "",
  [switch]$SmokeTest,
  [switch]$RequireStage1,
  [int]$Seconds = 3,
  [int]$Smp = 1,
  [ValidateSet("", "A", "B", "C", "D", "E", "F")]
  [string]$RequireSmpGate = "",
  [string]$Append = "",
  [string]$DiskImage = ""
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$buildDir = Join-Path $root "build"
$elf = Join-Path $buildDir "caribe_rv32.elf"
$disk = if ($DiskImage) {
  if ([System.IO.Path]::IsPathRooted($DiskImage)) {
    $DiskImage
  } else {
    Join-Path $root $DiskImage
  }
} else {
  Join-Path $root "hfsplus.img"
}

if (-not (Test-Path -LiteralPath $elf)) {
  throw "Missing $elf. Build it first, or keep the prebuilt artifact from the zip."
}

if (-not (Test-Path -LiteralPath $disk)) {
  throw "Missing HFS+ disk image: $disk"
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

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $root)
$pathAdds = @(
  (Split-Path -Parent $QemuPath),
  (Join-Path $workspaceRoot "msys64\ucrt64\bin"),
  (Join-Path $workspaceRoot "msys64\usr\bin")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$env:PATH = ($pathAdds -join [IO.Path]::PathSeparator) + [IO.Path]::PathSeparator + $env:PATH

if ($SmokeTest) {
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  $serial = Join-Path $buildDir "serial.log"
  $stdout = Join-Path $buildDir "qemu.stdout.log"
  $stderr = Join-Path $buildDir "qemu.stderr.log"
  Remove-Item -LiteralPath $serial -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stdout -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stderr -Force -ErrorAction SilentlyContinue

  $qemuArgs = @(
    "-M", "virt",
    "-smp", "$Smp",
    "-m", "256",
    "-display", "none",
    "-serial", "file:$serial",
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

  try {
    Start-Sleep -Seconds $Seconds
  } finally {
    if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
      Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
    }
  }

  Start-Sleep -Milliseconds 250
  $serialText = if (Test-Path -LiteralPath $serial) {
    Get-Content -LiteralPath $serial -Raw
  } else {
    ""
  }

  Write-Output $serialText

  $bootedFromHfs = ($serialText -match "\[ELF\] saltando entry=") -and
                   ($serialText -match "\[XNU-CaribeOS\]")
  $firmwareMemoryReady = $serialText -match
                         "\[pmap\] OpenSBI M-mode reserved=0x80000000-0x80200000"
  $xnuMmuReady = ($serialText -match "\[pmap\] MMU handoff satp=") -and
                 ($serialText -match "\[pmap\] user root=.*shared kernel root slots=512")
  $gateAOnlineReady =
    ($serialText -match "\[smp-gate-a\] hart=1 slot=1") -and
    ($serialText -match "\[smp-gate-a\] per-hart tp/sscratch/stvec/stacks PASS")
  $gateAParkedReady = $gateAOnlineReady -and
    ($serialText -match "\[smp-gate-a\] hart=1 slot=1 cpu_data=0x[0-9a-fA-F]+ stack=0x[0-9a-fA-F]+ int_stack=0x[0-9a-fA-F]+") -and
    ($serialText -match "\[smp-smoke\] secondary parked confirmed")
  $gateBReady = $gateAParkedReady -and
    ($serialText -match "\[smp-gate-b\] ping-pong rounds=64 hart0-acks=64 hart1-acks=64 unexpected=0") -and
    ($serialText -match "\[smp-gate-b\] bidirectional SBI IPI/SSIP PASS")
  $userspaceAffinityReady =
    $serialText -match "\[smp-affinity\] Linux userspace bound to hart 0 PASS"
  $gateCReady = $gateAOnlineReady -and $userspaceAffinityReady -and
    ($serialText -match "\[smp-gate-c\] processor-state=4 idle-thread=0x(?!00000000)[0-9a-fA-F]{8} idle-entries=[1-9][0-9]* timer-irqs=[1-9][0-9]*") -and
    ($serialText -match "\[smp-gate-c\] XNU idle thread and per-hart timer PASS")
  $gateDReady = $gateCReady -and
    ($serialText -match "\[smp-gate-d\] rounds=10000 requests=10000 completions=10000 cpu=1 errors=0") -and
    ($serialText -match "\[smp-gate-d\] bound XNU kernel thread synchronization PASS")
  $gateEReady = $gateDReady -and
    ($serialText -match "\[smp-gate-e\] rounds=1024 active-mask=0x00000003 local-fences=[1-9][0-9]* remote-fences=[1-9][0-9]* stale=0 errors=0") -and
    ($serialText -match "\[smp-gate-e\] shared translation RFENCE coherence PASS")
  $gateFReady = $gateEReady -and
    ($serialText -match "\[smp-gate-f\] ast-signals=[1-9][0-9]* ast-ipis-total=[1-9][0-9]* ast-ipis-delta=[1-9][0-9]* remote-preemptions=[1-9][0-9]* preempt-cpu=1 before-release=1 wake-ipis=[0-9]+ prior-signals=0x00000001 unhandled=0") -and
    ($serialText -match "\[smp-gate-f\] preempt-state=6 current-pri=81 new-pri=95 processor-cpu-id=1 active-thread=0x(?!00000000)[0-9a-fA-F]{8} expected-active=0x(?!00000000)[0-9a-fA-F]{8} next-thread=0x00000000") -and
    ($serialText -match "\[smp-gate-f\] workers=2 cpu0=50000 cpu1=50000 locked-total=100000 overlap=0 online-mask=0x00000003 active-pmap-mask=0x00000003 errors=0") -and
    ($serialText -match "\[smp-gate-f\] dual-processor kernel scheduler and RV32A locks PASS")
  $smpGateReady = switch ($RequireSmpGate) {
    "A" { $gateAParkedReady }
    "B" { $gateBReady }
    "C" { $gateCReady }
    "D" { $gateDReady }
    "E" { $gateEReady }
    "F" { $gateFReady }
    default { $true }
  }
  $smpReady = ($Smp -le 1) -or
              ($serialText -match "\[smp-smoke\] secondary parked confirmed") -or
              (($RequireSmpGate -match '^[C-F]$') -and $smpGateReady)
  $stage1Ready = $firmwareMemoryReady -and $xnuMmuReady -and $smpReady -and
                 ($serialText -match "\[stage1-caribed\] system ready") -and
                 ($serialText -match "\[musl-probe\] PASS real musl libc") -and
                 ($serialText -match "\[gnu-bash\] PASS arrays loops arithmetic") -and
                 ($serialText -match "\[ld-caribe\] dynamic-loader handoff ok") -and
                 ($serialText -match "\[dynamic-probe\] main entry reached via ld-caribe") -and
                 ($serialText -match "\[linux\] exit status=0")

  if ($serialText -notmatch "\[CaribeBootX-RV32\]" -or -not $bootedFromHfs) {
    throw "QEMU smoke test did not reach native HFS+ boot into XNU-CaribeOS entry. See $serial and $stderr."
  }
  if ($serialText -match "(?m)(panic|scause=|stval=|sepc=)") {
    throw "QEMU smoke test saw a kernel panic or trap signature. See $serial and $stderr."
  }
  if ($RequireStage1 -and -not $stage1Ready) {
    throw "QEMU smoke test did not reach stage1 userspace readiness. See $serial and $stderr."
  }
  if ($RequireSmpGate -and -not $smpGateReady) {
    throw "QEMU smoke test did not pass SMP Gate $RequireSmpGate. See $serial and $stderr."
  }

  Write-Output "QEMU smoke test OK."
  exit 0
}

$qemuArgs = @(
  "-M", "virt",
  "-smp", "$Smp",
  "-m", "256",
  "-nographic",
  "-serial", "stdio",
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

& $QemuPath @qemuArgs
