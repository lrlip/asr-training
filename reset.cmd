@echo off
rem Double-click this file to choose which training sessions to remove, clone again and set up;
rem reset1.cmd, reset2.cmd and resetall.cmd skip the choice. It runs reset.ps1 next to it with the
rem execution policy bypassed for this run only and keeps the window open so the messages stay
rem readable.
setlocal
set "RESET_DIRECTORY=%~dp0"
set "RESET_SCRIPT=%~dp0reset.ps1"

rem Explorer runs a .cmd straight from a zip in a temporary folder, without the files next to it.
if not exist "%RESET_SCRIPT%" (
  echo reset.ps1 is not next to this file. If you opened the zip, extract it first:
  echo right-click the zip, choose Extract All, and double-click reset.cmd in the extracted folder.
  echo Press any key to close this window.
  pause >nul
  exit /b 1
)

rem Files from a downloaded zip carry the Mark of the Web, which a RemoteSigned policy refuses to run.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:RESET_DIRECTORY -File -Filter *.ps1 -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RESET_SCRIPT%" %*
set "RESET_EXIT_CODE=%ERRORLEVEL%"

echo.
if "%RESET_EXIT_CODE%"=="0" (
  echo Reset finished. Press any key to close this window.
) else (
  echo Reset did not finish. Read the messages above.
  echo Press any key to close this window.
)
pause >nul
exit /b %RESET_EXIT_CODE%
