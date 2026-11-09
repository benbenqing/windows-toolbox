#Requires -Version 5.1
<#
.SYNOPSIS
    Builds an app package and keeps the Scoop manifest in sync.

.DESCRIPTION
    Scoop installs from a URL plus a SHA256 hash, so every release needs a
    freshly built archive committed to this repository. This script zips
    apps/<App> into packages/<App>-<Version>.zip, points
    bucket/<App>.json at the raw.githubusercontent.com URL, and rewrites the
    hash. Run it from anywhere; paths are resolved from the repository root.

.EXAMPLE
    .\scripts\publish.ps1
    .\scripts\publish.ps1 -App terminal-proxy -Version 1.0.1 -Commit
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$App = 'terminal-proxy',

    [Parameter(Position = 1)]
    [string]$Version,

    [string]$Repo = 'benbenqing/scoop-bucket',

    [string]$Branch = 'main',

    [switch]$Commit,

    [string]$Message
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot "apps\$App"
$manifestPath = Join-Path $repoRoot "bucket\$App.json"
$packageDir = Join-Path $repoRoot 'packages'

if (-not (Test-Path -LiteralPath $appDir)) {
    throw "App directory not found: $appDir"
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

if (-not $Version) {
    $Version = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).version
}

if ($Version -notmatch '^\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$') {
    throw "Invalid version '$Version'."
}

# Only runtime files go into the package; docs, tests and repo plumbing stay out.
$payload = Get-ChildItem -LiteralPath $appDir -File | Where-Object {
    $_.Extension -in '.ps1', '.cmd', '.bat', '.exe', '.txt' -and $_.Name -ne 'smoke-test.ps1'
}

if (-not $payload) {
    throw "No packageable files found in $appDir"
}

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
$zipPath = Join-Path $packageDir "$App-$Version.zip"

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $payload.FullName -DestinationPath $zipPath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.version = $Version
$manifest.url = "https://raw.githubusercontent.com/$Repo/$Branch/packages/$App-$Version.zip"
$manifest.hash = "sha256:$hash"

$json = $manifest | ConvertTo-Json -Depth 10
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $json + [Environment]::NewLine, $utf8NoBom)

Write-Output "Package: $zipPath"
Write-Output "SHA256 : $hash"
Write-Output "Manifest updated: $manifestPath"

if ($Commit) {
    if (-not $Message) {
        $Message = "release $App $Version"
    }

    git -C $repoRoot add -- "bucket/$App.json" "packages/$App-$Version.zip"
    if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }

    git -C $repoRoot commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }

    Write-Output 'Committed. Push with: git push'
}
