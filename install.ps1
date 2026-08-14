#Requires -Version 5.1
# dsh-edge-app 安装/自动更新脚本
# 安装模式: Node.js -> npm dsh(已装且最新则跳过) -> 启动器 -> 官方图标 -> 快捷方式
# 更新模式(-UpdateCheck): launcher.vbs 每次打开后台静默调用, 有新版自动 npm 更新
# 用法: 双击"双击安装.bat", 或 powershell -ExecutionPolicy Bypass -File .\install.ps1

param([switch]$SkipNode, [switch]$UpdateCheck)

$ErrorActionPreference = "Continue"

$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$AppName      = "DeepSeek Harness"
$ShortcutName = "DeepSeek Harness.lnk"
$Url          = "http://127.0.0.1:3080"
$Pkg          = "@deepseek-ai/dsh"
$InstallDir   = Join-Path $env:LOCALAPPDATA "dsh-edge-app"
$LockFile     = Join-Path $InstallDir "update.lock"
$MyDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$LauncherSrc  = Join-Path $MyDir "launcher.vbs"
$LauncherDst  = Join-Path $InstallDir "launcher.vbs"
$IconDst      = Join-Path $InstallDir "deepseek.ico"
$Wscript      = Join-Path $env:WINDIR "System32\wscript.exe"

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

function Test-DshWeb {
    $conn = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        try { $null = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3; return $true } catch {}
    }
    return $false
}

function Start-DshWebBackground {
    $dsh = Get-Command dsh -ErrorAction SilentlyContinue
    if (-not $dsh) { return $false }
    $out = Join-Path $InstallDir "dsh-web.log"
    $err = Join-Path $InstallDir "dsh-web.err.log"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "dsh web" -WorkingDirectory $HOME -WindowStyle Hidden `
        -RedirectStandardOutput $out -RedirectStandardError $err
    return $true
}

function Wait-DshWeb {
    param([int]$TimeoutSeconds = 90)
    for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
        if (Test-DshWeb) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

function New-OfficialIcon {
    param([string]$OutIcoPath)
    Add-Type -AssemblyName System.Drawing
    $edgeExe = Get-MsEdgePath
    if (-not $edgeExe) { return $false }
    $svgFile = Join-Path $InstallDir "favicon.svg"
    try {
        Invoke-WebRequest -Uri "$Url/favicon.svg" -OutFile $svgFile -UseBasicParsing -TimeoutSec 10
    } catch { return $false }
    $hashFile = Join-Path $InstallDir "favicon.hash"
    if (Test-Path -LiteralPath $OutIcoPath -and (Test-Path -LiteralPath $hashFile)) {
        $old = (Get-Content -LiteralPath $hashFile -Raw -ErrorAction SilentlyContinue).Trim()
        $new = (Get-FileHash -LiteralPath $svgFile -Algorithm MD5).Hash
        if ($old -and $old -eq $new) {
            Write-Host "      图标未变化，使用现有图标（跳过生成）"
            return $true
        }
    }
    try {
        $svg = [System.IO.File]::ReadAllText($svgFile)
        $svg = $svg -replace 'width="[0-9.]+"', 'width="512"' -replace 'height="[0-9.]+"', 'height="512"'
        $svg512 = Join-Path $InstallDir "favicon-512.svg"
        [System.IO.File]::WriteAllText($svg512, $svg)
        $png512 = Join-Path $InstallDir "favicon-512.png"
        $fileUrl = (New-Object System.Uri($svg512)).AbsoluteUri
        & $edgeExe --headless --disable-gpu --default-background-color=00000000 --window-size=512,512 `
            --screenshot=$png512 $fileUrl 2>$null | Out-Null
        if (-not (Test-Path -LiteralPath $png512)) { return $false }

        $src = New-Object System.Drawing.Bitmap($png512)
        $sizes = @(16, 24, 32, 48, 64, 128, 256)
        $pngs = @()
        foreach ($s in $sizes) {
            $b = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($b)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.DrawImage($src, 0, 0, $s, $s)
            $ms = New-Object System.IO.MemoryStream
            $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $pngs += , $ms.ToArray()
            $g.Dispose(); $b.Dispose(); $ms.Dispose()
        }
        $src.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($ms)
        $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $s = $sizes[$i]
            $bw.Write([Byte]($(if ($s -ge 256) { 0 } else { $s })))
            $bw.Write([Byte]($(if ($s -ge 256) { 0 } else { $s })))
            $bw.Write([Byte]0); $bw.Write([Byte]0)
            $bw.Write([UInt16]1); $bw.Write([UInt16]32)
            $bw.Write([UInt32]$pngs[$i].Length)
            $bw.Write([UInt32]$offset)
            $offset += $pngs[$i].Length
        }
        foreach ($p in $pngs) { $bw.Write($p) }
        $bw.Flush()
        [System.IO.File]::WriteAllBytes($OutIcoPath, $ms.ToArray())
        [System.IO.File]::WriteAllText($hashFile, (Get-FileHash -LiteralPath $svgFile -Algorithm MD5).Hash)
        Remove-Item -LiteralPath $svg512, $png512 -Force -ErrorAction SilentlyContinue
        return (Test-Path -LiteralPath $OutIcoPath)
    } catch {
        return $false
    }
}

