param(
  [Parameter(Mandatory = $true)][string]$BackupDirectory,
  [switch]$CloneTest
)

$ErrorActionPreference = "Stop"

function Assert-Exit([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE"
  }
}

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

try {
  $backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
  $bundles = @(
    (Join-Path $backup "caribeos-xnu-tranche201.bundle")
    (Join-Path $backup "caribeos-runtime-tranche201.bundle")
  )
  $bundleVerifier = Join-Path $backup ".bundle-verifier.git"
  if (-not (Test-Path -LiteralPath $bundleVerifier -PathType Container)) {
    Invoke-Git $backup init --bare ".bundle-verifier.git" | Out-Null
  }
  $isBare = (Invoke-Git $bundleVerifier rev-parse --is-bare-repository).Trim()
  if ($isBare -ne "true") {
    throw "Bundle verifier is not a bare Git repository: $bundleVerifier"
  }
  foreach ($bundle in $bundles) {
    if (-not (Test-Path -LiteralPath $bundle -PathType Leaf)) {
      throw "Missing bundle: $bundle"
    }
    Invoke-Git $bundleVerifier bundle verify $bundle
  }

  $sumFile = Join-Path $backup "SHA256SUMS.txt"
  if (Test-Path -LiteralPath $sumFile) {
    foreach ($line in Get-Content -LiteralPath $sumFile) {
      if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { continue }
      $file = Join-Path $backup ($matches[2].Replace('/', '\'))
      if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Hashed file is missing: $file"
      }
      $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
      if ($actual -ne $matches[1]) {
        throw "SHA-256 mismatch: $file"
      }
    }
  }

  foreach ($archive in Get-ChildItem -LiteralPath $backup -Filter "*.tar.gz" -File) {
    & tar -tzf $archive.FullName | Out-Null
    Assert-Exit "tar listing $($archive.FullName)"
  }

  if ($CloneTest) {
    $testRoot = Join-Path $backup ("verify-clone-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    if (Test-Path -LiteralPath $testRoot) { throw "Verification path exists: $testRoot" }
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $names = @("xnu", "runtime")
    for ($i = 0; $i -lt $bundles.Count; $i++) {
      $clone = Join-Path $testRoot $names[$i]
      Invoke-Git $backup clone $bundles[$i] $clone
      Invoke-Git $clone fsck --full
      Invoke-Git $clone rev-parse "tranche-201-stage2-complete^{tag}" | Out-Null
    }
  }

  Write-Host "Backup verification passed: $backup"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
