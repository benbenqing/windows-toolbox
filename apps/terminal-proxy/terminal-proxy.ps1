[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('on', 'off', 'status')]
    [string]$Command = 'status',

    [Parameter(Position = 1)]
    [string]$ProxyUrl = 'http://127.0.0.1:7897',

    [ValidateSet('Process', 'User', 'Both')]
    [string]$Scope = 'Both'
)

$ProxyVariables = @(
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'http_proxy',
    'https_proxy',
    'all_proxy'
)

function Normalize-ProxyUrl {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw 'ProxyUrl cannot be empty.'
    }

    if ($normalized -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $normalized = "http://$normalized"
    }

    return $normalized
}

function Get-Targets {
    param([Parameter(Mandatory = $true)][string]$SelectedScope)

    if ($SelectedScope -eq 'Both') {
        return @('Process', 'User')
    }

    return @($SelectedScope)
}

function Set-ProxyEnvironment {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$SelectedScope
    )

    foreach ($target in Get-Targets -SelectedScope $SelectedScope) {
        foreach ($name in $ProxyVariables) {
            [Environment]::SetEnvironmentVariable(
                $name,
                $Value,
                [EnvironmentVariableTarget]::$target
            )
        }
    }
}

function Remove-ProxyEnvironment {
    param([Parameter(Mandatory = $true)][string]$SelectedScope)

    foreach ($target in Get-Targets -SelectedScope $SelectedScope) {
        if ($target -eq 'User') {
            # Remove the registry values explicitly so Windows does not retain
            # an empty entry in the Environment UI.
            foreach ($name in $ProxyVariables) {
                Remove-ItemProperty `
                    -LiteralPath 'HKCU:\Environment' `
                    -Name $name `
                    -ErrorAction SilentlyContinue
            }
            continue
        }

        foreach ($name in $ProxyVariables) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        }
    }
}

function Show-ProxyStatus {
    $rows = foreach ($name in $ProxyVariables) {
        [PSCustomObject]@{
            Variable = $name
            Process  = [Environment]::GetEnvironmentVariable(
                $name,
                [EnvironmentVariableTarget]::Process
            )
            User     = [Environment]::GetEnvironmentVariable(
                $name,
                [EnvironmentVariableTarget]::User
            )
        }
    }

    Write-Output 'Terminal proxy status'
    Write-Output '----------------------'
    $rows | Format-Table -AutoSize
}

switch ($Command) {
    'on' {
        $normalizedUrl = Normalize-ProxyUrl -Value $ProxyUrl
        Set-ProxyEnvironment -Value $normalizedUrl -SelectedScope $Scope
        Write-Output "Proxy enabled: $normalizedUrl (scope: $Scope)"
        break
    }
    'off' {
        Remove-ProxyEnvironment -SelectedScope $Scope
        Write-Output "Proxy disabled (scope: $Scope)"
        break
    }
    'status' {
        Show-ProxyStatus
        break
    }
}
