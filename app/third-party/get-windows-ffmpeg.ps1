#requires -Version 7.0
[CmdletBinding()]
param([string]$ArchivePath, [ValidateRange(1, 240)][int]$TimeoutMinutes = 30)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'This candidate is for Windows x64 only.'
}
$asset = 'ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0'
$url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-28-19-47/$asset.zip"
$expectedHash = 'cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed'
$expectedSize = 195092333

function Assert-UnlinkedPath([IO.FileSystemInfo]$Item) {
    $cursor = $Item
    while ($null -ne $cursor) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Linked paths are not supported: $($Item.FullName)"
        }
        $cursor = if ($cursor -is [IO.DirectoryInfo]) { $cursor.Parent } else { $cursor.Directory }
    }
}

Assert-UnlinkedPath (Get-Item -LiteralPath $PSScriptRoot -Force)
$bin = Join-Path $PSScriptRoot 'bin'
if (Test-Path -LiteralPath $bin) {
    $binItem = Get-Item -LiteralPath $bin -Force
    if (-not $binItem.PSIsContainer) { throw 'The binary path is not a directory.' }
    Assert-UnlinkedPath $binItem
}
$destination = Join-Path $bin 'ffmpeg-win64-gpl-9.0-cd9b8df51452'
if (Test-Path -LiteralPath $destination) { throw "Candidate directory already exists: $destination" }
if ($ArchivePath) {
    $archive = Get-Item -LiteralPath $ArchivePath -Force
    if ($archive.PSIsContainer) { throw 'ArchivePath must name a file.' }
    Assert-UnlinkedPath $archive
    $archiveFile = $archive.FullName
} else {
    [IO.Directory]::CreateDirectory($bin) | Out-Null
    $archiveFile = Join-Path $bin ('download-' + [Guid]::NewGuid().ToString('N') + '.zip.partial')
    $output = [IO.File]::Open($archiveFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $client = [Net.Http.HttpClient]::new()
    $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromMinutes($TimeoutMinutes))
    $response = $null
    $download = $null
    try {
        $response = $client.GetAsync($url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancel.Token).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null
        $download = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $download.CopyToAsync($output, 81920, $cancel.Token).GetAwaiter().GetResult() | Out-Null
    } finally {
        if ($null -ne $download) { $download.Dispose() }
        if ($null -ne $response) { $response.Dispose() }
        $output.Dispose()
        $cancel.Dispose()
        $client.Dispose()
    }
}
$file = [IO.File]::Open($archiveFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$sha = [Security.Cryptography.SHA256]::Create()
$zip = $null
try {
    $actualHash = [BitConverter]::ToString($sha.ComputeHash($file)).Replace('-', '').ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw "SHA256 mismatch; archive not extracted: $archiveFile" }
    if ($file.Length -ne $expectedSize) { throw 'Archive length differs from the pinned asset.' }
    $file.Position = 0
    [IO.Directory]::CreateDirectory($bin) | Out-Null
    $staging = Join-Path $bin ('extract-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Read, $true)
    [IO.Compression.ZipFileExtensions]::ExtractToDirectory($zip, $staging)
    $candidate = Join-Path $staging $asset
    foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $candidate "bin/$name") -PathType Leaf)) {
            throw "Pinned archive lacks expected executable: $name"
        }
    }
    [IO.Directory]::Move($staging, $destination)
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
    $sha.Dispose()
    $file.Dispose()
}
# A verified, fully extracted download is complete, so drop the .partial suffix.
# The tools are already in place, so a failed rename only warns.
if (-not $ArchivePath) {
    try { [IO.File]::Move($archiveFile, ($archiveFile -replace '\.partial$', '')) }
    catch { Write-Warning "Verified archive kept its .partial name: $($_.Exception.Message)" }
}
Write-Output (Join-Path $destination "$asset/bin/ffmpeg.exe")
Write-Output (Join-Path $destination "$asset/bin/ffprobe.exe")
