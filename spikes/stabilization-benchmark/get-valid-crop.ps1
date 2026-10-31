#requires -Version 7.0
# WP 1A.2: finds the largest rectangle with the frame's own shape that contains
# no border pixel, in a border-union image (binary PGM, 8-bit): dark is picture
# in every frame, bright is border in at least one frame. An engine makes this
# image by moving an all-white copy of the clip the same way as the real video,
# so dark scenery cannot read as border and tilted corners are included.
# Prints JSON: crop_pct is the share of the frame area outside that rectangle.
param([Parameter(Mandatory)][string]$MaskPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$BorderThreshold = 32

$bytes = [IO.File]::ReadAllBytes($MaskPath)
# Header: P5, width, height, maximum, each followed by one whitespace byte.
$position = 0; $fields = @()
while ($fields.Count -lt 4) {
    while ([char]$bytes[$position] -match '\s') { $position++ }
    $start = $position
    while ([char]$bytes[$position] -notmatch '\s') { $position++ }
    $fields += [Text.Encoding]::ASCII.GetString($bytes, $start, $position - $start)
}
$position++
if ($fields[0] -ne 'P5' -or [int]$fields[3] -ne 255) { throw "Not an 8-bit binary PGM: $MaskPath" }
$width = [int]$fields[1]; $height = [int]$fields[2]
if ($bytes.Length - $position -ne $width * $height) { throw "PGM size does not match its header: $MaskPath" }

# Summed-area table of border pixels: any rectangle's border count in four lookups.
$sum = [int[]]::new(($width + 1) * ($height + 1))
$stride = $width + 1
for ($y = 0; $y -lt $height; $y++) {
    $row = 0
    for ($x = 0; $x -lt $width; $x++) {
        if ($bytes[$position + $y * $width + $x] -gt $BorderThreshold) { $row++ }
        $sum[($y + 1) * $stride + $x + 1] = $sum[$y * $stride + $x + 1] + $row
    }
}

function Test-Fits([int]$W, [int]$H) {
    for ($y = 0; $y + $H -le $height; $y++) {
        for ($x = 0; $x + $W -le $width; $x++) {
            $inside = $sum[($y + $H) * $stride + $x + $W] - $sum[$y * $stride + $x + $W] - $sum[($y + $H) * $stride + $x] + $sum[$y * $stride + $x]
            if ($inside -eq 0) { return $true }
        }
    }
    return $false
}

# If a rectangle fits, every smaller one of the same shape fits: search on width.
$low = 0; $high = $width
while ($low -lt $high) {
    $middle = [int][Math]::Ceiling(($low + $high) / 2)
    $h = [int][Math]::Floor($middle * $height / $width)
    if ($h -ge 1 -and (Test-Fits $middle $h)) { $low = $middle } else { $high = $middle - 1 }
}
$keptHeight = [int][Math]::Floor($low * $height / $width)
[ordered]@{
    mask_width = $width; mask_height = $height; kept_width = $low; kept_height = $keptHeight
    crop_pct = [Math]::Round(100 * (1 - ($low * $keptHeight) / ($width * $height)), 2)
} | ConvertTo-Json -Compress
