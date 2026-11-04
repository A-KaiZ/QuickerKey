param([Parameter(Mandatory=$true)][string]$Probe)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$wpf = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/WPF'
$temp = Join-Path $env:TEMP ('quickerkeys-ocr-tests-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $fixtures = @()
    foreach ($arch in @('x86','x64')) {
        $fixture = Join-Path $temp ("TrioOcrFixture-$arch.exe")
        & $compiler /nologo /target:winexe "/platform:$arch" /codepage:65001 /warnaserror+ "/out:$fixture" /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'Fixture.cs')
        if ($LASTEXITCODE -ne 0) { throw 'OCR fixture compilation failed.' }
        $fixtures += $fixture
    }
    $testExe = Join-Path (Split-Path $Probe -Parent) 'TrioOcrTests.exe'
    $echoExe = Join-Path $temp 'TrioOcrBinaryEcho.exe'
    & $compiler /nologo /target:exe /platform:x64 /warnaserror+ "/out:$echoExe" (Join-Path $PSScriptRoot 'BinaryEcho.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Binary echo compilation failed.' }
    & $compiler /nologo /target:exe /platform:x64 /codepage:65001 /warnaserror+ "/out:$testExe" "/reference:$Probe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/reference:$wpf/UIAutomationClient.dll" "/reference:$wpf/UIAutomationTypes.dll" "/reference:$wpf/WindowsBase.dll" (Join-Path $PSScriptRoot 'Tests.cs')
    if ($LASTEXITCODE -ne 0) { throw 'OCR tests compilation failed.' }
    & $testExe $Probe (Join-Path (Split-Path $Probe -Parent) 'ocr') $echoExe @fixtures
    if ($LASTEXITCODE -ne 0) { throw 'OCR tests failed.' }
} finally {
    Remove-Item $temp -Force -Recurse -ErrorAction SilentlyContinue
    if ($testExe -and (Test-Path $testExe)) { Remove-Item $testExe -Force }
}
