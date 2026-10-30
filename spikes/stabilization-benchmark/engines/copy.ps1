#requires -Version 7.0
# Baseline engine: copies the input unchanged. It gives the "no stabilization"
# row in comparisons and lets the harness be tested without FFmpeg.
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [string]$FfmpegPath = ''
)
$ErrorActionPreference = 'Stop'
Copy-Item -LiteralPath $InputPath -Destination $OutputPath
