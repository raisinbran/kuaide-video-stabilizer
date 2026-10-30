#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'Run this check on Windows x64.'
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-download-test-' + [Guid]::NewGuid().ToString('N'))
$copy = New-Item -ItemType Directory -Path (Join-Path $work 'app/third-party')
$script = Join-Path $copy.FullName 'get-windows-ffmpeg.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'get-windows-ffmpeg.ps1') -Destination $script
$archive = Join-Path $work 'wrong archive.zip'
[IO.File]::WriteAllBytes($archive, [Text.Encoding]::ASCII.GetBytes('wrong archive bytes'))
$before = (Get-FileHash -LiteralPath $archive).Hash
$messages = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File $script -ArchivePath $archive 2>&1
if ($LASTEXITCODE -eq 0 -or ($messages -join "`n") -notmatch 'SHA256 mismatch') {
    throw 'Wrong bytes did not fail at the checksum gate.'
}
if (Test-Path -LiteralPath (Join-Path $copy.FullName 'bin')) {
    throw 'Checksum rejection created a binary or extraction directory.'
}
if ((Get-FileHash -LiteralPath $archive).Hash -ne $before) { throw 'Local archive changed.' }
Write-Output 'PASS checksum rejection precedes extraction and preserves input'
Write-Output "Scratch results: $work"
