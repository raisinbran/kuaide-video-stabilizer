#requires -Version 7.0
# Two-pass libvidstab through FFmpeg: vidstabdetect writes the camera motion,
# vidstabtransform smooths it and moves each frame. Options come from the
# settings file: `detect` and `transform` are filter option strings, `crf` and
# `preset` set the libx264 encode. The first audio track is kept as AAC.
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [Parameter(Mandatory)][string]$FfmpegPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
Set-Location -LiteralPath $WorkDirectory

# Option strings may only set options: no file names, paths or extra filters.
foreach ($value in @($settings.detect, $settings.transform)) {
    if ($value -match "result|input|[\\/\[\];,']") { throw "Unsafe filter options: $value" }
}

& $FfmpegPath -hide_banner -nostdin -n -i $InputPath -vf "vidstabdetect=$($settings.detect):result=motion.trf" -f null -
if ($LASTEXITCODE -ne 0) { throw "vidstabdetect failed ($LASTEXITCODE)" }
& $FfmpegPath -hide_banner -nostdin -n -i $InputPath -map 0:v:0 -map '0:a:0?' `
    -vf "vidstabtransform=input=motion.trf:$($settings.transform),format=yuv420p" `
    -c:v libx264 -preset $settings.preset -crf $settings.crf -c:a aac -b:a 192k -movflags +faststart $OutputPath
if ($LASTEXITCODE -ne 0) { throw "vidstabtransform failed ($LASTEXITCODE)" }
