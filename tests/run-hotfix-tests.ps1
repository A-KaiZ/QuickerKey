param([Parameter(Mandatory=$true)][string]$AutoHotkey)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = [IO.File]::ReadAllText((Join-Path $repo 'QuickerKeys.ahk'))
# Guard the supplied animated startup against accidental replacement by a static splash.
$logo = [regex]::Match($source, '(?s)(?m)^VisLogo\(\) \{.*?(?=^VisVelkommen\(\*\) \{)').Value
$required = @(
  'Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "QK-oppstart")',
  'SetTimer LogoSteg, 30',
  'LogoSteg() {',
  'Floor(t / 65) + 1',
  'L.linje.Move((L.W - lb) // 2, , lb)',
  'L.under.Text := "by MAAUNI and KAISAD"',
  'WinSetTransparent a, "ahk_id " L.g.Hwnd',
  'LogoKlikk(wParam, lParam, msg, hwnd)',
  'OnMessage(0x201, LogoKlikk, 0)',
  'ko := LOGO_KO, LOGO_KO := []'
)
foreach ($expected in $required) {
  if (!$logo.Contains($expected)) { throw "Animated-logo regression: missing [$expected]" }
}
if (!$source.Contains('EtterLogo(VisHoved)')) { throw 'Startup GUI no longer waits for logo completion' }
Write-Host 'PASS animated startup source contract'

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
