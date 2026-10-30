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
    $inClips = Invoke-Harness $baseline (Join-Path $clips 'outputs')
    Assert-True ($existing.exit_code -ne 0 -and $insideRun.exit_code -ne 0 -and -not (Test-Path -LiteralPath $inside) -and
        $inClips.exit_code -ne 0 -and -not (Test-Path (Join-Path $clips 'outputs'))) 'An existing, in-repo or in-clips output folder was accepted.'
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
    $engineParams = 'param($InputPath, $OutputPath, $SettingsPath, $WorkDirectory, $FfmpegPath)'
    $fixtures = @{
        fail = 'Write-Error "engine broke"; exit 3'
        hang = 'Start-Sleep -Seconds 60'
        # Starts a detached program that outlives the engine; the harness must not wait for it.
        orphan = "Start-Process -FilePath '$pwsh' -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 30' -WindowStyle Hidden; Copy-Item -LiteralPath `$InputPath -Destination `$OutputPath"
        tamper = 'Copy-Item -LiteralPath $InputPath -Destination $OutputPath; [IO.File]::AppendAllText($InputPath, "x")'
    }
    foreach ($name in $fixtures.Keys) {
        Set-Content -LiteralPath (Join-Path $engines "$name.ps1") -Value "$engineParams; $($fixtures[$name])"
        Set-Content -LiteralPath (Join-Path $work "$name.json") -Value (@{ engine = $name; name = 'fixture' } | ConvertTo-Json)
    }
    $failRun = Join-Path $work 'run-fail'
    $failed = Invoke-Harness (Join-Path $work 'fail.json') $failRun @('-EngineDirectory', $engines)
    $failReport = Get-Content -LiteralPath (Join-Path $failRun 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($failed.exit_code -eq 1 -and $failReport.failed -eq 3 -and @($failReport.results | Where-Object { $_.exit_code -eq 3 -and $_.log_tail -match 'engine broke' }).Count -eq 3) 'A failing engine was not recorded for every clip.'
    $hangRun = Join-Path $work 'run-hang'
    $hung = Invoke-Harness (Join-Path $work 'hang.json') $hangRun @('-EngineDirectory', $engines, '-TimeoutSeconds', '3')
    $hangReport = Get-Content -LiteralPath (Join-Path $hangRun 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($hung.exit_code -eq 1 -and @($hangReport.results | Where-Object { $_.timed_out -and $_.status -eq 'failed' }).Count -eq 3) 'A hung engine was not stopped and recorded.'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $orphaned = Invoke-Harness (Join-Path $work 'orphan.json') (Join-Path $work 'run-orphan') @('-EngineDirectory', $engines)
    Assert-True ($orphaned.exit_code -eq 0 -and $watch.Elapsed.TotalSeconds -lt 20) "A program left running by the engine held the harness ($([int]$watch.Elapsed.TotalSeconds) s)."
    Write-Output 'PASS failed, hung and orphaning engines are recorded per clip without holding the run'

    $tamperRun = Join-Path $work 'run-tamper'
    $tampered = Invoke-Harness (Join-Path $work 'tamper.json') $tamperRun @('-EngineDirectory', $engines)
    $tamperReport = Get-Content -LiteralPath (Join-Path $tamperRun 'run.json') -Raw | ConvertFrom-Json
    Assert-True ($tampered.exit_code -eq 2 -and $tamperReport.completed -eq 1 -and $tamperReport.results[0].status -eq 'input_changed' -and $tamperReport.stopped) 'An engine that changed an original was not caught and stopped.'
    Write-Output 'PASS an engine that changes an original clip stops the run'

    $collide = Join-Path $work 'collide.manifest.json'
    $entry = (Get-Content -LiteralPath (Join-Path $work 'manifest/clips.manifest.json') -Raw | ConvertFrom-Json).files | Where-Object file_name -eq 'shaken-still.mp4'
    foreach ($name in @('a b.mp4', 'a_b.mp4')) { Copy-Item -LiteralPath (Join-Path $clips 'shaken-still.mp4') -Destination (Join-Path $clips $name) }
    @{ files = @(foreach ($name in @('a b.mp4', 'a_b.mp4')) { [ordered]@{ file_name = $name; size_bytes = $entry.size_bytes; sha256 = $entry.sha256 } }) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $collide
    $messages = & $pwsh -NoProfile -NonInteractive -File $harness -SettingsPath $baseline -OutputDirectory (Join-Path $work 'run-collide') -ManifestPath $collide 2>&1
    Assert-True ($LASTEXITCODE -ne 0 -and ($messages -join "`n") -match 'same output folder' -and -not (Test-Path (Join-Path $work 'run-collide'))) 'Colliding folder names were not refused before running.'
    Write-Output 'PASS clips whose folder names collide are refused before any engine starts'
    Write-Output "Scratch results: $work"
} finally {
    $env:KUAIDE_CLIPS_DIR = $prior
}