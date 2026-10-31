#requires -Version 7.0
# WP 1A.2: measures leftover shake and dark edges for every successful clip in
# a benchmark run, and writes metrics.json into the run folder.
#
# Shake: both the original and the output are first brought to one analysis
# form: 30 fps, the central 70% of the frame (to reduce border interference),
# scaled to 640 px wide, 8-bit. libvidstab then estimates the camera motion
# between frames (x, y). Slow intended motion is removed with a 15-frame (0.5 s)
# moving average; shake_px is the RMS of what remains, in analysis pixels per
# 1/30 s, so clips and engines of any size and frame rate compare directly.
# Large original-motion outliers are dropped from both; they do not prove cuts.
# reduction is output shake / original shake (lower is steadier; 1 is unchanged).
# frame_change_ratio is the same comparison for raw picture change, which needs no
# tracking; shake_score_suspect is a hint that tracking says worse but it does not.
# Frozen output would look perfectly steady, so frozen time is measured too and
# a clip whose output freezes 1 s more than its original is flagged.
# Crop: identical bytes prove zero added crop. Otherwise crop_pct comes from the
# engine's border-union image (get-valid-crop.ps1), or stays null if it has none.
# Dark-edge detection confuses dark scenery with borders and misses rotated
# corners, so observed_dark_edges_pct is a diagnostic only.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][string]$FfmpegPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Window = 15
$Analysis = 'fps=30,crop=trunc(iw*0.7/2)*2:trunc(ih*0.7/2)*2,scale=640:-2,format=yuv420p'

# Frame-to-frame camera motion of a video, in analysis pixels.
function Get-Motion([string]$Path, [string]$Work) {
    [IO.Directory]::CreateDirectory($Work) | Out-Null
    Push-Location -LiteralPath $Work
    try {
        & $FfmpegPath -v error -nostdin -n -i $Path -vf "$Analysis,vidstabdetect=shakiness=10:accuracy=15:result=measure.trf" -f null - | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Motion analysis failed: $Path" }
        # debug=1 makes vidstabtransform write the per-frame motion as text to
        # global_motions.trf; its columns are: 0, x, y, angle, zoom, flags.
        & $FfmpegPath -v error -nostdin -i $Path -vf "$Analysis,vidstabtransform=input=measure.trf:optalgo=gauss:debug=1" -f null - | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Motion export failed: $Path" }
        return @(Get-Content -LiteralPath 'global_motions.trf' | Where-Object { $_ -match '^\s*-?\d' } | ForEach-Object {
            $f = $_.Trim() -split '\s+'
            [pscustomobject]@{ x = [double]::Parse($f[1], [Globalization.CultureInfo]::InvariantCulture); y = [double]::Parse($f[2], [Globalization.CultureInfo]::InvariantCulture) }
        })
    } finally { Pop-Location }
}

# Squared distance of each frame's motion from its 15-frame average (shake),
# and its squared size (all motion).
function Get-Residual($Motion) {
    for ($i = 0; $i -lt $Motion.Count; $i++) {
        $radius = [int][Math]::Floor($Window / 2)
        $from = [Math]::Max(0, $i - $radius); $to = [Math]::Min($Motion.Count - 1, $i + $radius)
        $mx = 0.0; $my = 0.0
        for ($j = $from; $j -le $to; $j++) { $mx += $Motion[$j].x; $my += $Motion[$j].y }
        $n = $to - $from + 1
        [pscustomobject]@{ shake = [Math]::Pow($Motion[$i].x - $mx / $n, 2) + [Math]::Pow($Motion[$i].y - $my / $n, 2); raw = [Math]::Pow($Motion[$i].x, 2) + [Math]::Pow($Motion[$i].y, 2) }
    }
}

function Get-Summary($Residual, [bool[]]$Keep) {
    $kept = @(for ($i = 0; $i -lt $Residual.Count; $i++) { if ($Keep[$i]) { $Residual[$i] } })
    return [ordered]@{
        shake_px = [Math]::Round([Math]::Sqrt(($kept.shake | Measure-Object -Sum).Sum / $kept.Count), 3)
        motion_px = [Math]::Round([Math]::Sqrt(($kept.raw | Measure-Object -Sum).Sum / $kept.Count), 3)
    }
}

# Seconds of frozen picture (no change for 0.5 s or more).
function Get-FrozenSeconds([string]$Path) {
    $lines = & $FfmpegPath -hide_banner -nostdin -i $Path -vf "$Analysis,freezedetect=n=0.001:d=0.5" -an -f null - 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "freezedetect failed: $Path" }
    $number = { param($text) [double]::Parse($text, [Globalization.CultureInfo]::InvariantCulture) }
    $total = 0.0
    foreach ($m in ($lines | Select-String -Pattern 'freeze_duration: ?([0-9.]+)')) { $total += & $number $m.Matches[0].Groups[1].Value }
    # A freeze that lasts to the end is reported only by its start.
    $starts = @($lines | Select-String -Pattern 'freeze_start: ?([0-9.]+)')
    $ends = @($lines | Select-String -Pattern 'freeze_end')
    if ($starts.Count -gt $ends.Count) {
        $length = $lines | Select-String -Pattern 'Duration: (\d+):(\d+):([0-9.]+)' | Select-Object -First 1
        $g = $length.Matches[0].Groups
        $seconds = 3600 * [int]$g[1].Value + 60 * [int]$g[2].Value + (& $number $g[3].Value)
        $total += $seconds - (& $number $starts[-1].Matches[0].Groups[1].Value)
    }
    return [Math]::Round($total, 2)
}

