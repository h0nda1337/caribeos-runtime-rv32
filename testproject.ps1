param(
  [ValidateSet("up", "smp", "process-gate-1", "process-gate-2", "process-gate-2-smp", "process-gate-3", "process-gate-3-smp", "process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-7-only", "process-gate-7-only-smp", "process-gate-8", "process-gate-8-smp", "process-gate-8-only", "process-gate-8-only-smp", "process-gate-9", "process-gate-9-smp", "process-gate-9-only", "process-gate-9-only-smp", "process-gate-10-only", "process-gate-10-only-smp", "process-gate-11", "process-gate-11-smp", "process-gate-12", "process-gate-12-smp", "process-gate-13", "process-gate-13-smp", "process-gate-14", "process-gate-15", "process-gate-15-smp", "process-gates", "interactive", "process-stress", "process-stability", "gate-a", "gate-b", "gate-c", "gate-d", "gate-e", "gate-f", "gates", "both", "all")]
  [string]$Mode = "up",
  [int]$Seconds = 45,
  [ValidateSet(100, 1000, 10000)]
  [int]$StressRounds = 10000,
  [switch]$KeepHistory,
  [switch]$NegativeVersionChecks
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "Required command not found in PATH: $Name"
  }
  return $cmd.Source
}

function Build-LatestXnuKernel {
  param(
    [string]$WorkspaceRoot,
    [string]$BuildDir
  )

  $xnuRoot = Join-Path $WorkspaceRoot "xnu-2050.48.11"
  $linkScript = Join-Path $xnuRoot "tools\riscv32-link-full-stage0.ps1"
  $kernelElf = Join-Path $xnuRoot "BUILD\obj\RELEASE_RISCV32\osfmk\RELEASE\xnu-caribeos-rv32-full-stage0.elf"
  $buildLog = Join-Path $BuildDir "testproject-latest-xnu-build.txt"
  if (-not (Test-Path -LiteralPath $linkScript)) {
    throw "XNU RV32 link script is missing: $linkScript"
  }

  Write-Host "==> refresh and link latest XNU-CaribeOS RV32 kernel"
  $savedErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & powershell -ExecutionPolicy Bypass -File $linkScript *> $buildLog
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $savedErrorActionPreference
  }
  if ($code -ne 0 -or -not (Test-Path -LiteralPath $kernelElf)) {
    Write-Host "FAILED: latest XNU-CaribeOS kernel build"
    Write-Host "Build log: $buildLog"
    if (Test-Path -LiteralPath $buildLog) {
      Get-Content -LiteralPath $buildLog -Tail 80
    }
    exit $(if ($code -ne 0) { $code } else { 1 })
  }
  $kernel = Get-Item -LiteralPath $kernelElf
  Write-Host ("XNU kernel: {0} bytes, linked {1:yyyy-MM-dd HH:mm:ss}" -f
    $kernel.Length, $kernel.LastWriteTime)
  Write-Host "Build log: $buildLog"
}

function Copy-SerialLog {
  param(
    [string]$BuildDir,
    [string]$Destination
  )

  $serial = Join-Path $BuildDir "serial.log"
  if (Test-Path -LiteralPath $serial) {
    Copy-Item -LiteralPath $serial -Destination $Destination -Force
  }
}

function Show-KeyLines {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    Write-Host "No serial log found at $SerialPath"
    return
  }

  $pattern = "CaribeBootX-RV32|XNU-CaribeOS|process-gate-(?:[1-9]|1[0-5])|\[tty\]|linux-process\]|linux-clone\]|linux-exec\]|linux-wait\]|linux-waitid\]|linux-signal\]|jobctl-wait\]|cpu1-probe\]|pmap\] OpenSBI M-mode reserved|pmap\] MMU handoff|shared kernel root slots|dynamic-loader handoff ok|dynamic-probe\] main entry|/proc/version|/proc/cpuinfo|/proc/meminfo|/proc/uptime|/proc/stat|/proc/caribeos|syscall register ABI|tty/null ABI ok|chdir/getcwd ABI ok|pipe/read/writev/ppoll ABI ok|llseek/readv/pread64 ABI ok|uname/statfs/prlimit/umask ABI ok|clock/times/sleep ABI ok|/proc/self/fd enumerated|/proc/self/fdinfo|^pos:\t|^flags:\t|^mnt_id:\t|^ino:\t|fd-links/relative path ABI ok|dup/dup3/fcntl ABI ok|process table wait4/waitid ABI ok|signal/jobctl ABI ok|exec /bin/musl-probe|musl-probe\]|gnu-bash\]|execveat AT_EMPTY_PATH|linux-exec\] execveat AT_EMPTY_PATH|linux-exec\] shebang|^[0-9]+\.[0-9]+ [0-9]+\.[0-9]+|^cpu |^cpu[0-9]+ |^intr |^ctxt |^btime |^processes |^procs_running |processor\t:|isa\t\t:|mmu\t\t:|MemTotal:|MemFree:|MemAvailable:|bootloader\t:|cbx_|opensbi_|sbi_runtime\t:|fdt_model\t:|fdt_compatible\t:|fdt_inventory\t:|active_mem\t:|total_mem_kb\t:|ram_banks\t:|mem_pages\t:|firmware\t:|smp-smoke|stage1-caribed\] system ready|GNU_HASH versym check|SYMTAB versym check|missing VERSYM check|linux\] exit (?:status|signal)|panic|scause=|stval=|sepc="
  Select-String -Path $SerialPath -Pattern $pattern | ForEach-Object {
    Write-Host $_.Line
  }
  Select-String -Path $SerialPath -Pattern "smp-gate-[a-f]" | ForEach-Object {
    Write-Host $_.Line
  }
}

