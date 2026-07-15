param(
  [string]$BackupRoot = "F:\CaribeOS-Backups",
  [string]$XnuPath,
  [string]$RuntimePath,
  [switch]$SkipRawSnapshot,
  [switch]$PushGitHub
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
  param([string]$Repository, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $commandOutput = & git -C $Repository @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  foreach ($line in $commandOutput) {
    Write-Output ([string]$line)
  }
  if ($exitCode -ne 0) {
    throw "git $($Arguments -join ' ') failed in $Repository with exit code $exitCode"
  }
}

function Resolve-ProjectPaths {
  if (-not $script:RuntimePath) {
    $candidate = Split-Path -Parent $PSScriptRoot
    if (Test-Path -LiteralPath (Join-Path $candidate "testproject.ps1")) {
      $script:RuntimePath = $candidate
    }
  }
  if (-not $script:RuntimePath) {
    throw "RuntimePath is required when the script is not run from the runtime tools directory."
  }
  $script:RuntimePath = (Resolve-Path -LiteralPath $script:RuntimePath).Path
  if (-not $script:XnuPath) {
    $workspace = Split-Path -Parent (Split-Path -Parent $script:RuntimePath)
    $script:XnuPath = Join-Path $workspace "xnu-2050.48.11"
  }
  $script:XnuPath = (Resolve-Path -LiteralPath $script:XnuPath).Path
}

function Assert-RepositoryReady {
  param([string]$Repository)
  Invoke-Git $Repository rev-parse --is-inside-work-tree | Out-Null
  foreach ($name in @("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG")) {
    $path = (& git -C $Repository rev-parse --git-path $name).Trim()
    if (Test-Path -LiteralPath $path) {
      throw "Incomplete Git operation detected in $Repository ($name)."
    }
  }
  foreach ($name in @("rebase-apply", "rebase-merge", "sequencer")) {
    $path = (& git -C $Repository rev-parse --git-path $name).Trim()
    if (Test-Path -LiteralPath $path) {
      throw "Incomplete Git operation detected in $Repository ($name)."
    }
  }
}

function New-RawSnapshot {
  param([string]$Repository, [string]$Output)
  $parent = Split-Path -Parent $Repository
  $leaf = Split-Path -Leaf $Repository
  & tar -czf $Output -C $parent $leaf
  if ($LASTEXITCODE -ne 0) {
    throw "tar failed for $Repository with exit code $LASTEXITCODE"
  }
  & tar -tzf $Output | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "snapshot listing failed for $Output"
  }
}

try {
  foreach ($command in @("git", "tar")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
      throw "Required command not found: $command"
    }
  }
  Resolve-ProjectPaths
  Assert-RepositoryReady $XnuPath
  Assert-RepositoryReady $RuntimePath

  New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $destination = Join-Path $BackupRoot "caribeos-$timestamp"
  if (Test-Path -LiteralPath $destination) {
    throw "Backup destination already exists: $destination"
  }
  New-Item -ItemType Directory -Path $destination | Out-Null

  Invoke-Git $XnuPath status --porcelain=v2 --branch --untracked-files=all |
    Out-File -LiteralPath (Join-Path $destination "xnu-status.txt") -Encoding utf8
  Invoke-Git $RuntimePath status --porcelain=v2 --branch --untracked-files=all |
    Out-File -LiteralPath (Join-Path $destination "runtime-status.txt") -Encoding utf8

  if (-not $SkipRawSnapshot) {
    New-RawSnapshot $XnuPath (Join-Path $destination "xnu-working-tree.tar.gz")
    New-RawSnapshot $RuntimePath (Join-Path $destination "runtime-working-tree.tar.gz")
  }

  $xnuBundle = Join-Path $destination "caribeos-xnu-tranche201.bundle"
  $runtimeBundle = Join-Path $destination "caribeos-runtime-tranche201.bundle"
  Invoke-Git $XnuPath bundle create $xnuBundle --all
  Invoke-Git $RuntimePath bundle create $runtimeBundle --all
  $bundleVerifier = Join-Path $destination ".bundle-verifier.git"
  Invoke-Git $destination init --bare ".bundle-verifier.git" | Out-Null
  Invoke-Git $bundleVerifier bundle verify $xnuBundle
  Invoke-Git $bundleVerifier bundle verify $runtimeBundle
  Invoke-Git $XnuPath fsck --full
  Invoke-Git $RuntimePath fsck --full

  $logs = Join-Path $destination "selected-logs"
  New-Item -ItemType Directory -Path $logs | Out-Null
  $runtimeBuild = Join-Path $RuntimePath "build"
  if (Test-Path -LiteralPath $runtimeBuild) {
    Get-ChildItem -LiteralPath $runtimeBuild -Filter "tranche201-final-*.txt" -File |
      Copy-Item -Destination $logs
  }

  $hashFiles = Get-ChildItem -LiteralPath $destination -File -Recurse |
    Where-Object { $_.Name -ne "SHA256SUMS.txt" }
  $hashLines = foreach ($file in $hashFiles) {
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($file.FullName.Substring($destination.Length + 1).Replace('\', '/'))"
  }
  $hashLines | Out-File -LiteralPath (Join-Path $destination "SHA256SUMS.txt") -Encoding ascii

  $manifest = [ordered]@{
    timestamp = (Get-Date).ToString("o")
    xnu_path = $XnuPath
    runtime_path = $RuntimePath
    xnu_commit = (& git -C $XnuPath rev-parse HEAD).Trim()
    runtime_commit = (& git -C $RuntimePath rev-parse HEAD).Trim()
    tag = "tranche-201-stage2-complete"
    xnu_dirty = [bool](@(& git -C $XnuPath status --porcelain).Count)
    runtime_dirty = [bool](@(& git -C $RuntimePath status --porcelain).Count)
    bundles_verified = $true
    raw_snapshots = -not [bool]$SkipRawSnapshot
    git_version = (& git --version | Out-String).Trim()
  }
  $manifest | ConvertTo-Json -Depth 4 |
    Out-File -LiteralPath (Join-Path $destination "BACKUP_MANIFEST.json") -Encoding utf8

  if ($PushGitHub) {
    foreach ($repository in @($XnuPath, $RuntimePath)) {
      $remote = & git -C $repository remote
      if ($remote -notcontains "github-backup") {
        throw "github-backup remote is missing in $repository"
      }
      Invoke-Git $repository push github-backup --all
      Invoke-Git $repository push github-backup --tags
    }
  }

  Write-Host "CaribeOS backup verified: $destination"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
