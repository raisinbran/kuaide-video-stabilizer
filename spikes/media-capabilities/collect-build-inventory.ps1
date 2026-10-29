#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FfmpegPath,
    [Parameter(Mandatory)][string]$FfprobePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$SourceUrl,
    [string]$LicensePath,
    [ValidateRange(1, 120)][int]$TimeoutSeconds = 15
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PlainPath([string]$Path, [bool]$Directory) {
    $item = Get-Item -LiteralPath $Path
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

function Invoke-Tool([string]$Path, [string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    if ([IO.Path]::GetExtension($Path) -eq '.ps1') {
        $start.FileName = (Get-Process -Id $PID).Path
        foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $Path)) {
            $start.ArgumentList.Add($argument)
        }
    } else {
        $start.FileName = $Path
    }
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Could not start tool: $Path" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "Tool timed out after $TimeoutSeconds seconds: $Path"
        }
        $result = [ordered]@{
            arguments = $Arguments
            exit_code = $process.ExitCode
            stdout = $stdout.GetAwaiter().GetResult()
            stderr = $stderr.GetAwaiter().GetResult()
        }
        if ($result.exit_code -ne 0) { throw "Tool failed with exit code $($result.exit_code): $Path" }
        return $result
    } finally {
        $process.Dispose()
    }
}

$ffmpeg = Resolve-PlainPath $FfmpegPath $false
$ffprobe = Resolve-PlainPath $FfprobePath $false
$output = Resolve-PlainPath $OutputDirectory $true
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach ($directory in @($repo, [IO.Path]::GetDirectoryName($ffmpeg), [IO.Path]::GetDirectoryName($ffprobe))) {
    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside the repository and tool directories.' }
}
$reportPath = Join-Path $output 'build-inventory.json'
if (Test-Path -LiteralPath $reportPath) { throw "Output already exists: $reportPath" }
$license = $null
if ($LicensePath) {
    $licenseFile = Resolve-PlainPath $LicensePath $false
    $license = [ordered]@{
        path = $licenseFile
        sha256 = (Get-FileHash -LiteralPath $licenseFile -Algorithm SHA256).Hash.ToLowerInvariant()
        text = [IO.File]::ReadAllText($licenseFile)
        status = 'caller-supplied; applicability not verified'
    }
}
$tools = [ordered]@{}
foreach ($entry in @(@('ffmpeg', $ffmpeg), @('ffprobe', $ffprobe))) {
    $name, $path = $entry
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $commands = [ordered]@{
        version = Invoke-Tool $path @('-version')
        buildconf = Invoke-Tool $path @('-buildconf')
    }
    if ($name -eq 'ffmpeg') {
        $commands.filters = Invoke-Tool $path @('-hide_banner', '-filters')
        $commands.encoders = Invoke-Tool $path @('-hide_banner', '-encoders')
    }
    if ($hash -ne (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()) {
        throw "Tool changed during collection: $path"
    }
    $tools[$name] = [ordered]@{ path = $path; sha256 = $hash; commands = $commands }
}
$report = [ordered]@{
    schema_version = 1
    collected_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    host = [ordered]@{ os = [Runtime.InteropServices.RuntimeInformation]::OSDescription; architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); powershell = $PSVersionTable.PSVersion.ToString() }
    evidence = 'Tool-reported build inventory; no encode, decode, filter or hardware execution tested.'
    provenance = [ordered]@{
        source_url = if ($SourceUrl) { $SourceUrl } else { $null }
        source_status = if ($SourceUrl) { 'caller-supplied; not verified' } else { 'unknown' }
        license = $license
        license_status = if ($license) { 'caller-supplied; applicability not verified' } else { 'unknown' }
        authenticity = 'not verified; SHA256 identifies the collected files only'
    }
    tools = $tools
}
$json = $report | ConvertTo-Json -Depth 12
$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
    $stream.Write($bytes, 0, $bytes.Length)
} finally {
    $stream.Dispose()
}
Write-Output $reportPath
