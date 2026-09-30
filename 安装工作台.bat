@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
pushd "%~dp0"
if errorlevel 1 goto folder_error
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\install_windows.ps1" -Mode Install
set "STUDIO_EXIT=%errorlevel%"
popd
if not "%STUDIO_EXIT%"=="0" echo Installation stopped. Please keep install.log and the logs folder.
pause
exit /b %STUDIO_EXIT%
:folder_error
echo Cannot open the workbench folder. Please fully extract the ZIP first.
pause
exit /b 1
