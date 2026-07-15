param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
  [string]$CapacityPrecheck = (Join-Path $PSScriptRoot "GITHUB_CAPACITY_PRECHECK.md")
)

$ErrorActionPreference = "Stop"
$tag = "tranche-201-stage2-complete"
$repository = "$Owner/caribeos-runtime-rv32"
$safeDecisions = @("SAFE_TO_PUSH_FREE", "SAFE_TO_PUSH_WITHOUT_LFS", "SAFE_AFTER_EXCLUDING_GENERATED_FILES")

function Assert-Exit([string]$Operation) {
  if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE" }
}

try {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI is unavailable." }
  & gh auth status
  Assert-Exit "gh auth status"
  $private = (& gh repo view $repository --json isPrivate --jq .isPrivate).Trim()
  Assert-Exit "verify repository privacy"
  if ($private -ne "true") { throw "Release repository is not private: $repository" }

  $precheck = Get-Content -LiteralPath $CapacityPrecheck -Raw
  $decision = $safeDecisions | Where-Object { $precheck -match "(?m)^DECISION=$_$" }
  if ($decision.Count -ne 1) { throw "Capacity precheck does not permit upload." }

  $release = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
  $assets = @(
    "caribeos-tranche-201-qemu-developer-preview.zip",
    "SHA256SUMS.txt",
    "TRANCHE_201_MANIFEST.json",
    "kernel.elf",
    "initrd.img",
    "TRANCHE_201_RELEASE_NOTES.md"
  ) | ForEach-Object { Join-Path $release $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
  if (-not $assets) { throw "No approved release assets were found." }

  & gh release view $tag --repo $repository | Out-Null
  if ($LASTEXITCODE -eq 0) { throw "Release already exists; refusing an ambiguous update." }

  $notes = Join-Path $release "github-release-notes.txt"
  @"
Developer Preview. Experimental, QEMU only, and not production ready.
CaribeOS is not affiliated with Apple.

Tranche 201 preserves Gates 1-15 PASS, interactive Bash, UP/SMP validation,
real process lifecycle, userspace on CPU1, and exact long-run resource return.
See the bundled release notes and manifest for known limitations and hashes.
"@ | Out-File -LiteralPath $notes -Encoding utf8

  & gh release create $tag --repo $repository --title "CaribeOS Tranche 201 - Stage 2 Complete" --notes-file $notes @assets
  Assert-Exit "create private release"
  & gh release view $tag --repo $repository | Out-Null
  Assert-Exit "verify private release"
  Write-Host "Private release created and verified: $repository $tag"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
