param([Parameter(Mandatory=$true)][string]$OutputDirectory)
# Build/test machine only. This runtime is not included in the user package.
$ErrorActionPreference = 'Stop'
$archive = Join-Path $env:TEMP 'quickerkeys-ahk-v2.0.19.zip'
if (!(Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip' -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne '4E0D0E65655066A646A210951320FEAEF0729A3597177131ADAEC4066BEF5869') {
    throw 'AutoHotkey test runtime digest mismatch.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Expand-Archive $archive $OutputDirectory -Force
if (!(Test-Path (Join-Path $OutputDirectory 'AutoHotkey64.exe'))) { throw 'Missing test runtime.' }
