#requires -Version 7.0
# WP 1A.1: makes the two computer-generated benchmark clips the draft critique
# asks for, in a new folder outside the repository:
#   shaken-still.mp4  one still image panned along a fixed sine path (known shake)
#   hard-cut.mp4      two different shaken stills joined by a cut at 2.0 s
# Point KUAIDE_CLIPS_DIR at the folder and run write-clip-manifest.ps1 to list them.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FfmpegPath,
    [Parameter(Mandatory)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Ffmpeg([string[]]$Arguments) {
    & $FfmpegPath -v error -nostdin -n @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: $($Arguments -join ' ')" }
}

$output = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (($output + [IO.Path]::DirectorySeparatorChar).StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the repository.' }
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-synthetic-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
[IO.Directory]::CreateDirectory($output) | Out-Null

$encode = @('-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-pix_fmt', 'yuv420p')
# 640x360 window moving inside an 800x460 still: up to +-40 px across, +-25 px down.
$shake = "crop=640:360:'80+40*sin(2*PI*3*t)':'50+25*sin(2*PI*2*t+1)'"
Invoke-Ffmpeg @('-f', 'lavfi', '-i', 'testsrc2=size=800x460', '-frames:v', '1', (Join-Path $work 'still-a.png'))
Invoke-Ffmpeg @('-f', 'lavfi', '-i', 'mandelbrot=size=800x460', '-frames:v', '1', (Join-Path $work 'still-b.png'))
Invoke-Ffmpeg (@('-loop', '1', '-framerate', '30', '-t', '4', '-i', (Join-Path $work 'still-a.png'), '-vf', $shake) + $encode + @((Join-Path $output 'shaken-still.mp4')))
Invoke-Ffmpeg (@('-loop', '1', '-framerate', '30', '-t', '2', '-i', (Join-Path $work 'still-a.png'),
    '-loop', '1', '-framerate', '30', '-t', '2', '-i', (Join-Path $work 'still-b.png'),
    '-filter_complex', "[0:v]$shake[a];[1:v]$shake[b];[a][b]concat=n=2:v=1") + $encode + @((Join-Path $output 'hard-cut.mp4')))
Remove-Item -LiteralPath $work -Recurse
Get-ChildItem -LiteralPath $output | ForEach-Object FullName