function Assert-ProcessGate1 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 1 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-1] bootstrap begin",
    "[process-gate-1] PID1 XNU task/thread/pmap created; runnable PASS",
    "[process-gate-1] PID1 real XNU task/thread entered U-mode PASS",
    "[linux-process] pid=1 ppid=0 state=RUNNABLE",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 1 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "PID1 bootstrap failed; legacy fallback",
    "invalid Linux user thread bootstrap",
    "thread_bootstrap_return stub parked",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 1 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate2 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 2 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-2] begin real child exit/zombie/reap test",
    "[process-gate-2] child real XNU task/thread entered U-mode PASS",
    "[process-gate-2] child U-mode pid=2 calling exit_group(7)",
    "[linux] exit status=7",
    "[process-gate-2] child exit(7) -> ZOMBIE; SIGCHLD pending PASS",
    "[process-gate-2] XNU task/thread released",
    "Sv32 pages returned=",
    "[process-gate-2] zombie reaped; process table baseline restored PASS",
    "[process-gate-2] Gate 2 real exit/zombie/reap PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 2 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "[process-gate-2] FAIL",
    "child getpid mismatch FAIL",
    "exit_group returned FAIL",
    "PID1 bootstrap failed; legacy fallback",
    "destroying active user pmap",
    "page ownership mismatch",
    "double free in Sv32",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 2 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate3 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 3 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-3] begin two real task/thread processes test",
    "[process-gate-3] parent pid=2 task=0x",
    "[process-gate-3] pid=2 real XNU task/thread entered U-mode cpu=0 PASS",
    "[process-gate-3] parent U-mode pid=2 before clone(SIGCHLD)",
    "[process-gate-3] clone copied registers pc=0x",
    "and stack-pages=32 PASS",
    "[process-gate-3] simultaneous real processes parent=2 child=3",
    "[linux-clone] Gate 3 real child task/thread pid=3 parent=2 PASS",
    "[process-gate-3] parent clone returned pid=3; entering real wait4",
    "[linux-wait] parent=2 blocking selector=1 id=3 without polling",
    "[process-gate-3] pid=3 real XNU task/thread entered U-mode cpu=0 PASS",
    "[process-gate-3] child U-mode pid=3 ppid=2 calling exit_group(9)",
    "[linux] exit status=9",
    "[linux-wait] parent=2 woke and reaped child=3 status=9 PASS",
    "[process-gate-3] parent resumed after child status=9 and continues PASS",
    "[process-gate-3] child exit(9) woke blocked parent; real wait4 reaped PASS",
    "[process-gate-3] two tasks/threads released; Sv32 pages returned=",
    "backing-slots=0 zombies=1 PASS",
    "[process-gate-3] Gate 3 two real processes and blocking wait PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 3 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "[process-gate-3] FAIL",
    "LEGACY synthetic child record pid=3",
    "parent identity/clone/wait status mismatch FAIL",
    "child identity mismatch FAIL",
    "exit_group returned FAIL",
    "destroying active user pmap",
    "page ownership mismatch",
    "double free in Sv32",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 3 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate4 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 4 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-4] begin eager private-VM fork stress rounds=1000",
    "[process-gate-4] parent pid=2 task=0x",
    "[process-gate-4] parent entered U-mode cpu=0 PASS",
    "[process-gate-4] parent value=10 starting 1000 eager forks",
    "[process-gate-4] eager fork iteration=1 child=",
    "private-pages=35 affinity=cpu0",
    "[process-gate-4] first child private value=20 exit=12",
    "[process-gate-4] parent retained private value=10 status=12 PASS",
    "[process-gate-4] eager fork iteration=1000 child=",
    "[process-gate-4] user loop completed forks=1000 value=10 status=12 PASS",
    "[process-gate-4] kernel verified forks=1000 private-pages-per-fork=35 user-page-copies=35000 PASS",
    "[process-gate-4] task/thread/pmap/fd/backing/zombie counters baseline PASS",
    "[process-gate-4] Gate 4 eager private VM fork x1000 PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 4 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "[process-gate-4] FAIL",
    "parent fork/private-memory/wait mismatch FAIL",
    "child private-memory mismatch FAIL",
    "Linux user backing ownership mismatch",
    "Linux user backing free stack corrupt",
    "Gate 4 eager fork page count changed",
    "Gate 4 fork page-table count changed",
    "destroying active user pmap",
    "double free in Sv32",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 4 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate5 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 5 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-5] begin per-process fd/OFD fork-exec test",
    "[process-gate-5] parent pid=2 task=0x",
    "[process-gate-5] parent entered U-mode cpu=0 PASS",
    "[process-gate-5] parent opened fd3 CLOEXEC and read ABCD offset=4 PASS",
    "[process-gate-5] fork child=",
    "shared-ofd-table affinity=cpu0 PASS",
    "[process-gate-5] child pid=",
    "entered U-mode cpu=0 PASS",
    "[process-gate-5] child read EFGH through shared OFD and closed fd5 PASS",
    "[linux-exec] execve path=/bin/process-fd-exec",
    "[process-gate-5] exec kept process identity and removed CLOEXEC fd3 PASS",
    "[process-gate-5] exec image read PIPE from inherited fd4 PASS",
    "[linux] exit status=21",
    "[process-gate-5] parent observed shared offset and read IJKL after status=21 PASS",
    "[process-gate-5] parent close remained independent; user fd scenario PASS",
    "[process-gate-5] shared offset, independent close, CLOEXEC and inherited pipe PASS",
    "[process-gate-5] OFD alloc=6 retain=6 release=12 free=6; all baselines restored PASS",
    "[process-gate-5] per-process exec arena isolated child image from PID1 PASS",
    "[process-gate-5] Gate 5 per-process fd/OFD semantics PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 5 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "[process-gate-5] FAIL",
    "fd/OFD scenario FAIL",
    "exec image descriptor verification FAIL",
    "Linux OFD reference underflow",
    "Linux OFD free state corrupt",
    "process owns invalid fd OFD",
    "process owns invalid stdio OFD",
    "destroying active user pmap",
    "double free in Sv32",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 5 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate6 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 6 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-6] begin transactional exec stress rounds=1000",
    "[process-gate-6] parent pid=2 task=0x",
    "[process-gate-6] parent entered U-mode cpu=0 PASS",
    "[process-gate-6] parent state prepared; starting fork-exec-wait x1000",
    "[process-gate-6] fork iteration=1 child=",
    "[process-gate-6] rejected exec stage=interpreter-lookup errno=2 preserved old pmap/register image PASS",
    "[process-gate-6] failed exec returned ENOENT with registers/data/fd intact PASS",
    "[linux-exec] execve path=/bin/process-exec-child transactional commit pid=",
    "generation=1 old-pmap=0x",
    "new-pmap=0x",
    "[process-gate-6] exec image verified identity/argv/env/cwd/umask/credentials/signals/CLOEXEC PASS",
    "[process-gate-6] fork iteration=1000 child=",
    "[process-gate-6] reaped exec child iteration=1000 pid=",
    "status=23 resources released PASS",
    "[process-gate-6] userspace parent observed status=23 x1000 and continued PASS",
    "[process-gate-6] transactional commits=1000 rollback=1 old translations=0 PASS",
    "[process-gate-6] cloned user pages=35000 pmap-create/destroy=2002 page-tables-returned=6005 PASS",
    "[process-gate-6] PID/parent/cwd/umask/credentials/pgid/sid preserved; signal reset semantics PASS",
    "[process-gate-6] Gate 6 real fork-exec-exit-wait x1000 PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 6 missing marker '$marker' in $SerialPath"
    }
  }
  $forbidden = @(
    "[process-gate-6] FAIL",
    "pre-exec child scenario FAIL",
    "exec image invariant FAIL",
    "Gate 6 rollback changed live image",
    "Gate 6 old executable translation survived exec",
    "exec map commit returned wrong old map",
    "invalid exec arena release",
    "exec arena ownership mismatch",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 6 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate7 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 7 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-7] begin real wait4/waitid/zombie/reparent test",
    "[process-gate-7] parent pid=2 task=0x",
    "affinity=cpu0 runnable PASS",
    "[process-gate-7] parent entered U-mode cpu=0 PASS",
    "[process-gate-7] userspace parent starting real wait race matrix",
    "[process-gate-7] parent waited before child exit; SIGCHLD wakeup PASS",
    "[process-gate-7] child exited before wait; waitid WNOWAIT preserved zombie PASS",
    "[process-gate-7] WNOHANG returned 0 for live matching child PASS",
    "[process-gate-7] fork index=4 child=",
    "[process-gate-7] fork index=13 child=",
    "[process-gate-7] fork index=14 child=",
    "[process-gate-7] ten children exited/reaped in reverse order with no duplicates PASS",
    "[process-gate-7] wait4/waitid report ECHILD after final reap PASS",
    "[process-gate-7] parent leaving live child for PID1 reparent test",
    "[process-gate-7] exiting parent reparented live child to PID1 PASS",
    "[process-gate-7] wait-before-exit and exit-before-wait races PASS",
    "[process-gate-7] wait4 PID/ANY/WNOHANG and waitid PID/ALL/WNOWAIT PASS",
    "[process-gate-7] ten simultaneous children reaped out-of-order exactly once PASS",
    "[process-gate-7] XNU wait-channel blocks/resumes=",
    "[process-gate-7] cloned user pages=",
    "pmap-create/destroy=15 page-tables-returned=",
    "[process-gate-7] zombies=0 process/task/thread/pmap/fd baselines restored PASS",
    "[process-gate-7] Gate 7 real wait and zombie lifecycle PASS",
    "[stage1-caribed] process table wait4/waitid ABI ok",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 7 missing marker '$marker' in $SerialPath"
    }
  }
  $waitEvidence = [regex]::Match($serialText,
    '\[process-gate-7\] XNU wait-channel blocks/resumes=([0-9]+)/([0-9]+) no polling PASS')
  if (-not $waitEvidence.Success -or
      [uint32]$waitEvidence.Groups[1].Value -eq 0 -or
      $waitEvidence.Groups[1].Value -ne $waitEvidence.Groups[2].Value) {
    throw "Process Gate 7 did not prove balanced, nonzero XNU wait-channel blocking in $SerialPath"
  }
  $forbidden = @(
    "[process-gate-7] FAIL",
    "userspace wait scenario FAIL",
    "LEGACY synthetic child record",
    "invalid real wait selector",
    "invalid waitid selector",
    "expected child disappeared",
    "wait parent lifecycle mismatch",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 7 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate8 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 8 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-8] begin real SIGCHLD frame/rt_sigreturn test",
    "[process-gate-8] parent pid=2 task=0x",
    "affinity=cpu0 runnable PASS",
    "[process-gate-8] parent entered U-mode cpu=0 PASS",
    "[process-gate-8] userspace installing real SIGCHLD action",
    "[process-gate-8] eager fork child=",
    "private-pages=",
    "affinity=cpu0 PASS",
    "[process-gate-8] child pid=",
    "entered inherited U-mode cpu=0 PASS",
    "[process-gate-8] blocked SIGCHLD visible through rt_sigpending PASS",
    "[linux-signal] SIGCHLD frame pid=2 child=",
    "status=42 sp=0x",
    "handler=0x",
    "[process-gate-8] SIGCHLD handler entered with siginfo/ucontext PASS",
    "[linux-signal] rt_sigreturn restored pc=0x",
    "cpu=0 PASS",
    "[process-gate-8] rt_sigreturn restored PC/SP/registers/mask PASS",
    "[process-gate-8] child wait status=42 after handler PASS",
    "[process-gate-8] child resources and private pages returned PASS",
    "[process-gate-8] kernel observed one frame delivery and one rt_sigreturn PASS",
    "[process-gate-8] cloned user pages=",
    "pmap-create/destroy=2 page-tables-returned=",
    "[process-gate-8] process/task/thread/pmap/fd/signal baselines restored PASS",
    "[process-gate-8] Gate 8 real Linux RV32 signal frame PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 8 missing marker '$marker' in $SerialPath"
    }
  }

  $frameEvidence = [regex]::Match($serialText,
    '\[linux-signal\] SIGCHLD frame pid=2 child=([0-9]+) status=42 sp=0x([0-9a-fA-F]+) handler=0x([0-9a-fA-F]+) PASS')
  $returnEvidence = [regex]::Match($serialText,
    '\[linux-signal\] rt_sigreturn restored pc=0x([0-9a-fA-F]+) sp=0x([0-9a-fA-F]+) cpu=0 PASS')
  if (-not $frameEvidence.Success -or -not $returnEvidence.Success) {
    throw "Process Gate 8 did not emit parseable signal-frame evidence in $SerialPath"
  }
  $childPid = [uint32]$frameEvidence.Groups[1].Value
  $frameSp = [Convert]::ToUInt32($frameEvidence.Groups[2].Value, 16)
  $handlerPc = [Convert]::ToUInt32($frameEvidence.Groups[3].Value, 16)
  $restoredPc = [Convert]::ToUInt32($returnEvidence.Groups[1].Value, 16)
  $restoredSp = [Convert]::ToUInt32($returnEvidence.Groups[2].Value, 16)
  $frameDelta = if ($restoredSp -gt $frameSp) {
    [uint64]$restoredSp - [uint64]$frameSp
  } else {
    [uint64]0
  }
  if ($childPid -le 2 -or $handlerPc -eq 0 -or $restoredPc -eq 0 -or
      ($frameSp -band 15) -ne 0 -or $restoredSp -le $frameSp -or
      $frameDelta -lt 944 -or $frameDelta -gt 959) {
    throw "Process Gate 8 signal-frame addresses or child identity are invalid in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-8] FAIL",
    "userspace signal-frame scenario FAIL",
    "frame setup failed pid=",
    "rt_sigreturn frame ownership raced",
    "signal parent lifecycle mismatch",
    "signal, process, VM or descriptor counters did not return",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 8 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate9 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 9 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-9] begin directed signal/altstack/EINTR test",
    "[process-gate-9] parent pid=2 task=0x",
    "affinity=cpu0 runnable PASS",
    "[process-gate-9] parent entered U-mode cpu=0 PASS",
    "[process-gate-9] userspace installed SIGUSR1 SA_SIGINFO/SA_ONSTACK",
    "[process-gate-9] kill(self) delivered handler after syscall PASS",
    "[process-gate-9] eager fork index=1 child=",
    "[process-gate-9] SIGUSR1 interrupted XNU deadline sleep with EINTR PASS",
    "[process-gate-9] released sender child index=1 status=51 private pages returned PASS",
    "[process-gate-9] eager fork index=2 child=",
    "[process-gate-9] SIGUSR1 woke blocked wait4 with EINTR PASS",
    "[process-gate-9] released sender child index=2 status=52 private pages returned PASS",
    "[process-gate-9] wait4 retry reaped real sender child status=52 PASS",
    "[process-gate-9] altstack/siginfo/ucontext/handler-mask restored x3 PASS",
    "[process-gate-9] kernel queued=3 wakeups=2 frames/returns=3/3 PASS",
    "[process-gate-9] cloned user pages=",
    "pmap-create/destroy=3 page-tables-returned=",
    "[process-gate-9] process/task/thread/pmap/fd/signal baselines restored PASS",
    "[process-gate-9] Gate 9 directed signals and EINTR PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 9 missing marker '$marker' in $SerialPath"
    }
  }

  $queued = [regex]::Matches($serialText,
    '\[linux-signal\] queued signal=10 sender=([0-9]+) target=2 PASS')
  $frames = [regex]::Matches($serialText,
    '\[linux-signal\] signal=10 frame pid=2 sender=([0-9]+) sp=0x([0-9a-fA-F]+) handler=0x([0-9a-fA-F]+) PASS')
  $returns = [regex]::Matches($serialText,
    '\[linux-signal\] signal=10 rt_sigreturn pc=0x([0-9a-fA-F]+) sp=0x([0-9a-fA-F]+) cpu=0 PASS')
  if ($queued.Count -ne 3 -or $frames.Count -ne 3 -or
      $returns.Count -ne 3) {
    throw "Process Gate 9 did not prove exactly three queues, frames and returns in $SerialPath"
  }
  $frameStack = $null
  foreach ($match in $frames) {
    $sender = [uint32]$match.Groups[1].Value
    $sp = [Convert]::ToUInt32($match.Groups[2].Value, 16)
    $handler = [Convert]::ToUInt32($match.Groups[3].Value, 16)
    if ($sender -lt 2 -or $handler -eq 0 -or ($sp -band 15) -ne 0 -or
        $sp -ge 0x01000000) {
      throw "Process Gate 9 frame is not on the mapped low-address altstack in $SerialPath"
    }
    if ($null -eq $frameStack) {
      $frameStack = $sp
    } elseif ($frameStack -ne $sp) {
      throw "Process Gate 9 did not reuse the restored alternate stack deterministically in $SerialPath"
    }
  }
  foreach ($match in $returns) {
    $pc = [Convert]::ToUInt32($match.Groups[1].Value, 16)
    $sp = [Convert]::ToUInt32($match.Groups[2].Value, 16)
    if ($pc -eq 0 -or $sp -lt 0x70000000) {
      throw "Process Gate 9 rt_sigreturn did not restore the normal user context in $SerialPath"
    }
  }
  if ($queued[0].Groups[1].Value -ne "2" -or
      $queued[1].Groups[1].Value -eq "2" -or
      $queued[2].Groups[1].Value -eq "2") {
    throw "Process Gate 9 did not distinguish self and child senders in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-9] FAIL",
    "userspace directed-signal scenario FAIL",
    "frame setup failed pid=",
    "rt_sigreturn frame ownership raced",
    "directed signal parent lifecycle mismatch",
    "signal, process, VM or descriptor counters did not return",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 9 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate10 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 10 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[tty] NS16550 RX IRQ base=0x",
    "canonical ring ready PASS",
    "[process-gate-10] begin real UART RX and blocking TTY test",
    "[process-gate-10] parent pid=2 task=0x",
    "affinity=cpu0 runnable PASS",
    "[process-gate-10] parent entered U-mode cpu=0 PASS",
    "[process-gate-10] empty O_NONBLOCK read returned EAGAIN PASS",
    "[process-gate-10] type: ",
    "[process-gate-10] canonical echo/backspace partial reads FIONREAD PASS",
    "[process-gate-10] raw VMIN=2: ",
    "[process-gate-10] noncanonical VMIN=2 read returned XY PASS",
    "[process-gate-10] noncanonical VMIN=0 VTIME=1 timeout returned 0 PASS",
    "[process-gate-10] signal child index=1 pid=",
    "[process-gate-10] signal-read: blocking without UART input",
    "[process-gate-10] SIGUSR1 interrupted blocking read with EINTR PASS",
    "[process-gate-10] signal child status=61 resources returned PASS",
    "[process-gate-10] userspace UART/TTY scenario complete PASS",
    "[process-gate-10] UART irq=",
    "rx-bytes=11 lines=1 echo=12 overruns=0 PASS",
    "[process-gate-10] TTY read blocks/wakeups=",
    "EAGAIN=1 EINTR=1 VTIME=1 PASS",
    "[process-gate-10] cloned user pages=",
    "pmap-create/destroy=2 page-tables-returned=",
    "[process-gate-10] process/task/thread/pmap/fd/tty/signal baselines restored PASS",
    "[process-gate-10] Gate 10 real blocking UART TTY PASS",
    "[gnu-bash] PASS arrays loops arithmetic functions conditionals case",
    "[dynamic-probe] main entry reached via ld-caribe",
    "[linux] exit status=0"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 10 missing marker '$marker' in $SerialPath"
    }
  }

  $uart = [regex]::Match($serialText,
    '\[process-gate-10\] UART irq=([0-9]+) rx-bytes=11 lines=1 echo=12 overruns=0 PASS')
  $blocking = [regex]::Match($serialText,
    '\[process-gate-10\] TTY read blocks/wakeups=([0-9]+)/([0-9]+) EAGAIN=1 EINTR=1 VTIME=1 PASS')
  if (-not $uart.Success -or [uint32]$uart.Groups[1].Value -eq 0) {
    throw "Process Gate 10 did not prove a real UART interrupt in $SerialPath"
  }
  if (-not $blocking.Success) {
    throw "Process Gate 10 did not emit parseable blocking-read evidence in $SerialPath"
  }
  $blocks = [uint32]$blocking.Groups[1].Value
  $wakeups = [uint32]$blocking.Groups[2].Value
  if ($blocks -lt 3 -or $wakeups -ne $blocks) {
    throw "Process Gate 10 lost a TTY block/wakeup event in $SerialPath"
  }

  $queued = [regex]::Matches($serialText,
    '\[linux-signal\] queued signal=10 sender=([0-9]+) target=2 PASS')
  $frames = [regex]::Matches($serialText,
    '\[linux-signal\] signal=10 frame pid=2 sender=([0-9]+) sp=0x([0-9a-fA-F]+) handler=0x([0-9a-fA-F]+) PASS')
  $returns = [regex]::Matches($serialText,
    '\[linux-signal\] signal=10 rt_sigreturn pc=0x([0-9a-fA-F]+) sp=0x([0-9a-fA-F]+) cpu=0 PASS')
  if ($queued.Count -ne 1 -or $frames.Count -ne 1 -or
      $returns.Count -ne 1) {
    throw "Process Gate 10 did not prove exactly one signal queue, frame, and return in $SerialPath"
  }
  $sender = [uint32]$queued[0].Groups[1].Value
  $frameSender = [uint32]$frames[0].Groups[1].Value
  $frameSp = [Convert]::ToUInt32($frames[0].Groups[2].Value, 16)
  $handler = [Convert]::ToUInt32($frames[0].Groups[3].Value, 16)
  $returnPc = [Convert]::ToUInt32($returns[0].Groups[1].Value, 16)
  $returnSp = [Convert]::ToUInt32($returns[0].Groups[2].Value, 16)
  if ($sender -le 2 -or $frameSender -ne $sender -or $handler -eq 0 -or
      ($frameSp -band 15) -ne 0 -or $frameSp -ge 0x01000000 -or
      $returnPc -eq 0 -or $returnSp -lt 0x70000000) {
    throw "Process Gate 10 signal frame or restored user context is invalid in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-10] FAIL",
    "userspace UART/TTY scenario FAIL",
    "frame setup failed pid=",
    "rt_sigreturn frame ownership raced",
    "TTY parent lifecycle mismatch",
    "TTY, signal, process, VM or descriptor counters did not return",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu"
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 10 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate11 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 11 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-11] PID1 interactive argv/env stack PASS",
    "[stage1-init] exec /sbin/interactive-init",
    "[process-gate-11] PID 1 interactive init started tty=1 pgid=1 sid=1 PASS",
    "[process-gate-11] Bash child pid=2 affinity=cpu0 PASS",
    "[linux-exec] execve path=/bin/bash transactional commit pid=2",
    "CaribeOS login shell",
    "[process-gate-11] pselect6 blocking on TTY without polling PASS",
    "[process-gate-11] pselect6 woke for TTY readiness PASS",
    "[process-gate-11] waitid job-control options=0x0000000e accepted PASS",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 11 missing marker '$marker' in $SerialPath"
    }
  }

  $commandClones = [regex]::Matches($serialText,
    '\[linux-clone\] real task/thread child pid=([0-9]+) parent=2 affinity=cpu0')
  $commandExecs = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/caribectl transactional commit pid=([0-9]+)')
  $rendezvous = [regex]::Matches($serialText,
    '\[process-gate-11\] child U-mode rendezvous pid=([0-9]+) PASS')
  $argvEnv = [regex]::Matches($serialText,
    '\[process-gate-11\] exec argv/env collected argc=1 envc=12 PASS')
  $completed = [regex]::Matches($serialText,
    '(?m)^\[stage1-caribectl\] done\r?$')
  if ($commandClones.Count -ne 2 -or $commandExecs.Count -ne 2 -or
      $rendezvous.Count -ne 2 -or $argvEnv.Count -ne 2 -or
      $completed.Count -ne 2) {
    throw "Process Gate 11 did not prove exactly two real command process cycles in $SerialPath"
  }
  if ($commandClones[0].Groups[1].Value -eq
      $commandClones[1].Groups[1].Value -or
      $rendezvous[0].Groups[1].Value -eq
      $rendezvous[1].Groups[1].Value) {
    throw "Process Gate 11 reused a PID across distinct command cycles in $SerialPath"
  }
  if (-not $serialText.Contains("[linux-waitid] parent=1 blocking") -or
      -not $serialText.Contains("without polling")) {
    throw "Process Gate 11 did not prove PID1 blocking wait/reap in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-11] FAIL",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 11 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate12 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 12 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-11] Bash child pid=2 affinity=cpu0 PASS",
    "[process-gate-11] pselect6 blocking on TTY without polling PASS",
    "[process-gate-11] waitid job-control options=0x0000000e accepted PASS",
    "[process-gate-12] pipe writer pid=",
    "blocking on full pipe without polling PASS",
    "[process-gate-12] pipe reader pid=",
    "blocking on empty pipe without polling PASS",
    "observed EOF after final writer close PASS",
    "[pipeline-consumer] redirected input bytes=65 PASS",
    "[pipeline-producer] stderr redirection PASS",
    "[pipeline-sigpipe] default disposition armed PASS",
    "[process-gate-12] SIGPIPE queued pid=",
    "[process-gate-12] default SIGPIPE terminating pid=",
    "[linux] exit signal=13",
    "sigpipe=141",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 12 missing marker '$marker' in $SerialPath"
    }
  }

  $commandClones = [regex]::Matches($serialText,
    '\[linux-clone\] real task/thread child pid=([0-9]+) parent=2 affinity=cpu0')
  $rendezvous = [regex]::Matches($serialText,
    '\[process-gate-11\] child U-mode rendezvous pid=([0-9]+) PASS')
  $producerExecs = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/pipeline-producer transactional commit pid=([0-9]+)')
  $consumerExecs = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/pipeline-consumer transactional commit pid=([0-9]+)')
  $sigpipeExecs = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/pipeline-sigpipe transactional commit pid=([0-9]+)')
  $pipelineResults = [regex]::Matches($serialText,
    '\[pipeline-consumer\] bytes=12288 checksum=1566720 pattern=sequential PASS')
  $pipeCreates = [regex]::Matches($serialText,
    '\[process-gate-12\] pipe id=([0-9]+) read-fd=([0-9]+) write-fd=([0-9]+) capacity=4096 created PASS')
  $allPipeReleases = [regex]::Matches($serialText,
    '\[process-gate-12\] pipe id=([0-9]+) released readers/writers=0/0 bytes=([0-9]+)/([0-9]+) blocks/wakeups=([0-9]+)/([0-9]+)\+([0-9]+)/([0-9]+) PASS')
  $transferReleases = [regex]::Matches($serialText,
    '\[process-gate-12\] pipe id=([0-9]+) released readers/writers=0/0 bytes=12288/12288 blocks/wakeups=([0-9]+)/([0-9]+)\+([0-9]+)/([0-9]+) PASS')
  $lifecycles = [regex]::Matches($serialText,
    '\[process-gate-12\] blocking pipeline lifecycle index=([0-9]+) transfer=12288 EOF=1 no-lost-wakeup=1 resources=0 PASS')

  if ($commandClones.Count -ne 8 -or $rendezvous.Count -ne 8 -or
      $producerExecs.Count -ne 3 -or $consumerExecs.Count -ne 3 -or
      $sigpipeExecs.Count -ne 1 -or $pipelineResults.Count -ne 2 -or
      $pipeCreates.Count -ne 9 -or $allPipeReleases.Count -ne 9 -or
      $transferReleases.Count -ne 2 -or
      $lifecycles.Count -ne 2) {
    throw "Process Gate 12 process/pipe lifecycle counts are incomplete in $SerialPath"
  }
  foreach ($release in $transferReleases) {
    $readBlocks = [uint32]$release.Groups[2].Value
    $readWakeups = [uint32]$release.Groups[3].Value
    $writeBlocks = [uint32]$release.Groups[4].Value
    $writeWakeups = [uint32]$release.Groups[5].Value
    if ($readBlocks -eq 0 -or $readBlocks -ne $readWakeups -or
        $writeBlocks -eq 0 -or $writeBlocks -ne $writeWakeups) {
      throw "Process Gate 12 has unbalanced pipe block/wakeup counters in $SerialPath"
    }
  }
  if ($lifecycles[0].Groups[1].Value -ne "1" -or
      $lifecycles[1].Groups[1].Value -ne "2") {
    throw "Process Gate 12 lifecycle indices are not monotonic in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-12] FAIL",
    "[pipeline-consumer] FAIL",
    "[pipeline-sigpipe] FAIL",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "fatal user signal=",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 12 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate13 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 13 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-11] PID1 interactive argv/env stack PASS",
    "[process-gate-11] PID 1 interactive init started tty=1 pgid=1 sid=1 PASS",
    "[process-gate-11] Bash child pid=2 affinity=cpu0 PASS",
    "[process-gate-11] pselect6 blocking on TTY without polling PASS",
    "[process-gate-11] waitid job-control options=0x0000000e accepted PASS",
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
    "[linux] exit signal=2",
    "interrupt-status=130",
    "[process-gate-13] TTY VQUIT -> SIGQUIT foreground-pgid=",
    "[process-gate-13] default SIGQUIT terminating pid=",
    "[linux] exit signal=3",
    "quit-status=131",
    "gate13-finished",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 13 missing marker '$marker' in $SerialPath"
    }
  }

  $commandClones = [regex]::Matches($serialText,
    '\[linux-clone\] real task/thread child pid=([0-9]+) parent=2 affinity=cpu0')
  $rendezvous = [regex]::Matches($serialText,
    '\[process-gate-11\] child U-mode rendezvous pid=([0-9]+) PASS')
  $jobExecs = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/jobctl-wait transactional commit pid=([0-9]+)')
  $jobStarts = [regex]::Matches($serialText,
    '\[jobctl-wait\] pid=([0-9]+) pgid=([0-9]+) foreground=([0-9]+) blocking-read PASS')
  $ttyStops = [regex]::Matches($serialText,
    '\[process-gate-13\] TTY VSUSP -> SIGTSTP foreground-pgid=([0-9]+) targets=([0-9]+) PASS')
  $defaultStops = [regex]::Matches($serialText,
    '\[process-gate-13\] default SIGTSTP stopped pid=([0-9]+) pgid=([0-9]+) signal=20 PASS')
  $stopWaits = [regex]::Matches($serialText,
    '\[process-gate-13\] waitid observed child=([0-9]+) code=CLD_STOPPED status=20 PASS')
  $shellStopped = [regex]::Matches($serialText,
    '(?m)^\[1\]\+\s+Stopped.*jobctl-wait\r?$')
  $continues = [regex]::Matches($serialText,
    '\[process-gate-13\] SIGCONT resumed pid=([0-9]+) pgid=([0-9]+) PASS')
  $groupContinues = [regex]::Matches($serialText,
    '\[process-gate-13\] kill process-group pgid=([0-9]+) signal=18 targets=([0-9]+) PASS')
  $continueWaits = [regex]::Matches($serialText,
    '\[process-gate-13\] waitid observed child=([0-9]+) code=CLD_CONTINUED status=18 PASS')
  $helperResumes = [regex]::Matches($serialText,
    '(?m)^\[jobctl-wait\] resumed after SIGCONT; blocking-read PASS\r?$')
  $ttyRoutes = [regex]::Matches($serialText,
    '\[process-gate-13\] TTY VINTR -> SIGINT foreground-pgid=([0-9]+) targets=([0-9]+) PASS')
  $defaultExits = [regex]::Matches($serialText,
    '\[process-gate-13\] default SIGINT terminating pid=([0-9]+) at syscall return PASS')
  $signalExits = [regex]::Matches($serialText,
    '(?m)^\[linux\] exit signal=2\r?$')
  $statusLines = [regex]::Matches($serialText,
    '(?m)^interrupt-status=130\r?$')
  $ttyQuits = [regex]::Matches($serialText,
    '\[process-gate-13\] TTY VQUIT -> SIGQUIT foreground-pgid=([0-9]+) targets=([0-9]+) PASS')
  $defaultQuits = [regex]::Matches($serialText,
    '\[process-gate-13\] default SIGQUIT terminating pid=([0-9]+) at syscall return PASS')
  $signalQuitExits = [regex]::Matches($serialText,
    '(?m)^\[linux\] exit signal=3\r?$')
  $quitStatusLines = [regex]::Matches($serialText,
    '(?m)^quit-status=131\r?$')

  if ($commandClones.Count -ne 2 -or $rendezvous.Count -ne 2 -or
      $jobExecs.Count -ne 2 -or $jobStarts.Count -ne 2 -or
      $ttyStops.Count -ne 1 -or $defaultStops.Count -ne 1 -or
      $stopWaits.Count -ne 1 -or $shellStopped.Count -ne 2 -or
      $continues.Count -ne 1 -or $groupContinues.Count -ne 1 -or
      $continueWaits.Count -ne 1 -or $helperResumes.Count -ne 1 -or
      $ttyRoutes.Count -ne 1 -or $defaultExits.Count -ne 1 -or
      $signalExits.Count -ne 1 -or $statusLines.Count -ne 1 -or
      $ttyQuits.Count -ne 1 -or $defaultQuits.Count -ne 1 -or
      $signalQuitExits.Count -ne 1 -or $quitStatusLines.Count -ne 1) {
    throw "Process Gate 13 did not prove one stop/continue/interrupt lifecycle and one independent quit lifecycle in $SerialPath"
  }

  $jobPid = $jobStarts[0].Groups[1].Value
  $jobPgid = $jobStarts[0].Groups[2].Value
  $foregroundPgid = $jobStarts[0].Groups[3].Value
  if ($jobPid -ne $jobPgid -or $jobPgid -ne $foregroundPgid -or
      $commandClones[0].Groups[1].Value -ne $jobPid -or
      $rendezvous[0].Groups[1].Value -ne $jobPid -or
      $jobExecs[0].Groups[1].Value -ne $jobPid -or
      $ttyStops[0].Groups[1].Value -ne $jobPgid -or
      $ttyStops[0].Groups[2].Value -ne "1" -or
      $defaultStops[0].Groups[1].Value -ne $jobPid -or
      $defaultStops[0].Groups[2].Value -ne $jobPgid -or
      $stopWaits[0].Groups[1].Value -ne $jobPid -or
      $continues[0].Groups[1].Value -ne $jobPid -or
      $continues[0].Groups[2].Value -ne $jobPgid -or
      $groupContinues[0].Groups[1].Value -ne $jobPgid -or
      $groupContinues[0].Groups[2].Value -ne "1" -or
      $continueWaits[0].Groups[1].Value -ne $jobPid -or
      $ttyRoutes[0].Groups[1].Value -ne $jobPgid -or
      $ttyRoutes[0].Groups[2].Value -ne "1" -or
      $defaultExits[0].Groups[1].Value -ne $jobPid) {
    throw "Process Gate 13 PID/PGID/foreground signal routing is inconsistent in $SerialPath"
  }

  $quitPid = $jobStarts[1].Groups[1].Value
  $quitPgid = $jobStarts[1].Groups[2].Value
  $quitForegroundPgid = $jobStarts[1].Groups[3].Value
  if ($quitPid -eq $jobPid -or $quitPid -ne $quitPgid -or
      $quitPgid -ne $quitForegroundPgid -or
      $commandClones[1].Groups[1].Value -ne $quitPid -or
      $rendezvous[1].Groups[1].Value -ne $quitPid -or
      $jobExecs[1].Groups[1].Value -ne $quitPid -or
      $ttyQuits[0].Groups[1].Value -ne $quitPgid -or
      $ttyQuits[0].Groups[2].Value -ne "1" -or
      $defaultQuits[0].Groups[1].Value -ne $quitPid) {
    throw "Process Gate 13 SIGQUIT PID/PGID/foreground routing is inconsistent in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-13] FAIL",
    "[jobctl-wait] FAIL",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "unexpected supervisor interrupt",
    "fatal user signal=",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 13 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessGate14 {
  param([string]$SerialPath)

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 14 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[CaribeBootX-RV32] S-mode up. hart=0",
    "[XNU-CaribeOS] riscv32_kernel_entry",
    "[smp-gate-a] per-hart tp/sscratch/stvec/stacks PASS",
    "[smp-gate-c] XNU idle thread and per-hart timer PASS",
    "[smp-gate-d] bound XNU kernel thread synchronization PASS",
    "[smp-gate-e] shared translation RFENCE coherence PASS",
    "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS",
    "[process-gate-11] Bash child pid=2 affinity=cpu0 PASS",
    "[process-gate-14] child pid=",
    "parent=2 bound-cpu=1",
    "entered U-mode cpu=1 active-pmap-mask=0x00000002",
    "trap-stack=per-hart PASS",
    "cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS",
    "cpu=1 node=0 affinity=1 PASS",
    "getcpu-rounds=10000 mmap-rounds=256",
    "exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS",
    "child-last-cpu=1 pmap-release=1 status=0 PASS",
    "cpu1-status=0",
    "gate14-finished",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 14 missing marker '$marker' in $SerialPath"
    }
  }

  $clones = [regex]::Matches($serialText,
    '\[linux-clone\] real task/thread child pid=([0-9]+) parent=2 affinity=cpu1')
  $allCpu1Clones = [regex]::Matches($serialText,
    '\[linux-clone\] real task/thread child pid=([0-9]+) parent=([0-9]+) affinity=cpu1')
  $bound = [regex]::Matches($serialText,
    '\[process-gate-14\] child pid=([0-9]+) parent=2 bound-cpu=1 processor=0x([0-9a-f]+) private-pages=([0-9]+) PASS')
  $entered = [regex]::Matches($serialText,
    '\[process-gate-14\] child pid=([0-9]+) entered U-mode cpu=1 active-pmap-mask=0x00000002 trap-stack=per-hart PASS')
  $execSwitches = [regex]::Matches($serialText,
    '\[process-gate-14\] exec pid=([0-9]+) cpu=1 new-pmap-mask=0x00000002 old-pmap-mask=0x00000000 switch-coherent PASS')
  $execCommits = [regex]::Matches($serialText,
    '\[linux-exec\] execve path=/bin/cpu1-probe transactional commit pid=([0-9]+)')
  $getcpu = [regex]::Matches($serialText,
    '\[process-gate-14\] getcpu pid=([0-9]+) cpu=1 node=0 affinity=1 PASS')
  $probes = [regex]::Matches($serialText,
    '\[cpu1-probe\] pid=([0-9]+) cpu=1 getcpu-rounds=10000 mmap-rounds=256 checksum=0x([0-9a-f]+) PASS')
  $exits = [regex]::Matches($serialText,
    '\[process-gate-14\] child pid=([0-9]+) exit cpu=1 active-pmap-mask=0x00000002 status=0 PASS')
  $waits = [regex]::Matches($serialText,
    '\[process-gate-14\] Bash pid=2 cpu=0 (?:woke/|wait4 )reaped child=([0-9]+) child-last-cpu=1 pmap-release=1 status=0 PASS')
  $statusLines = [regex]::Matches($serialText,
    '(?m)^cpu1-status=0\r?$')
  $gateD = [regex]::Matches($serialText,
    '\[smp-gate-d\] rounds=10000 requests=10000 completions=10000 cpu=1 errors=0')
  $gateE = [regex]::Matches($serialText,
    '\[smp-gate-e\] rounds=1024 active-mask=0x00000003 local-fences=([0-9]+) remote-fences=([0-9]+) stale=0 errors=0')
  $gateF = [regex]::Matches($serialText,
    '\[smp-gate-f\] workers=2 cpu0=50000 cpu1=50000 locked-total=100000 overlap=0 online-mask=0x00000003 active-pmap-mask=0x00000003 errors=0')

  if ($clones.Count -ne 1 -or $allCpu1Clones.Count -ne 1 -or
      $bound.Count -ne 1 -or $entered.Count -ne 1 -or
      $execSwitches.Count -ne 1 -or $execCommits.Count -ne 1 -or
      $getcpu.Count -ne 1 -or $probes.Count -ne 1 -or
      $exits.Count -ne 1 -or $waits.Count -ne 1 -or
      $statusLines.Count -ne 1 -or $gateD.Count -ne 1 -or
      $gateE.Count -ne 1 -or $gateF.Count -ne 1) {
    throw "Process Gate 14 did not prove exactly one complete CPU1 lifecycle with stable SMP gates in $SerialPath"
  }

  $childPid = $clones[0].Groups[1].Value
  foreach ($observed in @(
      $allCpu1Clones[0].Groups[1].Value,
      $bound[0].Groups[1].Value,
      $entered[0].Groups[1].Value,
      $execSwitches[0].Groups[1].Value,
      $execCommits[0].Groups[1].Value,
      $getcpu[0].Groups[1].Value,
      $probes[0].Groups[1].Value,
      $exits[0].Groups[1].Value,
      $waits[0].Groups[1].Value)) {
    if ($observed -ne $childPid) {
      throw "Process Gate 14 mixed lifecycle evidence from different PIDs in $SerialPath"
    }
  }
  if ($allCpu1Clones[0].Groups[2].Value -ne "2" -or
      [Convert]::ToUInt32($bound[0].Groups[2].Value, 16) -eq 0 -or
      [uint32]$bound[0].Groups[3].Value -eq 0 -or
      [uint32]$gateE[0].Groups[1].Value -eq 0 -or
      [uint32]$gateE[0].Groups[2].Value -eq 0) {
    throw "Process Gate 14 did not retain a real CPU1 processor, private image, or RFENCE activity in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-14] FAIL",
    "[cpu1-probe] FAIL",
    "userspace trap violated CPU affinity",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "unexpected supervisor interrupt",
    "fatal user signal=",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 14 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Convert-ProcessResourceSnapshot {
  param([string]$Line)

  $snapshot = @{}
  foreach ($field in ($Line.Trim() -split ' ')) {
    $parts = $field -split '=', 2
    if ($parts.Count -ne 2 -or $parts[0] -notmatch '^[a-z0-9_]+$' -or
        $parts[1] -notmatch '^[0-9]+$') {
      throw "Malformed /proc/caribe/resources token '$field'."
    }
    $snapshot[$parts[0]] = [uint64]$parts[1]
  }
  if (-not $snapshot.ContainsKey('version') -or $snapshot.version -ne 1) {
    throw "Unsupported /proc/caribe/resources snapshot version."
  }
  return $snapshot
}

function Assert-ProcessGate15 {
  param(
    [string]$SerialPath,
    [switch]$RequireSmp
  )

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process Gate 15 serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[process-gate-15] fork-only-exit-wait rounds=1000 PASS",
    "[process-gate-15] fork-exec-exit-wait rounds=1000 PASS",
    "[process-gate-15] pipes=1000 bytes=64000 alloc-close/read-write verified PASS",
    "[process-gate-15] signals=1000 handlers=1000 siginfo=1000 altstack=1000 PASS",
    "[process-gate-15] pipelines=100 processes=200 transfer-bytes=1228800 PASS",
    "[process-gate-15] child-batches=10 batch-width=10 fork-exit-wait=100 zombies=0 PASS",
    "[process-gate-15] tty-lines=1000 content=validated canonical-blocking PASS",
    "gate15-finished",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process Gate 15 missing marker '$marker' in $SerialPath"
    }
  }
  if ($RequireSmp -and -not $serialText.Contains(
      "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
    throw "Process Gate 15 SMP did not preserve SMP Gate F in $SerialPath"
  }

  $resourceLines = [regex]::Matches($serialText,
    '(?m)^version=1 process_capacity=[0-9]+ .*\r?$')
  if ($resourceLines.Count -ne 2) {
    throw "Process Gate 15 expected exactly two resource snapshots in $SerialPath"
  }
  $baseline = Convert-ProcessResourceSnapshot $resourceLines[0].Value
  $final = Convert-ProcessResourceSnapshot $resourceLines[1].Value
  $stableFields = @(
    'process_capacity', 'process_entries', 'process_live', 'zombies',
    'tasks', 'threads', 'pmaps', 'pt_pages', 'kernel_pt_pages',
    'user_pages', 'exec_arenas', 'fd_refs', 'ofds', 'pipes',
    'signal_frames', 'free_pages', 'wired_pages',
    'kernel_stacks_active', 'kernel_stacks_total', 'zones',
    'zone_active', 'zone_bytes'
  )
  foreach ($field in $stableFields) {
    if (-not $baseline.ContainsKey($field) -or
        -not $final.ContainsKey($field) -or
        $baseline[$field] -ne $final[$field]) {
      throw "Process Gate 15 live resource '$field' drifted in $SerialPath"
    }
  }
  foreach ($field in @('zombies', 'pipes', 'signal_frames')) {
    if ($final[$field] -ne 0) {
      throw "Process Gate 15 final resource '$field' is not zero in $SerialPath"
    }
  }

  $cumulativeFields = @(
    'process_created', 'process_removed', 'process_exited', 'process_reaped',
    'pmap_created', 'pmap_destroyed', 'pt_alloc', 'pt_free',
    'backing_alloc', 'backing_free', 'ofd_alloc', 'ofd_free',
    'ofd_retain', 'ofd_release', 'pipe_alloc', 'pipe_release',
    'reserved_stack_handoffs', 'pipe_read_bytes', 'pipe_write_bytes',
    'pipe_read_blocks', 'pipe_read_wakeups', 'pipe_write_blocks',
    'pipe_write_wakeups', 'signal_queued', 'signal_discarded',
    'signal_delivered', 'signal_returned', 'signal_failures',
    'tty_lines', 'tty_overruns', 'tty_reads', 'tty_read_blocks',
    'tty_read_wakeups'
  )
  $delta = @{}
  foreach ($field in $cumulativeFields) {
    if (-not $baseline.ContainsKey($field) -or
        -not $final.ContainsKey($field) -or
        $final[$field] -lt $baseline[$field]) {
      throw "Process Gate 15 cumulative resource '$field' regressed or is missing in $SerialPath"
    }
    $delta[$field] = [uint64]($final[$field] - $baseline[$field])
  }
  if ($delta.process_created -lt 2307 -or
      $delta.process_created -ne $delta.process_removed -or
      $delta.process_created -ne $delta.process_exited -or
      $delta.process_created -ne $delta.process_reaped) {
    throw "Process Gate 15 process lifecycle accounting is not balanced in $SerialPath"
  }
  if ($delta.pmap_created -ne $delta.pmap_destroyed -or
      $delta.pt_alloc -ne $delta.pt_free -or
      $delta.backing_alloc -ne $delta.backing_free) {
    throw "Process Gate 15 VM accounting is not balanced in $SerialPath"
  }
  if ($delta.ofd_alloc -ne $delta.ofd_free -or
      $delta.ofd_release -ne ($delta.ofd_retain + $delta.ofd_alloc)) {
    throw "Process Gate 15 OFD accounting is not balanced in $SerialPath"
  }
  if ($delta.pipe_alloc -ne 1107 -or $delta.pipe_release -ne 1107 -or
      $delta.pipe_read_bytes -ne 1292800 -or
      $delta.pipe_write_bytes -ne 1292800 -or
      $delta.pipe_read_blocks -eq 0 -or
      $delta.pipe_read_blocks -ne $delta.pipe_read_wakeups -or
      $delta.pipe_write_blocks -eq 0 -or
      $delta.pipe_write_blocks -ne $delta.pipe_write_wakeups) {
    throw "Process Gate 15 pipe accounting is invalid in $SerialPath"
  }
  if ($delta.signal_delivered -lt 1000 -or
      $delta.signal_delivered -ne $delta.signal_returned -or
      $delta.signal_failures -ne 0) {
    throw "Process Gate 15 signal frame accounting is invalid in $SerialPath"
  }
  if ($delta.tty_lines -lt 1000 -or $delta.tty_overruns -ne 0 -or
      $delta.tty_read_blocks -eq 0 -or
      $delta.tty_read_blocks -ne $delta.tty_read_wakeups) {
    throw "Process Gate 15 TTY accounting is invalid in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-15] FAIL",
    "[gate15-stack]",
    "invalid stack handoff",
    "incoming trampoline has no continuation",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "unexpected supervisor interrupt",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process Gate 15 forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Assert-ProcessStress {
  param(
    [string]$SerialPath,
    [int]$Rounds
  )

  if (-not (Test-Path -LiteralPath $SerialPath)) {
    throw "Process stress serial log is missing: $SerialPath"
  }
  $serialText = Get-Content -LiteralPath $SerialPath -Raw
  $required = @(
    "[smp-gate-c] XNU idle thread and per-hart timer PASS",
    "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS",
    "[process-gate-14-stress] driver pid=",
    "[process-gate-14-stress] driver exec pid=",
    "[process-gate-14-stress] baseline processes=3 zombies=0",
    "[process-gate-14-stress] strict-baseline cycle=1",
    "[process-gate-14-stress] cycles=$Rounds fork=$Rounds entry=$Rounds exec=$Rounds getcpu=$Rounds exit=$Rounds reap=$Rounds errors=0 PASS",
    "[process-gate-14-stress] resource-baseline=stable",
    "[process-gate-14-stress] physical-baseline",
    "[process-gate-14-stress] zone-baseline",
    "gate14-stress-driver-status=0",
    "[process-gate-11] Bash exited status=0 and PID1 reaped PID2 PASS",
    "[process-gate-11] Gate 11 persistent interactive Bash PASS"
  )
  foreach ($marker in $required) {
    if (-not $serialText.Contains($marker)) {
      throw "Process stress missing marker '$marker' in $SerialPath"
    }
  }

  $final = [regex]::Matches($serialText,
    ('\[process-gate-14-stress\] cycles={0} fork={0} entry={0} exec={0} getcpu={0} exit={0} reap={0} errors=0 PASS' -f $Rounds))
  $resources = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] resource-baseline=stable pmap-create/destroy=([0-9]+)/([0-9]+) backing-alloc/free=([0-9]+)/([0-9]+) zombies=0 PASS')
  $ofd = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] ofd-retain/release=([0-9]+)/([0-9]+) rates=([0-9]+)/([0-9]+) live=([0-9]+) references=([0-9]+) PASS')
  $pageTables = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] user-pt-baseline=([0-9]+)/([0-9]+) kernel-pt-growth=([0-9]+) kernel-l0-growth=([0-9]+) last-kernel-l0-va=0x([0-9a-f]+) PASS')
  $physical = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] physical-baseline free-pages=([0-9]+)/([0-9]+) wired-pages=([0-9]+)/([0-9]+) kernel-stacks-active=([0-9]+)/([0-9]+) kernel-stacks-total=([0-9]+)/([0-9]+) PASS')
  $strictBaseline = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] strict-baseline cycle=1 zones=([0-9]+) active=([0-9]+) bytes=([0-9]+) no-warmup PASS')
  $zones = [regex]::Matches($serialText,
    '\[process-gate-14-stress\] zone-baseline zones=([0-9]+)/([0-9]+) active=([0-9]+)/([0-9]+) bytes=([0-9]+)/([0-9]+) PASS')
  if ($final.Count -ne 1 -or $resources.Count -ne 1 -or
      $ofd.Count -ne 1 -or $pageTables.Count -ne 1 -or
      $physical.Count -ne 1 -or $strictBaseline.Count -ne 1 -or
      $zones.Count -ne 1) {
    throw "Process stress did not emit exactly one complete resource summary in $SerialPath"
  }

  $expectedPmaps = [uint64](2 * ($Rounds - 1))
  $pmapCreates = [uint64]$resources[0].Groups[1].Value
  $pmapDestroys = [uint64]$resources[0].Groups[2].Value
  $backingAlloc = [uint64]$resources[0].Groups[3].Value
  $backingFree = [uint64]$resources[0].Groups[4].Value
  if ($pmapCreates -ne $expectedPmaps -or
      $pmapDestroys -ne $expectedPmaps -or
      $backingAlloc -ne $backingFree -or
      $backingAlloc -eq 0) {
    throw "Process stress pmap/backing lifecycle counters are unbalanced in $SerialPath"
  }

  if ($ofd[0].Groups[1].Value -ne $ofd[0].Groups[2].Value -or
      $ofd[0].Groups[3].Value -ne $ofd[0].Groups[4].Value -or
      [uint64]$ofd[0].Groups[1].Value -eq 0) {
    throw "Process stress OFD retain/release counters are unbalanced in $SerialPath"
  }
  if ($pageTables[0].Groups[1].Value -ne
      $pageTables[0].Groups[2].Value -or
      $pageTables[0].Groups[3].Value -ne
      $pageTables[0].Groups[4].Value) {
    throw "Process stress user/kernel page-table ownership counters drifted in $SerialPath"
  }
  for ($i = 1; $i -le 8; $i += 2) {
    if ($physical[0].Groups[$i].Value -ne
        $physical[0].Groups[$i + 1].Value) {
      throw "Process stress physical or kernel-stack baseline drifted in $SerialPath"
    }
  }
  for ($i = 1; $i -le 6; $i += 2) {
    if ($zones[0].Groups[$i].Value -ne
        $zones[0].Groups[$i + 1].Value) {
      throw "Process stress zone baseline drifted in $SerialPath"
    }
  }
  if ($strictBaseline[0].Groups[1].Value -ne
      $zones[0].Groups[1].Value -or
      $strictBaseline[0].Groups[2].Value -ne
      $zones[0].Groups[3].Value -or
      $strictBaseline[0].Groups[3].Value -ne
      $zones[0].Groups[5].Value) {
    throw "Process stress allocator baseline was not strict from cycle 1 in $SerialPath"
  }

  $forbidden = @(
    "[process-gate-14-stress] DRIFT",
    "[process-gate-14-stress] FAIL",
    "[process-gate-14] FAIL",
    "userspace trap violated CPU affinity",
    "Linux user backing page pool exhausted",
    "destroying active user pmap",
    "double free in Sv32",
    "unexpected supervisor interrupt",
    "fatal user signal=",
    "panic(cpu",
    "scause=",
    "stval=",
    "sepc="
  )
  foreach ($marker in $forbidden) {
    if ($serialText.Contains($marker)) {
      throw "Process stress forbidden marker '$marker' in $SerialPath"
    }
  }
}

