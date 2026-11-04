param([Parameter(Mandatory=$true)][string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = [IO.File]::ReadAllText((Join-Path $repo 'QuickerKeys.ahk'))
$marker = 'OnError(FeilFanger)'
if (($source.Split($marker).Count - 1) -ne 1) { throw 'App startup marker changed' }
$source = $source.Replace($marker, "RunTrioTests()`r`nExitApp 99`r`n" + $marker)
$source += "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'trio-reader-tests.ahk'))
$temp = Join-Path ([IO.Path]::GetTempPath()) ('quickerkeys-tests-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $script = Join-Path $temp 'trio-tests.ahk'
    [IO.File]::WriteAllText($script, $source, [Text.UTF8Encoding]::new($true))
    Copy-Item (Join-Path $PSScriptRoot 'trio-fixture.ahk') $temp
    [IO.File]::WriteAllText((Join-Path $temp 'trio-winforms-fixture.ps1'), [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'trio-winforms-fixture.ps1')), [Text.UTF8Encoding]::new($true))
    $proc = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $script + '"')) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $temp 'stdout.txt') -RedirectStandardError (Join-Path $temp 'stderr.txt')
    if (!$proc.WaitForExit(90000)) { $proc.Kill(); throw 'AHK test timed out' }
    Get-Content (Join-Path $temp 'stdout.txt') -ErrorAction SilentlyContinue
    Get-Content (Join-Path $temp 'stderr.txt') -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) { throw "AHK tests exited $($proc.ExitCode)" }
} finally {
    Remove-Item $temp -Recurse -Force
}
