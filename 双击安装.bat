@echo off
rem ============================================
rem  DeepSeek Harness Edge App - One-click installer
rem  Requires: Windows 10/11 with Microsoft Edge
rem ============================================
setlocal
echo.
echo [dsh-edge-app] Installing DeepSeek Harness as an Edge desktop app...
echo [dsh-edge-app] If a PowerShell window opens below, let it finish (1-3 minutes).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set RESULT=%ERRORLEVEL%
echo.
if %RESULT%==0 (
    echo [OK] Install finished. Shortcuts were created on Desktop and Start Menu.
) else (
    echo [FAIL] Install failed with code %RESULT%. See the error messages above.
)
echo.
pause