function New-DshShortcut {
    param([string]$Path, [string]$Icon)
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($Path)
    $sc.TargetPath  = $Wscript
    $sc.Arguments   = "`"$LauncherDst`""
    if ($Icon -and (Test-Path -LiteralPath $Icon)) { $sc.IconLocation = $Icon }
    $sc.Description = "$AppName - 点击后: 后台更新 dsh -> 启动 dsh web -> 打开 Edge 独立窗口"
    $sc.Save()
    Write-Host "[dsh-edge-app] 已创建快捷方式: $Path"
}

function Test-NodeVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { return $null }
    return ((& node --version) -replace "v", "")
}

function Get-DshVersion {
    $dshCmd = Get-Command dsh -ErrorAction SilentlyContinue
    if (-not $dshCmd) { return "" }
    try { return ((& dsh --version 2>$null) | Select-Object -Last 1).Trim() } catch { return "" }
}

function Get-LatestVersion {
    $latest = ((& npm view $Pkg version 2>$null) | Select-Object -Last 1)
    if ($latest) { return $latest.Trim() }
    return ""
}

# 安装/升级 dsh 到最新版; 返回: 0=已最新, 1=安装/升级成功, -1=失败
# 优化: npm>=11 一次完成(带 allow-scripts); 官方源失败自动 npmmirror 重试; 安装模式可见进度, 更新模式静默
function Update-Dsh {
    param([bool]$Quiet = $true)
    $npmMajor = [int](((& npm --version 2>$null) -split "\.")[0])
    $base = @("install", "-g")
    if ($npmMajor -ge 11) {
        $base += "--allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs"
    }
    foreach ($reg in @("", "https://registry.npmmirror.com")) {
        $npmArgs = @($base)
        if ($reg) { $npmArgs += "--registry=$reg" }
        $npmArgs += $Pkg
        if ($Quiet) { & npm @npmArgs 2>&1 | Out-Null } else { & npm @npmArgs }
        if ($LASTEXITCODE -eq 0) { return 1 }
        if (-not $Quiet -and $reg) {
            Write-Host "      官方源失败，改用 npmmirror 镜像重试 ..." -ForegroundColor Yellow
        }
    }
    return -1
}

# ================== 更新检查模式（launcher.vbs 每次打开后台调用） ==================
if ($UpdateCheck) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $lock = $null
    try {
        $lock = New-Object System.IO.FileStream($LockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    }
    catch {
        exit 0
    }
    try {
        $local = Get-DshVersion
        if (-not $local) { exit 0 }
        $latest = Get-LatestVersion
        if (-not $latest -or $latest -eq $local) { exit 0 }
        for ($i = 0; $i -lt 90; $i++) {
            if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) { break }
            Start-Sleep -Seconds 1
        }
        Update-Dsh | Out-Null
    }
    finally {
        if ($lock) { $lock.Dispose() }
        Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

# ================== 安装模式 ==================
Write-Host ""
Write-Host "  dsh-edge-app 安装器 - DeepSeek Harness Edge 应用" -ForegroundColor Cyan
Write-Host ""

# 1. Node.js
if (-not $SkipNode) {
    $nodeVer = Test-NodeVersion
    if (-not $nodeVer) {
        Write-Host "[1/5] 未检测到 Node.js，尝试 winget 安装 Node.js LTS ..." -ForegroundColor Yellow
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

# 2. 检查/安装 dsh（已安装且最新则跳过）
$local = Get-DshVersion
$latest = Get-LatestVersion
if (-not $local) {
    Write-Host "[2/5] 正在安装 DeepSeek Harness (@deepseek-ai/dsh) ..."
    if ((Update-Dsh -Quiet $false) -lt 0) {
        Write-Host "[错误] npm 安装 dsh 失败，请检查网络/npm 配置" -ForegroundColor Red
        exit 1
    }
}
elseif (-not $latest) {
    Write-Host "[2/5] [警告] 无法连接 npm 检查最新版，跳过（已安装: $local）" -ForegroundColor Yellow
}
elseif ($local -eq $latest) {
    Write-Host "[2/5] 已安装且是最新版 ($local)，跳过安装"
}
else {
    Write-Host "[2/5] 发现新版本: $local -> $latest，正在升级 ..."
    if ((Update-Dsh -Quiet $false) -lt 0) {
        Write-Host "[错误] npm 升级 dsh 失败，请检查网络/npm 配置" -ForegroundColor Red
        exit 1
    }
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
if (-not (Get-Command dsh -ErrorAction SilentlyContinue)) {
    Write-Host "[错误] 安装完成但找不到 dsh 命令，请重开终端后重试" -ForegroundColor Red
    exit 1
}
try { $dshVer = (& dsh --version 2>$null) } catch { $dshVer = "" }
Write-Host "[2/5] dsh 就绪: $dshVer"

# 3. 部署启动器 + 自身（供 -UpdateCheck 模式使用）
Write-Host "[3/5] 安装无窗口启动器与自动更新脚本 ..."
if (-not (Test-Path -LiteralPath $LauncherSrc)) {
    Write-Host "[错误] 缺少 launcher.vbs（请与 install.ps1 放在同一目录）" -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath $LauncherSrc -Destination $LauncherDst -Force
Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination (Join-Path $InstallDir "install.ps1") -Force

# 4. 后台启动 dsh web
Write-Host "[4/5] 后台启动 dsh web ..."
if (-not (Test-DshWeb)) {
    Start-DshWebBackground
    if (-not (Wait-DshWeb)) {
        Write-Host "[警告] dsh web 未就绪，继续安装（图标将用内置回退）" -ForegroundColor Yellow
    }
}

# 5. 官方图标 + 快捷方式 + 打开
Write-Host "[5/5] 提取官方图标并创建快捷方式 ..."
$edge = Get-MsEdgePath
if (-not $edge) {
    Write-Host "[错误] 未找到 Microsoft Edge，请先安装: https://www.microsoft.com/edge" -ForegroundColor Red
    exit 1
}
$icon = ""
if (New-OfficialIcon -OutIcoPath $IconDst) {
    $icon = $IconDst
    Write-Host "      图标: 已从 dsh web 自动提取官方 favicon"
}
else {
    Write-Host "      图标: 提取失败，使用默认图标（重新运行安装脚本可重试）" -ForegroundColor Yellow
}
$desktop = [Environment]::GetFolderPath('Desktop')
New-DshShortcut -Path (Join-Path $desktop $ShortcutName) -Icon $icon
New-DshShortcut -Path (Join-Path (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs") $ShortcutName) -Icon $icon

Start-Process -FilePath $Wscript -ArgumentList "`"$LauncherDst`""
Write-Host ""
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "  以后只点击桌面 '$ShortcutName' 即可: 后台更新 -> 启动 dsh web -> 打开 Edge 独立窗口" -ForegroundColor Green
Write-Host "  后台地址: $Url" -ForegroundColor Green
Write-Host ""