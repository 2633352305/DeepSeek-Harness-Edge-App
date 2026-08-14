@echo off
rem dsh-edge-app 一键安装（双击运行）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo 安装失败，请查看上方错误信息。
  pause
)