# Copyright (c) 2026 h0nda1337
# SPDX-License-Identifier: BSD-2-Clause
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root "scripts/qemu-rv32-graphics.ps1"), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Graphics runner PowerShell parse error" }
$definition = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Invoke-LoggedBuild"
}, $true)
if (-not $definition) { throw "Missing logged-build helper" }
. ([scriptblock]::Create($definition.Extent.Text))
$directory = Join-Path $root ("build/logged-build-guard-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $directory | Out-Null
$log = Join-Path $directory "native.txt"
try {
    $code = Invoke-LoggedBuild -Program "powershell" -Parameters @("-NoProfile", "-Command", "[Console]::Error.WriteLine('fixture warning'); exit 0") -Log $log
    if ($code -ne 0 -or -not (Get-Content -LiteralPath $log -Raw).Contains("fixture warning")) { throw "Native diagnostic was lost or treated as a failed exit" }
    $code = Invoke-LoggedBuild -Program "powershell" -Parameters @("-NoProfile", "-Command", "[Console]::Error.WriteLine('fixture error'); exit 7") -Log $log
    if ($code -ne 7 -or -not (Get-Content -LiteralPath $log -Raw).Contains("fixture error")) { throw "Real native failure exit code was lost" }
    $LASTEXITCODE = 0
    try {
        $code = Invoke-LoggedBuild -Program "caribe-missing-build-executable-fixture" -Parameters @() -Log $log
        if ($code -eq 0) { throw "A missing executable reused a stale successful exit code" }
    } catch [System.Management.Automation.CommandNotFoundException] {
        # A terminating launch failure is also a valid rejection, never build success.
    }
    if ($ErrorActionPreference -ne "Stop") { throw "Caller error policy was not restored" }
    Write-Host "PASS logged native diagnostics and explicit exit codes; no QEMU launched"
} finally {
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log }
    Remove-Item -LiteralPath $directory
}