# Mean frame-to-frame picture change, which needs no motion tracking. Scene
# changes (lights, moving people) count too, so it checks shake_px, not replaces it.
function Get-FrameChange([string]$Path) {
    $lines = & $FfmpegPath -v error -nostdin -i $Path -vf "$Analysis,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" -an -f null -
    if ($LASTEXITCODE -ne 0) { throw "Frame-change measure failed: $Path" }
    $values = @($lines | Select-String -Pattern 'YAVG=([0-9.]+)' | ForEach-Object { [double]::Parse($_.Matches[0].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) })
    return [Math]::Round(($values | Measure-Object -Average).Average, 3)
}

# Compares an output with its original on the same frames.
function Measure-Pair([string]$Original, [string]$Output, [string]$Work) {
    $before = @(Get-Motion $Original (Join-Path $Work 'in'))
    $after = @(Get-Motion $Output (Join-Path $Work 'out'))
    if ($before.Count -le $Window) { throw "Too few frames to measure shake: $Original" }
    if ([Math]::Abs($after.Count - $before.Count) -gt [Math]::Max(2, 0.01 * $before.Count)) {
        throw "Output has $($after.Count) frames at 30 fps, original $($before.Count): $Output"
    }
    $count = [Math]::Min($before.Count, $after.Count)
    $inResidual = @(Get-Residual $before)[0..($count - 1)]
    $outResidual = @(Get-Residual $after)[0..($count - 1)]
    # Large outliers can come from cuts, moving subjects or tracking failures.
    # The same original-based exclusions keep both measurements on equal frames.
    $sorted = @($inResidual.shake | Sort-Object)
    $limit = [Math]::Max(100 * $sorted[[int]($sorted.Count / 2)], 1.0)
    $keep = [bool[]]@($inResidual | ForEach-Object { $_.shake -le $limit })
    $inSummary = Get-Summary $inResidual $keep
    $outSummary = Get-Summary $outResidual $keep
    $changeIn = Get-FrameChange $Original
    $changeOut = Get-FrameChange $Output
    $frozenIn = Get-FrozenSeconds $Original
    $frozenOut = Get-FrozenSeconds $Output
    return [ordered]@{
        frames = $count; frames_dropped = @($keep | Where-Object { -not $_ }).Count
        original = $inSummary; output = $outSummary
        reduction = if ($inSummary.shake_px -gt 0) { [Math]::Round($outSummary.shake_px / $inSummary.shake_px, 3) } else { $null }
        frame_change_original = $changeIn; frame_change_output = $changeOut
        frame_change_ratio = if ($changeIn -gt 0) { [Math]::Round($changeOut / $changeIn, 3) } else { $null }
        # A hint to look at the clip, not a verdict: nearly every stabilized output has
        # a ratio below 1, and black borders may lower it. No test covers the true case.
        shake_score_suspect = $inSummary.shake_px -gt 0 -and ($outSummary.shake_px / $inSummary.shake_px) -gt 1.1 -and $changeIn -gt 0 -and ($changeOut / $changeIn) -le 1.0
        frozen_seconds_original = $frozenIn; frozen_seconds_output = $frozenOut
        frozen_output = ($frozenOut - $frozenIn) -gt 1.0
    }
}
function Get-DarkEdgePercent([string]$Path) {
    $lines = & $FfmpegPath -hide_banner -nostdin -i $Path -vf 'format=yuv420p,cropdetect=limit=24:round=2:reset=1' -f null - 2>&1 | ForEach-Object { "$_" }
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
        $original = Join-Path $clips $result.file_name
        $identical = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
        $pair = Measure-Pair $original $output (Join-Path $scratch ($result.file_name -replace '[^A-Za-z0-9._-]', '_'))
        $entry = [ordered]@{ file_name = $result.file_name; engine = $run.engine; settings_name = $run.settings_name; elapsed_ms = $result.elapsed_ms }
        foreach ($key in $pair.Keys) { $entry[$key] = $pair[$key] }
        $entry.observed_dark_edges_pct = Get-DarkEdgePercent $output
        $mask = Join-Path $folder 'work/border-union.pgm'
        if ($identical) {
            $entry.crop_pct = 0.0; $entry.crop_status = 'unchanged_bytes'
        } elseif (Test-Path -LiteralPath $mask -PathType Leaf) {
            $valid = & $PSScriptRoot/get-valid-crop.ps1 -MaskPath $mask | ConvertFrom-Json
            $entry.crop_pct = $valid.crop_pct; $entry.crop_status = 'geometric_mask'
        } else {
            $entry.crop_pct = $null; $entry.crop_status = 'geometric_measurement_unavailable'
        }
        $entry
    }
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
$file = [IO.File]::Open($metricsPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((@{ measurement_version = 4; window_frames = $Window; analysis = $Analysis; clips = @($metrics) } | ConvertTo-Json -Depth 6) + [Environment]::NewLine)
    $file.Write($bytes, 0, $bytes.Length)
} finally { $file.Dispose() }
Write-Output $metricsPath
