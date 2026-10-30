#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FfmpegPath,
    [Parameter(Mandatory)][string]$FfprobePath,
    [Parameter(Mandatory)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PlainPath([string]$Path, [bool]$Directory) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -ne $Directory) { throw "Unexpected path kind: $Path" }
    $cursor = $item
    while ($null -ne $cursor) {
        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked path rejected: $Path" }
        $cursor = if ($cursor -is [IO.DirectoryInfo]) { $cursor.Parent } else { $cursor.Directory }
    }
    return $item.FullName
}

function Test-WithinDirectory([string]$Path, [string]$Directory) {
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $prefix = $Directory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $Path.Equals($Directory, $comparison) -or $Path.StartsWith($prefix, $comparison)
}

function Invoke-SmokeCommand([string]$Name, [string]$Path, [string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Path
    $start.WorkingDirectory = $output
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) { throw "Could not start $Name" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit(30000)
        if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
        $entry = [ordered]@{ name = $Name; arguments = $Arguments; exit_code = $process.ExitCode; timed_out = $timedOut; elapsed_ms = $watch.ElapsedMilliseconds; stdout = $stdout.GetAwaiter().GetResult(); stderr = $stderr.GetAwaiter().GetResult() }
        $commands.Add($entry)
        if ($timedOut -or $entry.exit_code -ne 0) { throw "Smoke command failed: $Name (exit $($entry.exit_code), timed_out $timedOut)" }
        return $entry
    } finally { $process.Dispose() }
}

$ffmpeg = Resolve-PlainPath $FfmpegPath $false
$ffprobe = Resolve-PlainPath $FfprobePath $false
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist; choose a new external directory.' }
$null = Resolve-PlainPath ([IO.Path]::GetDirectoryName($output)) $true
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach ($directory in @($repo, [IO.Path]::GetDirectoryName($ffmpeg), [IO.Path]::GetDirectoryName($ffprobe))) {
    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside repository and tool directories.' }
}
$tools = [ordered]@{}
foreach ($entry in @(@('ffmpeg', $ffmpeg), @('ffprobe', $ffprobe))) {
    $tools[$entry[0]] = [ordered]@{ path = $entry[1]; sha256 = (Get-FileHash -LiteralPath $entry[1]).Hash.ToLowerInvariant() }
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$commands = [Collections.Generic.List[object]]::new()
$checks = [Collections.Generic.List[object]]::new()
$report = [ordered]@{ status = 'failed'; failure = $null; generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o'); host = [ordered]@{ os = [Runtime.InteropServices.RuntimeInformation]::OSDescription; architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); powershell = $PSVersionTable.PSVersion.ToString() }; tools = $tools; commands = $commands; checks = $checks; evidence = 'Short synthetic software smoke only; no hardware, footage, quality or source-provenance validation.' }
try {
    $null = Invoke-SmokeCommand 'ffmpeg-version' $ffmpeg @('-version')
    $null = Invoke-SmokeCommand 'ffprobe-version' $ffprobe @('-version')
    $common = @('-nostdin', '-hide_banner', '-n')
    $source = @('-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=30:duration=1', '-an')
    $null = Invoke-SmokeCommand 'encode-h264' $ffmpeg ($common + $source + @('-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '20', '-pix_fmt', 'yuv420p', '-threads', '2', 'h264.mp4'))
    $null = Invoke-SmokeCommand 'encode-hevc' $ffmpeg ($common + $source + @('-c:v', 'libx265', '-preset', 'ultrafast', '-crf', '28', '-pix_fmt', 'yuv420p', '-x265-params', 'pools=1:frame-threads=1', 'hevc.mp4'))
    $null = Invoke-SmokeCommand 'detect-motion' $ffmpeg ($common + @('-i', 'h264.mp4', '-vf', 'vidstabdetect=shakiness=5:accuracy=9:result=transforms.trf', '-an', '-f', 'null', '-'))
    if (-not (Test-Path -LiteralPath (Join-Path $output 'transforms.trf') -PathType Leaf) -or (Get-Item -LiteralPath (Join-Path $output 'transforms.trf')).Length -eq 0) { throw 'Motion analysis did not create a nonempty transform file.' }
    $null = Invoke-SmokeCommand 'transform-motion' $ffmpeg ($common + @('-i', 'h264.mp4', '-vf', 'vidstabtransform=input=transforms.trf:smoothing=10:optzoom=0', '-an', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '20', '-pix_fmt', 'yuv420p', '-threads', '2', 'stabilized.mp4'))
    foreach ($expected in @(@('h264.mp4', 'h264'), @('hevc.mp4', 'hevc'), @('stabilized.mp4', 'h264'))) {
        $name, $codec = $expected
        $probe = Invoke-SmokeCommand "probe-$name" $ffprobe @('-v', 'error', '-select_streams', 'v:0', '-count_frames', '-show_entries', 'stream=codec_name,width,height,nb_read_frames:format=duration', '-of', 'json', $name)
        $metadata = $probe.stdout | ConvertFrom-Json
        if (@($metadata.streams).Count -ne 1) { throw "Expected one selected video stream: $name" }
        $stream = $metadata.streams[0]
        $duration = [double]::Parse($metadata.format.duration, [Globalization.CultureInfo]::InvariantCulture)
        if ($stream.codec_name -ne $codec -or $stream.width -ne 320 -or $stream.height -ne 180 -or [int]$stream.nb_read_frames -ne 30 -or [Math]::Abs($duration - 1.0) -gt 0.05) { throw "Output does not match expected codec, size, frame count or duration: $name" }
        $checks.Add([ordered]@{ file_name = $name; codec = $stream.codec_name; width = $stream.width; height = $stream.height; decoded_frame_count = [int]$stream.nb_read_frames; duration_seconds = $duration; sha256 = (Get-FileHash -LiteralPath (Join-Path $output $name)).Hash.ToLowerInvariant() })
    }
    foreach ($tool in $tools.Values) {
        if ($tool.sha256 -ne (Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant()) { throw 'A tool changed during the smoke run.' }
    }
    $report.status = 'passed'
} catch {
    $report.failure = $_.Exception.Message
    throw
} finally {
    $reportPath = Join-Path $output $(if ($report.status -eq 'passed') { 'software-smoke.json' } else { 'software-smoke-failed.json' })
    $file = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 12) + [Environment]::NewLine)
        $file.Write($bytes, 0, $bytes.Length)
    } finally { $file.Dispose() }
}
Write-Output $reportPath
