# DeepSeek Harness 桌面端

中文 | [English](#english)

## 中文

一键安装 [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness)，并将其 Web 界面注册为 **Edge 独立应用**（桌面快捷方式）。

点击 "DeepSeek Harness" 应用后：像原生应用一样使用 DeepSeek Harness 后台，体积极小，无需额外封装，仅作为Edge快捷方式，一键打开终端与独立网页。

### 特性

- **自动跟随官方更新**：每次打开应用都会检查DeepSeek Harness官方最新版并自动更新，**无需其他操作**
- **点击秒开**：更新检查在后台异步执行，不阻塞打开，不弹任何窗口
- **一个脚本搞定**：自动检查/安装 Node.js → 检查 dsh（**已安装且为最新版则跳过**，否则自动安装/升级）→ 安装无窗口启动器 → 创建桌面 + 开始菜单快捷方式
- **官方图标自动获取**：安装时从 `dsh web` 页面自动提取官方 favicon（黑色鲸鱼）生成多尺寸图标，随官方版本同步；提取失败时使用默认图标（重跑安装脚本可重试）
- 桌面快捷方式名为 **DeepSeek Harness**，点击后：后台检查更新 → 无窗口后台启动 `dsh web` → 就绪后自动打开 Edge 独立应用窗口
- Edge 应用形态：`msedge --app=...`，无标签栏/地址栏，独立任务栏图标
- 日志写入 `%LOCALAPPDATA%\dsh-edge-app\`

### 要求

- **Microsoft Edge**（系统自带）

### 快速开始

双击 `双击安装.bat`，或手动运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会先检查：Node.js 缺失自动安装；dsh 已安装且为最新版则跳过，否则自动安装/升级。

安装完成后，桌面会出现 **"DeepSeek Harness"** 快捷方式（开始菜单也有）。

以后每次使用：双击该快捷方式即可——脚本会自动完成"检查更新 + 启动服务 + 打开应用窗口"，无需再开命令行。

**卸载**：双击 `卸载.bat` 一键卸载（停止服务 → 删快捷方式 → 删安装目录与缓存 → npm 卸载 dsh）。只删除程序与缓存，**保留你的工作区与文档**。

> **关于"在 Edge 里安装为应用"**：dsh web 本身就是标准 PWA（自带 `manifest.webmanifest`）。如想要系统级的 Edge 应用条目（`edge://apps` 列表、可单独卸载），可在 Edge 中打开 http://127.0.0.1:3080 后点击地址栏的"安装应用"按钮——图标同样自动使用官方鲸鱼图标。本项目的桌面快捷方式已等效实现独立应用窗口体验，且额外具备"自动更新 + 后台启动"能力（Edge 应用条目本身不提供启动服务的能力）。

### 工作原理

```
点击快捷方式 (DeepSeek Harness)
    │  (目标: wscript.exe launcher.vbs，全程无窗口)
    ▼
后台检查更新（install.ps1 -UpdateCheck，异步，每次打开都检查，自动 npm 更新）
    ▼
launcher.vbs 检查 http://127.0.0.1:3080 是否就绪
    │  未就绪 → cmd /c dsh web（隐藏窗口后台启动，日志重定向）
    ▼
轮询等待服务就绪（最多 90 秒）
    ▼
msedge --app=http://127.0.0.1:3080  ← 独立应用窗口打开 DSH 后台
```

### 常用操作

| 操作 | 方式 |
| --- | --- |
| 打开 DSH 后台 | 双击桌面 "DeepSeek Harness" 快捷方式 |
| 停止后台服务 | `Stop-Process -Id (Get-NetTCPConnection -LocalPort 3080).OwningProcess -Force` |
| 重新安装 / 更新 dsh | 重新运行 `双击安装.bat`（已装且最新会自动跳过） |
| 查看运行日志 | `%LOCALAPPDATA%\dsh-edge-app\dsh-web.log` / `dsh-web.err.log` |
| 一键卸载 | 双击 `卸载.bat`（保留工作区与文档） |

### 常见问题

- **执行策略限制**：请通过 `双击安装.bat` 运行，或使用 `-ExecutionPolicy Bypass` 参数
- **安装后找不到 `dsh` 命令**：重开终端让 PATH 生效
- **端口 3080 被占用**：停止占用该端口的进程后再点击应用
- **应用窗口打不开**：查看 `dsh-web.err.log`；确认 Edge 已安装
- **卸载**：双击 `卸载.bat` 一键卸载（程序/服务/快捷方式/缓存，保留工作区与文档）；或手动：删快捷方式 + `npm uninstall -g @deepseek-ai/dsh` + 删 `%LOCALAPPDATA%\dsh-edge-app\`

---

## English

One-command installer for [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) on Windows. Registers the dsh web UI (`http://127.0.0.1:3080`) as a standalone **Edge app** with desktop shortcut: clicking the app checks for updates in the background, silently starts `dsh web`, waits until the service is ready, then opens a dedicated Edge app window (not a tab).

### Features

- **Opens instantly**: update check runs in the background (async), never blocks or pops up windows
- **Auto-updates**: every open silently checks npm for the latest version and installs it automatically — zero manual work
- **One script**: auto-installs Node.js → checks dsh (**skips if already installed and up to date**, else installs/upgrades automatically) → deploys the windowless launcher → creates desktop + Start Menu shortcuts
- **Official icon**: auto-extracts the official favicon (black whale) from dsh web at install time; falls back to the default icon if extraction fails (re-run the installer to retry)
- Desktop shortcut named **DeepSeek Harness**: background update check → hidden `dsh web` start → Edge standalone app window
- Standalone window via `msedge --app=...`: no tabs, no address bar, own taskbar icon
- Logs under `%LOCALAPPDATA%\dsh-edge-app\`

### Requirements

- Windows 10/11, Microsoft Edge, Node.js >= 18 (auto-installed via winget if missing)

### Quick start

Double-click `双击安装.bat`, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then just double-click the **"DeepSeek Harness"** shortcut on your desktop — it handles everything (check updates + start server + open app window).

> **Install as a real Edge app**: dsh web is a standard PWA. If you want a system-level entry in `edge://apps`, open http://127.0.0.1:3080 in Edge and click "Install app" in the address bar. This project's shortcut already delivers the same standalone-window experience plus auto-update and background start (which an Edge app entry does not provide).

### Uninstall

Double-click `卸载.bat` — it stops the service, removes the shortcuts, the install dir and caches, and uninstalls dsh via npm. **Your workspace and documents are kept.**

### How it works

```
Click shortcut (target: wscript.exe launcher.vbs, fully windowless)
    ▼
background update check (install.ps1 -UpdateCheck, async, checks on every open, auto npm update)
    ▼
launcher.vbs probes http://127.0.0.1:3080
    │  not ready → cmd /c dsh web (hidden window, logs redirected)
    ▼
poll until service is ready (max 90s)
    ▼
msedge --app=http://127.0.0.1:3080  ← standalone Edge app window
```

### Troubleshooting

- PowerShell execution policy: run via `双击安装.bat` or add `-ExecutionPolicy Bypass`
- Port 3080 occupied: stop the process listening on it, then click the app again
- App window won't open: check `%LOCALAPPDATA%\dsh-edge-app\dsh-web.err.log`
