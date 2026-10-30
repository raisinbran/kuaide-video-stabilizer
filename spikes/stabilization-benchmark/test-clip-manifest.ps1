#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$writer = Join-Path $PSScriptRoot 'write-clip-manifest.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-manifest-tests-' + [Guid]::NewGuid().ToString('N'))
$originals = New-Item -ItemType Directory -Path (Join-Path $work 'originals')
$output = New-Item -ItemType Directory -Path (Join-Path $work 'output')
[IO.File]::WriteAllBytes((Join-Path $originals.FullName 'space clip.mp4'), [byte[]]@(97, 98, 99))
[IO.File]::WriteAllBytes((Join-Path $originals.FullName '歩く clip.MOV'), [byte[]]@())
# Windows and Drive leave hidden files such as desktop.ini beside clips; they must not be listed.
$hidden = Join-Path $originals.FullName 'desktop.ini'
[IO.File]::WriteAllBytes($hidden, [byte[]]@(120))
[IO.File]::SetAttributes($hidden, [IO.FileAttributes]::Hidden)
$pwsh = (Get-Process -Id $PID).Path
$priorClips = $env:KUAIDE_CLIPS_DIR

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Manifest([string]$Directory) {
    $messages = & $pwsh -NoProfile -NonInteractive -File $writer -OutputDirectory $Directory 2>&1
    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
}

try {
    $env:KUAIDE_CLIPS_DIR = $originals.FullName
    $result = Invoke-Manifest $output.FullName
    Assert-True ($result.exit_code -eq 0) $result.messages
    $manifestPath = Join-Path $output.FullName 'clips.manifest.json'
    $json = Get-Content -LiteralPath $manifestPath -Raw
    $manifest = $json | ConvertFrom-Json
    Assert-True ($manifest.files.Count -eq 2) 'Wrong number of files.'
    $ascii = $manifest.files | Where-Object file_name -eq 'space clip.mp4'
    $unicode = $manifest.files | Where-Object file_name -eq '歩く clip.MOV'
    Assert-True ($ascii.size_bytes -eq 3 -and $ascii.sha256 -eq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') 'Full byte hash or size was incorrect.'
    Assert-True ($unicode.size_bytes -eq 0 -and $unicode.sha256 -eq 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') 'Unicode file was lost or changed.'
    Assert-True (-not $json.Contains($originals.FullName) -and -not $json.Contains($originals.FullName.Replace('\', '\\'))) 'Manifest contains an absolute source directory.'
    Assert-True ($ascii.media_format -eq 'unknown' -and $ascii.originality -eq 'unknown' -and $ascii.camera -eq 'unknown' -and $ascii.footage_categories.Count -eq 0) 'Filename was promoted to media evidence.'
    Assert-True ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $originals.FullName 'space clip.mp4'))) -eq 'abc') 'Original bytes changed.'
    Write-Output 'PASS names, full hashes and unknown evidence survive collection'

    $hashBefore = (Get-FileHash -LiteralPath $manifestPath).Hash
    $result = Invoke-Manifest $output.FullName
    Assert-True ($result.exit_code -ne 0 -and (Get-FileHash -LiteralPath $manifestPath).Hash -eq $hashBefore) 'Existing output was replaced.'
    $result = Invoke-Manifest $originals.FullName
    Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $originals.FullName 'clips.manifest.json'))) 'The clips directory received a report.'
    # The repo folder holds the committed manifest; a refused run must leave it as it was.
    $committed = Join-Path $PSScriptRoot 'clips.manifest.json'
    $committedHash = if (Test-Path -LiteralPath $committed) { (Get-FileHash -LiteralPath $committed).Hash } else { $null }
    $result = Invoke-Manifest $PSScriptRoot
    $afterHash = if (Test-Path -LiteralPath $committed) { (Get-FileHash -LiteralPath $committed).Hash } else { $null }
    Assert-True ($result.exit_code -ne 0 -and $afterHash -eq $committedHash) 'The repository folder received or changed a report.'
    Write-Output 'PASS output guards preserve reports and source directories'

    $env:KUAIDE_CLIPS_DIR = ''
    $emptyOutput = New-Item -ItemType Directory -Path (Join-Path $work 'missing-environment')
    $result = Invoke-Manifest $emptyOutput.FullName
    Assert-True ($result.exit_code -ne 0 -and $result.messages -match 'KUAIDE_CLIPS_DIR' -and -not (Test-Path (Join-Path $emptyOutput.FullName 'clips.manifest.json'))) 'Missing environment was accepted.'
    Write-Output 'PASS missing source environment fails without output'

    $env:KUAIDE_CLIPS_DIR = (New-Item -ItemType Junction -Path (Join-Path $work 'linked-originals') -Target $originals.FullName).FullName
    $linkOutput = New-Item -ItemType Directory -Path (Join-Path $work 'linked-output')
    $result = Invoke-Manifest $linkOutput.FullName
    Assert-True ($result.exit_code -ne 0 -and $result.messages -match 'Linked paths' -and -not (Test-Path (Join-Path $linkOutput.FullName 'clips.manifest.json'))) 'A junction to the clips was accepted.'
    Write-Output 'PASS linked clips directory is rejected'
    Write-Output "Scratch results: $work"
} finally {
    $env:KUAIDE_CLIPS_DIR = $priorClips
}
