#requires -Version 7.0
# WP 1C-B: reads the format, timing, rotation, color and extra tracks of every
# clip in the manifest with ffprobe, and writes one summary JSON per run.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FfprobePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$ManifestPath = (Join-Path $PSScriptRoot '../stabilization-benchmark/clips.manifest.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Probe([string[]]$Arguments) {
    $text = & $FfprobePath -v error @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed ($LASTEXITCODE): $($Arguments -join ' ')" }
    return ($text -join "`n")
}

function Get-Property($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

# '30000/1001' -> 29.97; '0/0' -> $null.
function ConvertFrom-Rate([string]$Rate) {
    $parts = $Rate -split '/'
    if ($parts.Count -ne 2 -or [double]$parts[1] -eq 0) { return $null }
    return [Math]::Round([double]::Parse($parts[0], [Globalization.CultureInfo]::InvariantCulture) / [double]::Parse($parts[1], [Globalization.CultureInfo]::InvariantCulture), 3)
}

# Frame timing from packet timestamps (no decoding). Sorted, because B-frames
# arrive out of presentation order.
function Get-FrameTiming([string]$Path) {
    $csv = Invoke-Probe @('-select_streams', 'v:0', '-show_entries', 'packet=pts_time', '-of', 'csv=p=0', $Path)
    $lines = @($csv -split "`n" | ForEach-Object { $_.Trim().TrimEnd(',') } | Where-Object { $_ })
    # Edit lists can give negative times; raw streams give N/A, which is counted, not read.
    $times = @($lines | Where-Object { $_ -match '^-?[0-9.]+$' } | ForEach-Object { [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture) } | Sort-Object)
    $untimed = $lines.Count - $times.Count
    if ($times.Count -lt 3) { return [ordered]@{ frames = $times.Count; packets_without_time = $untimed; variable_frame_rate = $null } }
    $gaps = for ($i = 1; $i -lt $times.Count; $i++) { ($times[$i] - $times[$i - 1]) * 1000 }
    $stats = $gaps | Measure-Object -Minimum -Maximum -Average
    return [ordered]@{
        frames = $times.Count
        packets_without_time = $untimed
        frame_gap_ms_min = [Math]::Round($stats.Minimum, 3)
        frame_gap_ms_max = [Math]::Round($stats.Maximum, 3)
        frame_gap_ms_mean = [Math]::Round($stats.Average, 3)
        # WebM stores whole milliseconds, so 16/17 ms gaps are rounding, not a varying rate.
        variable_frame_rate = ($stats.Maximum - $stats.Minimum) -gt 2.0
    }
}

function Get-Rotation($Stream) {
    foreach ($side in @(Get-Property $Stream 'side_data_list')) {
        $rotation = Get-Property $side 'rotation'
        if ($null -ne $rotation) { return [int]$rotation }
    }
    # The old `rotate` tag counts clockwise, the display matrix counterclockwise;
    # report the display-matrix convention (an iPhone portrait clip is -90).
    $rotate = Get-Property (Get-Property $Stream 'tags') 'rotate'
    if ($null -ne $rotate) { return -[int]$rotate }
    return 0
}

$clips = $env:KUAIDE_CLIPS_DIR
if ([string]::IsNullOrWhiteSpace($clips)) { throw 'Set KUAIDE_CLIPS_DIR to the original-clips directory.' }
$output = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist; choose a new folder outside the repository.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($output.StartsWith($repo.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the repository.' }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

$results = foreach ($entry in $manifest.files) {
    $path = Join-Path $clips $entry.file_name
    $file = Get-Item -LiteralPath $path -Force
    if ($file.Length -ne $entry.size_bytes) { throw "Size differs from the manifest: $($entry.file_name)" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "SHA-256 differs from the manifest: $($entry.file_name)" }
    $probe = Invoke-Probe @('-show_format', '-show_streams', '-of', 'json', $path) | ConvertFrom-Json
    $videoStreams = @($probe.streams | Where-Object codec_type -eq 'video')
    if ($videoStreams.Count -eq 0) { throw "No video stream: $($entry.file_name)" }
    $video = $videoStreams[0]
    $duration = Get-Property $probe.format 'duration'
    $audio = @($probe.streams | Where-Object codec_type -eq 'audio')
    $transfer = Get-Property $video 'color_transfer'
    [ordered]@{
        file_name = $entry.file_name
        sha256 = $entry.sha256
        container = $probe.format.format_name
        duration_s = if ($duration) { [Math]::Round([double]::Parse($duration, [Globalization.CultureInfo]::InvariantCulture), 3) } else { $null }
        video = [ordered]@{
            codec = $video.codec_name
            profile = Get-Property $video 'profile'
            width = $video.width
            height = $video.height
            pixel_format = Get-Property $video 'pix_fmt'
            rotation_degrees = Get-Rotation $video
            nominal_fps = ConvertFrom-Rate $video.r_frame_rate
            average_fps = ConvertFrom-Rate $video.avg_frame_rate
            color_primaries = Get-Property $video 'color_primaries'
            color_transfer = $transfer
            color_space = Get-Property $video 'color_space'
            # PQ (smpte2084) and HLG (arib-std-b67) are the HDR transfer curves.
            hdr = $transfer -in @('smpte2084', 'arib-std-b67')
            timing = Get-FrameTiming $path
        }
        audio = @($audio | ForEach-Object { [ordered]@{ codec = $_.codec_name; channels = Get-Property $_ 'channels'; sample_rate = Get-Property $_ 'sample_rate' } })
        other_streams = @($probe.streams | Where-Object { $_.codec_type -notin @('video', 'audio') } | ForEach-Object {
            [ordered]@{ index = $_.index; type = $_.codec_type; tag = Get-Property $_ 'codec_tag_string'; handler = Get-Property (Get-Property $_ 'tags') 'handler_name' }
        })
    }
}
foreach ($result in $results) {
    # GoPro GPMF (gpmd) and CAMM tracks carry gyro samples; other data tracks are listed but not assumed to.
    $result.gyro_track = [bool]@($result.other_streams | Where-Object { $_.tag -in @('gpmd', 'camm') -or "$($_.handler)" -match 'gyro|GoPro MET' }).Count
}

[IO.Directory]::CreateDirectory($output) | Out-Null
$report = [ordered]@{ generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o'); ffprobe_sha256 = (Get-FileHash -LiteralPath $FfprobePath).Hash.ToLowerInvariant(); clips = @($results) }
$reportPath = Join-Path $output 'clip-probes.json'
$file = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    $file.Write($bytes, 0, $bytes.Length)
} finally { $file.Dispose() }
Write-Output $reportPath
