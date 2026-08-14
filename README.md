# dsh-edge-app

[English](#english) | [中文](#中文)

一键安装 [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness)，并将其 Web 界面注册为 **Edge 独立应用**（带桌面快捷方式）。

点击 "DeepSeek Harness" 应用后：**无窗口后台启动** `dsh web` → 等待服务就绪 → 自动打开 **Edge 独立应用窗口**（非标签页，无地址栏），像原生应用一样使用 DeepSeek Harness 后台。

One-command installer for [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) on Windows. Registers the dsh web UI (`http://127.0.0.1:3080`) as a standalone **Edge app** with desktop shortcut: clicking the app silently starts `dsh web` in the background, waits until the service is ready, then opens a dedicated Edge app window (not a tab).

---

## 中文

### 特性

- **一个脚本搞定**：自动检查/安装 Node.js → npm 安装官方 `@deepseek-ai/dsh` → 安装无窗口启动器 → 创建桌面 + 开始菜单快捷方式
- 桌面快捷方式名为 **DeepSeek Harness**，使用 **DeepSeek 黑色鲸鱼图标**（来源：[LobeHub](https://github.com/lobehub/lobe-icons)）
- 点击快捷方式 = 打开应用：**无任何窗口闪现**，静默后台启动 `dsh web`，就绪后自动弹出 Edge 独立应用窗口
- Edge 应用形态：`msedge --app=...`，无标签栏/地址栏，独立任务栏图标
- 日志写入 `%LOCALAPPDATA%\dsh-edge-app\`

### 环境要求

- Windows 10/11
- Microsoft Edge（系统自带）
- Node.js >= 18（缺失时脚本会用 winget 自动安装）

### 快速开始

双击 `install.bat`，或手动运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装完成后，桌面会出现 **"DeepSeek Harness"** 快捷方式（开始菜单也有）。

以后每次使用：双击该快捷方式即可——脚本会自动完成"启动服务 + 打开应用窗口"，无需再开命令行。

### 工作原理

```
点击快捷方式 (DeepSeek Harness)
    │  (目标: wscript.exe launcher.vbs，全程无窗口)
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
| 重新安装 / 更新 dsh | 重新运行 `install.bat`（npm 会自动升级） |
| 查看运行日志 | `%LOCALAPPDATA%\dsh-edge-app\dsh-web.log` / `dsh-web.err.log` |

### 常见问题

- **执行策略限制**：请通过 `install.bat` 运行，或使用 `-ExecutionPolicy Bypass` 参数
- **安装后找不到 `dsh` 命令**：重开终端让 PATH 生效
- **端口 3080 被占用**：停止占用该端口的进程后再点击应用
- **应用窗口打不开**：查看 `dsh-web.err.log`；确认 Edge 已安装
- **卸载**：删除桌面/开始菜单快捷方式，`npm uninstall -g @deepseek-ai/dsh`，删除 `%LOCALAPPDATA%\dsh-edge-app\`

### 许可证

[MIT](LICENSE)

---

## English

### Features

- **One script**: checks/installs Node.js → installs official `@deepseek-ai/dsh` via npm → installs a windowless launcher → creates Desktop + Start Menu shortcuts
- Desktop shortcut named **DeepSeek Harness** with the **black DeepSeek whale icon** (from [LobeHub](https://github.com/lobehub/lobe-icons))
- Clicking the shortcut silently starts `dsh web` in the background (**no console window flashes**), waits until ready, then opens a standalone Edge app window
- App-style Edge window: `msedge --app=...` — no tabs, no address bar, own taskbar icon
- Logs: `%LOCALAPPDATA%\dsh-edge-app\`

### Requirements

- Windows 10/11, Microsoft Edge, Node.js >= 18 (auto-installed via winget if missing)

### Quick start

Double-click `install.bat`, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then just double-click the **"DeepSeek Harness"** shortcut on your desktop — it handles everything (start server + open app window).

### How it works

```
Click shortcut (target: wscript.exe launcher.vbs, fully windowless)
    ▼
launcher.vbs probes http://127.0.0.1:3080
    │  not ready → cmd /c dsh web (hidden window, logs redirected)
    ▼
poll until service is ready (max 90s)
    ▼
msedge --app=http://127.0.0.1:3080  ← standalone Edge app window
```

### Troubleshooting

- PowerShell execution policy: run via `install.bat` or add `-ExecutionPolicy Bypass`
- Port 3080 occupied: stop the process listening on it, then click the app again
- App window won't open: check `%LOCALAPPDATA%\dsh-edge-app\dsh-web.err.log`

### License

[MIT](LICENSE)