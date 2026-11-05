param([Parameter(Mandatory=$true)][string]$Package, [Parameter(Mandatory=$true)][string]$AutoHotkey)
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
    [DllImport("shell32.dll")] public static extern void SHChangeNotify(int value, uint flags, IntPtr first, IntPtr second);
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
function Invoke-Launch([string]$Directory, [bool]$Document, [bool]$ExpectWindow) {
    $info = if ($Document) {
        [Diagnostics.ProcessStartInfo]::new((Join-Path $Directory 'QuickerKeys.ahk'))
    } else {
        [Diagnostics.ProcessStartInfo]::new($env:ComSpec, ('/d /c ""' + (Join-Path $Directory 'Start-QuickerKeys.cmd') + '""'))
    }
    $info.UseShellExecute = $Document
    $info.WorkingDirectory = $Directory
    if (!$Document) {
        $info.CreateNoWindow = $true
        $info.RedirectStandardInput = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
    }
    $process = [Diagnostics.Process]::Start($info)
    if (!$Document) {
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Close()
    }
    $found = $false
    try {
        if ($ExpectWindow) {
            $timer = [Diagnostics.Stopwatch]::StartNew()
            while ($timer.Elapsed.TotalSeconds -lt 30) {
                $appPid = [QuickerKeysLaunchWindow]::Find()
                if ($appPid -gt 0) {
                    $candidate = Get-Process -Id $appPid -ErrorAction SilentlyContinue
                    if ($candidate -and $candidate.Path -eq $AutoHotkey) { $found = $true; break }
                }
                Start-Sleep -Milliseconds 100
            }
        }
    } finally {
        Get-Process -Name AutoHotkey64 -ErrorAction SilentlyContinue | Where-Object Path -eq $AutoHotkey | Stop-Process -Force
        if ($process -and !$process.WaitForExit(10000)) { $process.Kill($true); throw 'Launcher did not return after app exit.' }
    }
    try {
        return [PSCustomObject]@{ Window = $found; Code = $(if ($process) { $process.ExitCode } else { 0 });
            Output = $(if ($Document) { '' } else { $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult() }) }
    } finally { if ($process) { $process.Dispose() } }
}
$temp = Join-Path $env:TEMP ('quickerkeys-launcher-' + [Guid]::NewGuid())
$progId = 'QuickerKeys.CI.' + [Guid]::NewGuid().ToString('N')
$classes = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes')
$extension = $classes.OpenSubKey('.ahk', $true)
$hadExtension = $null -ne $extension
$oldDefault = if ($extension) { $extension.GetValue('') } else { $null }
$oldKind = if ($null -ne $oldDefault) { $extension.GetValueKind('') } else { $null }
try {
    # Isolated CI user only: stand in for an existing, configured AutoHotkey association.
    # No association is installed or modified by the user package or its launcher.
    if (!$extension) { $extension = $classes.CreateSubKey('.ahk') }
    $command = $classes.CreateSubKey($progId + '\shell\open\command')
    try { $command.SetValue('', ('"' + $AutoHotkey + '" "%1" %*')) } finally { $command.Dispose() }
    $extension.SetValue('', $progId)
    [QuickerKeysLaunchWindow]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    $full = Join-Path $temp 'pakke med mellomrom ! & (ø)'
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    Copy-Item (Join-Path $Package '*') $full -Recurse
    Require (!(Test-Path (Join-Path $full 'Runtime'))) 'user package does not contain a second AutoHotkey runtime'
    $direct = Invoke-Launch $full $true $true
    Require $direct.Window 'opening the main AHK script through its registered application starts the actual GUI'
    $normal = Invoke-Launch $full $false $true
    Require ($normal.Window -and $normal.Code -eq 0) ('optional CMD uses the same association without a bundled runtime: ' + $normal.Output)
    Require (@(Get-Process -Name TrioOcrProbe,TrioCaptureProbe -ErrorAction SilentlyContinue).Count -eq 0) 'normal startup never launches an OCR or capture helper'
    Remove-Item (Join-Path $full 'QuickerKeys.ahk')
    $missing = Invoke-Launch $full $false $false
    Require ($missing.Code -eq 2 -and $missing.Output.Contains('QK_STARTUP MISSING_SCRIPT')) 'missing script is reported without trying an alternate executable'
} finally {
    if ($null -ne $oldDefault) { $extension.SetValue('', $oldDefault, $oldKind) } else { $extension.DeleteValue('', $false) }
    $extension.Dispose()
    if (!$hadExtension) { $classes.DeleteSubKeyTree('.ahk', $false) }
    $classes.DeleteSubKeyTree($progId, $false); $classes.Dispose()
    [QuickerKeysLaunchWindow]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
