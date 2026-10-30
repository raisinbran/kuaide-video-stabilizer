#requires -Version 7.0
# Checks the libvidstab engine and measure-run.ps1 on the synthetic shaken still:
# the copy baseline must measure as unchanged, libvidstab must cut the shake to
# under half with a measured crop, and unsafe filter options must be refused.
# Outputs without a border image keep crop unavailable.
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
    Assert-True ([Math]::Abs($copy.reduction - 1) -lt 0.02 -and $copy.crop_pct -eq 0 -and $copy.crop_status -eq 'unchanged_bytes' -and $copy.original.shake_px -gt 10) "Copy baseline did not measure as unchanged: $($copy | ConvertTo-Json -Compress)"
    Write-Output 'PASS the unstabilized baseline measures as unchanged with no crop'

    $stabilized = Measure-Settings (Join-Path $PSScriptRoot 'settings/libvidstab-auto.json') 'auto'
    Assert-True ($stabilized.reduction -lt 0.5 -and $stabilized.crop_status -eq 'geometric_mask' -and $stabilized.crop_pct -gt 2 -and $stabilized.crop_pct -lt 50) "libvidstab did not reduce shake with a measured crop: $($stabilized | ConvertTo-Json -Compress)"
    Write-Output "PASS libvidstab cuts synthetic shake to $([int]($stabilized.reduction * 100))% with $($stabilized.crop_pct)% crop"

    $unsafe = Join-Path $work 'unsafe.json'
    @{ engine = 'libvidstab'; name = 'unsafe'; detect = 'shakiness=5'; transform = 'smoothing=10,drawtext=text=x'; preset = 'veryfast'; crf = 18 } | ConvertTo-Json | Set-Content -LiteralPath $unsafe
    $refused = Invoke-Script 'run-benchmark.ps1' @('-SettingsPath', $unsafe, '-OutputDirectory', (Join-Path $work 'run-unsafe'), '-ManifestPath', (Join-Path $work 'manifest/clips.manifest.json'), '-FfmpegPath', $FfmpegPath)
    $report = Get-Content -LiteralPath (Join-Path $work 'run-unsafe/run.json') -Raw | ConvertFrom-Json
    Assert-True ($refused.exit_code -eq 1 -and @($report.results | Where-Object { $_.status -eq 'failed' -and $_.log_tail -match 'Unsafe filter options' }).Count -eq $report.clips) 'Unsafe filter options were not refused.'
    Write-Output 'PASS filter options that add filters or name files are refused'

    # Stand-in engines that would fool a careless measure.
    $engines = Join-Path $work 'engines'
    [IO.Directory]::CreateDirectory($engines) | Out-Null
    $params = 'param($InputPath, $OutputPath, $SettingsPath, $WorkDirectory, $FfmpegPath)'
    $fixtures = @{
        fps60 = "& `$FfmpegPath -v error -nostdin -i `$InputPath -vf 'minterpolate=fps=60' -c:v libx264 -preset veryfast -crf 18 `$OutputPath"
        frozen = "& `$FfmpegPath -v error -nostdin -i `$InputPath -vf 'select=eq(n\,0),loop=loop=-1:size=1,trim=end_frame=120,setpts=N/30/TB' -c:v libx264 -preset veryfast -crf 18 `$OutputPath"
        short = "& `$FfmpegPath -v error -nostdin -i `$InputPath -vf 'select=not(mod(n\,2)),setpts=N/30/TB' -c:v libx264 -preset veryfast -crf 18 `$OutputPath"
        dark = "& `$FfmpegPath -v error -nostdin -i `$InputPath -vf 'drawbox=x=0:y=0:w=iw:h=ih/5:color=black:t=fill' -c:v libx264 -preset veryfast -crf 18 `$OutputPath"
        rotated = "& `$FfmpegPath -v error -nostdin -i `$InputPath -vf 'rotate=0.1:fillcolor=black' -c:v libx264 -preset veryfast -crf 18 `$OutputPath"
    }
    $measured = @{}
    foreach ($name in $fixtures.Keys) {
        Set-Content -LiteralPath (Join-Path $engines "$name.ps1") -Value "$params; $($fixtures[$name])"
        $settings = Join-Path $work "$name.json"
        @{ engine = $name; name = 'fixture' } | ConvertTo-Json | Set-Content -LiteralPath $settings
        $run = Join-Path $work "run-$name"
        $result = Invoke-Script 'run-benchmark.ps1' @('-SettingsPath', $settings, '-OutputDirectory', $run, '-ManifestPath', (Join-Path $work 'manifest/clips.manifest.json'), '-FfmpegPath', $FfmpegPath, '-EngineDirectory', $engines)
        Assert-True ($result.exit_code -eq 0) "Fixture engine $name failed: $($result.messages)"
        $measured[$name] = Invoke-Script 'measure-run.ps1' @('-RunDirectory', $run, '-FfmpegPath', $FfmpegPath)
        if ($measured[$name].exit_code -eq 0) {
            $measured[$name].clip = @((Get-Content -LiteralPath (Join-Path $run 'metrics.json') -Raw | ConvertFrom-Json).clips | Where-Object file_name -eq 'shaken-still.mp4')[0]
        }
    }
    Assert-True ($measured.fps60.exit_code -eq 0 -and [Math]::Abs($measured.fps60.clip.reduction - 1) -lt 0.15) "A 60 fps copy did not measure as unchanged: $($measured.fps60.clip.reduction)"
    Write-Output 'PASS a higher frame rate alone does not count as stabilization'
    Assert-True ($measured.frozen.exit_code -eq 0 -and $measured.frozen.clip.frozen_output) 'A frozen output was not flagged.'
    Write-Output 'PASS a frozen output is flagged'
    Assert-True ($measured.short.exit_code -ne 0 -and $measured.short.messages -match 'frames at 30 fps') 'An output with half the frames was measured.'
    Write-Output 'PASS an output with missing frames is refused'
    foreach ($name in @('dark', 'rotated')) {
        Assert-True ($measured[$name].exit_code -eq 0 -and $null -eq $measured[$name].clip.crop_pct -and $measured[$name].clip.crop_status -eq 'geometric_measurement_unavailable') "Uncertain crop was presented as measured for $name."
    }
    Assert-True ($measured.dark.clip.observed_dark_edges_pct -gt 10) 'The dark-edge fixture did not exercise the misleading border detector.'
    Write-Output 'PASS dark edges and rotated corners do not become crop scores'

    # Known shapes: a band gives an exact answer; tilted corners must count though
    # the old border detector called a tilted white frame full size.
    $ppm = { param($Name, $Filter)
        $path = Join-Path $work $Name
        & $FfmpegPath -v error -nostdin -f lavfi -i 'color=white:s=320x180:d=0.1' -vf "$Filter,format=gray,negate" -frames:v 1 -c:v pgm -f image2 -update 1 $path
        Assert-True ($LASTEXITCODE -eq 0) "Could not make $Name"
        $path
    }
    $crop = { param($Path) (& $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'get-valid-crop.ps1') -MaskPath $Path) | ConvertFrom-Json }
    $whole = & $crop (& $ppm 'whole.pgm' 'null')
    $band = & $crop (& $ppm 'band.pgm' 'drawbox=x=0:y=0:w=32:h=ih:color=black:t=fill')
    $tilted = & $crop (& $ppm 'tilted.pgm' 'rotate=0.1:fillcolor=black')
    Assert-True ($whole.crop_pct -eq 0) "A frame without border lost $($whole.crop_pct)%."
    Assert-True ($band.kept_width -eq 288 -and [Math]::Abs($band.crop_pct - 19) -lt 0.5) "A 10% band should keep 90% of each side: $($band | ConvertTo-Json -Compress)"
    Assert-True ($tilted.crop_pct -gt 10 -and $tilted.crop_pct -lt 40) "Tilted corners were not counted: $($tilted | ConvertTo-Json -Compress)"
    Write-Output "PASS the valid rectangle is exact for a band and counts tilted corners ($($tilted.crop_pct)%)"
    Remove-Item -LiteralPath $work -Recurse -Force
} finally {
    $env:KUAIDE_CLIPS_DIR = $prior
}