function Invoke-MakeTarget {
  param(
    [string]$Target,
    [string]$Name,
    [int]$Seconds,
    [string]$BuildDir,
    [int]$ProcessStressRounds = 0,
    [switch]$KeepHistory
  )

  $runLog = Join-Path $BuildDir "testproject-latest-$Name-run.txt"
  $serialLog = Join-Path $BuildDir "testproject-latest-$Name-serial.txt"

  $makeArguments = @($Target, "QEMU_SMOKE_SECONDS=$Seconds")
  if ($ProcessStressRounds -gt 0) {
    $makeArguments += "GATE14_STRESS_ROUNDS=$ProcessStressRounds"
  }
  if ($Name -in @("process-gate-15", "process-gate-15-smp")) {
    $makeArguments += "GATE15_SECONDS=$Seconds"
  }
  Write-Host ("==> make " + ($makeArguments -join " "))
  $savedErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & make @makeArguments *> $runLog
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $savedErrorActionPreference
  }
  Copy-SerialLog -BuildDir $BuildDir -Destination $serialLog

  if ($Name -match '^gate-[a-f]$') {
    $gateDir = Join-Path $BuildDir "smp-gates"
    New-Item -ItemType Directory -Force -Path $gateDir | Out-Null
    Copy-Item -LiteralPath $runLog -Destination (Join-Path $gateDir "$Name-latest-run.txt") -Force
    if (Test-Path -LiteralPath $serialLog) {
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $gateDir "$Name-latest-serial.txt") -Force
    }
  }

  if ($Name -in @("process-gate-1", "process-gate-2", "process-gate-2-smp", "process-gate-3", "process-gate-3-smp", "process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-7-only", "process-gate-7-only-smp", "process-gate-8", "process-gate-8-smp", "process-gate-8-only", "process-gate-8-only-smp", "process-gate-9", "process-gate-9-smp", "process-gate-9-only", "process-gate-9-only-smp", "process-gate-10-only", "process-gate-10-only-smp", "process-gate-11", "process-gate-11-smp", "process-gate-12", "process-gate-12-smp", "process-gate-13", "process-gate-13-smp", "process-gate-14", "process-gate-15", "process-gate-15-smp")) {
    $gateDir = Join-Path $BuildDir "process-gates"
    New-Item -ItemType Directory -Force -Path $gateDir | Out-Null
    $gateLabel = switch ($Name) {
      "process-gate-1" { "gate-1" }
      "process-gate-2" { "gate-2" }
      "process-gate-2-smp" { "gate-2-smp" }
      "process-gate-3" { "gate-3" }
      "process-gate-3-smp" { "gate-3-smp" }
      "process-gate-4" { "gate-4" }
      "process-gate-4-smp" { "gate-4-smp" }
      "process-gate-5" { "gate-5" }
      "process-gate-5-smp" { "gate-5-smp" }
      "process-gate-6" { "gate-6" }
      "process-gate-6-smp" { "gate-6-smp" }
      "process-gate-7" { "gate-7" }
      "process-gate-7-smp" { "gate-7-smp" }
      "process-gate-7-only" { "gate-7-isolated" }
      "process-gate-7-only-smp" { "gate-7-smp-isolated" }
      "process-gate-8" { "gate-8" }
      "process-gate-8-smp" { "gate-8-smp" }
      "process-gate-8-only" { "gate-8-isolated" }
      "process-gate-8-only-smp" { "gate-8-smp-isolated" }
      "process-gate-9" { "gate-9" }
      "process-gate-9-smp" { "gate-9-smp" }
      "process-gate-9-only" { "gate-9-isolated" }
      "process-gate-9-only-smp" { "gate-9-smp-isolated" }
      "process-gate-10-only" { "gate-10-isolated" }
      "process-gate-10-only-smp" { "gate-10-smp-isolated" }
      "process-gate-11" { "gate-11" }
      "process-gate-11-smp" { "gate-11-smp" }
      "process-gate-12" { "gate-12" }
      "process-gate-12-smp" { "gate-12-smp" }
      "process-gate-13" { "gate-13" }
      "process-gate-13-smp" { "gate-13-smp" }
      "process-gate-14" { "gate-14" }
      "process-gate-15" { "gate-15" }
      "process-gate-15-smp" { "gate-15-smp" }
    }
    Copy-Item -LiteralPath $runLog -Destination (Join-Path $gateDir "$gateLabel-latest-run.txt") -Force
    if (Test-Path -LiteralPath $serialLog) {
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $gateDir "$gateLabel-latest-serial.txt") -Force
    }

    $semanticLog = switch ($Name) {
      "process-gate-1" { "process-gate-1-real-init.txt" }
      "process-gate-2" { "process-gate-2-exit-teardown.txt" }
      "process-gate-3" { "process-gate-3-two-tasks.txt" }
      "process-gate-4" { "process-gate-4-fork-vm.txt" }
      "process-gate-5" { "process-gate-5-fd-inheritance.txt" }
      "process-gate-6" { "process-gate-6-exec.txt" }
      "process-gate-7-only" { "process-gate-7-wait-zombie.txt" }
      "process-gate-8-only" { "process-gate-8-sigchld.txt" }
      "process-gate-9-only" { "process-gate-9-signal-frame.txt" }
      "process-gate-10-only" { "process-gate-10-tty-input.txt" }
      "process-gate-11" { "process-gate-11-bash-prompt.txt" }
      "process-gate-12" { "process-gate-12-pipeline.txt" }
      "process-gate-13" { "process-gate-13-job-control.txt" }
      "process-gate-14" { "process-gate-14-userspace-cpu1.txt" }
      "process-gate-15" { "process-gate-15-stability-up.txt" }
      "process-gate-15-smp" { "process-gate-15-stability-smp.txt" }
    }
    if ($semanticLog -and (Test-Path -LiteralPath $serialLog)) {
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $gateDir $semanticLog) -Force
    }
  }

  if ($Name -eq "process-stress") {
    $gateDir = Join-Path $BuildDir "process-gates"
    New-Item -ItemType Directory -Force -Path $gateDir | Out-Null
    Copy-Item -LiteralPath $runLog -Destination (Join-Path $BuildDir "process-stress-latest-run.txt") -Force
    Copy-Item -LiteralPath $runLog -Destination (Join-Path $gateDir "gate-14-stress-$ProcessStressRounds-latest-run.txt") -Force
    if (Test-Path -LiteralPath $serialLog) {
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $BuildDir "process-stress-latest-serial.txt") -Force
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $gateDir "gate-14-stress-$ProcessStressRounds-latest-serial.txt") -Force
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $gateDir "process-stress-latest.txt") -Force
    }
  }

  if ($KeepHistory) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $runLog -Destination (Join-Path $BuildDir "testproject-$stamp-$Name-run.txt") -Force
    if (Test-Path -LiteralPath $serialLog) {
      Copy-Item -LiteralPath $serialLog -Destination (Join-Path $BuildDir "testproject-$stamp-$Name-serial.txt") -Force
    }
  }

  if ($code -ne 0) {
    Write-Host "FAILED: $Target"
    Write-Host "Run log: $runLog"
    Write-Host "Serial log: $serialLog"
    Show-KeyLines -SerialPath $serialLog
    exit $code
  }

  if ($Name -in @("up", "smp", "process-gate-1", "process-gate-2", "process-gate-2-smp", "process-gate-3", "process-gate-3-smp", "process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-7-only", "process-gate-7-only-smp", "process-gate-8", "process-gate-8-smp", "process-gate-8-only", "process-gate-8-only-smp", "process-gate-9", "process-gate-9-smp", "process-gate-9-only", "process-gate-9-only-smp", "process-gate-10-only", "process-gate-10-only-smp", "gate-a", "gate-b", "gate-c", "gate-d", "gate-e", "gate-f")) {
    try {
      Assert-ProcessGate1 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 1 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-2", "process-gate-2-smp", "process-gate-3", "process-gate-3-smp", "process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate2 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 2 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-3", "process-gate-3-smp", "process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate3 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 3 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-4", "process-gate-4-smp", "process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate4 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 4 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-5", "process-gate-5-smp", "process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate5 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 5 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-6", "process-gate-6-smp", "process-gate-7", "process-gate-7-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate6 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 6 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-7", "process-gate-7-smp", "process-gate-7-only", "process-gate-7-only-smp", "process-gate-8", "process-gate-8-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate7 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 7 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-8", "process-gate-8-smp", "process-gate-8-only", "process-gate-8-only-smp", "process-gate-9", "process-gate-9-smp")) {
    try {
      Assert-ProcessGate8 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 8 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-9", "process-gate-9-smp", "process-gate-9-only", "process-gate-9-only-smp")) {
    try {
      Assert-ProcessGate9 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 9 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-10-only", "process-gate-10-only-smp")) {
    try {
      Assert-ProcessGate10 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 10 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-11", "process-gate-11-smp")) {
    try {
      Assert-ProcessGate11 -SerialPath $serialLog
      if ($Name -eq "process-gate-11-smp") {
        $serialText = Get-Content -LiteralPath $serialLog -Raw
        if (-not $serialText.Contains(
            "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
          throw "Process Gate 11 SMP did not preserve SMP Gate F in $serialLog"
        }
      }
    } catch {
      Write-Host "FAILED: Process Gate 11 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-12", "process-gate-12-smp")) {
    try {
      Assert-ProcessGate12 -SerialPath $serialLog
      if ($Name -eq "process-gate-12-smp") {
        $serialText = Get-Content -LiteralPath $serialLog -Raw
        if (-not $serialText.Contains(
            "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
          throw "Process Gate 12 SMP did not preserve SMP Gate F in $serialLog"
        }
      }
    } catch {
      Write-Host "FAILED: Process Gate 12 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-13", "process-gate-13-smp")) {
    try {
      Assert-ProcessGate13 -SerialPath $serialLog
      if ($Name -eq "process-gate-13-smp") {
        $serialText = Get-Content -LiteralPath $serialLog -Raw
        if (-not $serialText.Contains(
            "[smp-gate-f] dual-processor kernel scheduler and RV32A locks PASS")) {
          throw "Process Gate 13 SMP did not preserve SMP Gate F in $serialLog"
        }
      }
    } catch {
      Write-Host "FAILED: Process Gate 13 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -eq "process-gate-14") {
    try {
      Assert-ProcessGate14 -SerialPath $serialLog
    } catch {
      Write-Host "FAILED: Process Gate 14 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -in @("process-gate-15", "process-gate-15-smp")) {
    try {
      Assert-ProcessGate15 -SerialPath $serialLog `
        -RequireSmp:($Name -eq "process-gate-15-smp")
    } catch {
      Write-Host "FAILED: Process Gate 15 assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  if ($Name -eq "process-stress") {
    try {
      Assert-ProcessStress -SerialPath $serialLog -Rounds $ProcessStressRounds
    } catch {
      Write-Host "FAILED: Process stress assertions"
      Write-Host $_.Exception.Message
      Show-KeyLines -SerialPath $serialLog
      exit 1
    }
  }

  Write-Host "OK: $Target"
  Write-Host "QEMU smoke test OK: $Target"
  Write-Host "Run log: $runLog"
  Write-Host "Serial log: $serialLog"
  Show-KeyLines -SerialPath $serialLog
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$buildDir = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $root)
$pathAdds = @(
  (Join-Path $workspaceRoot "msys64\ucrt64\bin"),
  (Join-Path $workspaceRoot "msys64\usr\bin")
) | Where-Object { Test-Path -LiteralPath $_ }
if ($pathAdds.Count -ne 0) {
  $env:PATH = ($pathAdds -join [IO.Path]::PathSeparator) +
              [IO.Path]::PathSeparator + $env:PATH
}

Require-Command "make" | Out-Null
Require-Command "qemu-system-riscv32" | Out-Null
if (-not (Get-Command "riscv64-unknown-elf-gcc" -ErrorAction SilentlyContinue) -and
    -not (Get-Command "riscv32-unknown-elf-gcc" -ErrorAction SilentlyContinue)) {
  throw "Required RISC-V GCC toolchain not found in PATH."
}

$projectDrive = ([IO.Path]::GetPathRoot($root)).TrimEnd('\').TrimEnd(':')
$free = (Get-PSDrive $projectDrive -ErrorAction SilentlyContinue).Free
if ($free) {
  Write-Host ("{0}: free space: {1:N2} GB" -f $projectDrive, ($free / 1GB))
}

Build-LatestXnuKernel -WorkspaceRoot $workspaceRoot -BuildDir $buildDir

if ($Mode -in @("process-gates", "all")) {
  $processGateSuite = @(
    [pscustomobject]@{ Target = "boot_stage1"; Name = "process-gate-1"; Minimum = 45 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_2"; Name = "process-gate-2"; Minimum = 45 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_3"; Name = "process-gate-3"; Minimum = 45 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_4"; Name = "process-gate-4"; Minimum = 120 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_5"; Name = "process-gate-5"; Minimum = 120 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_6"; Name = "process-gate-6"; Minimum = 300 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_7_only"; Name = "process-gate-7-only"; Minimum = 90 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_8_only"; Name = "process-gate-8-only"; Minimum = 90 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_9_only"; Name = "process-gate-9-only"; Minimum = 100 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_10_only"; Name = "process-gate-10-only"; Minimum = 120 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_11"; Name = "process-gate-11"; Minimum = 120 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_12"; Name = "process-gate-12"; Minimum = 180 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_13"; Name = "process-gate-13"; Minimum = 180 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_14"; Name = "process-gate-14"; Minimum = 240 },
    [pscustomobject]@{ Target = "boot_stage1_process_gate_15"; Name = "process-gate-15"; Minimum = 90 }
  )
  foreach ($gate in $processGateSuite) {
    $gateSeconds = [Math]::Max($Seconds, $gate.Minimum)
    Invoke-MakeTarget -Target $gate.Target -Name $gate.Name `
      -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  }
}

if ($Mode -eq "up" -or $Mode -eq "both" -or $Mode -eq "all") {
  Invoke-MakeTarget -Target "boot_stage1" -Name "up" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "interactive") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_11" -Name "process-gate-11" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-1") {
  Invoke-MakeTarget -Target "boot_stage1" -Name "process-gate-1" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-2") {
  Invoke-MakeTarget -Target "boot_stage1_process_gate_2" -Name "process-gate-2" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-2-smp") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_2_smp" -Name "process-gate-2-smp" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-3") {
  Invoke-MakeTarget -Target "boot_stage1_process_gate_3" -Name "process-gate-3" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-3-smp") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_3_smp" -Name "process-gate-3-smp" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-4") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_4" -Name "process-gate-4" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-4-smp") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_4_smp" -Name "process-gate-4-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-5") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_5" -Name "process-gate-5" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-5-smp") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_5_smp" -Name "process-gate-5-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-6") {
  $gateSeconds = [Math]::Max($Seconds, 300)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_6" -Name "process-gate-6" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-6-smp") {
  $gateSeconds = [Math]::Max($Seconds, 320)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_6_smp" -Name "process-gate-6-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-7") {
  $gateSeconds = [Math]::Max($Seconds, 480)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_7" -Name "process-gate-7" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-7-smp") {
  $gateSeconds = [Math]::Max($Seconds, 600)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_7_smp" -Name "process-gate-7-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-7-only") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_7_only" -Name "process-gate-7-only" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-7-only-smp") {
  $gateSeconds = [Math]::Max($Seconds, 100)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_7_only_smp" -Name "process-gate-7-only-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-8") {
  $gateSeconds = [Math]::Max($Seconds, 540)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_8" -Name "process-gate-8" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-8-smp") {
  $gateSeconds = [Math]::Max($Seconds, 680)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_8_smp" -Name "process-gate-8-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-8-only") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_8_only" -Name "process-gate-8-only" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-8-only-smp") {
  $gateSeconds = [Math]::Max($Seconds, 100)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_8_only_smp" -Name "process-gate-8-only-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-9") {
  $gateSeconds = [Math]::Max($Seconds, 600)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_9" -Name "process-gate-9" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-9-smp") {
  $gateSeconds = [Math]::Max($Seconds, 750)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_9_smp" -Name "process-gate-9-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-9-only") {
  $gateSeconds = [Math]::Max($Seconds, 100)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_9_only" -Name "process-gate-9-only" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-9-only-smp") {
  $gateSeconds = [Math]::Max($Seconds, 110)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_9_only_smp" -Name "process-gate-9-only-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-10-only") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_10_only" -Name "process-gate-10-only" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-10-only-smp") {
  $gateSeconds = [Math]::Max($Seconds, 140)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_10_only_smp" -Name "process-gate-10-only-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-11") {
  $gateSeconds = [Math]::Max($Seconds, 120)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_11" -Name "process-gate-11" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-11-smp") {
  $gateSeconds = [Math]::Max($Seconds, 150)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_11_smp" -Name "process-gate-11-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-12") {
  $gateSeconds = [Math]::Max($Seconds, 180)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_12" -Name "process-gate-12" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-12-smp") {
  $gateSeconds = [Math]::Max($Seconds, 210)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_12_smp" -Name "process-gate-12-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-13") {
  $gateSeconds = [Math]::Max($Seconds, 180)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_13" -Name "process-gate-13" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-13-smp") {
  $gateSeconds = [Math]::Max($Seconds, 210)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_13_smp" -Name "process-gate-13-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-14") {
  $gateSeconds = [Math]::Max($Seconds, 240)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_14" -Name "process-gate-14" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-15") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_15" -Name "process-gate-15" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-gate-15-smp") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_15_smp" -Name "process-gate-15-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-stability") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_15" -Name "process-gate-15" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  Invoke-MakeTarget -Target "boot_stage1_process_gate_15_smp" -Name "process-gate-15-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "all") {
  $gateSeconds = [Math]::Max($Seconds, 90)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_15_smp" -Name "process-gate-15-smp" -Seconds $gateSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "process-stress" -or $Mode -eq "all") {
  $stressSeconds = [Math]::Max($Seconds, 300)
  Invoke-MakeTarget -Target "boot_stage1_process_gate_14_stress" -Name "process-stress" -Seconds $stressSeconds -BuildDir $buildDir -ProcessStressRounds $StressRounds -KeepHistory:$KeepHistory
}

if ($Mode -eq "smp" -or $Mode -eq "both") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp" -Name "smp" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-a" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_a" -Name "gate-a" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-b" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_b" -Name "gate-b" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-c" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_c" -Name "gate-c" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-d" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_d" -Name "gate-d" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-e" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_e" -Name "gate-e" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($Mode -eq "gate-f" -or $Mode -eq "gates" -or $Mode -eq "all") {
  $smpSeconds = [Math]::Max($Seconds, 50)
  Invoke-MakeTarget -Target "boot_stage1_smp_gate_f" -Name "gate-f" -Seconds $smpSeconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

if ($NegativeVersionChecks) {
  Invoke-MakeTarget -Target "boot_stage1_badmainversym_expected_fail" -Name "badmainversym" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  Invoke-MakeTarget -Target "boot_stage1_badversym_expected_fail" -Name "badversym" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  Invoke-MakeTarget -Target "boot_stage1_noversym_expected_fail" -Name "noversym" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  Invoke-MakeTarget -Target "boot_stage1_sysv_badversym_expected_fail" -Name "sysv-badversym" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
  Invoke-MakeTarget -Target "boot_stage1_badvername_expected_fail" -Name "badvername" -Seconds $Seconds -BuildDir $buildDir -KeepHistory:$KeepHistory
}

Write-Host "testproject.ps1 completed."
