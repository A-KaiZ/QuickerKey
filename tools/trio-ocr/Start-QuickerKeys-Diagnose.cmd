@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
pushd "%~dp0"
if errorlevel 1 goto directory_failed
if not exist "Runtime\AutoHotkey64.exe" goto runtime_missing
if not exist "QuickerKeys.ahk" goto script_missing
echo QK_STARTUP launching-bundled-runtime
echo This window stays open while QuickerKeys runs.
echo If no app window appears, report the last QK_STARTUP line and any Windows message.
echo No OCR helper is started by this diagnostic.
"%~dp0Runtime\AutoHotkey64.exe" /ErrorStdOut=UTF-8 "%~dp0QuickerKeys.ahk" /startup-diagnostic
set "QK_START_EXIT=%errorlevel%"
echo.
echo QK_STARTUP PROCESS_EXIT %QK_START_EXIT%
echo The app process has ended. A Windows block is not proof of a missing .NET runtime.
goto finished

:runtime_missing
echo QK_STARTUP MISSING_RUNTIME
echo Runtime\AutoHotkey64.exe is missing. Extract the entire package first.
set "QK_START_EXIT=2"
goto finished

:script_missing
echo QK_STARTUP MISSING_SCRIPT
echo QuickerKeys.ahk is missing. Keep this file in the package root folder.
set "QK_START_EXIT=2"
goto finished

:directory_failed
echo QK_STARTUP DIRECTORY_FAILED
echo Cannot access the package folder.
pause
exit /b 2

:finished
pause
popd
exit /b %QK_START_EXIT%
