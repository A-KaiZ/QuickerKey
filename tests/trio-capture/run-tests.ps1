param([Parameter(Mandatory=$true)][string]$Probe)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('quickerkeys-capture-tests-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $testDirectory | Out-Null
try {
    $fixtures = @()
    foreach ($arch in @('x86','x64')) {
        $fixture = Join-Path $testDirectory ("TrioCaptureFixture-$arch.exe")
        & $compiler /nologo /target:winexe "/platform:$arch" /codepage:65001 /warnaserror+ "/out:$fixture" /reference:System.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'Fixture.cs')
        if ($LASTEXITCODE -ne 0) { throw "Fixture compilation failed ($arch)." }
        $fixtures += $fixture
    }
    $testExe = Join-Path (Split-Path $Probe -Parent) 'TrioCaptureTests.exe'
    $stalledWorker = Join-Path $testDirectory 'TrioCaptureStalledWorker.exe'
    & $compiler /nologo /target:exe /platform:x64 /warnaserror+ "/out:$stalledWorker" (Join-Path $PSScriptRoot 'StalledWorker.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Stalled worker compilation failed.' }
    & $compiler /nologo /target:exe /platform:x64 /codepage:65001 /warnaserror+ "/out:$testExe" "/reference:$Probe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'Tests.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Capture tests compilation failed.' }
    & $testExe $Probe $stalledWorker @fixtures
    if ($LASTEXITCODE -ne 0) { throw 'Capture tests failed.' }
} finally {
    Remove-Item $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
    if ($testExe -and (Test-Path $testExe)) { Remove-Item $testExe -Force }
}
