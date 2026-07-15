param(
  [Parameter(Mandatory = $true)][string]$XnuPath,
  [Parameter(Mandatory = $true)][string]$RuntimePath,
  [string]$CapacityPrecheck = "",
  [string]$Owner,
  [string]$VerificationRoot
)

$ErrorActionPreference = "Stop"
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

function Invoke-Git {
  param([string]$Repository, [string[]]$Arguments, [string]$Operation)
  $result = Invoke-Captured "git" (@("-C", $Repository) + $Arguments)
  Require-Success $result $Operation
  $result
}

try {
  if (-not $CapacityPrecheck) {
    $CapacityPrecheck = Join-Path $PSScriptRoot "GITHUB_CAPACITY_PRECHECK.md"
  }
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is not installed or not on PATH."
  }
  $auth = Invoke-Captured "gh" @("auth", "status")
  Require-Success $auth "gh auth status"
  if ($auth.Text) { Write-Host $auth.Text }

  if (-not (Test-Path -LiteralPath $CapacityPrecheck -PathType Leaf)) {
    throw "Capacity precheck is missing: $CapacityPrecheck"
  }
  $capacityPath = (Resolve-Path -LiteralPath $CapacityPrecheck).Path
  $precheck = Get-Content -LiteralPath $capacityPath -Raw
  $decisionMatches = [regex]::Matches($precheck, "(?m)^DECISION=([A-Z_]+)\r?$")
  if ($decisionMatches.Count -ne 1) {
    throw "Capacity precheck must contain exactly one DECISION line."
  }
  $decision = $decisionMatches[0].Groups[1].Value
  if ($safeDecisions -notcontains $decision) {
    throw "Capacity decision does not permit a push: $decision"
  }

  if (-not $Owner) {
    $ownerResult = Invoke-Captured "gh" @("api", "user", "--jq", ".login")
    Require-Success $ownerResult "detect GitHub owner"
    $Owner = $ownerResult.Text.Trim()
  }
  if ($Owner -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$') {
    throw "Authenticated GitHub owner is empty or invalid."
  }

  $repositories = @(
    [pscustomobject]@{
      Path = (Resolve-Path -LiteralPath $XnuPath).Path
      Name = "caribeos-xnu-rv32"
      Critical = @("README.md", "osfmk/riscv32/linux_syscall.c")
    }
    [pscustomobject]@{
      Path = (Resolve-Path -LiteralPath $RuntimePath).Path
      Name = "caribeos-runtime-rv32"
      Critical = @("testproject.ps1", "tools/backup-caribeos.ps1")
    }
  )

  foreach ($item in $repositories) {
    $status = Invoke-Git $item.Path @("status", "--porcelain") "repository status"
    if ($status.Lines.Count -ne 0) {
      throw "Repository must be clean before push: $($item.Path)"
    }
    $tree = Invoke-Git $item.Path @("ls-tree", "-r", "-l", "HEAD") "tracked file-size scan"
    foreach ($line in $tree.Lines) {
      if ($line -match '^[0-9]+\s+blob\s+[0-9a-f]+\s+([0-9]+)\t(.+)$' -and
          [int64]$matches[1] -gt 100MB) {
        throw "Tracked file over 100 MiB blocks push: $($matches[2])"
      }
    }

    $repositoryName = "$Owner/$($item.Name)"
    $probe = Invoke-Captured "gh" @("api", "repos/$repositoryName", "--silent")
    if ($probe.ExitCode -eq 0) {
      Write-Host "Using existing private repository: $repositoryName"
    } elseif ($probe.Text -match 'HTTP 404') {
      $create = Invoke-Captured "gh" @("repo", "create", $repositoryName, "--private")
      Require-Success $create "create private repository $repositoryName"
    } else {
      throw "Repository existence is ambiguous for ${repositoryName}: $($probe.Text)"
    }

    $view = Invoke-Captured "gh" @("repo", "view", $repositoryName, "--json", "isPrivate", "--jq", ".isPrivate")
    Require-Success $view "verify repository privacy $repositoryName"
    if ($view.Text.Trim() -ne "true") {
      throw "Repository is not private: $repositoryName"
    }

    $expected = "https://github.com/$repositoryName.git"
    $allowedRemoteUrls = @($expected, "git@github.com:$repositoryName.git")
    $remoteList = Invoke-Git $item.Path @("remote") "list Git remotes"
    if ($remoteList.Lines -contains "github-backup") {
      $remoteUrl = Invoke-Git $item.Path @("remote", "get-url", "github-backup") "read github-backup remote"
      $actual = $remoteUrl.Text.Trim()
      if ($allowedRemoteUrls -notcontains $actual) {
        throw "Existing github-backup remote is ambiguous: $actual"
      }
    } else {
      Invoke-Git $item.Path @("remote", "add", "github-backup", $expected) "add github-backup remote" | Out-Null
    }

    Invoke-Git $item.Path @("push", "github-backup", "--all") "push branches for $($item.Name)" | Out-Null
    Invoke-Git $item.Path @("push", "github-backup", "--tags") "push tags for $($item.Name)" | Out-Null

    $localRefs = Invoke-Git $item.Path @(
      "for-each-ref", "--format=%(objectname)`t%(refname)", "refs/heads", "refs/tags"
    ) "enumerate local refs"
    $remoteRefs = Invoke-Git $item.Path @("ls-remote", "github-backup") "enumerate remote refs"
    $remoteMap = @{}
    foreach ($line in $remoteRefs.Lines) {
      if ($line -match '^([0-9a-f]{40})\s+(.+)$') { $remoteMap[$matches[2]] = $matches[1] }
    }
    foreach ($line in $localRefs.Lines) {
      if ($line -notmatch '^([0-9a-f]{40})\s+(.+)$') { throw "Malformed local ref: $line" }
      if (-not $remoteMap.ContainsKey($matches[2]) -or $remoteMap[$matches[2]] -ne $matches[1]) {
        throw "Remote ref mismatch for $repositoryName $($matches[2])"
      }
    }

    $defaultBranch = Invoke-Captured "gh" @("repo", "edit", $repositoryName, "--default-branch", "main")
    Require-Success $defaultBranch "set default branch for $repositoryName"
    $privateAfterPush = Invoke-Captured "gh" @("repo", "view", $repositoryName, "--json", "isPrivate", "--jq", ".isPrivate")
    Require-Success $privateAfterPush "recheck repository privacy $repositoryName"
    if ($privateAfterPush.Text.Trim() -ne "true") { throw "Privacy changed unexpectedly: $repositoryName" }
  }

  if (-not $VerificationRoot) {
    $VerificationRoot = Join-Path (Split-Path -Parent $capacityPath) `
      ("github-restore-test-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
  }
  $verification = [IO.Path]::GetFullPath($VerificationRoot)
  if (Test-Path -LiteralPath $verification) {
    throw "GitHub verification destination already exists: $verification"
  }
  New-Item -ItemType Directory -Path $verification | Out-Null

  foreach ($item in $repositories) {
    $repositoryName = "$Owner/$($item.Name)"
    $clone = Join-Path $verification $item.Name
    $url = "https://github.com/$repositoryName.git"
    Invoke-Git $verification @("clone", $url, $clone) "clone private GitHub repository" | Out-Null
    Invoke-Git $clone @("fsck", "--full") "fsck private GitHub clone" | Out-Null
    $sourceHead = (Invoke-Git $item.Path @("rev-parse", "HEAD") "source HEAD").Text.Trim()
    $cloneHead = (Invoke-Git $clone @("rev-parse", "HEAD") "clone HEAD").Text.Trim()
    if ($sourceHead -ne $cloneHead) { throw "GitHub clone HEAD mismatch: $repositoryName" }
    $tagType = (Invoke-Git $clone @("cat-file", "-t", "refs/tags/tranche-201-stage2-complete") "annotated tag check").Text.Trim()
    if ($tagType -ne "tag") { throw "GitHub clone tag is not annotated: $repositoryName" }
    Invoke-Git $clone @("rev-parse", "refs/remotes/origin/archive/tranche-201-stage2-complete") "archive branch check" | Out-Null
    $sourceCount = (Invoke-Git $item.Path @("ls-files") "source file count").Lines.Count
    $cloneCount = (Invoke-Git $clone @("ls-files") "clone file count").Lines.Count
    if ($sourceCount -ne $cloneCount) { throw "GitHub clone file-count mismatch: $repositoryName" }
    foreach ($critical in $item.Critical) {
      if (-not (Test-Path -LiteralPath (Join-Path $clone $critical) -PathType Leaf)) {
        throw "Critical file missing from GitHub clone: $repositoryName $critical"
      }
    }
  }

  Write-Host "Private GitHub push, privacy, refs, clone, and fsck verification passed."
  Write-Host "https://github.com/$Owner/caribeos-xnu-rv32"
  Write-Host "https://github.com/$Owner/caribeos-runtime-rv32"
  exit 0
} catch {
  Write-Error $_
  exit 1
}
