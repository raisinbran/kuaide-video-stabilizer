#requires -Version 7.0
# Checks the libvidstab engine and measure-run.ps1 on the synthetic shaken still:
# the copy baseline must measure as unchanged, libvidstab must cut the shake to
# under half with a small crop, and unsafe filter options must be refused.
param([Parameter(Mandatory)][string]$FfmpegPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$pwsh = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-libvidstab-tests-' + [Guid]::NewGuid().ToString('N'))
$clips = Join-Path $work 'clips'
$prior = $env:KUAIDE_CLIPS_DIR

function Invoke-Script([string]$Name, [string[]]$Arguments) {
    $messages = & $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot $Name) @Arguments 2>&1
    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
}

function Measure-Settings([string]$SettingsPath, [string]$Name) {
    $run = Join-Path $work "run-$Name"
    $result = Invoke-Script 'run-benchmark.ps1' @('-SettingsPath', $SettingsPath, '-OutputDirectory', $run, '-ManifestPath', (Join-Path $work 'manifest/clips.manifest.json'), '-FfmpegPath', $FfmpegPath)
    Assert-True ($result.exit_code -eq 0) "Run failed for $Name`: $($result.messages)"
    $result = Invoke-Script 'measure-run.ps1' @('-RunDirectory', $run, '-FfmpegPath', $FfmpegPath)
    Assert-True ($result.exit_code -eq 0) "Measurement failed for $Name`: $($result.messages)"
    return @((Get-Content -LiteralPath (Join-Path $run 'metrics.json') -Raw | ConvertFrom-Json).clips | Where-Object file_name -eq 'shaken-still.mp4')[0]
}

try {
    $made = Invoke-Script 'make-synthetic-clips.ps1' @('-FfmpegPath', $FfmpegPath, '-OutputDirectory', $clips)
    Assert-True ($made.exit_code -eq 0) $made.messages
    $env:KUAIDE_CLIPS_DIR = $clips
    $manifest = New-Item -ItemType Directory -Path (Join-Path $work 'manifest')
    $listed = Invoke-Script 'write-clip-manifest.ps1' @('-OutputDirectory', $manifest.FullName)
    Assert-True ($listed.exit_code -eq 0) $listed.messages

    $copy = Measure-Settings (Join-Path $PSScriptRoot 'settings/copy-baseline.json') 'copy'
    Assert-True ([Math]::Abs($copy.reduction - 1) -lt 0.02 -and $copy.crop_pct -lt 1 -and $copy.original.shake_px -gt 10) "Copy baseline did not measure as unchanged: $($copy | ConvertTo-Json -Compress)"
    Write-Output 'PASS the unstabilized baseline measures as unchanged with no crop'

    $stabilized = Measure-Settings (Join-Path $PSScriptRoot 'settings/libvidstab-auto.json') 'auto'
    Assert-True ($stabilized.reduction -lt 0.5 -and $stabilized.crop_pct -gt 0 -and $stabilized.crop_pct -lt 30) "libvidstab did not reduce shake as expected: $($stabilized | ConvertTo-Json -Compress)"
    Write-Output "PASS libvidstab cuts synthetic shake to $([int]($stabilized.reduction * 100))% with $($stabilized.crop_pct)% crop"

    $unsafe = Join-Path $work 'unsafe.json'
    @{ engine = 'libvidstab'; name = 'unsafe'; detect = 'shakiness=5'; transform = 'smoothing=10,drawtext=text=x'; preset = 'veryfast'; crf = 18 } | ConvertTo-Json | Set-Content -LiteralPath $unsafe
    $refused = Invoke-Script 'run-benchmark.ps1' @('-SettingsPath', $unsafe, '-OutputDirectory', (Join-Path $work 'run-unsafe'), '-ManifestPath', (Join-Path $work 'manifest/clips.manifest.json'), '-FfmpegPath', $FfmpegPath)
    $report = Get-Content -LiteralPath (Join-Path $work 'run-unsafe/run.json') -Raw | ConvertFrom-Json
    Assert-True ($refused.exit_code -eq 1 -and @($report.results | Where-Object { $_.status -eq 'failed' -and $_.log_tail -match 'Unsafe filter options' }).Count -eq $report.clips) 'Unsafe filter options were not refused.'
    Write-Output 'PASS filter options that add filters or name files are refused'
    Write-Output "Scratch results: $work"
} finally {
    $env:KUAIDE_CLIPS_DIR = $prior
}
