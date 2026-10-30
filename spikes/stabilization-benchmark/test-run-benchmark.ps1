#requires -Version 7.0
# Checks make-synthetic-clips.ps1 and run-benchmark.ps1 end to end with the
# copy engine and two fixture engines (one fails, one hangs).
param([Parameter(Mandatory)][string]$FfmpegPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$pwsh = (Get-Process -Id $PID).Path
$harness = Join-Path $PSScriptRoot 'run-benchmark.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-harness-tests-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
$clips = Join-Path $work 'clips'
$prior = $env:KUAIDE_CLIPS_DIR

function Invoke-Harness([string]$Settings, [string]$Output, [string[]]$Extra = @()) {
    $messages = & $pwsh -NoProfile -NonInteractive -File $harness -SettingsPath $Settings -OutputDirectory $Output -ManifestPath (Join-Path $work 'manifest/clips.manifest.json') @Extra 2>&1
    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
}

try {
    & $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'make-synthetic-clips.ps1') -FfmpegPath $FfmpegPath -OutputDirectory $clips | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'Synthetic clips were not made.'
    $env:KUAIDE_CLIPS_DIR = $clips
    $manifestDirectory = New-Item -ItemType Directory -Path (Join-Path $work 'manifest')
    & $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'write-clip-manifest.ps1') -OutputDirectory $manifestDirectory.FullName | Out-Null
    $manifest = Get-Content -LiteralPath (Join-Path $manifestDirectory.FullName 'clips.manifest.json') -Raw | ConvertFrom-Json
    Assert-True ((@($manifest.files.file_name) -join ',') -eq 'hard-cut.mp4,shaken-still.mp4') 'Synthetic clips are missing from the manifest.'
    Write-Output 'PASS synthetic shaken and hard-cut clips are made and listed'

    # Real clip sets have names that differ only by extension (Caltrain .mp4 and .webm).
    Copy-Item -LiteralPath (Join-Path $clips 'shaken-still.mp4') -Destination (Join-Path $clips 'shaken-still.mov')
    Remove-Item -LiteralPath (Join-Path $manifestDirectory.FullName 'clips.manifest.json')
    & $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'write-clip-manifest.ps1') -OutputDirectory $manifestDirectory.FullName | Out-Null

    $baseline = Join-Path $PSScriptRoot 'settings/copy-baseline.json'
    $run = Join-Path $work 'run-copy'
    $result = Invoke-Harness $baseline $run
    Assert-True ($result.exit_code -eq 0) $result.messages
    $report = Get-Content -LiteralPath (Join-Path $run 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($report.failed -eq 0 -and @($report.results).Count -eq 3) 'Copy run did not succeed for every clip.'
    foreach ($clip in $report.results) {
        Assert-True ($clip.status -eq 'ok' -and $clip.output_sha256 -eq $clip.input_sha256 -and $clip.elapsed_ms -ge 0) "Copy output differs: $($clip.file_name)"
    }
    Write-Output 'PASS copy engine runs every clip and records matching hashes'

    $existing = Invoke-Harness $baseline $run
    $inside = Join-Path $PSScriptRoot 'harness-output-must-not-exist'
    $insideRun = Invoke-Harness $baseline $inside
    Assert-True ($existing.exit_code -ne 0 -and $insideRun.exit_code -ne 0 -and -not (Test-Path -LiteralPath $inside)) 'An existing or in-repo output folder was accepted.'
    [IO.File]::AppendAllText((Join-Path $clips 'hard-cut.mp4'), 'x')
    $changed = Invoke-Harness $baseline (Join-Path $work 'run-changed')
    Assert-True ($changed.exit_code -ne 0 -and $changed.messages -match 'differs from the manifest' -and -not (Test-Path (Join-Path $work 'run-changed'))) 'A changed clip was run.'
    Write-Output 'PASS output guards and the clip check stop the run before any engine starts'

    # Fresh clips, because the previous step changed one of the originals. The
    # clip script gives identical bytes on each run, so the manifest still matches.
    $clips = Join-Path $work 'clips-2'
    & $pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'make-synthetic-clips.ps1') -FfmpegPath $FfmpegPath -OutputDirectory $clips | Out-Null
    Copy-Item -LiteralPath (Join-Path $clips 'shaken-still.mp4') -Destination (Join-Path $clips 'shaken-still.mov')
    $env:KUAIDE_CLIPS_DIR = $clips
    $engines = (New-Item -ItemType Directory -Path (Join-Path $work 'engines')).FullName
    Set-Content -LiteralPath (Join-Path $engines 'fail.ps1') -Value 'param($InputPath, $OutputPath, $SettingsPath, $WorkDirectory, $FfmpegPath); Write-Error "engine broke"; exit 3'
    Set-Content -LiteralPath (Join-Path $engines 'hang.ps1') -Value 'param($InputPath, $OutputPath, $SettingsPath, $WorkDirectory, $FfmpegPath); Start-Sleep -Seconds 60'
    foreach ($name in @('fail', 'hang')) {
        Set-Content -LiteralPath (Join-Path $work "$name.json") -Value (@{ engine = $name; name = 'fixture' } | ConvertTo-Json)
    }
    $failRun = Join-Path $work 'run-fail'
    $failed = Invoke-Harness (Join-Path $work 'fail.json') $failRun @('-EngineDirectory', $engines)
    $failReport = Get-Content -LiteralPath (Join-Path $failRun 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($failed.exit_code -eq 1 -and $failReport.failed -eq 3 -and @($failReport.results | Where-Object { $_.exit_code -eq 3 -and $_.stderr_tail -match 'engine broke' }).Count -eq 3) 'A failing engine was not recorded for every clip.'
    $hangRun = Join-Path $work 'run-hang'
    $hung = Invoke-Harness (Join-Path $work 'hang.json') $hangRun @('-EngineDirectory', $engines, '-TimeoutSeconds', '3')
    $hangReport = Get-Content -LiteralPath (Join-Path $hangRun 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($hung.exit_code -eq 1 -and @($hangReport.results | Where-Object { $_.timed_out -and $_.status -eq 'failed' }).Count -eq 3) 'A hung engine was not stopped and recorded.'
    Write-Output 'PASS failed and hung engines are recorded per clip and the run exits 1'
    Write-Output "Scratch results: $work"
} finally {
    $env:KUAIDE_CLIPS_DIR = $prior
}
