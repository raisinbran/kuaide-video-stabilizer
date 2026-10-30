#requires -Version 7.0
# WP 1C-B: tries each graphics-card encoder on a short synthetic 1080p clip,
# alone and after libvidstab, and records which ones produce a decodable file.
# An encoder the machine lacks is recorded as failed, not as an error.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FfmpegPath,
    [Parameter(Mandatory)][string]$FfprobePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string[]]$Encoders = @('h264_nvenc', 'hevc_nvenc', 'h264_qsv', 'hevc_qsv', 'h264_amf', 'hevc_amf', 'libx264')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# `pwsh -File` passes `-Encoders a,b` as one string.
$Encoders = @($Encoders | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$output =$PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist; choose a new folder outside the repository.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($output.StartsWith($repo.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the repository.' }
[IO.Directory]::CreateDirectory($output) | Out-Null
$source = Join-Path $output 'source.mp4'
& $FfmpegPath -v error -nostdin -n -f lavfi -i 'testsrc2=size=1920x1080:rate=30:duration=3' -c:v libx264 -preset veryfast -pix_fmt yuv420p $source
if ($LASTEXITCODE -ne 0) { throw 'Could not make the source clip.' }
Push-Location $output
try {
    & $FfmpegPath -v error -nostdin -n -i $source -vf 'vidstabdetect=result=transforms.trf' -f null -
    if ($LASTEXITCODE -ne 0) { throw 'Motion analysis failed.' }
    $results = foreach ($encoder in $Encoders) {
        foreach ($chain in @('encode-only', 'after-vidstab')) {
            $name = "$encoder-$chain.mp4"
            $filter = if ($chain -eq 'after-vidstab') { @('-vf', 'vidstabtransform=input=transforms.trf,format=yuv420p') } else { @('-pix_fmt', 'yuv420p') }
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $messages = & $FfmpegPath -v error -nostdin -n -i $source @filter -c:v $encoder -b:v 8M $name 2>&1
            $exit = $LASTEXITCODE
            $elapsed = $watch.ElapsedMilliseconds
            $frames = $null
            if ($exit -eq 0) {
                $count = & $FfprobePath -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 $name
                if ($LASTEXITCODE -ne 0) { throw "ffprobe could not read $name" }
                $frames = [int]$count
            }
            [ordered]@{
                encoder = $encoder; chain = $chain; ok = ($exit -eq 0 -and $frames -eq 90); exit_code = $exit
                elapsed_ms = $elapsed; decoded_frames = $frames
                # The first lines name the cause (for example a driver too old); the last are generic.
                error = if ($exit -ne 0) { (($messages | Select-Object -First 2) -join ' ').Trim() } else { $null }
            }
        }
    }
} finally { Pop-Location }
$report = [ordered]@{
    generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    ffmpeg_sha256 = (Get-FileHash -LiteralPath $FfmpegPath).Hash.ToLowerInvariant()
    source = '3 s testsrc2, 1920x1080, 30 fps, libx264'
    results = @($results)
}
$reportPath = Join-Path $output 'hardware-encoders.json'
$file = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 6) + [Environment]::NewLine)
    $file.Write($bytes, 0, $bytes.Length)
} finally { $file.Dispose() }
Write-Output $reportPath
