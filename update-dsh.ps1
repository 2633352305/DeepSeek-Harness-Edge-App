# ============================================================
# dsh-edge-app 自动更新检查（由 launcher.vbs 静默调用）
# - 限频：24 小时内最多检查一次（state 文件记录时间）
# - 有新版本时自动 npm 更新，无需任何操作
# - 全程静默无窗口，日志写入 update.log
# ============================================================
#Requires -Version 5.1

$ErrorActionPreference = "Continue"

$InstallDir     = Join-Path $env:LOCALAPPDATA "dsh-edge-app"
$StateFile      = Join-Path $InstallDir "update-state.txt"
$LogFile        = Join-Path $InstallDir "update.log"
$Pkg            = "@deepseek-ai/dsh"
$ThrottleHours  = 24

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

# ---------- 限频检查 ----------
$lastCheck = 0
if (Test-Path -LiteralPath $StateFile) {
    $line = Get-Content -LiteralPath $StateFile -TotalCount 1 -ErrorAction SilentlyContinue
    if ($line -match '^\d+') { $lastCheck = [long]$Matches[0] }
}
$nowEpoch = [long]((Get-Date).ToUniversalTime() - [datetime]::new(1970,1,1,0,0,0,[datetimekind]::Utc)).TotalSeconds
if (($nowEpoch - $lastCheck) -lt ($ThrottleHours * 3600)) { exit 0 }

# ---------- 获取最新版本 ----------
$latest = (& npm view $Pkg version 2>$null | Select-Object -Last 1)
if (-not $latest) { exit 0 }   # 网络/注册表不可用则跳过，不影响使用
$latest = $latest.Trim()

# ---------- 获取本地版本 ----------
$local = ""
$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if ($dsh) {
    try { $local = ((& dsh --version 2>$null) | Select-Object -Last 1).Trim() } catch {}
}
if (-not $local) { exit 0 }    # dsh 未安装则跳过（安装器负责）

# ---------- 有新版则更新 ----------
if ($local -ne $latest) {
    Write-Log "发现新版本: $local -> $latest，开始自动更新 ..."
    & npm install -g $Pkg 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $npmMajor = [int](((& npm --version 2>$null) -split "\.")[0])
        if ($npmMajor -ge 11) {
            & npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty $Pkg 2>&1 | Out-Null
        }
        Write-Log "自动更新成功: $latest"
    }
    else {
        Write-Log "自动更新失败 (npm exit $LASTEXITCODE)，继续使用当前版本"
    }
}

# ---------- 记录检查时间 ----------
Set-Content -LiteralPath $StateFile -Value ($nowEpoch.ToString())
exit 0