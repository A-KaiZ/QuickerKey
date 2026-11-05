param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
& (Join-Path $PSScriptRoot 'build.ps1') -OutputDirectory (Join-Path $OutputDirectory 'TrioOCR')
Copy-Item (Join-Path $repo 'QuickerKeys.ahk') $OutputDirectory -Force
Copy-Item (Join-Path $PSScriptRoot 'README.md') (Join-Path $OutputDirectory 'README.md') -Force
$sourceRoot = Join-Path $OutputDirectory 'TrioOCR/source'
Copy-Item (Join-Path $repo 'QuickerKeys.ahk'),(Join-Path $repo 'README.md') $sourceRoot -Force
Copy-Item (Join-Path $repo 'tests') $sourceRoot -Recurse -Force
$sourceDocs = Join-Path $sourceRoot 'docs'
New-Item -ItemType Directory -Force -Path $sourceDocs | Out-Null
Copy-Item (Join-Path $repo 'docs/QA-trio-ocr-v3.13.md') $sourceDocs -Force
$runtime = Join-Path $OutputDirectory 'Runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$ahkZip = Join-Path $env:TEMP 'quickerkeys-ahk-v2.0.19.zip'
if (!(Test-Path $ahkZip)) { Invoke-WebRequest 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip' -OutFile $ahkZip }
if ((Get-FileHash $ahkZip -Algorithm SHA256).Hash -ne '4E0D0E65655066A646A210951320FEAEF0729A3597177131ADAEC4066BEF5869') { throw 'AutoHotkey runtime digest mismatch.' }
Expand-Archive $ahkZip $runtime -Force
foreach ($name in @('Start-QuickerKeys.cmd','Start-QuickerKeys-Diagnose.cmd')) {
    $text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $name)).Replace("`r`n", "`n").Replace("`n", "`r`n")
    [IO.File]::WriteAllText((Join-Path $OutputDirectory $name), $text, [Text.Encoding]::ASCII)
}
[IO.File]::WriteAllLines((Join-Path $OutputDirectory 'FILES.sha256'), @(Get-ChildItem $OutputDirectory -Recurse -File | Where-Object Name -ne 'FILES.sha256' | Sort-Object FullName | ForEach-Object {
    (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($OutputDirectory.TrimEnd('\','/').Length + 1).Replace('\','/')
}))
Write-Output 'Built QuickerKeys 3.13-sandbox1 with local OCR test and pinned AHK runtime.'
