[CmdletBinding()]
param(
    [string]$NpmRegistry = 'https://registry.npmjs.org/',
    [string]$MavenRepository = 'https://repo.maven.apache.org/maven2',
    [string]$MavenArtifact = 'org.junit.jupiter:junit-jupiter:5.12.0',
    [int]$CommandTimeoutSec = 30,
    [int]$WebTimeoutSec = 30,
    [switch]$SkipDownloads
)

$ErrorActionPreference = 'Continue'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Name,
        [ValidateSet('PASS', 'FAIL', 'SKIP')][string]$Status,
        [string]$Detail
    )

    $results.Add([PSCustomObject]@{
            Test   = $Name
            Status = $Status
            Detail = $Detail
        })
}

function Test-CommandAvailable {
    param([string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        Add-Result -Name "$Name available" -Status 'SKIP' -Detail 'Command not found'
        return $false
    }

    Add-Result -Name "$Name available" -Status 'PASS' -Detail $command.Source
    return $true
}

function Invoke-NativeTest {
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$Arguments
    )

    $executable = (Get-Command $Command -ErrorAction SilentlyContinue).Source
    if ($executable -match '\.ps1$') {
        $cmdExecutable = [IO.Path]::ChangeExtension($executable, '.cmd')
        if (Test-Path -LiteralPath $cmdExecutable) {
            $executable = $cmdExecutable
        }
    }

    $argumentsJson = @($Arguments) | ConvertTo-Json -Compress
    $job = Start-Job -ScriptBlock {
        param($Executable, $ArgumentsJson)
        $CommandArguments = @($ArgumentsJson | ConvertFrom-Json)
        $text = & $Executable @CommandArguments 2>&1 | Out-String
        [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = $text
        }
    } -ArgumentList $executable, $argumentsJson

    $completed = Wait-Job -Job $job -Timeout $CommandTimeoutSec
    if ($null -eq $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Add-Result -Name $Name -Status 'FAIL' -Detail "timeout after ${CommandTimeoutSec}s"
        return $false
    }

    $nativeResult = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $output = [string]$nativeResult.Output
    $exitCode = [int]$nativeResult.ExitCode
    $detail = ($output.Trim() -replace '\s+', ' ')
    if ($detail.Length -gt 240) {
        $detail = $detail.Substring(0, 240) + '...'
    }

    if ($exitCode -eq 0) {
        Add-Result -Name $Name -Status 'PASS' -Detail $detail
        return $true
    }

    Add-Result -Name $Name -Status 'FAIL' -Detail "exit=$exitCode $detail"
    return $false
}

function Invoke-WebTest {
    param(
        [string]$Name,
        [string]$Uri
    )

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec $WebTimeoutSec
        Add-Result -Name $Name -Status 'PASS' -Detail "HTTP $([int]$response.StatusCode)"
        return $true
    }
    catch {
        Add-Result -Name $Name -Status 'FAIL' -Detail $_.Exception.Message
        return $false
    }
}

Write-Output 'Development tool connectivity test'
Write-Output '=================================='
Write-Output "Working directory: $((Get-Location).Path)"
Write-Output "NPM registry: $NpmRegistry"
Write-Output "Maven repository: $MavenRepository"
Write-Output ''

Write-Output '[npm / npx]'
$npmAvailable = Test-CommandAvailable -Name 'npm'
if ($npmAvailable) {
    Invoke-NativeTest -Name 'npm ping' -Command 'npm' -Arguments @('ping', "--registry=$NpmRegistry") | Out-Null
    Invoke-NativeTest -Name 'npm view package version' -Command 'npm' -Arguments @('view', '@modelcontextprotocol/server-filesystem', 'version', "--registry=$NpmRegistry") | Out-Null

    if ($SkipDownloads) {
        Add-Result -Name 'npm exec package download' -Status 'SKIP' -Detail 'Skipped by -SkipDownloads'
    }
    else {
        Invoke-NativeTest -Name 'npm exec package download' -Command 'npm' -Arguments @(
            'exec', '--yes', '--package=@modelcontextprotocol/server-filesystem', '--call', 'node -p 1'
        ) | Out-Null
    }
}

Write-Output ''
Write-Output '[Maven]'
$mvnAvailable = Test-CommandAvailable -Name 'mvn'
if ($mvnAvailable) {
    Invoke-NativeTest -Name 'mvn -version' -Command 'mvn' -Arguments @('-version') | Out-Null
    $mavenPom = "$MavenRepository/org/junit/jupiter/junit-jupiter/5.12.0/junit-jupiter-5.12.0.pom"
    Invoke-WebTest -Name 'Maven Central HTTP' -Uri $mavenPom | Out-Null

    if ($SkipDownloads) {
        Add-Result -Name 'Maven dependency download' -Status 'SKIP' -Detail 'Skipped by -SkipDownloads'
    }
    else {
        Invoke-NativeTest -Name 'Maven dependency download' -Command 'mvn' -Arguments @(
            '-U', 'dependency:get', "-Dartifact=$MavenArtifact",
            "-DremoteRepositories=central::default::$MavenRepository"
        ) | Out-Null
    }
}

Write-Output ''
Write-Output '[Gradle]'
$gradleWrapper = Join-Path (Get-Location) 'gradlew.bat'
$hasWrapper = Test-Path -LiteralPath $gradleWrapper
$gradleAvailable = Test-CommandAvailable -Name 'gradle'
if ($hasWrapper) {
    Invoke-NativeTest -Name 'Gradle Wrapper --version' -Command $gradleWrapper -Arguments @('--version') | Out-Null
}
elseif (-not $gradleAvailable) {
    Add-Result -Name 'Gradle project wrapper' -Status 'SKIP' -Detail 'gradlew.bat not found in current directory'
}

Invoke-WebTest -Name 'Gradle services HTTP' -Uri 'https://services.gradle.org/versions/current' | Out-Null
Invoke-WebTest -Name 'Gradle Plugin Portal HTTP' -Uri 'https://plugins.gradle.org/m2/' | Out-Null

if (-not $SkipDownloads -and $hasWrapper) {
    Invoke-NativeTest -Name 'Gradle dependency refresh' -Command $gradleWrapper -Arguments @('dependencies', '--refresh-dependencies') | Out-Null
}
elseif ($hasWrapper) {
    Add-Result -Name 'Gradle dependency refresh' -Status 'SKIP' -Detail 'Skipped by -SkipDownloads'
}
else {
    Add-Result -Name 'Gradle dependency refresh' -Status 'SKIP' -Detail 'gradlew.bat not found in current directory'
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
$results | Format-Table -AutoSize

$failed = @($results | Where-Object Status -eq 'FAIL')
if ($failed.Count -gt 0) {
    Write-Output "Failed tests: $($failed.Count)"
    exit 1
}

Write-Output 'No failed tests.'
