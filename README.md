# scoop-bucket

个人 Scoop bucket，用来在多台 Windows 机器之间分发自己写的终端小工具。

目前收录：

| App | 命令 | 说明 |
| --- | --- | --- |
| `terminal-proxy` | `tproxy` / `tproxy-ui` / `tproxy-test` | 一键开关终端代理环境变量（HTTP_PROXY / HTTPS_PROXY / ALL_PROXY） |
| `phone-mirror` | `pmirror` | Android 投屏与键鼠控制，基于 scrcpy + adb，支持息屏 / 低延迟 / 无线投屏 |
| `codex-fix` | `codex-fix` | 修复 Codex 在 Windows 上的沙箱 ACL、残留进程和文件锁问题 |
| `ttool` | `ttool` / `t` | 统一入口：数字菜单 + 子命令直通上面三个工具（`depends` 会自动装齐） |

## 在另一台电脑上安装

一条命令装齐整套：

```powershell
scoop bucket add benbenqing https://github.com/benbenqing/scoop-bucket
scoop install benbenqing/ttool     # 自动依赖 terminal-proxy / phone-mirror / codex-fix
```

也可以只装某个工具：

```powershell
scoop install benbenqing/terminal-proxy
scoop install benbenqing/phone-mirror
scoop install benbenqing/codex-fix
```

装完后以 shim 形式进 `~\scoop\shims`，新开的终端直接可用：

```powershell
# tproxy
tproxy status              # 查看当前 HTTP/HTTPS/ALL_PROXY
tproxy on                  # 开启，默认 http://127.0.0.1:7897
tproxy on 127.0.0.1:1080   # 换成别的代理
tproxy off                 # 关闭（默认同时清理进程与 Windows 用户环境变量）
tproxy-ui                  # 交互式菜单
tproxy-test                # npm / Maven / Gradle 连通性自检

# pmirror（需要 scrcpy，见下）
pmirror                    # 常规投屏
pmirror off                # 息屏投屏
pmirror fast | max         # 低延迟 / 超清
pmirror wifi               # 一键无线投屏
pmirror devices            # 查看已连接设备

# codex-fix
codex-fix                  # 修复沙箱权限
codex-fix kill             # 结束残留 Codex 进程
codex-fix clean            # 深度重置
codex-fix status           # 诊断报告

# ttool
t                          # 数字菜单
t proxy on                 # tproxy 直通
t mirror wifi              # pmirror 直通
t codex fix                # codex-fix 直通
```

### 依赖说明

- `pmirror` 需要 `scrcpy`（自带 adb）：`scoop install extras/scrcpy`。
  脚本会在 PATH、`~\scoop\apps\scrcpy`、winget 安装目录、Android SDK 里找
  `scrcpy.exe` / `adb.exe`。
- `tproxy` 默认代理地址是 `http://127.0.0.1:7897`，按自己的客户端端口改。

升级：

```powershell
scoop update
scoop update ttool
```

> `raw.githubusercontent.com` 国内可能连不上。先 `tproxy on`，或给 Scoop 单独配代理：
> `scoop config proxy 127.0.0.1:7897`。

## 仓库结构

```
bucket/<app>.json     # Scoop 清单：下载地址 + SHA256 + bin 映射
apps/<app>/           # 工具源码（唯一真源）
packages/             # 由脚本生成的安装包，必须提交
scripts/publish.ps1   # 打包 + 回写版本/URL/哈希
```

## 发布新版本

1. 改 `apps/<app>/` 下的脚本。
2. 打包并更新清单（版本号不传则沿用清单里的版本）：

   ```powershell
   pwsh .\scripts\publish.ps1 -App ttool -Version 1.0.1 -Commit
   git push
   ```

3. 其它机器 `scoop update; scoop update ttool`。

脚本做三件事：把 `apps/<app>` 打成 `packages/<app>-<ver>.zip`、计算 SHA256、
把 `bucket/<app>.json` 的 `url`/`hash`/`version` 改好。清单里的 URL 指向
`raw.githubusercontent.com/benbenqing/scoop-bucket/main/packages/...`，所以
**包文件和清单必须一起提交**。

## 新增一个工具

1. 源码放进 `apps/<app>/`，清单放进 `bucket/<app>.json`（`bin` 里写 ps1 → 命令名）。
2. `pwsh .\scripts\publish.ps1 -App <app> -Version 1.0.0 -Commit`
3. `git push`，另一台机器 `scoop update` 后即可 `scoop install benbenqing/<app>`。
