# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tokens = $null; $errors = $null
$project = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'testproject.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Project runner parse error' }
$parameters = [scriptblock]::Create($project.ParamBlock.Extent.Text + "`n[pscustomobject]@{Cpu=`$Cpu; Mode=`$Mode; Futex=[bool]`$NativeFutex; Tcb=[bool]`$NativeTcb; Gate=`$TcbGate; Locker=[bool]`$NativeLocker; LockerGate=`$LockerGate}")
$profile = & $parameters -Mode graphics -Cpu 'rv32,f=false,d=false,h=false,zfa=false' -NativeFutex -NativeTcb -TcbGate B -NativeLocker -LockerGate B
if ($profile.Cpu -ne 'rv32,f=false,d=false,h=false,zfa=false' -or $profile.Mode -ne 'graphics' -or -not $profile.Futex -or -not $profile.Tcb -or $profile.Gate -ne 'B') {
    throw 'Project runner strict CPU/private-futex parameter binding regression'
}
if (-not $profile.Locker -or $profile.LockerGate -ne 'B') { throw 'Project runner Locker parameter binding regression' }
if (-not $project.Extent.Text.Contains('-Cpu $Cpu -SkipKernelBuild')) { throw 'Project runner lost explicit CPU forwarding' }
if (-not $project.Extent.Text.Contains('-NativeTcb:$NativeTcb -TcbGate $TcbGate')) { throw 'Project runner lost TCB forwarding' }
if (-not $project.Extent.Text.Contains('-NativeLocker:$NativeLocker -LockerGate $LockerGate')) { throw 'Project runner lost Locker forwarding' }
$mutex = New-Object Threading.Mutex($false, 'Local\CaribeOS-HFS-Graphics')
$owned = $false
try {
    try { $owned = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { throw 'A real runner is active; do not disturb it to test the lock' }
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/qemu-rv32-graphics.ps1') -SkipKernelBuild 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -eq 0 -or $output -notmatch 'Another graphics runner owns the HFS disk rebuild/run lock') {
        throw 'The actual graphics runner did not reject concurrent disk ownership'
    }
    foreach ($entry in @(
        @{Script='scripts/qemu-rv32-graphics.ps1'; Arguments=@('-NativeTcb','-DisableNativeThreads'); Error='TCB gates require enabled'},
        @{Script='scripts/qemu-rv32-graphics.ps1'; Arguments=@('-NativeTcb','-DisableNativeFutex'); Error='TCB gates require enabled'},
        @{Script='testproject.ps1'; Arguments=@('-Mode','up','-NativeTcb'); Error='TCB gates are supported for graphics'},
        @{Script='testproject.ps1'; Arguments=@('-Mode','graphics','-NativeTcb','-DisableNativeFutex'); Error='TCB gates require enabled'},
        @{Script='scripts/qemu-rv32-graphics.ps1'; Arguments=@('-NativeLocker','-DisableNativeThreads'); Error='Locker gates require enabled'},
        @{Script='scripts/qemu-rv32-graphics.ps1'; Arguments=@('-NativeLocker','-DisableNativeFutex'); Error='Locker gates require enabled'},
        @{Script='testproject.ps1'; Arguments=@('-Mode','up','-NativeLocker'); Error='Locker gates are supported for graphics'},
        @{Script='testproject.ps1'; Arguments=@('-Mode','up','-LockerGate','A'); Error='Locker gates are supported for graphics'},
        @{Script='testproject.ps1'; Arguments=@('-Mode','graphics','-NativeLocker','-DisableNativeFutex'); Error='Locker gates require enabled'}
    )) {
        $previous = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $arguments = $entry.Arguments
            $output = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $entry.Script) @arguments 2>&1 | Out-String)
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previous }
        if ($code -eq 0 -or $output -notmatch $entry.Error) { throw "Missing early invalid TCB rejection in $($entry.Script)" }
    }
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
Write-Host 'PASS actual CPU/TCB/Locker binding and forwarding, early invalid-profile and second-runner disk lock rejection; no kernel build, HFS writes or QEMU launched'
