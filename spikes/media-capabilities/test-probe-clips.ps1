#requires -Version 7.0
# Checks probe-clips.ps1 against small generated clips whose rotation, HDR tags
# and frame timing are known. Needs the verified FFmpeg and ffprobe paths.
param(
    [Parameter(Mandatory)][string]$FfmpegPath,
    [Parameter(Mandatory)][string]$FfprobePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Clip([string]$Name, [string[]]$Arguments) {
    & $FfmpegPath -v error -nostdin -n @Arguments (Join-Path $clips $Name)
    if ($LASTEXITCODE -ne 0) { throw "Could not make $Name" }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-probe-tests-' + [Guid]::NewGuid().ToString('N'))
$clips = (New-Item -ItemType Directory -Path (Join-Path $work 'clips')).FullName
$source = @('-f', 'lavfi', '-i', 'testsrc2=size=320x240:rate=30:duration=2')
New-Clip 'plain.mp4' ($source + @('-c:v', 'libx264', '-pix_fmt', 'yuv420p'))
# Rotation is a container display matrix, which ffmpeg writes when re-wrapping.
New-Clip 'rotated.mp4' @('-display_rotation', '90', '-i', (Join-Path $clips 'plain.mp4'), '-c', 'copy')
New-Clip 'hdr.mp4' ($source + @('-c:v', 'libx265', '-pix_fmt', 'yuv420p10le', '-x265-params', 'log-level=error:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc'))
# One second at 30 fps then one at 15 fps: frame gaps of 33 and 67 ms.
New-Clip 'vfr.mp4' @('-f', 'lavfi', '-i', 'testsrc2=size=320x240:rate=30:duration=1', '-f', 'lavfi', '-i', 'testsrc2=size=320x240:rate=15:duration=1', '-filter_complex', '[0:v][1:v]concat=n=2:v=1', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-pix_fmt', 'yuv420p')

$files = foreach ($name in @('plain.mp4', 'rotated.mp4', 'hdr.mp4', 'vfr.mp4')) {
    $path = Join-Path $clips $name
    [ordered]@{ file_name = $name; size_bytes = (Get-Item $path).Length; sha256 = (Get-FileHash $path).Hash.ToLowerInvariant() }
}
$manifest = Join-Path $work 'clips.manifest.json'
@{ files = @($files) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifest -Encoding utf8
$probe = Join-Path $PSScriptRoot 'probe-clips.ps1'
$pwsh = (Get-Process -Id $PID).Path
$prior = $env:KUAIDE_CLIPS_DIR
try {
    $env:KUAIDE_CLIPS_DIR = $clips
    $out = Join-Path $work 'run'
    & $pwsh -NoProfile -NonInteractive -File $probe -FfprobePath $FfprobePath -OutputDirectory $out -ManifestPath $manifest | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'Probe failed on generated clips.'
    $report = (Get-Content -LiteralPath (Join-Path $out 'clip-probes.json') -Raw | ConvertFrom-Json).clips
    $byName = @{}; foreach ($clip in $report) { $byName[$clip.file_name] = $clip }
    Assert-True ([Math]::Abs($byName['rotated.mp4'].video.rotation_degrees) -eq 90 -and $byName['plain.mp4'].video.rotation_degrees -eq 0) 'Rotation was not read.'
    Assert-True ($byName['hdr.mp4'].video.hdr -and -not $byName['plain.mp4'].video.hdr) 'HDR flag is wrong.'
    Assert-True ($byName['vfr.mp4'].video.timing.variable_frame_rate -and -not $byName['plain.mp4'].video.timing.variable_frame_rate) 'Variable frame rate flag is wrong.'
    Assert-True (-not ($report | Where-Object gyro_track)) 'Generated clips have no gyro track.'
    Write-Output 'PASS rotation, HDR and variable frame rate are detected'

    [IO.File]::AppendAllText((Join-Path $clips 'hdr.mp4'), 'x')
    & $pwsh -NoProfile -NonInteractive -File $probe -FfprobePath $FfprobePath -OutputDirectory (Join-Path $work 'changed') -ManifestPath $manifest 2>&1 | Out-Null
    Assert-True ($LASTEXITCODE -ne 0 -and -not (Test-Path (Join-Path $work 'changed'))) 'A clip that differs from the manifest was probed.'
    Write-Output 'PASS a clip that differs from the manifest stops the run without output'
    Write-Output "Scratch results: $work"
} finally {
    $env:KUAIDE_CLIPS_DIR = $prior
}
