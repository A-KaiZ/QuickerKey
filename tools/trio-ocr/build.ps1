param([Parameter(Mandatory=$true)][string]$OutputDirectory,[switch]$SkipEngine)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
& (Join-Path $repo 'tools/trio-capture/build.ps1') -OutputDirectory $OutputDirectory
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$wpf = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/WPF'
$exe = Join-Path $OutputDirectory 'TrioOcrProbe.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 /warnaserror+ /main:QuickerKeys.Ocr.OcrProgram "/out:$exe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/reference:$wpf/UIAutomationClient.dll" "/reference:$wpf/UIAutomationTypes.dll" "/reference:$wpf/WindowsBase.dll" "/win32manifest:$(Join-Path $repo 'tools/trio-capture/app.manifest')" (Join-Path $repo 'tools/trio-capture/TrioCaptureProbe.cs') (Join-Path $PSScriptRoot 'TrioOcr.cs') (Join-Path $PSScriptRoot 'TrioOcrProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'OCR probe compilation failed.' }
Copy-Item (Join-Path $OutputDirectory 'TrioCaptureProbe.exe.config') ($exe + '.config') -Force
$source = Join-Path $OutputDirectory 'source/ocr'
New-Item -ItemType Directory -Force -Path $source | Out-Null
Copy-Item (Join-Path $PSScriptRoot '*.cs'),(Join-Path $PSScriptRoot '*.ps1') $source -Force
Copy-Item (Join-Path $PSScriptRoot 'README.md') (Join-Path $OutputDirectory 'OCR-README.md') -Force
foreach ($module in @('trio-capture','trio-ocr')) {
    $moduleSource = Join-Path $OutputDirectory ("source/tools/$module")
    New-Item -ItemType Directory -Force -Path $moduleSource | Out-Null
    Copy-Item (Join-Path $repo "tools/$module/*") $moduleSource -Force -Recurse
}
if (!$SkipEngine) { & (Join-Path $PSScriptRoot 'prepare-engine.ps1') -OutputDirectory (Join-Path $OutputDirectory 'ocr') }
Write-Output 'Built local OCR probe P1.0.'
