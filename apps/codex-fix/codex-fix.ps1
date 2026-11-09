<#
.SYNOPSIS
    codex-fix - OpenAI Codex Windows 沙箱与权限快速修复工具
.DESCRIPTION
    一键修复 Codex 在 Windows 环境下由于多实例切换、ACL 继承损坏或文件锁冲突导致的
    “Windows 设置未完成 / 设置已停止 / helper_sandbox_lock_failed” 错误。
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('fix', 'clean', 'kill', 'status', 'help', '-h', '--help')]
    [string]$Action = 'fix'
)

$CodexHome = Join-Path $env:USERPROFILE ".codex"
$SandboxDir = Join-Path $CodexHome ".sandbox"
$SandboxBinDir = Join-Path $CodexHome ".sandbox-bin"
$CurrentUser = $env:USERNAME

function Show-Help {
    Write-Host ""
    Write-Host "codex-fix - Codex Windows 沙箱与权限修复工具" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "用法: codex-fix [命令]"
    Write-Host ""
    Write-Host "命令列表:" -ForegroundColor Yellow
    Write-Host "  codex-fix          [默认] 修复沙箱目录权限继承与完全控制权，清理错误状态"
    Write-Host "  codex-fix kill     结束所有 Codex 残留/僵死后台进程，彻底释放文件锁"
    Write-Host "  codex-fix clean    深度重置：修复权限 + 清除旧的沙箱 setup 标记与日志"
    Write-Host "  codex-fix status   查看当前沙箱目录权限、服务状态及最近错误"
    Write-Host "  codex-fix help     显示本帮助"
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
}

function Check-Service {
    $svc = Get-Service -Name "CodexSandboxService*" -ErrorAction SilentlyContinue
    if ($svc) {
        $statusColor = if ($svc.Status -eq 'Running') { 'Green' } else { 'Yellow' }
        Write-Host "  [服务] CodexSandboxService 状态: " -NoNewline
        Write-Host "$($svc.Status)" -ForegroundColor $statusColor
    } else {
        Write-Host "  [服务] 未安装或未检测到 CodexSandboxService 服务" -ForegroundColor DarkGray
    }
}

function Kill-CodexProcesses {
    Write-Host "正在扫描残留的 Codex 后台进程..." -ForegroundColor Cyan
    $procs = Get-Process -Name "*codex*" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match "codex" -and $_.ProcessName -notmatch "codex-fix"
    }

    if ($procs.Count -gt 0) {
        foreach ($p in $procs) {
            Write-Host "  正在终止: $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Yellow
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
        Write-Host "已清理 $($procs.Count) 个后台进程。" -ForegroundColor Green
    } else {
        Write-Host "未发现运行中的 Codex 残留进程。" -ForegroundColor Green
    }
}

function Fix-Permissions {
    param([bool]$CleanMarkers = $false)

    Write-Host "正在检查与修复 Codex 沙箱目录..." -ForegroundColor Cyan

    if (-not (Test-Path $CodexHome)) {
        Write-Host "未检测到 $CodexHome 目录，无需修复。" -ForegroundColor Yellow
        return
    }

    # 1. 确保目录存在
    if (-not (Test-Path $SandboxDir)) {
        New-Item -ItemType Directory -Path $SandboxDir -Force | Out-Null
    }
    if (-not (Test-Path $SandboxBinDir)) {
        New-Item -ItemType Directory -Path $SandboxBinDir -Force | Out-Null
    }

    # 2. 修复 ACL 继承
    Write-Host "  [1/4] 恢复目录安全继承 (Inheritance)..." -ForegroundColor Cyan
    & icacls "$SandboxBinDir" /inheritance:e | Out-Null
    & icacls "$SandboxDir" /inheritance:e | Out-Null

    # 3. 授予当前用户、SYSTEM 及 Administrators 完全控制权限
    Write-Host "  [2/4] 授予 SYSTEM / Administrators / $CurrentUser 完全控制权限 (Full Control)..." -ForegroundColor Cyan
    & icacls "$SandboxBinDir" /grant "${CurrentUser}:(OI)(CI)(F)" /grant "SYSTEM:(OI)(CI)(F)" /grant "Administrators:(OI)(CI)(F)" | Out-Null
    & icacls "$SandboxDir" /grant "${CurrentUser}:(OI)(CI)(F)" /grant "SYSTEM:(OI)(CI)(F)" /grant "Administrators:(OI)(CI)(F)" | Out-Null

    # 4. 清理阻塞错误标记
    Write-Host "  [3/4] 清理阻塞状态标记 (setup_error.json)..." -ForegroundColor Cyan
    $errJson = Join-Path $SandboxDir "setup_error.json"
    if (Test-Path $errJson) {
        Remove-Item -Path $errJson -Force -ErrorAction SilentlyContinue
        Write-Host "        已清除旧的 setup_error.json" -ForegroundColor Green
    }

    if ($CleanMarkers) {
        Write-Host "  [4/4] 深度清理：重置 setup_marker.json 与旧日志..." -ForegroundColor Cyan
        $marker = Join-Path $SandboxDir "setup_marker.json"
        if (Test-Path $marker) {
            Remove-Item -Path $marker -Force -ErrorAction SilentlyContinue
            Write-Host "        已清除 setup_marker.json" -ForegroundColor Green
        }
    } else {
        Write-Host "  [4/4] 状态验证与就绪检查..." -ForegroundColor Cyan
    }

    Check-Service

    Write-Host ""
    Write-Host "沙箱权限修复完成！" -ForegroundColor Green
    Write-Host "接下来你可以：" -ForegroundColor Cyan
    Write-Host "  1. 直接在 Codex 弹窗界面点击【重新设置】" -ForegroundColor White
    Write-Host "  2. 或直接重新打开 Codex 客户端即可正常使用" -ForegroundColor White
}

function Show-Status {
    Write-Host "Codex 沙箱环境诊断报告" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "目录检测:"
    Write-Host "  .codex:        $([bool](Test-Path $CodexHome))"
    Write-Host "  .sandbox:      $([bool](Test-Path $SandboxDir))"
    Write-Host "  .sandbox-bin:  $([bool](Test-Path $SandboxBinDir))"
    
    $errJson = Join-Path $SandboxDir "setup_error.json"
    if (Test-Path $errJson) {
        Write-Host "  最近报错 (setup_error.json):" -ForegroundColor Red
        Get-Content $errJson | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    } else {
        Write-Host "  最近报错: 无 (正常)" -ForegroundColor Green
    }

    $marker = Join-Path $SandboxDir "setup_marker.json"
    if (Test-Path $marker) {
        $len = (Get-Item $marker).Length
        Write-Host "  沙箱就绪标记 (setup_marker.json): 存在 ($len 字节)" -ForegroundColor Green
    } else {
        Write-Host "  沙箱就绪标记 (setup_marker.json): 未生成 / 缺失" -ForegroundColor Yellow
    }

    Write-Host ""
    Check-Service
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
}

switch ($Action.ToLower()) {
    { $_ -in @('help', '-h', '--help') } {
        Show-Help
        break
    }
    'kill' {
        Kill-CodexProcesses
        break
    }
    'clean' {
        Kill-CodexProcesses
        Fix-Permissions -CleanMarkers $true
        break
    }
    'status' {
        Show-Status
        break
    }
    default {
        Fix-Permissions -CleanMarkers $false
        break
    }
}
