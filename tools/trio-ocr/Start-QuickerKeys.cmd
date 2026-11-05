@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0"
if errorlevel 1 goto directory_failed
if not exist "Runtime\AutoHotkey64.exe" goto runtime_missing
if not exist "QuickerKeys.ahk" goto script_missing
start "" "%~dp0Runtime\AutoHotkey64.exe" "%~dp0QuickerKeys.ahk"
if errorlevel 1 goto launch_failed
popd
exit /b 0

:runtime_missing
echo QK_STARTUP MISSING_RUNTIME
echo Runtime\AutoHotkey64.exe is missing. Extract the entire package first.
goto failed

:script_missing
echo QK_STARTUP MISSING_SCRIPT
echo QuickerKeys.ahk is missing. Keep this file in the package root folder.
goto failed

:launch_failed
echo QK_STARTUP LAUNCH_FAILED
echo Windows did not start AutoHotkey. See the Windows message or contact IT.
goto failed

:directory_failed
echo QK_STARTUP DIRECTORY_FAILED
echo Cannot access the package folder.
pause
exit /b 2

:failed
echo For a visible startup trace, use Start-QuickerKeys-Diagnose.cmd.
pause
popd
exit /b 2
