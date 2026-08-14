# ============================================================
# dsh-edge-app 一键安装脚本（Windows）
#
# 1) 检查/安装 Node.js (>= 18，缺失时用 winget 自动安装)
# 2) npm 全局安装 DeepSeek Harness (@deepseek-ai/dsh)
# 3) 安装无窗口启动器 launcher.vbs 到 %LOCALAPPDATA%\dsh-edge-app\
# 4) 创建桌面 + 开始菜单快捷方式 "DeepSeek Harness"（鲸鱼图标）
#    （点击后：无窗口后台启动 dsh web -> 等待就绪 ->
#    自动打开 Edge 独立应用窗口，非标签页）
# 5) 首次运行
#
# 用法：双击 install.bat，或：
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# ============================================================
#Requires -Version 5.1

param(
    [switch]$SkipNode
)

$ErrorActionPreference = "Continue"

$AppName     = "DeepSeek Harness"
$ShortcutName = "DeepSeek Harness.lnk"
$Url         = "http://127.0.0.1:3080"
$InstallDir  = Join-Path $env:LOCALAPPDATA "dsh-edge-app"
$LauncherSrc = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "launcher.vbs"
$LauncherDst = Join-Path $InstallDir "launcher.vbs"
$UpdateSrc   = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "update-dsh.ps1"
$UpdateDst   = Join-Path $InstallDir "update-dsh.ps1"
$IconSrc     = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "deepseek.ico"
$IconDst     = Join-Path $InstallDir "deepseek.ico"
$Wscript     = Join-Path $env:WINDIR "System32\wscript.exe"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  dsh-edge-app 安装器 - DeepSeek Harness Edge 应用" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 查找 Microsoft Edge ----------
function Get-MsEdgePath {
    $reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" -ErrorAction SilentlyContinue
    if ($reg -and $reg.'(default)') { return $reg.'(default)' }
    foreach ($p in @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

# ---------- 创建快捷方式（wscript + launcher.vbs，无窗口） ----------
function New-DshShortcut {
    param([string]$Path)
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($Path)
    $sc.TargetPath  = $Wscript
    $sc.Arguments   = "`"$LauncherDst`""
    $sc.IconLocation = $IconDst
    $sc.Description = "$AppName - 后台启动 dsh web 并打开 Edge 独立应用窗口"
    $sc.Save()
    Write-Host "[dsh-edge-app] 已创建快捷方式: $Path"
}

# ---------- 检查 Node.js ----------
function Test-NodeVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { return $null }
    return ((& node --version) -replace "v", "")
}

# ---------- 1. Node.js ----------
if (-not $SkipNode) {
    $nodeVer = Test-NodeVersion
    if (-not $nodeVer) {
        Write-Host "[1/5] 未检测到 Node.js，尝试通过 winget 安装 Node.js LTS ..." -ForegroundColor Yellow
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $nodeVer = Test-NodeVersion
        }
        if (-not $nodeVer) {
            Write-Host "[错误] Node.js 安装失败，请手动安装: https://nodejs.org (LTS, >= 18)" -ForegroundColor Red
            exit 1
        }
    }
    $major = [int](($nodeVer -split "\.")[0])
    if ($major -lt 18) {
        Write-Host "[错误] Node.js 版本过低 (v$nodeVer)，需要 >= 18: https://nodejs.org" -ForegroundColor Red
        exit 1
    }
    Write-Host "[1/5] Node.js 检查通过: v$nodeVer"
}
else {
    Write-Host "[1/5] 跳过 Node.js 检查 (-SkipNode)"
}

# ---------- 2. 安装 dsh ----------
Write-Host "[2/5] 通过 npm 安装 DeepSeek Harness (@deepseek-ai/dsh) ..."
& npm install -g @deepseek-ai/dsh
if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] npm 安装 dsh 失败，请检查网络/npm 配置" -ForegroundColor Red
    exit 1
}
# npm >= 11 默认拦截依赖的原生构建脚本，这里放行（node-pty/koffi 等）
$npmMajor = [int](((& npm --version) -split "\.")[0])
if ($npmMajor -ge 11) {
    Write-Host "      放行原生依赖构建脚本 (allow-scripts) ..."
    & npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty @deepseek-ai/dsh 2>&1 | Out-Null
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
if (-not (Get-Command dsh -ErrorAction SilentlyContinue)) {
    Write-Host "[错误] 安装完成但找不到 dsh 命令，请重开终端后重试" -ForegroundColor Red
    exit 1
}
try { $dshVer = (& dsh --version 2>$null) } catch { $dshVer = "" }
Write-Host "[2/5] dsh 安装成功: $dshVer"

# ---------- 3. 安装启动器与图标 ----------
Write-Host "[3/5] 安装无窗口启动器与鲸鱼图标 ..."
if (-not (Test-Path -LiteralPath $LauncherSrc)) {
    Write-Host "[错误] 缺少 launcher.vbs（请与 install.ps1 放在同一目录）" -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath $LauncherSrc -Destination $LauncherDst -Force
if (Test-Path -LiteralPath $UpdateSrc) {
    Copy-Item -LiteralPath $UpdateSrc -Destination $UpdateDst -Force
}
if (Test-Path -LiteralPath $IconSrc) {
    Copy-Item -LiteralPath $IconSrc -Destination $IconDst -Force
}
Write-Host "[3/5] 启动器已安装: $LauncherDst"

# ---------- 4. 创建快捷方式 ----------
Write-Host "[4/5] 创建桌面与开始菜单快捷方式 ..."
$edge = Get-MsEdgePath
if (-not $edge) {
    Write-Host "[错误] 未找到 Microsoft Edge，请先安装: https://www.microsoft.com/edge" -ForegroundColor Red
    exit 1
}
Write-Host "      Edge: $edge"
$desktop = [Environment]::GetFolderPath('Desktop')
New-DshShortcut (Join-Path $desktop $ShortcutName)
New-DshShortcut (Join-Path (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs") $ShortcutName)

# ---------- 5. 首次运行 ----------
Write-Host "[5/5] 首次运行：后台启动 dsh web 并打开 Edge 应用窗口 ..."
Start-Process -FilePath $Wscript -ArgumentList "`"$LauncherDst`""
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "  桌面快捷方式: $ShortcutName" -ForegroundColor Green
Write-Host "  点击后自动: 无窗口启动 dsh web -> 就绪 -> 打开 Edge 独立窗口" -ForegroundColor Green
Write-Host "  后台地址: $Url" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""