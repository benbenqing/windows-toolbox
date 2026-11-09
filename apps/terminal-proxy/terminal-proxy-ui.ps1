[CmdletBinding()]
param()

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$proxyScript = Join-Path $scriptRoot 'terminal-proxy.ps1'
$testScript = Join-Path $scriptRoot 'dev-connectivity-test.ps1'

function Show-Menu {
    Clear-Host
    Write-Output 'Terminal Proxy'
    Write-Output '=============='
    Write-Output ''
    Write-Output '1. Enable proxy       Set HTTP/HTTPS/ALL proxy variables'
    Write-Output '2. Disable proxy      Remove User proxy variables'
    Write-Output '3. Show status        Display Process and User values'
    Write-Output '4. Connectivity test  Check npm, Maven and Gradle access'
    Write-Output '5. Help                Show command examples'
    Write-Output '0. Exit'
    Write-Output ''
}

function Pause-Menu {
    Write-Output ''
    [void](Read-Host 'Press Enter to continue')
}

function Show-Help {
    Write-Output 'Commands'
    Write-Output '--------'
    Write-Output 'tproxy on       Enable the default local proxy'
    Write-Output 'tproxy off      Remove proxy variables from User scope'
    Write-Output 'tproxy status   Show Process and User proxy values'
    Write-Output 'tproxy-test     Test npm, Maven and Gradle connectivity'
    Write-Output ''
    Write-Output 'For the current PowerShell process, dot-source the script:'
    Write-Output '. E:\configSwitch\terminalProxy\terminal-proxy.ps1 off -Scope Process'
}

while ($true) {
    Show-Menu
    $choice = Read-Host 'Select an action'
    switch ($choice) {
        '1' {
            & $proxyScript on
            Pause-Menu
        }
        '2' {
            & $proxyScript off -Scope User
            Pause-Menu
        }
        '3' {
            & $proxyScript status
            Pause-Menu
        }
        '4' {
            & $testScript -SkipDownloads
            Pause-Menu
        }
        '5' {
            Show-Help
            Pause-Menu
        }
        '0' {
            return
        }
        default {
            Write-Output 'Unknown selection.'
            Pause-Menu
        }
    }
}
