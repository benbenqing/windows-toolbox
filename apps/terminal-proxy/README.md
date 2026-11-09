# Terminal Proxy

Small PowerShell command for enabling or disabling a local proxy through the
common proxy environment variables used by development tools.

Managed variables:

- `HTTP_PROXY` / `http_proxy`
- `HTTPS_PROXY` / `https_proxy`
- `ALL_PROXY` / `all_proxy`

The default proxy is `http://127.0.0.1:7897`. No Java-specific options such as
`GRADLE_OPTS` are configured.

## Usage

```powershell
.\terminal-proxy.ps1 on
.\terminal-proxy.ps1 status
.\terminal-proxy.ps1 off
```

`on` and `off` default to `Both`, which updates the current PowerShell process
and the Windows User environment. The User environment affects newly started
terminals and tools.

`off` removes the proxy variables. It does not change Windows routes or disable
a TUN/VPN virtual adapter. If the virtual adapter owns the route, traffic can
still go through it; if it only provides a local proxy, tools connect directly.

Use a different proxy or scope when needed:

```powershell
.\terminal-proxy.ps1 on http://127.0.0.1:7897
.\terminal-proxy.ps1 on 127.0.0.1:7897 -Scope Process
.\terminal-proxy.ps1 off -Scope User
```

To update the current shell process directly, dot-source the script:

```powershell
. .\terminal-proxy.ps1 on
. .\terminal-proxy.ps1 off
```

This matters because a normally invoked PowerShell script runs in a child
process and cannot alter the parent shell's process environment. The User
environment is still updated by the normal invocation when the default `Both`
scope is used. For `off`, User-scope values are removed from
`HKCU:\Environment`, rather than being retained as empty entries. Restart
existing terminals when needed.

On Windows, environment variable names are case-insensitive. The script writes
both spellings for compatibility with tools that conventionally look up either
uppercase or lowercase names.

## Scoop local install

Build the local package and install the manifest:

```powershell
Compress-Archive -Path .\terminal-proxy.ps1 -DestinationPath .\terminal-proxy-1.0.0.zip -Force
$hash = (Get-FileHash .\terminal-proxy-1.0.0.zip -Algorithm SHA256).Hash.ToLower()
.\update-manifest-hash.ps1 -Hash $hash
scoop install .\terminal-proxy.json
```

After installation, use the short command:

```powershell
tproxy on
tproxy status
tproxy off
```

For an interactive menu:

```powershell
tproxy-ui
```

The menu provides proxy enable/disable, status, connectivity test, and command
help. Scriptable short commands remain available for automation.

## Development tool connectivity test

Run the diagnostic script from the project directory:

```powershell
.\dev-connectivity-test.ps1
```

It checks npm registry access and `npm exec`, Maven Central access and
`dependency:get`, local Gradle availability, Gradle service/plugin URLs, and
`gradlew.bat dependencies --refresh-dependencies` when a wrapper exists in the
current directory. Use `-SkipDownloads` to perform only command and HTTP
checks.
