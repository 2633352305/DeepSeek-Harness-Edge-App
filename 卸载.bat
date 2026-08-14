@echo off
chcp 65001 >nul
rem ============================================
rem  DeepSeek Harness Edge App - One-click uninstaller
rem  Removes: dsh program, background service, shortcuts,
rem  install dir and caches. Keeps: your workspace/docs.
rem ============================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
set RESULT=%ERRORLEVEL%
echo.
if %RESULT%==0 (
    echo [OK] Uninstall finished. Your workspace files are untouched.
) else (
    echo [FAIL] Uninstall failed with code %RESULT%. See the error messages above.
)
echo.
pause