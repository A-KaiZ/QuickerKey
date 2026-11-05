param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class QuickerKeysLaunchWindow {
    private delegate bool Callback(IntPtr window, IntPtr unused);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr unused);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    public static int Find() {
        int process = 0;
        EnumWindows(delegate(IntPtr window, IntPtr unused) {
            StringBuilder text = new StringBuilder(200); GetWindowText(window, text, text.Capacity);
            if (IsWindowVisible(window) && text.ToString() == "QuickerKeys") {
                uint found; GetWindowThreadProcessId(window, out found); process = (int)found; return false;
            }
            return true;
        }, IntPtr.Zero);
        return process;
    }
}
'@
function Require([bool]$Value, [string]$Label) {
    if (!$Value) { throw $Label }
    Write-Host "PASS $Label"
}
function Invoke-Launcher([string]$Directory, [string]$File, [bool]$ExpectWindow) {
    $runtime = Join-Path $Directory 'Runtime/AutoHotkey64.exe'
    $info = [Diagnostics.ProcessStartInfo]::new($env:ComSpec, ('/d /c ""' + (Join-Path $Directory $File) + '""'))
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Close() # Let PAUSE finish after a failure in this noninteractive test.
    $found = $false
    try {
        if ($ExpectWindow) {
            $timer = [Diagnostics.Stopwatch]::StartNew()
            while ($timer.Elapsed.TotalSeconds -lt 30) {
                $appPid = [QuickerKeysLaunchWindow]::Find()
                if ($appPid -gt 0) {
                    $candidate = Get-Process -Id $appPid -ErrorAction SilentlyContinue
                    if ($candidate -and $candidate.Path -eq $runtime) { $found = $true; break }
                }
                Start-Sleep -Milliseconds 100
            }
            Start-Sleep -Milliseconds 300
        }
    } finally {
        Get-Process -Name AutoHotkey64 -ErrorAction SilentlyContinue | Where-Object Path -eq $runtime | Stop-Process -Force
        if (!$process.WaitForExit(10000)) { $process.Kill($true); throw 'Launcher did not return after app exit.' }
    }
    try {
        return [PSCustomObject]@{ Window = $found; Code = $process.ExitCode; Output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult() }
    } finally { $process.Dispose() }
}
$temp = Join-Path $env:TEMP ('quickerkeys-launcher-' + [Guid]::NewGuid())
try {
    $full = Join-Path $temp 'pakke med mellomrom ! & (ø)'
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    Copy-Item (Join-Path $Package '*') $full -Recurse
    $normal = Invoke-Launcher $full 'Start-QuickerKeys.cmd' $true
    $extra = ''
    if (!$normal.Window) { $extra = (Invoke-Launcher $full 'Start-QuickerKeys-Diagnose.cmd' $true).Output }
    Require ($normal.Window -and $normal.Code -eq 0) ('normal CMD starts the real unmodified app from a special-character path: ' + $normal.Output + $extra)

    $settings = Join-Path $env:APPDATA 'QuickerKeysSandbox313/Innstillinger/QuickerKeys.ini'
    [IO.File]::WriteAllText($settings, "[App]`r`nStartSkjult=1`r`nLogo=0`r`n")
    $diagnostic = Invoke-Launcher $full 'Start-QuickerKeys-Diagnose.cmd' $true
    Require ($diagnostic.Window -and $diagnostic.Output.Contains('QK_STARTUP window-shown')) ('diagnostic launches the real app and reveals a hidden main window: ' + $diagnostic.Output)

    $broken = Join-Path $temp 'incomplete package'
    New-Item -ItemType Directory -Path $broken | Out-Null
    Copy-Item (Join-Path $full 'Start-QuickerKeys*.cmd') $broken
    Copy-Item (Join-Path $full 'QuickerKeys.ahk') $broken
    $missing = Invoke-Launcher $broken 'Start-QuickerKeys-Diagnose.cmd' $false
    Require ($missing.Code -eq 2 -and $missing.Output.Contains('QK_STARTUP MISSING_RUNTIME')) 'missing bundled runtime is reported before launch'
    $missingNormal = Invoke-Launcher $broken 'Start-QuickerKeys.cmd' $false
    Require ($missingNormal.Code -eq 2 -and $missingNormal.Output.Contains('QK_STARTUP MISSING_RUNTIME')) 'normal launcher reports an incomplete extraction'
    Copy-Item (Join-Path $full 'Runtime') $broken -Recurse
    Remove-Item (Join-Path $broken 'QuickerKeys.ahk')
    $missingScript = Invoke-Launcher $broken 'Start-QuickerKeys-Diagnose.cmd' $false
    Require ($missingScript.Code -eq 2 -and $missingScript.Output.Contains('QK_STARTUP MISSING_SCRIPT')) 'missing main script is distinguished from a runtime failure'

    [IO.File]::WriteAllText((Join-Path $broken 'QuickerKeys.ahk'), "#Requires AutoHotkey v2.0`r`nif (`r`n")
    $syntax = Invoke-Launcher $broken 'Start-QuickerKeys-Diagnose.cmd' $false
    Require ($syntax.Code -ne 0 -and $syntax.Output.Contains('Error:') -and $syntax.Output.Contains('QK_STARTUP PROCESS_EXIT')) 'AutoHotkey syntax errors and process exit are visible in the diagnostic'

    $app = [IO.File]::ReadAllText((Join-Path $full 'QuickerKeys.ahk'))
    $app = $app.Replace('global APP_NAVN    :=', "throw OSError(5)`r`nglobal APP_NAVN    :=")
    [IO.File]::WriteAllText((Join-Path $broken 'QuickerKeys.ahk'), $app, [Text.UTF8Encoding]::new($true))
    $runtimeFailure = Invoke-Launcher $broken 'Start-QuickerKeys-Diagnose.cmd' $false
    Require ($runtimeFailure.Code -eq 1 -and $runtimeFailure.Output.Contains('QK_STARTUP ERROR type=OSError') -and $runtimeFailure.Output.Contains('win32=5')) 'startup runtime errors report their type, line and Windows code before normal logging is ready'
    Require (@(Get-Process -Name TrioOcrProbe,TrioCaptureProbe -ErrorAction SilentlyContinue).Count -eq 0) 'startup diagnosis never starts an OCR or capture helper'
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
