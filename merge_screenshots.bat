@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%merge_screenshots.ps1"

if not exist "%PS1%" (
  echo [ERROR] merge_screenshots.ps1 not found: %PS1%
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo [ERROR] Merge failed. ErrorLevel=%RC%
  exit /b %RC%
)

echo [OK] Merge and archive completed.
exit /b 0
