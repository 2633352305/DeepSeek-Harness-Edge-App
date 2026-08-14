@echo off
rem dsh-edge-app 双击安装（自动：装 Node.js -> 装 dsh -> 创建鲸鱼图标快捷方式 -> 启动）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo 安装失败，请查看上方错误信息。
  pause
)