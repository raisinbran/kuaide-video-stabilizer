#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$collector = Join-Path $PSScriptRoot 'collect-build-inventory.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-inventory-tests-' + [Guid]::NewGuid().ToString('N'))
$tools = New-Item -ItemType Directory -Path (Join-Path $work 'tools')
$fixture = Join-Path $tools.FullName 'media tool.ps1'
@(
    'if ($args -contains ''-version'') { ''ffmpeg version fixture''; exit 0 }',
    'if ($args -contains ''-buildconf'') { [Console]::Error.WriteLine(''configuration: --enable-libx264 --enable-libvidstab''); exit 0 }',
    'if ($args -contains ''-filters'') { '' ... vidstabdetect V->V''; exit 0 }',
    'if ($args -contains ''-encoders'') { '' V..... h264_nvenc''; exit 0 }',
    'exit 7'
) | Set-Content -LiteralPath $fixture -Encoding utf8
$pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Collector([string]$Directory, [string]$Tool = $fixture, [int]$Timeout = 15) {
    $messages = & $pwsh -NoProfile -NonInteractive -File $collector -FfmpegPath $Tool -FfprobePath $fixture -OutputDirectory $Directory -TimeoutSeconds $Timeout 2>&1
    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
}

$output = New-Item -ItemType Directory -Path (Join-Path $work 'success')
$result = Invoke-Collector $output.FullName
Assert-True ($result.exit_code -eq 0) $result.messages
$report = Get-Content -LiteralPath (Join-Path $output.FullName 'build-inventory.json') -Raw | ConvertFrom-Json
Assert-True ($report.tools.ffmpeg.sha256 -eq (Get-FileHash -LiteralPath $fixture).Hash.ToLowerInvariant()) 'Wrong tool hash.'
Assert-True ($report.tools.ffmpeg.commands.encoders.stdout -match 'h264_nvenc') 'Encoder listing missing.'
Assert-True ($report.tools.ffmpeg.commands.filters.stdout -match 'vidstabdetect') 'Filter listing missing.'
Assert-True ($report.tools.ffprobe.commands.buildconf.stderr -match '--enable-libvidstab') 'Build configuration stderr lost.'
Assert-True ($report.provenance.source_status -eq 'unknown' -and $report.provenance.license_status -eq 'unknown') 'Unknown provenance overstated.'
Assert-True ($report.evidence -match 'no encode, decode, filter or hardware execution tested') 'Inventory must not claim runtime validation.'
Assert-True ($report.tools.ffmpeg.commands.version.stdout -match 'version fixture' -and $report.tools.ffprobe.commands.version.stdout -match 'version fixture') 'Version evidence missing.'
Write-Output 'PASS inventory preserves raw evidence and unknown provenance'

$license = Join-Path $work 'COPYING.txt'
'Fixture license text' | Set-Content -LiteralPath $license
$output = New-Item -ItemType Directory -Path (Join-Path $work 'supplied')
$messages = & $pwsh -NoProfile -NonInteractive -File $collector -FfmpegPath $fixture -FfprobePath $fixture -OutputDirectory $output.FullName -SourceUrl 'https://example.invalid/build.zip' -LicensePath $license 2>&1
Assert-True ($LASTEXITCODE -eq 0) ($messages -join "`n")
$report = Get-Content -LiteralPath (Join-Path $output.FullName 'build-inventory.json') -Raw | ConvertFrom-Json
Assert-True ($report.provenance.source_url -eq 'https://example.invalid/build.zip' -and $report.provenance.source_status -eq 'caller-supplied; not verified') 'Supplied source was promoted to verified provenance.'
Assert-True ($report.provenance.license.text.Trim() -eq 'Fixture license text' -and $report.provenance.license.sha256 -eq (Get-FileHash -LiteralPath $license).Hash.ToLowerInvariant()) 'Supplied license evidence changed.'
Assert-True ($report.provenance.license_status -eq 'caller-supplied; applicability not verified') 'Supplied license was promoted to verified applicability.'
Write-Output 'PASS supplied provenance remains unverified'

$before = (Get-FileHash -LiteralPath (Join-Path $output.FullName 'build-inventory.json')).Hash
$result = Invoke-Collector $output.FullName
Assert-True ($result.exit_code -ne 0) 'Existing report was accepted.'
Assert-True ((Get-FileHash -LiteralPath (Join-Path $output.FullName 'build-inventory.json')).Hash -eq $before) 'Existing report changed.'
$result = Invoke-Collector $tools.FullName
Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $tools.FullName 'build-inventory.json'))) 'Tool directory was writable.'
$result = Invoke-Collector $PSScriptRoot
Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $PSScriptRoot 'build-inventory.json'))) 'Repository output was accepted.'
Write-Output 'PASS output guards preserve existing files and source locations'

$failing = Join-Path $tools.FullName 'failing.ps1'
'exit 9' | Set-Content -LiteralPath $failing
$output = New-Item -ItemType Directory -Path (Join-Path $work 'failure')
$result = Invoke-Collector $output.FullName $failing
Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $output.FullName 'build-inventory.json'))) 'Failed tool produced a report.'
$hanging = Join-Path $tools.FullName 'hanging.ps1'
'Start-Sleep -Seconds 30' | Set-Content -LiteralPath $hanging
$output = New-Item -ItemType Directory -Path (Join-Path $work 'timeout')
$watch = [Diagnostics.Stopwatch]::StartNew()
$result = Invoke-Collector $output.FullName $hanging 1
Assert-True ($result.exit_code -ne 0 -and $result.messages -match 'timed out') 'Hung tool did not report timeout.'
Assert-True ($watch.Elapsed.TotalSeconds -lt 15 -and -not (Test-Path (Join-Path $output.FullName 'build-inventory.json'))) 'Timeout did not bound collection.'
Write-Output 'PASS failed and hung tools leave no inventory'
Write-Output "Scratch results: $work"
