<#
.SYNOPSIS
    ttool - 开发者个人通用工具箱入口 (Unified Developer Toolkit)
.DESCRIPTION
    统一管理个人常用脚本工具（代理、投屏、Codex修复等），支持子命令直达与交互式数字菜单。
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$SubArgs
)

# 工具注册表（未来有新工具直接在下方数组追加即可）
$Tools = @(
    @{
        Key         = 'proxy'
        Aliases     = @('p', 'tproxy', 'prox')
        Title       = '[网络代理] tproxy'
        Description = '快速开启/关闭全局终端 HTTP/HTTPS 代理环境'
        TargetShim  = 'tproxy'
        TargetFile  = "$env:USERPROFILE\scoop\apps\terminal-proxy\current\terminal-proxy.ps1"
        Actions     = @(
            @{ Code = '1'; Label = '开启代理 (on)'; Args = @('on') },
            @{ Code = '2'; Label = '关闭代理 (off)'; Args = @('off') },
            @{ Code = '3'; Label = '查看状态 (status)'; Args = @('status') }
        )
    },
    @{
        Key         = 'mirror'
        Aliases     = @('m', 'pmirror', 'phone', 'scrcpy')
        Title       = '[手机投屏] pmirror'
        Description = 'Android 手机极速低延迟投屏与键鼠控制 (scrcpy)'
        TargetShim  = 'pmirror'
        TargetFile  = "$env:USERPROFILE\scoop\apps\phone-mirror\current\pmirror.ps1"
        Actions     = @(
            @{ Code = '4'; Label = '常规投屏 (保持亮屏)'; Args = @('start') },
            @{ Code = '5'; Label = '息屏投屏 (手机黑屏省电)'; Args = @('off') },
            @{ Code = '6'; Label = '一键无线 WiFi 投屏'; Args = @('wifi') },
            @{ Code = '7'; Label = '检测连接设备 (devices)'; Args = @('devices') }
        )
    },
    @{
        Key         = 'codex'
        Aliases     = @('c', 'fix', 'codex-fix')
        Title       = '[沙箱修复] codex-fix'
        Description = '一键修复 Codex Windows 沙箱权限与多实例文件锁错误'
        TargetShim  = 'codex-fix'
        TargetFile  = "$env:USERPROFILE\scoop\apps\codex-fix\current\codex-fix.ps1"
        Actions     = @(
            @{ Code = '8'; Label = '一键修复沙箱权限 (fix)'; Args = @('fix') },
            @{ Code = '9'; Label = '强杀残留死锁进程 (kill)'; Args = @('kill') },
            @{ Code = '10'; Label = '沙箱环境诊断 (status)'; Args = @('status') }
        )
    }
)

function Invoke-ToolTarget {
    param(
        [Parameter(Mandatory = $true)]$ToolConfig,
        [string[]]$Arguments
    )

    if (Test-Path $ToolConfig.TargetFile) {
        & $ToolConfig.TargetFile @Arguments
    } elseif (Get-Command $ToolConfig.TargetShim -ErrorAction SilentlyContinue) {
        & $ToolConfig.TargetShim @Arguments
    } else {
        Write-Error "找不到工具可执行脚本: $($ToolConfig.TargetShim)"
    }
}

function Show-Help {
    Write-Host ''
    Write-Host '=================================================================' -ForegroundColor Cyan
    Write-Host '              tTool - 个人开发者统一工具箱 (Toolkit)             ' -ForegroundColor Cyan
    Write-Host '=================================================================' -ForegroundColor Cyan
    Write-Host '用法:' -ForegroundColor Yellow
    Write-Host '  t / ttool                   进入交互式快速菜单 (输入数字直接执行)'
    Write-Host '  t / ttool <工具> [参数...]  直接调用具体工具的子命令'
    Write-Host '  t / ttool help              显示本帮助菜单'
    Write-Host ''
    Write-Host '已注册的工具与子命令直达:' -ForegroundColor Yellow
    foreach ($t in $Tools) {
        $aliasStr = ($t.Aliases -join ', ')
        Write-Host "  $($t.Title)" -ForegroundColor Green
        Write-Host "    说明: $($t.Description)" -ForegroundColor Gray
        Write-Host "    命令: t $($t.Key)  [别名: $aliasStr]" -ForegroundColor DarkCyan
        Write-Host '    示例: ' -NoNewline -ForegroundColor Gray
        $examples = foreach ($act in $t.Actions) { "t $($t.Key) $($act.Args -join ' ')" }
        Write-Host ($examples -join ' | ') -ForegroundColor DarkGray
        Write-Host ''
    }
    Write-Host '提示: 原有的独立命令 (tproxy / pmirror / codex-fix) 依然保持完全独立可用。' -ForegroundColor DarkGray
    Write-Host '=================================================================' -ForegroundColor Cyan
}

function Show-InteractiveMenu {
    Write-Host ''
    Write-Host '=================================================================' -ForegroundColor Cyan
    Write-Host '              tTool 开发者个人快捷工具箱 (输入数字直达)          ' -ForegroundColor Cyan
    Write-Host '=================================================================' -ForegroundColor Cyan

    $actionMap = @{}
    foreach ($tool in $Tools) {
        Write-Host ''
        Write-Host "  $($tool.Title) - $($tool.Description)" -ForegroundColor Yellow
        Write-Host '  ' -NoNewline
        foreach ($act in $tool.Actions) {
            $actionMap[$act.Code] = @{
                Tool = $tool
                Args = $act.Args
            }
            Write-Host " [$($act.Code)] " -NoNewline -ForegroundColor Cyan
            Write-Host "$($act.Label)   " -NoNewline -ForegroundColor White
        }
        Write-Host ''
    }

    Write-Host ''
    Write-Host '  [q] 退出' -ForegroundColor DarkGray
    Write-Host '-----------------------------------------------------------------' -ForegroundColor DarkGray
    
    $choice = Read-Host '请输入对应数字编号选择操作 (如 1, 4, 8)'
    if ($choice) { $choice = $choice.Trim() }

    if ($choice -eq 'q' -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host '已退出。' -ForegroundColor DarkGray
        return
    }

    if ($actionMap.ContainsKey($choice)) {
        $selected = $actionMap[$choice]
        Write-Host ''
        Write-Host ">> 执行: t $($selected.Tool.Key) $($selected.Args -join ' ')" -ForegroundColor Cyan
        Write-Host ''
        Invoke-ToolTarget -ToolConfig $selected.Tool -Arguments $selected.Args
    } else {
        Write-Host "无效的选择编号: $choice" -ForegroundColor Red
    }
}

# 逻辑分发
if ([string]::IsNullOrWhiteSpace($Command)) {
    Show-InteractiveMenu
    exit 0
}

switch ($Command.ToLower()) {
    { $_ -in @('help', '-h', '--help', '/?') } {
        Show-Help
        exit 0
    }

    default {
        $matchedTool = $null
        foreach ($t in $Tools) {
            if ($t.Key -eq $Command.ToLower() -or ($t.Aliases -contains $Command.ToLower())) {
                $matchedTool = $t
                break
            }
        }

        if ($matchedTool) {
            Invoke-ToolTarget -ToolConfig $matchedTool -Arguments $SubArgs
        } else {
            Write-Host "未知的工具或子命令: $Command" -ForegroundColor Red
            Write-Host "请运行 't help' 查看可用工具列表，或直接运行 't' 查看菜单。" -ForegroundColor Yellow
            exit 1
        }
    }
}
