[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\terminal-proxy.ps1'
$scriptPath = [IO.Path]::GetFullPath($scriptPath)
$names = @(
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'http_proxy',
    'https_proxy',
    'all_proxy'
)
$proxyUrl = 'http://127.0.0.1:7897'

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

function Assert-ProcessVariableMissing {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ([Environment]::GetEnvironmentVariables('Process').Contains($Name)) {
        $actual = [Environment]::GetEnvironmentVariable($Name, 'Process')
        throw "$Message. Got '$actual'."
    }
}

try {
    & $scriptPath off -Scope Process | Out-Null
    & $scriptPath on -Scope Process | Out-Null

    foreach ($name in $names) {
        Assert-Equal `
            -Actual ([Environment]::GetEnvironmentVariable($name, 'Process')) `
            -Expected $proxyUrl `
            -Message "Process variable $name was not enabled"
    }

    & $scriptPath status | Out-Null
    & $scriptPath off -Scope Process | Out-Null

    foreach ($name in $names) {
        Assert-ProcessVariableMissing `
            -Name $name `
            -Message "Process variable $name was not removed"
    }

    Write-Output 'Smoke test passed.'
}
finally {
    & $scriptPath off -Scope Process | Out-Null
}
