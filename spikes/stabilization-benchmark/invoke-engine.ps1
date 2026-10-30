#requires -Version 7.0
# Runs one engine script in this process and sends all of its output to a log
# file. run-benchmark.ps1 starts this in a separate process, so no output pipe
# connects the harness to the engine or to anything the engine starts.
param(
    [Parameter(Mandatory)][string]$EnginePath,
    [Parameter(Mandatory)][string]$LogPath,
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$WorkDirectory,
    [string]$FfmpegPath = ''
)
$global:LASTEXITCODE = 0
try {
    & $EnginePath -InputPath $InputPath -OutputPath $OutputPath -SettingsPath $SettingsPath -WorkDirectory $WorkDirectory -FfmpegPath $FfmpegPath *>> $LogPath
    $code = $LASTEXITCODE
} catch {
    $_ | Out-String | Add-Content -LiteralPath $LogPath
    $code = 1
}
exit $code
