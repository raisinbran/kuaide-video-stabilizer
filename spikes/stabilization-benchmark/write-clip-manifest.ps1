#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PlainPath([string]$Path, [bool]$Directory) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -ne $Directory) { throw "Unexpected path kind: $Path" }
    $cursor = $item
    while ($null -ne $cursor) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Linked paths are not supported: $Path"
        }
        $cursor = if ($cursor -is [IO.DirectoryInfo]) { $cursor.Parent } else { $cursor.Directory }
    }
    return $item.FullName
}

function Test-WithinDirectory([string]$Path, [string]$Directory) {
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $prefix = $Directory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $Path.Equals($Directory, $comparison) -or $Path.StartsWith($prefix, $comparison)
}

if ([string]::IsNullOrWhiteSpace($env:KUAIDE_CLIPS_DIR)) { throw 'Set KUAIDE_CLIPS_DIR to the original-clips directory.' }
$clips = Resolve-PlainPath $env:KUAIDE_CLIPS_DIR $true
$output = Resolve-PlainPath $OutputDirectory $true
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach ($directory in @($clips, $repo)) {
    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside the repository and original-clips directory.' }
}
$reportPath = Join-Path $output 'clips.manifest.json'
if (Test-Path -LiteralPath $reportPath) { throw "Output already exists: $reportPath" }
$skip = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
$names = [string[]]@(Get-ChildItem -LiteralPath $clips -File -Force | Where-Object { ($_.Attributes -band $skip) -eq 0 } | ForEach-Object Name)
[Array]::Sort($names, [StringComparer]::Ordinal)
if ($names.Count -eq 0) { throw 'No top-level files found in the original-clips directory.' }
$entries = @(
    foreach ($name in $names) {
        $path = Resolve-PlainPath (Join-Path $clips $name) $false
        $before = Get-Item -LiteralPath $path -Force
        $size = $before.Length
        $modified = $before.LastWriteTimeUtc
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $after = Get-Item -LiteralPath $path -Force
        if ($after.Length -ne $size -or $after.LastWriteTimeUtc -ne $modified) { throw "File changed during hashing: $name" }
        [ordered]@{
            file_name = $name
            size_bytes = $size
            sha256 = $hash
            media_format = 'unknown'
            camera = 'unknown'
            originality = 'unknown'
            footage_categories = @()
            evidence = 'Full file bytes hashed; media content and metadata not probed.'
        }
    }
)
$manifest = [ordered]@{
    schema_version = 1
    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    source = 'KUAIDE_CLIPS_DIR; top-level regular files only'
    files = $entries
}
$json = $manifest | ConvertTo-Json -Depth 8
$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
    $stream.Write($bytes, 0, $bytes.Length)
} finally {
    $stream.Dispose()
}
Write-Output $reportPath
