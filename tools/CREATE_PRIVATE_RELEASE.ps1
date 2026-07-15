# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause

param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
  [string]$CapacityPrecheck = ""
)

$ErrorActionPreference = "Stop"
$tag = "tranche-201-stage2-complete"
$repository = "$Owner/caribeos-runtime-rv32"
$safeDecisions = @(
  "SAFE_TO_PUSH_FREE"
  "SAFE_TO_PUSH_WITHOUT_LFS"
  "SAFE_AFTER_EXCLUDING_GENERATED_FILES"
)

function Invoke-Captured {
  param([string]$FilePath, [string[]]$Arguments)
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $savedPreference
  [pscustomobject]@{
    ExitCode = $exitCode
    Lines = $output
    Text = ($output -join [Environment]::NewLine)
  }
}

function Require-Success {
  param($Result, [string]$Operation)
  if ($Result.ExitCode -ne 0) {
    throw "$Operation failed with exit code $($Result.ExitCode): $($Result.Text)"
  }
}

try {
  if (-not $CapacityPrecheck) {
    $CapacityPrecheck = Join-Path $PSScriptRoot "GITHUB_CAPACITY_PRECHECK.md"
  }
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is unavailable."
  }
  if ($Owner -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$') {
    throw "GitHub owner is empty or invalid."
  }
  if (-not (Test-Path -LiteralPath $CapacityPrecheck -PathType Leaf)) {
    throw "Capacity precheck is missing: $CapacityPrecheck"
  }
  $precheck = Get-Content -LiteralPath $CapacityPrecheck -Raw
  $decisionMatches = [regex]::Matches($precheck, "(?m)^DECISION=([A-Z_]+)\r?$")
  if ($decisionMatches.Count -ne 1) {
    throw "Capacity precheck must contain exactly one DECISION line."
  }
  $decision = $decisionMatches[0].Groups[1].Value
  if ($safeDecisions -notcontains $decision) {
    throw "Capacity decision does not permit a release upload: $decision"
  }

  $auth = Invoke-Captured "gh" @("auth", "status")
  Require-Success $auth "gh auth status"
  if ($auth.Text) { Write-Host $auth.Text }

  $repoProbe = Invoke-Captured "gh" @("api", "repos/$repository", "--silent")
  Require-Success $repoProbe "locate release repository"
  $private = Invoke-Captured "gh" @("repo", "view", $repository, "--json", "isPrivate", "--jq", ".isPrivate")
  Require-Success $private "verify repository privacy"
  if ($private.Text.Trim() -ne "true") {
    throw "Release repository is not private: $repository"
  }

  $release = (Resolve-Path -LiteralPath $ReleaseDirectory).Path
  $backup = Split-Path -Parent $release
  $manifestPath = Join-Path $release "TRANCHE_201_MANIFEST.json"
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Release manifest is missing: $manifestPath"
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if (-not $manifest.runtime_tag_object) {
    throw "Release manifest does not identify the annotated runtime tag object."
  }

  $tagProbe = Invoke-Captured "gh" @("api", "repos/$repository/git/ref/tags/$tag")
  Require-Success $tagProbe "verify remote release tag"
  $tagRef = $tagProbe.Text | ConvertFrom-Json
  if ($tagRef.object.type -ne "tag" -or $tagRef.object.sha -ne $manifest.runtime_tag_object) {
    throw "Remote tag is missing, lightweight, or does not match the preserved annotated tag."
  }

  $existing = Invoke-Captured "gh" @("api", "repos/$repository/releases/tags/$tag", "--silent")
  if ($existing.ExitCode -eq 0) {
    throw "Release already exists; refusing an ambiguous update."
  }
  if ($existing.Text -notmatch 'HTTP 404') {
    throw "Release existence is ambiguous: $($existing.Text)"
  }

  $assets = @(
    (Join-Path $backup "caribeos-tranche-201-qemu-developer-preview.zip")
    (Join-Path $backup "ZIP_SHA256SUMS.txt")
    (Join-Path $release "SHA256SUMS.txt")
    $manifestPath
    (Join-Path $release "kernel.elf")
    (Join-Path $release "initrd.img")
    (Join-Path $release "docs\RELEASE_NOTES.md")
  )
  foreach ($asset in $assets) {
    if (-not (Test-Path -LiteralPath $asset -PathType Leaf)) {
      throw "Required release asset is missing: $asset"
    }
    if ((Get-Item -LiteralPath $asset).Length -ge 2GB) {
      throw "Release asset is too large for the guarded flow: $asset"
    }
  }

  $arguments = @(
    "release", "create", $tag,
    "--repo", $repository,
    "--title", "CaribeOS Tranche 201 - Stage 2 Complete",
    "--notes-file", (Join-Path $release "docs\RELEASE_NOTES.md"),
    "--verify-tag",
    "--prerelease"
  ) + $assets
  $create = Invoke-Captured "gh" $arguments
  Require-Success $create "create private release"

  $view = Invoke-Captured "gh" @(
    "release", "view", $tag, "--repo", $repository,
    "--json", "tagName,isDraft,isPrerelease,url,assets"
  )
  Require-Success $view "verify private release"
  $releaseInfo = $view.Text | ConvertFrom-Json
  if ($releaseInfo.tagName -ne $tag -or $releaseInfo.isDraft -or -not $releaseInfo.isPrerelease) {
    throw "Created release metadata does not match the guarded request."
  }
  $assetNames = @($releaseInfo.assets | ForEach-Object { $_.name })
  foreach ($asset in $assets) {
    if ($assetNames -notcontains (Split-Path -Leaf $asset)) {
      throw "Created release is missing asset: $(Split-Path -Leaf $asset)"
    }
  }
  $privateAfter = Invoke-Captured "gh" @("repo", "view", $repository, "--json", "isPrivate", "--jq", ".isPrivate")
  Require-Success $privateAfter "recheck release repository privacy"
  if ($privateAfter.Text.Trim() -ne "true") { throw "Release repository privacy changed unexpectedly." }

  Write-Host "Private prerelease created and verified: $($releaseInfo.url)"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
