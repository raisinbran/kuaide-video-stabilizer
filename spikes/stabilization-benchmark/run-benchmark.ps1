#requires -Version 7.0
# WP 1A.1: runs one stabilization engine with one settings file on every clip in
# a manifest, and records run time, exit code and output hash per clip.
#
# An engine is a script `<EngineDirectory>/<engine>.ps1` that accepts
# -InputPath, -OutputPath, -SettingsPath, -WorkDirectory and -FfmpegPath, and
# exits 0 after writing OutputPath. The settings file is JSON with at least
# `engine` and `name`; the engine reads the rest itself.
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

function Get-Tail([string]$Text) {
    $lines = @($Text -split "`r?`n" | Where-Object { $_ })
    return ($lines | Select-Object -Last 20) -join "`n"
}

# Runs one engine in its own pwsh process; kills the whole process tree on timeout.
function Invoke-Engine([string[]]$Arguments, [string]$WorkDirectory) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($argument in @('-NoProfile', '-NonInteractive', '-File') + $Arguments) { $start.ArgumentList.Add($argument) }
    $start.WorkingDirectory = $WorkDirectory
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
        return [ordered]@{
            exit_code = $process.ExitCode; timed_out = $timedOut; elapsed_ms = $watch.ElapsedMilliseconds
            stdout_tail = Get-Tail $stdout.GetAwaiter().GetResult(); stderr_tail = Get-Tail $stderr.GetAwaiter().GetResult()
        }
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
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (($output + [IO.Path]::DirectorySeparatorChar).StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must be outside the repository.' }

# Check every clip before running anything, so a wrong folder fails fast.
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
foreach ($entry in $manifest.files) {
    $path = Join-Path $clips $entry.file_name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Clip missing: $($entry.file_name)" }
    if ((Get-Item -LiteralPath $path -Force).Length -ne $entry.size_bytes -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Clip differs from the manifest: $($entry.file_name)"
    }
}

[IO.Directory]::CreateDirectory($output) | Out-Null
$results = foreach ($entry in $manifest.files) {
    # The full name, extension included: clip.mp4 and clip.webm need separate folders.
    $clipDirectory = Join-Path $output ($entry.file_name -replace '[^A-Za-z0-9._-]', '_')
    if (Test-Path -LiteralPath $clipDirectory) { throw "Two clips map to the same output folder: $($entry.file_name)" }
    $work = Join-Path $clipDirectory 'work'
    [IO.Directory]::CreateDirectory($work) | Out-Null
    # Engines write MP4 unless the settings say `"output_extension": "same"` (keep the input's).
    $extension = if ($settings.PSObject.Properties['output_extension'] -and $settings.output_extension -eq 'same') { [IO.Path]::GetExtension($entry.file_name) } else { '.mp4' }
    $outputPath = Join-Path $clipDirectory "output$extension"
    $run = Invoke-Engine @($engine, '-InputPath', (Join-Path $clips $entry.file_name), '-OutputPath', $outputPath, '-SettingsPath', $settingsFile, '-WorkDirectory', $work, '-FfmpegPath', $FfmpegPath) $work
    $produced = Test-Path -LiteralPath $outputPath -PathType Leaf
    $result = [ordered]@{
        file_name = $entry.file_name; input_sha256 = $entry.sha256
        engine = $settings.engine; settings_name = $settings.name
        status = if ($run.exit_code -eq 0 -and -not $run.timed_out -and $produced) { 'ok' } else { 'failed' }
        output_sha256 = if ($produced) { (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
        output_bytes = if ($produced) { (Get-Item -LiteralPath $outputPath).Length } else { $null }
    }
    foreach ($key in $run.Keys) { $result[$key] = $run[$key] }
    Write-NewJson (Join-Path $clipDirectory 'result.json') $result
    $result
}
$failed = @($results | Where-Object { $_.status -ne 'ok' }).Count
Write-NewJson (Join-Path $output 'run.json') ([ordered]@{
    generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o'); engine = $settings.engine; settings_name = $settings.name
    settings = $settings; clips = $manifest.files.Count; failed = $failed; results = @($results)
})
Write-Output (Join-Path $output 'run.json')
if ($failed -gt 0) { exit 1 }
