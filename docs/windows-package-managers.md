# Windows 包管理工具

本机使用 WinGet、Scoop 和 Chocolatey。Windows Toolbox 自身的工具由 Scoop 管理。

| 工具 | 主要用途 | 常用命令 |
| --- | --- | --- |
| WinGet | 安装、更新常见 Windows 应用 | `winget search <名称>`、`winget install --id <ID> --exact` |
| Scoop | 管理当前用户的命令行工具和个人软件源 | `scoop search <名称>`、`scoop install <名称>` |
| Chocolatey | 使用 Chocolatey 软件包 | `choco search <名称>`、`choco install <名称> --yes` |

当前 Scoop 安装在 `$env:USERPROFILE\scoop`；Chocolatey 安装在
`$env:LOCALAPPDATA\Programs\Chocolatey`，采用当前用户安装。
需要系统权限的软件包仍应从管理员终端安装。安装新工具后，重新打开终端使 PATH 生效。

## 开发副本与 Scoop 软件源

开发副本放在 `D:\softCode\windows-toolbox`。`D:\softCode` 下可以并列放置其他项目。
在这个副本中修改 `apps/`，运行 `scripts/publish.ps1` 生成安装包和清单，再提交、推送。

Scoop 软件源是 Scoop 自己维护的另一个 Git 副本，添加方式如下：

```powershell
scoop bucket add windows-toolbox https://github.com/benbenqing/windows-toolbox
scoop search ttool

# 按需安装整套工具，或只安装一个工具
scoop install windows-toolbox/ttool
scoop install windows-toolbox/terminal-proxy
```

保留仓库根目录的 `bucket/`、`apps/`、`packages/` 和 `scripts/` 结构，
确保 Scoop 可以识别清单，发布脚本也能找到源码和安装包。

## 搜索与更新

```powershell
winget search --id GitHub.cli --exact --source winget
winget upgrade

scoop search ttool
scoop update
scoop status

choco search chocolatey --exact
choco outdated
```

先查看更新列表，再按软件名执行 `winget upgrade --id <ID> --exact`、
`scoop update <名称>` 或 `choco upgrade <名称> --yes`。

## 代理

使用本机 `127.0.0.1:7897` 代理时，可为 Scoop 和 Chocolatey 分别配置：

```powershell
scoop config proxy 127.0.0.1:7897
choco config set --name proxy --value http://127.0.0.1:7897 --yes
```

这两项配置只用于对应的包管理器。终端中的临时代理变量可用安装后的 `tproxy` 管理。

## 官方文档

- [WinGet](https://learn.microsoft.com/windows/package-manager/winget/)
- [Scoop 安装](https://github.com/ScoopInstaller/Install)
- [Chocolatey 安装](https://docs.chocolatey.org/en-us/choco/setup/)
