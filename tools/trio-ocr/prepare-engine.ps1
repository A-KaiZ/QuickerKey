param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$url = 'https://github.com/tesseract-ocr/tesseract/releases/download/5.5.0/tesseract-ocr-w64-setup-5.5.0.20241111.exe'
$expected = 'F3FC4236425B690C8BE756F35793F77394EE004BE0A6460A440C754D892F68BC'
$cache = Join-Path $env:TEMP 'quickerkeys-tesseract-5.5.0'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$installer = Join-Path $cache 'upstream.exe'
if (!(Test-Path $installer)) { Invoke-WebRequest $url -OutFile $installer }
if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne $expected) { throw 'Tesseract installer digest mismatch.' }
$extracted = Join-Path $cache 'extracted'
if (!(Test-Path $extracted)) {
    $sevenZip = Join-Path $env:ProgramFiles '7-Zip/7z.exe'
    if (!(Test-Path $sevenZip)) { throw '7-Zip is required on the build machine only.' }
    & $sevenZip x $installer "-o$extracted" -y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot extract the pinned upstream package.' }
}
$candidates = @(Get-ChildItem $extracted -Filter tesseract.exe -Recurse)
if ($candidates.Count -ne 1) { throw 'Expected one upstream tesseract.exe.' }
$engineRoot = $candidates[0].Directory.FullName
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Get-ChildItem $engineRoot -Force | Where-Object { $_.Name -notmatch '^\$' -and $_.Name -notmatch '^uninstall' } | Copy-Item -Destination $OutputDirectory -Recurse -Force
if (!(Test-Path (Join-Path $OutputDirectory 'tessdata/eng.traineddata'))) { throw 'Pinned package did not contain the English model.' }
$version = & (Join-Path $OutputDirectory 'tesseract.exe') --version 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $version -notmatch 'tesseract v?5\.5\.0') { throw 'Portable engine cannot run or has the wrong version.' }
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'PROVENANCE.txt'), "Tesseract Windows 5.5.0`r`nUpstream: $url`r`nInstaller SHA256: $expected`r`nExtracted on the build machine. No installation is performed on the user's machine.`r`n")
$manifest = Get-ChildItem $OutputDirectory -File -Recurse | Where-Object Name -ne 'FILES.sha256' | Sort-Object FullName | ForEach-Object {
    (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($OutputDirectory.TrimEnd('\','/').Length + 1).Replace('\','/')
}
[IO.File]::WriteAllLines((Join-Path $OutputDirectory 'FILES.sha256'), $manifest)
Write-Output ('Prepared pinned portable Tesseract; files=' + $manifest.Count)
