#Requires -Version 5.1
# dsh-edge-app 一键卸载: 停止服务 -> 删快捷方式 -> 删部署目录 -> npm 卸载 dsh
# 只删除程序与缓存，保留用户工作区/文档（如 dsh 工作目录、Agent 项目等）

$ErrorActionPreference = "Continue"

$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$AppName      = "DeepSeek Harness"
$ShortcutName = "DeepSeek Harness.lnk"
$InstallDir   = Join-Path $env:LOCALAPPDATA "dsh-edge-app"

Write-Host ""
Write-Host "  卸载 DeepSeek Harness ..." -ForegroundColor Yellow
Write-Host ""

# 1. 停止 dsh web（端口 3080）
$conn = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
    Write-Host "  [1/4] 已停止后台服务 (端口 3080)"
}
else {
    Write-Host "  [1/4] 后台服务未在运行"
}

# 2. 删除快捷方式
$paths = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $ShortcutName),
    (Join-Path (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs") $ShortcutName)
)
foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        Write-Host "  [2/4] 已删除快捷方式: $p"
    }
}
Write-Host "  [2/4] 快捷方式清理完成"

# 3. 删除部署目录（启动器/更新脚本/图标/日志，均为安装器生成；带重试与校验）
if (Test-Path -LiteralPath $InstallDir) {
    $removed = $false
    for ($i = 0; $i -lt 5; $i++) {
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $InstallDir)) { $removed = $true; break }
        Start-Sleep -Seconds 2
    }
    if ($removed) {
        Write-Host "  [3/4] 已删除安装目录: $InstallDir"
    }
    else {
        Write-Host "  [3/4] [警告] 安装目录被占用未能完全删除: $InstallDir（停止相关进程后重试，或手动删除）" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  [3/4] 安装目录不存在，跳过"
}

# 4. npm 卸载 dsh
Write-Host "  [4/4] 正在通过 npm 卸载 @deepseek-ai/dsh ..."
& npm uninstall -g @deepseek-ai/dsh 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [4/4] 已卸载 dsh"
}
else {
    Write-Host "  [4/4] [警告] npm 卸载失败 (exit $LASTEXITCODE)，可手动执行: npm uninstall -g @deepseek-ai/dsh" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  卸载完成！" -ForegroundColor Green
Write-Host "  已删除: dsh 程序、后台服务、快捷方式、安装目录与缓存" -ForegroundColor Green
Write-Host "  已保留: 用户工作区与文档（dsh 工作目录、Agent 项目、Node.js 等）" -ForegroundColor Green
Write-Host ""