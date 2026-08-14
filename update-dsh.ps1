#Requires -Version 5.1
# dsh-edge-app 后台自动更新检查（launcher.vbs 异步调用）
# 24h 限频; 失败重试 3 次, 每次间隔 3 秒; 有新版自动 npm 更新

$ErrorActionPreference = "Continue"

$InstallDir    = Join-Path $env:LOCALAPPDATA "dsh-edge-app"
$StateFile     = Join-Path $InstallDir "update-state.txt"
$LogFile       = Join-Path $InstallDir "update.log"
$LockFile      = Join-Path $InstallDir "update.lock"
$Pkg           = "@deepseek-ai/dsh"
$ThrottleHours = 24

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

$lock = $null
try {
    $lock = New-Object System.IO.FileStream($LockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch {
    exit 0
}

try {

$lastCheck = 0
if (Test-Path -LiteralPath $StateFile) {
    $line = Get-Content -LiteralPath $StateFile -TotalCount 1 -ErrorAction SilentlyContinue
    if ($line -match '^\d+') { $lastCheck = [long]$Matches[0] }
}
$nowEpoch = [long]((Get-Date).ToUniversalTime() - [datetime]::new(1970,1,1,0,0,0,[datetimekind]::Utc)).TotalSeconds
if (($nowEpoch - $lastCheck) -lt ($ThrottleHours * 3600)) { exit 0 }

$latest = ""
for ($attempt = 1; $attempt -le 3 -and -not $latest; $attempt++) {
    $latest = (& npm view $Pkg version 2>$null | Select-Object -Last 1)
    if ($latest) {
        $latest = $latest.Trim()
        break
    }
    if ($attempt -lt 3) {
        Write-Log "检查 npm 最新版失败（第 $attempt 次），3 秒后重试"
        Start-Sleep -Seconds 3
    }
}
if (-not $latest) {
    Write-Log "3 次检查 npm 最新版均失败，跳过本次更新检查"
    exit 0
}

$local = ""
$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if ($dsh) {
    try { $local = ((& dsh --version 2>$null) | Select-Object -Last 1).Trim() } catch {}
}
if (-not $local) { exit 0 }

if ($local -ne $latest) {
    for ($i = 0; $i -lt 90; $i++) {
        if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) { break }
        Start-Sleep -Seconds 1
    }
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

Set-Content -LiteralPath $StateFile -Value ($nowEpoch.ToString())

}

finally {
    if ($lock) { $lock.Dispose() }
    Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
}
exit 0