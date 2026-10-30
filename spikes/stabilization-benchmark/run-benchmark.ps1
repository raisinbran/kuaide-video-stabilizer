#requires -Version 7.0
# WP 1A.1: runs one stabilization engine with one settings file on every clip in
# a manifest, and records run time, exit code and output hash per clip.
#
# An engine is a script `<EngineDirectory>/<engine>.ps1` that accepts
# -InputPath, -OutputPath, -SettingsPath, -WorkDirectory and -FfmpegPath, and
# exits 0 after writing OutputPath. It must wait for any program it starts.
# The settings file is JSON with at least `engine` and `name`; the engine reads
# the rest itself.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'clips.manifest.json'),
    [string]$EngineDirectory = (Join-Path $PSScriptRoot 'engines'),
    [string]$FfmpegPath = '',
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = 1800
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Inside([string]$Path, [string]$Directory) {
    $prefix = [IO.Path]::GetFullPath($Directory).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return ($Path.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Test-ClipUnchanged($Entry) {
    $path = Join-Path $clips $Entry.file_name
    return (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path -Force).Length -eq $Entry.size_bytes -and
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $Entry.sha256
}

# Runs one engine through invoke-engine.ps1 in its own process. Output goes to
# a log file, so a program the engine leaves running cannot hold the harness;
# on timeout the whole process tree is killed.
function Invoke-Engine([string[]]$Arguments, [string]$WorkDirectory) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($argument in @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'invoke-engine.ps1')) + $Arguments) { $start.ArgumentList.Add($argument) }
    $start.WorkingDirectory = $WorkDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($start)
    try {
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
        return [ordered]@{ exit_code = $process.ExitCode; timed_out = $timedOut; elapsed_ms = $watch.ElapsedMilliseconds }
    } finally { $process.Dispose() }
}

function Write-NewJson([string]$Path, $Value) {
    $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
        $file.Write($bytes, 0, $bytes.Length)
    } finally { $file.Dispose() }
}

$clips = $env:KUAIDE_CLIPS_DIR
if ([string]::IsNullOrWhiteSpace($clips)) { throw 'Set KUAIDE_CLIPS_DIR to the original-clips directory.' }
$settingsFile = (Get-Item -LiteralPath $SettingsPath).FullName
$settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
foreach ($field in @('engine', 'name')) {
    if (-not $settings.PSObject.Properties[$field] -or -not "$($settings.$field)") { throw "Settings file lacks '$field'." }
}
if ($settings.engine -notmatch '^[a-z0-9-]+$') { throw 'Engine names use lowercase letters, digits and dashes only.' }
$engine = Join-Path $EngineDirectory "$($settings.engine).ps1"
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw "No engine script: $engine" }

$output = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist; choose a new folder outside the repository.' }
if (Test-Inside $output (Join-Path $PSScriptRoot '../..')) { throw 'Output must be outside the repository.' }
if (Test-Inside $output $clips) { throw 'Output must be outside the clips directory.' }

# Check every clip and every output folder name before running anything.
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$folders = @{}
foreach ($entry in $manifest.files) {
    if (-not (Test-Path -LiteralPath (Join-Path $clips $entry.file_name) -PathType Leaf)) { throw "Clip missing: $($entry.file_name)" }
    if (-not (Test-ClipUnchanged $entry)) { throw "Clip differs from the manifest: $($entry.file_name)" }
    # The full name, extension included: clip.mp4 and clip.webm need separate folders.
    $folder = $entry.file_name -replace '[^A-Za-z0-9._-]', '_'
    if ($folders.ContainsKey($folder.ToLowerInvariant())) { throw "Two clips map to the same output folder: $($entry.file_name)" }
    $folders[$folder.ToLowerInvariant()] = $folder
}

[IO.Directory]::CreateDirectory($output) | Out-Null
$results = [Collections.Generic.List[object]]::new()
$stopped = $null
try {
    foreach ($entry in $manifest.files) {
        $clipDirectory = Join-Path $output ($entry.file_name -replace '[^A-Za-z0-9._-]', '_')
        $work = Join-Path $clipDirectory 'work'
        [IO.Directory]::CreateDirectory($work) | Out-Null
        # Engines write MP4 unless the settings say `"output_extension": "same"` (keep the input's).
        $extension = if ($settings.PSObject.Properties['output_extension'] -and $settings.output_extension -eq 'same') { [IO.Path]::GetExtension($entry.file_name) } else { '.mp4' }
        $outputPath = Join-Path $clipDirectory "output$extension"
        $logPath = Join-Path $clipDirectory 'engine.log'
        $run = Invoke-Engine @('-EnginePath', $engine, '-LogPath', $logPath, '-InputPath', (Join-Path $clips $entry.file_name), '-OutputPath', $outputPath,
            '-SettingsPath', $settingsFile, '-WorkDirectory', $work, '-FfmpegPath', $FfmpegPath) $work
        $inputUnchanged = Test-ClipUnchanged $entry
        $produced = Test-Path -LiteralPath $outputPath -PathType Leaf
        $status = if (-not $inputUnchanged) { 'input_changed' } elseif ($run.exit_code -eq 0 -and -not $run.timed_out -and $produced) { 'ok' } else { 'failed' }
        $log = if (Test-Path -LiteralPath $logPath) { @(Get-Content -LiteralPath $logPath -Tail 20) -join "`n" } else { '' }
        $result = [ordered]@{
            file_name = $entry.file_name; input_sha256 = $entry.sha256
            engine = $settings.engine; settings_name = $settings.name; status = $status
            exit_code = $run.exit_code; timed_out = $run.timed_out; elapsed_ms = $run.elapsed_ms
            output_sha256 = if ($produced) { (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
            output_bytes = if ($produced) { (Get-Item -LiteralPath $outputPath).Length } else { $null }
            log_tail = $log
        }
        Write-NewJson (Join-Path $clipDirectory 'result.json') $result
        $results.Add($result)
        # An engine that alters an original must not touch any more clips.
        if (-not $inputUnchanged) { $stopped = "Engine changed the original clip: $($entry.file_name)"; break }
    }
} finally {
    $failed = @($results | Where-Object { $_.status -ne 'ok' }).Count
    Write-NewJson (Join-Path $output 'run.json') ([ordered]@{
        generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o'); engine = $settings.engine; settings_name = $settings.name
        settings = $settings; clips = $manifest.files.Count; completed = $results.Count; failed = $failed; stopped = $stopped; results = @($results)
    })
}
Write-Output (Join-Path $output 'run.json')
if ($stopped) { Write-Error $stopped -ErrorAction Continue; exit 2 }
if ($failed -gt 0) { exit 1 }
