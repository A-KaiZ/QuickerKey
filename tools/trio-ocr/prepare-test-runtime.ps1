param([Parameter(Mandatory=$true)][string]$OutputDirectory)
# Build/test machine only. This runtime is not included in the user package.
$ErrorActionPreference = 'Stop'
$archive = Join-Path $env:TEMP 'quickerkeys-ahk-v2.0.21.zip'
if (!(Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.21/AutoHotkey_2.0.21.zip' -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne '7386F45BE928F0825FFBE78811187636D72EFCBD264E2FD406E7E045D681A626') {
    throw 'AutoHotkey test runtime digest mismatch.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Expand-Archive $archive $OutputDirectory -Force
if (!(Test-Path (Join-Path $OutputDirectory 'AutoHotkey64.exe'))) { throw 'Missing test runtime.' }
