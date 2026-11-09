<#
.SYNOPSIS
    pmirror - Android 手机极速投屏与控制工具 (基于 scrcpy)
.DESCRIPTION
    一键投屏 Android 手机到电脑桌面，支持息屏投屏、低延迟模式、无线 WiFi 投屏等。
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Action = 'start',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

# 1. 查找 scrcpy.exe 和 adb.exe
function Find-Tool {
    param([string]$ToolName, [string[]]$Fallbacks)

    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    foreach ($fb in $Fallbacks) {
        if (Test-Path $fb) { return $fb }
    }
    return $null
}

$scrcpyFallbacks = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.0\scrcpy.exe",
    "$env:USERPROFILE\scoop\apps\scrcpy\current\scrcpy.exe"
)
$adbFallbacks = @(
    "E:\aiPro\Android\Sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v4.0\adb.exe",
    "$env:USERPROFILE\scoop\apps\scrcpy\current\adb.exe",
    "$env:USERPROFILE\scoop\apps\adb\current\adb.exe",
    "$env:USERPROFILE\scoop\apps\android-platform-tools\current\platform-tools\adb.exe"
)

$scrcpyExe = Find-Tool "scrcpy.exe" $scrcpyFallbacks
$adbExe = Find-Tool "adb.exe" $adbFallbacks

# help / devices 不需要 scrcpy，只有真正投屏时才强制检查
function Assert-Scrcpy {
    if ($scrcpyExe) { return }

    Write-Host "未找到 scrcpy.exe。" -ForegroundColor Red
    Write-Host "安装方式: scoop install extras/scrcpy （自带 adb）" -ForegroundColor Yellow
    Write-Host "或从 https://github.com/Genymobile/scrcpy/releases 下载后加入 PATH。" -ForegroundColor Yellow
    exit 1
}

# 2. 检查设备状态
function Get-AdbDevices {
    if (-not $adbExe) { return @() }
    $lines = & $adbExe devices
    $devList = @()
    foreach ($line in $lines) {
        if ($line -match '^([^\s]+)\s+(device|unauthorized|offline)$') {
            $devList += [PSCustomObject]@{
                Id     = $matches[1]
                Status = $matches[2]
            }
        }
    }
    return $devList
}

function Show-Help {
    Write-Host ""
    Write-Host "pmirror - 手机屏幕投屏工具" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "用法: pmirror [命令/模式] [自定义scrcpy参数...]"
    Write-Host ""
    Write-Host "常用模式:" -ForegroundColor Yellow
    Write-Host "  pmirror            常规启动投屏 (保持手机常亮)"
    Write-Host "  pmirror off / -s   息屏投屏 (手机黑屏省电，电脑正常显示控制)"
    Write-Host "  pmirror fast       低延迟模式 (限制 1080p, 8M 码率)"
    Write-Host "  pmirror max        超清模式 (原画无压缩)"
    Write-Host "  pmirror wifi       一键开启无线 WiFi 投屏 (自动获取手机IP连接)"
    Write-Host "  pmirror devices    查看当前已连接的 Android 设备"
    Write-Host "  pmirror help       显示本帮助"
    Write-Host ""
    Write-Host "快捷键提示 (投屏窗口激活时):" -ForegroundColor Yellow
    Write-Host "  Alt + F            全屏 / 退出全屏"
    Write-Host "  Alt + O            息屏 (关掉手机屏幕省电)"
    Write-Host "  Alt + Shift + O    点亮手机屏幕"
    Write-Host "  鼠标右键           返回键 (Back)"
    Write-Host "  鼠标滚轮中键       回到桌面 (Home)"
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
}

