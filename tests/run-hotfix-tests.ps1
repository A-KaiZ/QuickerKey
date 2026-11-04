param([Parameter(Mandatory=$true)][string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = [IO.File]::ReadAllText((Join-Path $repo 'QuickerKeys.ahk'))
$marker = 'OnError(FeilFanger)'
if (($source.Split($marker).Count - 1) -ne 1) { throw 'App startup marker changed' }
$source = $source.Replace($marker, "RunHotfixTests()`r`nExitApp 99`r`n" + $marker)
$source += "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'hotfix-tests.ahk'))
$temp = Join-Path ([IO.Path]::GetTempPath()) ('quickerkeys-hotfix-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $script = Join-Path $temp 'hotfix-tests.ahk'
    [IO.File]::WriteAllText($script, $source, [Text.UTF8Encoding]::new($true))
    Copy-Item (Join-Path $PSScriptRoot 'hotfix-fixture.ahk') $temp
    Copy-Item (Join-Path $PSScriptRoot 'hotfix-capture.ps1') $temp
    $proc = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $script + '"')) -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $temp 'stdout.txt') -RedirectStandardError (Join-Path $temp 'stderr.txt')
    if (!$proc.WaitForExit(90000)) { $proc.Kill(); throw 'AHK test timed out' }
    Get-Content (Join-Path $temp 'stdout.txt') -ErrorAction SilentlyContinue
    Get-Content (Join-Path $temp 'stderr.txt') -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) { throw "AHK tests exited $($proc.ExitCode)" }
} finally {
    $output = Join-Path $PSScriptRoot 'output'
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    Get-ChildItem $temp -Filter '*.png' | Copy-Item -Destination $output
    Remove-Item $temp -Recurse -Force
}
