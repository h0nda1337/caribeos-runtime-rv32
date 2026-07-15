param(
  [Parameter(Mandatory = $true)][string]$BackupDirectory,
  [Parameter(Mandatory = $true)][string]$DestinationRoot
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

try {
  $backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
  $destination = [IO.Path]::GetFullPath($DestinationRoot)
  if (Test-Path -LiteralPath $destination) {
    throw "Destination already exists; restore never overwrites: $destination"
  }

  $xnuBundle = Join-Path $backup "caribeos-xnu-tranche201.bundle"
  $runtimeBundle = Join-Path $backup "caribeos-runtime-tranche201.bundle"
  New-Item -ItemType Directory -Path $destination | Out-Null
  $bundleVerifier = Join-Path $destination ".bundle-verifier.git"
  Invoke-Git $destination init --bare ".bundle-verifier.git" | Out-Null
  foreach ($bundle in @($xnuBundle, $runtimeBundle)) {
    Invoke-Git $bundleVerifier bundle verify $bundle
  }

  $xnuRestore = Join-Path $destination "caribeos-xnu-rv32"
  $runtimeRestore = Join-Path $destination "caribeos-runtime-rv32"
  Invoke-Git $destination clone $xnuBundle $xnuRestore
  Invoke-Git $destination clone $runtimeBundle $runtimeRestore

  foreach ($repository in @($xnuRestore, $runtimeRestore)) {
    Invoke-Git $repository fsck --full
    Invoke-Git $repository rev-parse "tranche-201-stage2-complete^{tag}" | Out-Null
  }

  Write-Host "Restore completed in new directory: $destination"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
