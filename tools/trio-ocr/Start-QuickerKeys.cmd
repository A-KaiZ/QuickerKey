@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0"
if errorlevel 1 goto directory_failed
if not exist "QuickerKeys.ahk" goto script_missing
rem Use the existing Windows association. Do not invoke a bundled or alternate EXE.
start "" "%~dp0QuickerKeys.ahk"
if errorlevel 1 goto launch_failed
popd
exit /b 0

:script_missing
echo QK_STARTUP MISSING_SCRIPT
echo QuickerKeys.ahk is missing. Keep this file in the package root folder.
goto failed

:launch_failed
echo QK_STARTUP LAUNCH_FAILED
echo Windows could not open QuickerKeys.ahk through its registered application.
echo Open the script using your usual managed AutoHotkey v2 application.
goto failed

:directory_failed
echo QK_STARTUP DIRECTORY_FAILED
echo Cannot access the package folder.
pause
exit /b 2

:failed
pause
popd
exit /b 2
