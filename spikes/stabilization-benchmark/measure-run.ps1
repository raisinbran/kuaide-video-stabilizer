#requires -Version 7.0
# WP 1A.2: measures leftover shake and needed crop for every successful clip in
# a benchmark run, and writes metrics.json into the run folder.
#
# Shake: libvidstab estimates the camera motion between frames (x, y in pixels)
# for the original and the output. Slow intended motion is removed with a
# 15-frame moving average; shake_px is the RMS of what remains. reduction is
# output shake / original shake (lower is better; 1 means unchanged).
# Crop: cropdetect finds the picture area in every output frame; crop_pct is
# the share of the frame outside the area that is picture in all frames.
# Dark frame edges also read as border, so crop_pct is an upper bound. Black
# frames are skipped, and each edge comes from the 99th-percentile frame.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][string]$FfmpegPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Window = 15

function Get-Shake([string]$Path, [string]$Work) {
    [IO.Directory]::CreateDirectory($Work) | Out-Null
    Push-Location -LiteralPath $Work
    try {
        & $FfmpegPath -v error -nostdin -n -i $Path -vf 'vidstabdetect=shakiness=10:accuracy=15:result=measure.trf' -f null -
        if ($LASTEXITCODE -ne 0) { throw "Motion analysis failed: $Path" }
        # debug=1 makes vidstabtransform write the per-frame motion as text to global_motions.trf.
        & $FfmpegPath -v error -nostdin -i $Path -vf 'vidstabtransform=input=measure.trf:debug=1' -f null -
        if ($LASTEXITCODE -ne 0) { throw "Motion export failed: $Path" }
        $motion = @(Get-Content -LiteralPath 'global_motions.trf' | Where-Object { $_ -match '^\s*-?\d' } | ForEach-Object {
            $f = $_.Trim() -split '\s+'
            [pscustomobject]@{ x = [double]::Parse($f[1], [Globalization.CultureInfo]::InvariantCulture); y = [double]::Parse($f[2], [Globalization.CultureInfo]::InvariantCulture) }
        })
    } finally { Pop-Location }
    if ($motion.Count -le $Window) { throw "Too few frames to measure shake: $Path" }
    $residual = for ($i = 0; $i -lt $motion.Count; $i++) {
        $from = [Math]::Max(0, $i - [int]($Window / 2)); $to = [Math]::Min($motion.Count - 1, $i + [int]($Window / 2))
        $mx = 0.0; $my = 0.0
        for ($j = $from; $j -le $to; $j++) { $mx += $motion[$j].x; $my += $motion[$j].y }
        $n = $to - $from + 1
        [pscustomobject]@{ shake = [Math]::Pow($motion[$i].x - $mx / $n, 2) + [Math]::Pow($motion[$i].y - $my / $n, 2); raw = [Math]::Pow($motion[$i].x, 2) + [Math]::Pow($motion[$i].y, 2) }
    }
    # Cuts and black frames give single huge jumps that are not shake; drop samples
    # more than 10 times the typical (median) size, and say how many were dropped.
    $sorted = @($residual.shake | Sort-Object)
    $limit = [Math]::Max(100 * $sorted[[int]($sorted.Count / 2)], 1.0)
    $kept = @($residual | Where-Object { $_.shake -le $limit })
    return [ordered]@{
        frames = $motion.Count; outliers_dropped = $motion.Count - $kept.Count
        shake_px = [Math]::Round([Math]::Sqrt(($kept.shake | Measure-Object -Sum).Sum / $kept.Count), 3)
        motion_px = [Math]::Round([Math]::Sqrt(($kept.raw | Measure-Object -Sum).Sum / $kept.Count), 3)
    }
}

function Get-CropPercent([string]$Path) {
    $lines = & $FfmpegPath -hide_banner -nostdin -i $Path -vf 'cropdetect=limit=24:round=2:reset=1' -f null - 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "cropdetect failed: $Path" }
    # The last Video line is the filtered stream, after rotation is applied.
    $size = $lines | Select-String -Pattern 'Video: .*?, (\d{2,5})x(\d{2,5})' | Select-Object -Last 1
    $width = [int]$size.Matches[0].Groups[1].Value; $height = [int]$size.Matches[0].Groups[2].Value
    $boxes = foreach ($m in ($lines | Select-String -Pattern 'x1:(\d+) x2:(\d+) y1:(\d+) y2:(\d+)')) {
        $g = $m.Matches[0].Groups
        $box = [pscustomobject]@{ x1 = [int]$g[1].Value; x2 = [int]$g[2].Value; y1 = [int]$g[3].Value; y2 = [int]$g[4].Value }
        # A black frame gives an inside-out box; a mostly black one says nothing about borders.
        if ($box.x2 -lt $box.x1 -or $box.y2 -lt $box.y1) { continue }
        if (($box.x2 - $box.x1 + 1) * ($box.y2 - $box.y1 + 1) -lt 0.25 * $width * $height) { continue }
        $box
    }
    if (-not $boxes) { return $null }
    # Each edge from the 99th-percentile frame, so a few dark frames cannot set the crop.
    $at = { param($values, [double]$share) $sorted = @($values | Sort-Object); $sorted[[Math]::Min($sorted.Count - 1, [int]($share * $sorted.Count))] }
    $x1 = & $at $boxes.x1 0.99; $y1 = & $at $boxes.y1 0.99
    $x2 = & $at $boxes.x2 0.01; $y2 = & $at $boxes.y2 0.01
    $kept = [Math]::Max(0, $x2 - $x1 + 1) * [Math]::Max(0, $y2 - $y1 + 1)
    return [Math]::Round(100 * (1 - $kept / ($width * $height)), 2)
}

$clips = $env:KUAIDE_CLIPS_DIR
if ([string]::IsNullOrWhiteSpace($clips)) { throw 'Set KUAIDE_CLIPS_DIR to the original-clips directory.' }
$run = Get-Content -LiteralPath (Join-Path $RunDirectory 'run.json') -Raw | ConvertFrom-Json
$metricsPath = Join-Path $RunDirectory 'metrics.json'
if (Test-Path -LiteralPath $metricsPath) { throw 'metrics.json already exists in this run.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-measure-' + [Guid]::NewGuid().ToString('N'))
try {
    $metrics = foreach ($result in @($run.results | Where-Object status -eq 'ok')) {
        $folder = Join-Path $RunDirectory ($result.file_name -replace '[^A-Za-z0-9._-]', '_')
        $output = @(Get-ChildItem -LiteralPath $folder -Filter 'output.*' -File)[0].FullName
        $before = Get-Shake (Join-Path $clips $result.file_name) (Join-Path $scratch "$($result.file_name)-in")
        $after = Get-Shake $output (Join-Path $scratch "$($result.file_name)-out")
        [ordered]@{
            file_name = $result.file_name; engine = $run.engine; settings_name = $run.settings_name; elapsed_ms = $result.elapsed_ms
            original = $before; output = $after
            reduction = if ($before.shake_px -gt 0) { [Math]::Round($after.shake_px / $before.shake_px, 3) } else { $null }
            crop_pct = Get-CropPercent $output
        }
    }
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
$file = [IO.File]::Open($metricsPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((@{ window_frames = $Window; clips = @($metrics) } | ConvertTo-Json -Depth 6) + [Environment]::NewLine)
    $file.Write($bytes, 0, $bytes.Length)
} finally { $file.Dispose() }
Write-Output $metricsPath
