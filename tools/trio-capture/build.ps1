param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!(Test-Path $compiler)) { throw 'The Windows x64 .NET Framework compiler is required.' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$probeExe = Join-Path $OutputDirectory 'TrioCaptureProbe.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 /warnaserror+ "/out:$probeExe" "/win32manifest:$(Join-Path $PSScriptRoot 'app.manifest')" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'TrioCaptureProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'Capture probe compilation failed.' }
[IO.File]::WriteAllText(($probeExe + '.config'), '<?xml version="1.0"?><configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8" /></startup></configuration>')
Copy-Item (Join-Path $PSScriptRoot 'README.md') $OutputDirectory -Force
$sourceDirectory = Join-Path $OutputDirectory 'source'
New-Item -ItemType Directory -Force -Path $sourceDirectory | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'TrioCaptureProbe.cs'),(Join-Path $PSScriptRoot 'build.ps1'),(Join-Path $PSScriptRoot 'app.manifest'),(Join-Path $PSScriptRoot 'README.md') $sourceDirectory -Force
Get-FileHash $probeExe -Algorithm SHA256 | ForEach-Object {
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256.txt'), ($_.Hash.ToLowerInvariant() + '  TrioCaptureProbe.exe' + [Environment]::NewLine))
}
Write-Output 'Built standalone P0 capture probe (x64).'
