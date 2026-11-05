param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Test-Path (Join-Path $OutputDirectory 'Runtime')) { throw 'Old bundled runtime found. Build into a new output folder.' }
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
$text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Start-QuickerKeys.cmd')).Replace("`r`n", "`n").Replace("`n", "`r`n")
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'Start-QuickerKeys.cmd'), $text, [Text.Encoding]::ASCII)
[IO.File]::WriteAllLines((Join-Path $OutputDirectory 'FILES.sha256'), @(Get-ChildItem $OutputDirectory -Recurse -File | Where-Object Name -ne 'FILES.sha256' | Sort-Object FullName | ForEach-Object {
    (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($OutputDirectory.TrimEnd('\','/').Length + 1).Replace('\','/')
}))
Write-Output 'Built QuickerKeys 3.13-sandbox1 with local OCR test; opens through the existing AutoHotkey association.'
