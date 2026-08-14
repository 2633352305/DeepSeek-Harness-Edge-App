#Requires -Version 5.1
# dsh-edge-app: 每次打开时检查 dsh 最新版，有新版自动更新（launcher.vbs 异步调用，无窗口）

$ErrorActionPreference = "Continue"

$InstallDir = Join-Path $env:LOCALAPPDATA "dsh-edge-app"
$LockFile   = Join-Path $InstallDir "update.lock"
$Pkg        = "@deepseek-ai/dsh"

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

$lock = $null
try {
    $lock = New-Object System.IO.FileStream($LockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
}
catch {
    exit 0
}

try {

$latest = ((& npm view $Pkg version 2>$null) | Select-Object -Last 1)
if ($latest) { $latest = $latest.Trim() }
if (-not $latest) { exit 0 }

$local = ""
$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if ($dsh) {
    try { $local = ((& dsh --version 2>$null) | Select-Object -Last 1).Trim() } catch {}
}
if (-not $local -or $local -eq $latest) { exit 0 }

for ($i = 0; $i -lt 90; $i++) {
    if (Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue) { break }
    Start-Sleep -Seconds 1
}
& npm install -g $Pkg 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    $npmMajor = [int](((& npm --version 2>$null) -split "\.")[0])
    if ($npmMajor -ge 11) {
        & npm install -g --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty $Pkg 2>&1 | Out-Null
    }
}

}

finally {
    if ($lock) { $lock.Dispose() }
    Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
}
exit 0