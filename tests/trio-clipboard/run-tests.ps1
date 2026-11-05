param([Parameter(Mandatory=$true)][string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source = [IO.File]::ReadAllText((Join-Path $repo 'tools/trio-clipboard/QuickerKeys-Kopieringstest.ahk'))
$marker = '; CLIPBOARD_PROBE_START'
if (($source.Split($marker).Count - 1) -ne 1) { throw 'Clipboard probe startup marker changed.' }
$source = $source.Replace($marker, "RunClipboardProbeTests()`r`nExitApp 99`r`n" + $marker)
$source += "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Tests.ahk'))
$temp = Join-Path $env:TEMP ('quickerkeys-copy-probe-tests-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $script = Join-Path $temp 'Tests.ahk'
    [IO.File]::WriteAllText($script, $source, [Text.UTF8Encoding]::new($true))
    $process = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $script + '"')) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $temp 'stdout.txt') -RedirectStandardError (Join-Path $temp 'stderr.txt')
    if (!$process.WaitForExit(30000)) { $process.Kill(); throw 'Clipboard probe tests timed out.' }
    Get-Content (Join-Path $temp 'stdout.txt') -ErrorAction SilentlyContinue
    Get-Content (Join-Path $temp 'stderr.txt') -ErrorAction SilentlyContinue
    if ($process.ExitCode -ne 0) { throw "Clipboard probe tests exited $($process.ExitCode)." }
} finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
