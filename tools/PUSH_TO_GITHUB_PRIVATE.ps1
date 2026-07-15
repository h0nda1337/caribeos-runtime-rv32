param(
  [Parameter(Mandatory = $true)][string]$XnuPath,
  [Parameter(Mandatory = $true)][string]$RuntimePath,
  [string]$CapacityPrecheck = (Join-Path $PSScriptRoot "GITHUB_CAPACITY_PRECHECK.md"),
  [string]$Owner
)

$ErrorActionPreference = "Stop"
$safeDecisions = @(
  "SAFE_TO_PUSH_FREE",
  "SAFE_TO_PUSH_WITHOUT_LFS",
  "SAFE_AFTER_EXCLUDING_GENERATED_FILES"
)

function Assert-Exit([string]$Operation) {
  if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE" }
}

try {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is not installed or not on PATH."
  }
  & gh auth status
  Assert-Exit "gh auth status"

  if (-not (Test-Path -LiteralPath $CapacityPrecheck -PathType Leaf)) {
    throw "Capacity precheck is missing: $CapacityPrecheck"
  }
  $precheck = Get-Content -LiteralPath $CapacityPrecheck -Raw
  $decision = $safeDecisions | Where-Object { $precheck -match "(?m)^DECISION=$_$" }
  if ($decision.Count -ne 1) {
    throw "Capacity precheck does not contain exactly one allowed push decision."
  }

  if (-not $Owner) {
    $Owner = (& gh api user --jq .login).Trim()
    Assert-Exit "detect GitHub owner"
  }
  if (-not $Owner) { throw "Authenticated GitHub owner is empty." }

  $repositories = @(
    [pscustomobject]@{ Path = (Resolve-Path $XnuPath).Path; Name = "caribeos-xnu-rv32" },
    [pscustomobject]@{ Path = (Resolve-Path $RuntimePath).Path; Name = "caribeos-runtime-rv32" }
  )

  foreach ($item in $repositories) {
    if (@(& git -C $item.Path status --porcelain).Count -ne 0) {
      throw "Repository must be clean before push: $($item.Path)"
    }
    $large = Get-ChildItem -LiteralPath $item.Path -File -Recurse -Force |
      Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.Length -gt 100MB }
    if ($large) { throw "File over 100 MiB blocks push: $($large[0].FullName)" }

    & gh repo view "$Owner/$($item.Name)" --json nameWithOwner,isPrivate | Out-Null
    if ($LASTEXITCODE -ne 0) {
      & gh repo create "$Owner/$($item.Name)" --private
      Assert-Exit "create private repository $Owner/$($item.Name)"
    }
    $private = (& gh repo view "$Owner/$($item.Name)" --json isPrivate --jq .isPrivate).Trim()
    Assert-Exit "verify repository privacy $Owner/$($item.Name)"
    if ($private -ne "true") { throw "Repository is not private: $Owner/$($item.Name)" }

    $expected = "https://github.com/$Owner/$($item.Name).git"
    $remotes = @(& git -C $item.Path remote)
    if ($remotes -contains "github-backup") {
      $actual = (& git -C $item.Path remote get-url github-backup).Trim()
      if ($actual -notmatch [regex]::Escape("$Owner/$($item.Name)")) {
        throw "Existing github-backup remote is ambiguous: $actual"
      }
    } else {
      & git -C $item.Path remote add github-backup $expected
      Assert-Exit "add github-backup remote"
    }

    & git -C $item.Path push github-backup --all
    Assert-Exit "push branches for $($item.Name)"
    & git -C $item.Path push github-backup --tags
    Assert-Exit "push tags for $($item.Name)"
    & git -C $item.Path ls-remote github-backup | Out-Null
    Assert-Exit "verify remote refs for $($item.Name)"
  }

  Write-Host "Private GitHub push and privacy verification passed."
  exit 0
} catch {
  Write-Error $_
  exit 1
}