switch ($Action.ToLower()) {
    { $_ -in @('help', '-h', '--help', '/?') } {
        Show-Help
        exit 0
    }

    { $_ -in @('devices', 'list') } {
        Write-Host "正在检测 ADB 设备..." -ForegroundColor Cyan
        if (-not $adbExe) {
            Write-Host "未找到 adb.exe，请先安装 scrcpy 或 Android platform-tools。" -ForegroundColor Red
            Write-Host "  scoop install extras/scrcpy   # 自带 adb" -ForegroundColor Yellow
            exit 1
        }
        $devs = Get-AdbDevices
        if ($devs.Count -eq 0) {
            Write-Host "未检测到任何设备，请确保已连接 USB 且手机开启了「USB 调试」。" -ForegroundColor Yellow
        } else {
            $devs | Format-Table -AutoSize
        }
        exit 0
    }

    { $_ -in @('wifi', 'wireless', 'tcpip') } {
        Assert-Scrcpy
        Write-Host "正在配置无线投屏..." -ForegroundColor Cyan
        $devs = Get-AdbDevices | Where-Object { $_.Status -eq 'device' }
        if ($devs.Count -eq 0) {
            Write-Host "未检测到已授权的设备，请先插上 USB 并允许 USB 调试授权。" -ForegroundColor Red
            exit 1
        }
        $targetDev = $devs[0].Id
        Write-Host "检测到设备: $targetDev" -ForegroundColor Green
        
        # 获取手机 wlan0 IP 地址
        $ipOutput = & $adbExe -s $targetDev shell ip -f inet addr show wlan0
        $match = [regex]::Match($ipOutput, 'inet\s+(\d+\.\d+\.\d+\.\d+)')
        if (-not $match.Success) {
            # 备用方法获取路由网卡 IP
            $ipOutput = & $adbExe -s $targetDev shell ip route
            $match = [regex]::Match($ipOutput, 'src\s+(\d+\.\d+\.\d+\.\d+)')
        }

        if (-not $match.Success) {
            Write-Host "无法获取手机 WiFi IP 地址，请确保手机与电脑已连接在同一 WiFi 局域网下。" -ForegroundColor Red
            exit 1
        }

        $phoneIp = $match.Groups[1].Value
        Write-Host "手机局域网 IP: $phoneIp" -ForegroundColor Cyan
        Write-Host "正在开启 TCP/IP 5555 端口..." -ForegroundColor Cyan
        & $adbExe -s $targetDev tcpip 5555
        Start-Sleep -Seconds 1
        Write-Host "正在连接 $phoneIp:5555 ..." -ForegroundColor Cyan
        & $adbExe connect "$phoneIp:5555"
        
        Write-Host "无线连接成功！现在可以拔掉 USB 数据线了。" -ForegroundColor Green
        Write-Host "正在启动无线投屏..." -ForegroundColor Cyan
        & $scrcpyExe -s "$phoneIp:5555" --stay-awake @ExtraArgs
        exit 0
    }

    default {
        # 启动投屏
        Assert-Scrcpy
        $devs = Get-AdbDevices
        if ($devs.Count -eq 0) {
            Write-Host "未检测到连接的 Android 设备！" -ForegroundColor Red
            Write-Host "提示: 1. 请检查 USB 数据线是否连接好" -ForegroundColor Yellow
            Write-Host "      2. 请确认手机设置中已开启「开发者选项」和「USB 调试」" -ForegroundColor Yellow
            Write-Host "      3. 如果手机弹出「允许 USB 调试吗？」，请勾选「始终允许」并点「确定」" -ForegroundColor Yellow
            exit 1
        }

        $baseArgs = @('--stay-awake')

        switch ($Action.ToLower()) {
            { $_ -in @('off', '-s', '--turn-screen-off') } {
                $baseArgs += '--turn-screen-off'
                Write-Host "已启用【息屏省电】投屏模式..." -ForegroundColor Green
            }
            { $_ -in @('fast', 'low', 'perf') } {
                $baseArgs += @('-m', '1080', '-b', '8M')
                Write-Host "已启用【低延迟流畅】模式 (1080p / 8M)..." -ForegroundColor Green
            }
            { $_ -in @('max', 'high') } {
                $baseArgs += @('--video-bit-rate=16M')
                Write-Host "已启用【超清】模式..." -ForegroundColor Green
            }
            'start' {
                # 默认直接启动
            }
            default {
                # 如果传入的是其他参数直接放进参数列表
                $baseArgs += $Action
            }
        }

        if ($ExtraArgs) {
            $baseArgs += $ExtraArgs
        }

        Write-Host "正在启动投屏 (按 Ctrl+C 或关闭窗口退出)..." -ForegroundColor Cyan
        & $scrcpyExe @baseArgs
    }
}
