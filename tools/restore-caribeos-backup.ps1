param(
  [Parameter(Mandatory = $true)][string]$BackupDirectory,
  [Parameter(Mandatory = $true)][string]$DestinationRoot
)

$ErrorActionPreference = "Stop"

function Assert-Exit([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE"
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
  foreach ($bundle in @($xnuBundle, $runtimeBundle)) {
    & git bundle verify $bundle
    Assert-Exit "git bundle verify $bundle"
  }

  New-Item -ItemType Directory -Path $destination | Out-Null
  $xnuRestore = Join-Path $destination "caribeos-xnu-rv32"
  $runtimeRestore = Join-Path $destination "caribeos-runtime-rv32"
  & git clone $xnuBundle $xnuRestore
  Assert-Exit "XNU restore clone"
  & git clone $runtimeBundle $runtimeRestore
  Assert-Exit "runtime restore clone"

  foreach ($repository in @($xnuRestore, $runtimeRestore)) {
    & git -C $repository fsck --full
    Assert-Exit "git fsck $repository"
    & git -C $repository rev-parse "tranche-201-stage2-complete^{tag}" | Out-Null
    Assert-Exit "annotated tag check $repository"
  }

  Write-Host "Restore completed in new directory: $destination"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
