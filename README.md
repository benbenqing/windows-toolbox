# scoop-bucket

个人 Scoop bucket，用来在多台 Windows 机器之间分发自己写的终端小工具。

目前收录：

| App | 命令 | 说明 |
| --- | --- | --- |
| `terminal-proxy` | `tproxy` / `tproxy-ui` / `tproxy-test` | 一键开关终端代理环境变量（HTTP_PROXY / HTTPS_PROXY / ALL_PROXY） |

## 在另一台电脑上安装

```powershell
scoop bucket add qingbenben https://github.com/qingbenben/scoop-bucket
scoop install qingbenben/terminal-proxy
```

`tproxy` 会以 shim 形式装进 `~\scoop\shims`，新开的终端直接可用：

```powershell
tproxy status              # 查看当前 HTTP/HTTPS/ALL_PROXY
tproxy on                  # 开启，默认 http://127.0.0.1:7897
tproxy on 127.0.0.1:1080   # 换成别的代理
tproxy off                 # 关闭（默认同时清理进程与 Windows 用户环境变量）
tproxy-ui                  # 交互式菜单
tproxy-test                # npm / Maven / Gradle 连通性自检
```

升级：

```powershell
scoop update
scoop update terminal-proxy
```

> `raw.githubusercontent.com` 国内可能连不上。先 `tproxy on`，或给 Scoop 单独配代理：
> `scoop config proxy 127.0.0.1:7897`。

## 仓库结构

```
bucket/terminal-proxy.json     # Scoop 清单：下载地址 + SHA256 + bin 映射
apps/terminal-proxy/           # 工具源码（唯一真源）
packages/                      # 由脚本生成的安装包，必须提交
scripts/publish.ps1            # 打包 + 回写版本/URL/哈希
```

## 发布新版本

1. 改 `apps/terminal-proxy/` 下的脚本。
2. 打包并更新清单（版本号不传则沿用清单里的版本）：

   ```powershell
   pwsh .\scripts\publish.ps1 -Version 1.0.1 -Commit
   git push
   ```

3. 其它机器 `scoop update; scoop update terminal-proxy`。

脚本做三件事：把 `apps/<app>` 打成 `packages/<app>-<ver>.zip`、计算 SHA256、
把 `bucket/<app>.json` 的 `url`/`hash`/`version` 改好。清单里的 URL 指向
`raw.githubusercontent.com/qingbenben/scoop-bucket/main/packages/...`，所以
**包文件和清单必须一起提交**。

## 新增一个工具

1. 源码放进 `apps/<app>/`，清单放进 `bucket/<app>.json`（`bin` 里写 ps1 → 命令名）。
2. `pwsh .\scripts\publish.ps1 -App <app> -Version 1.0.0 -Commit`
3. `git push`，另一台机器 `scoop update` 后即可 `scoop install qingbenben/<app>`。
