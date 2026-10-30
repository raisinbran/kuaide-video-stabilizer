# WP 1C-R1: Collect local media-tool build evidence

## Overview

Add a small offline collector for the build identity and reported capabilities of trusted local FFmpeg and ffprobe files. This is a replacement plan for a bounded first part of WP 1C; it does not recover or claim to reproduce the missing WP 1C-A plan. PowerShell 7 is the proposed spike runtime because it is already available here.

## Definition of Done

A caller can collect versions, build configuration, FFmpeg filter and encoder listings, exact file SHA-256 and supplied provenance into a new JSON file outside the repository. Missing provenance stays unknown. Listed encoders are never presented as tested hardware support. The source files, existing reports and tool directories remain untouched. No downloads, camera samples or long renders are needed.

### Goals

- [x] Collect raw stdout, stderr and argument lists for both tools' version and build configuration, plus FFmpeg's filters and encoders.
- [x] Record exact file hashes and identify caller-supplied provenance as unverified.
- [x] Refuse existing reports, repository output, linked paths and output inside tool directories.
- [x] Verify successful collection, provenance labels, output safety, failing tools and timeouts through child-process fixtures.
- [x] Obtain fresh independent plan review before implementation and fresh code/test review afterward.

## Current State
Base commit: 9f2c01fd4d836a4df31a3fb8f2f8400acd59939c

The repository has no source or tests in `spikes/media-capabilities/`. The approved roadmap requires versions, configure flags, sources and licenses before binary selection. The missing `3be84fb` planning commit cannot be resolved locally or on GitHub. The recovery branch contains documentation only. The existing PowerShell 7 runtime supports this bounded offline step. This plan changes no app code or owner-decided feature.

## Module Shape

`spikes/media-capabilities/collect-build-inventory.ps1`
`spikes/media-capabilities/test-build-inventory.ps1`
`spikes/media-capabilities/README.md`

## Step 1: Add the collector behavior

Create a standalone script with explicit tool and output paths. Capture raw command output rather than guessing capability or license conclusions. Compute a file hash before and after the inspection. Child commands have a timeout and nonzero exits prevent report creation. Use create-new file semantics so an existing report cannot be overwritten.
```diff
diff --git a/spikes/media-capabilities/collect-build-inventory.ps1 b/spikes/media-capabilities/collect-build-inventory.ps1
new file mode 100644
index 0000000..49fffdb
--- /dev/null
+++ b/spikes/media-capabilities/collect-build-inventory.ps1
@@ -0,0 +1,130 @@
+#requires -Version 7.0
+[CmdletBinding()]
+param(
+    [Parameter(Mandatory)][string]$FfmpegPath,
+    [Parameter(Mandatory)][string]$FfprobePath,
+    [Parameter(Mandatory)][string]$OutputDirectory,
+    [string]$SourceUrl,
+    [string]$LicensePath,
+    [ValidateRange(1, 120)][int]$TimeoutSeconds = 15
+)
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+
+function Resolve-PlainPath([string]$Path, [bool]$Directory) {
+    $item = Get-Item -LiteralPath $Path
+    if ($item.PSIsContainer -ne $Directory) { throw "Unexpected path kind: $Path" }
+    $cursor = $item
+    while ($null -ne $cursor) {
+        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
+            throw "Linked paths are not supported: $Path"
+        }
+        $cursor = if ($cursor -is [IO.DirectoryInfo]) { $cursor.Parent } else { $cursor.Directory }
+    }
+    return $item.FullName
+}
+
+function Test-WithinDirectory([string]$Path, [string]$Directory) {
+    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
+    $prefix = $Directory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
+    return $Path.Equals($Directory, $comparison) -or $Path.StartsWith($prefix, $comparison)
+}
+
+function Invoke-Tool([string]$Path, [string[]]$Arguments) {
+    $start = [Diagnostics.ProcessStartInfo]::new()
+    if ([IO.Path]::GetExtension($Path) -eq '.ps1') {
+        $start.FileName = (Get-Process -Id $PID).Path
+        foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $Path)) {
+            $start.ArgumentList.Add($argument)
+        }
+    } else {
+        $start.FileName = $Path
+    }
+    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
+    $start.UseShellExecute = $false
+    $start.CreateNoWindow = $true
+    $start.RedirectStandardOutput = $true
+    $start.RedirectStandardError = $true
+    $process = [Diagnostics.Process]::new()
+    $process.StartInfo = $start
+    try {
+        if (-not $process.Start()) { throw "Could not start tool: $Path" }
+        $stdout = $process.StandardOutput.ReadToEndAsync()
+        $stderr = $process.StandardError.ReadToEndAsync()
+        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
+            $process.Kill($true)
+            $process.WaitForExit()
+            throw "Tool timed out after $TimeoutSeconds seconds: $Path"
+        }
+        $result = [ordered]@{
+            arguments = $Arguments
+            exit_code = $process.ExitCode
+            stdout = $stdout.GetAwaiter().GetResult()
+            stderr = $stderr.GetAwaiter().GetResult()
+        }
+        if ($result.exit_code -ne 0) { throw "Tool failed with exit code $($result.exit_code): $Path" }
+        return $result
+    } finally {
+        $process.Dispose()
+    }
+}
+
+$ffmpeg = Resolve-PlainPath $FfmpegPath $false
+$ffprobe = Resolve-PlainPath $FfprobePath $false
+$output = Resolve-PlainPath $OutputDirectory $true
+$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
+foreach ($directory in @($repo, [IO.Path]::GetDirectoryName($ffmpeg), [IO.Path]::GetDirectoryName($ffprobe))) {
+    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside the repository and tool directories.' }
+}
+$reportPath = Join-Path $output 'build-inventory.json'
+if (Test-Path -LiteralPath $reportPath) { throw "Output already exists: $reportPath" }
+$license = $null
+if ($LicensePath) {
+    $licenseFile = Resolve-PlainPath $LicensePath $false
+    $license = [ordered]@{
+        path = $licenseFile
+        sha256 = (Get-FileHash -LiteralPath $licenseFile -Algorithm SHA256).Hash.ToLowerInvariant()
+        text = [IO.File]::ReadAllText($licenseFile)
+        status = 'caller-supplied; applicability not verified'
+    }
+}
+$tools = [ordered]@{}
+foreach ($entry in @(@('ffmpeg', $ffmpeg), @('ffprobe', $ffprobe))) {
+    $name, $path = $entry
+    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
+    $commands = [ordered]@{
+        version = Invoke-Tool $path @('-version')
+        buildconf = Invoke-Tool $path @('-buildconf')
+    }
+    if ($name -eq 'ffmpeg') {
+        $commands.filters = Invoke-Tool $path @('-hide_banner', '-filters')
+        $commands.encoders = Invoke-Tool $path @('-hide_banner', '-encoders')
+    }
+    if ($hash -ne (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()) {
+        throw "Tool changed during collection: $path"
+    }
+    $tools[$name] = [ordered]@{ path = $path; sha256 = $hash; commands = $commands }
+}
+$report = [ordered]@{
+    schema_version = 1
+    collected_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
+    host = [ordered]@{ os = [Runtime.InteropServices.RuntimeInformation]::OSDescription; architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); powershell = $PSVersionTable.PSVersion.ToString() }
+    evidence = 'Tool-reported build inventory; no encode, decode, filter or hardware execution tested.'
+    provenance = [ordered]@{
+        source_url = if ($SourceUrl) { $SourceUrl } else { $null }
+        source_status = if ($SourceUrl) { 'caller-supplied; not verified' } else { 'unknown' }
+        license = $license
+        license_status = if ($license) { 'caller-supplied; applicability not verified' } else { 'unknown' }
+        authenticity = 'not verified; SHA256 identifies the collected files only'
+    }
+    tools = $tools
+}
+$json = $report | ConvertTo-Json -Depth 12
+$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
+try {
+    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
+    $stream.Write($bytes, 0, $bytes.Length)
+} finally {
+    $stream.Dispose()
+}
+Write-Output $reportPath
```

## Step 2: Add behavior checks

Run the public collector script with trusted command stand-ins in child PowerShell processes. The checks protect evidence fidelity, unverified provenance labels, existing files and output boundaries. A failing or hung tool must not leave a success report.

```diff
diff --git a/spikes/media-capabilities/test-build-inventory.ps1 b/spikes/media-capabilities/test-build-inventory.ps1
new file mode 100644
index 0000000..b45f8e8
--- /dev/null
+++ b/spikes/media-capabilities/test-build-inventory.ps1
@@ -0,0 +1,73 @@
+#requires -Version 7.0
+$ErrorActionPreference = 'Stop'
+Set-StrictMode -Version Latest
+$collector = Join-Path $PSScriptRoot 'collect-build-inventory.ps1'
+$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-inventory-tests-' + [Guid]::NewGuid().ToString('N'))
+$tools = New-Item -ItemType Directory -Path (Join-Path $work 'tools')
+$fixture = Join-Path $tools.FullName 'media tool.ps1'
+@(
+    'if ($args -contains ''-version'') { ''ffmpeg version fixture''; exit 0 }',
+    'if ($args -contains ''-buildconf'') { [Console]::Error.WriteLine(''configuration: --enable-libx264 --enable-libvidstab''); exit 0 }',
+    'if ($args -contains ''-filters'') { '' ... vidstabdetect V->V''; exit 0 }',
+    'if ($args -contains ''-encoders'') { '' V..... h264_nvenc''; exit 0 }',
+    'exit 7'
+) | Set-Content -LiteralPath $fixture -Encoding utf8
+$pwsh = (Get-Process -Id $PID).Path
+
+function Assert-True([bool]$Condition, [string]$Message) {
+    if (-not $Condition) { throw $Message }
+}
+
+function Invoke-Collector([string]$Directory, [string]$Tool = $fixture, [int]$Timeout = 15) {
+    $messages = & $pwsh -NoProfile -NonInteractive -File $collector -FfmpegPath $Tool -FfprobePath $fixture -OutputDirectory $Directory -TimeoutSeconds $Timeout 2>&1
+    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
+}
+
+$output = New-Item -ItemType Directory -Path (Join-Path $work 'success')
+$result = Invoke-Collector $output.FullName
+Assert-True ($result.exit_code -eq 0) $result.messages
+$report = Get-Content -LiteralPath (Join-Path $output.FullName 'build-inventory.json') -Raw | ConvertFrom-Json
+Assert-True ($report.tools.ffmpeg.sha256 -eq (Get-FileHash -LiteralPath $fixture).Hash.ToLowerInvariant()) 'Wrong tool hash.'
+Assert-True ($report.tools.ffmpeg.commands.encoders.stdout -match 'h264_nvenc') 'Encoder listing missing.'
+Assert-True ($report.tools.ffmpeg.commands.filters.stdout -match 'vidstabdetect') 'Filter listing missing.'
+Assert-True ($report.tools.ffprobe.commands.buildconf.stderr -match '--enable-libvidstab') 'Build configuration stderr lost.'
+Assert-True ($report.provenance.source_status -eq 'unknown' -and $report.provenance.license_status -eq 'unknown') 'Unknown provenance overstated.'
+Assert-True ($report.evidence -match 'no encode, decode, filter or hardware execution tested') 'Inventory must not claim runtime validation.'
+Assert-True ($report.tools.ffmpeg.commands.version.stdout -match 'version fixture' -and $report.tools.ffprobe.commands.version.stdout -match 'version fixture') 'Version evidence missing.'
+Write-Output 'PASS inventory preserves raw evidence and unknown provenance'
+
+$license = Join-Path $work 'COPYING.txt'
+'Fixture license text' | Set-Content -LiteralPath $license
+$output = New-Item -ItemType Directory -Path (Join-Path $work 'supplied')
+$messages = & $pwsh -NoProfile -NonInteractive -File $collector -FfmpegPath $fixture -FfprobePath $fixture -OutputDirectory $output.FullName -SourceUrl 'https://example.invalid/build.zip' -LicensePath $license 2>&1
+Assert-True ($LASTEXITCODE -eq 0) ($messages -join "`n")
+$report = Get-Content -LiteralPath (Join-Path $output.FullName 'build-inventory.json') -Raw | ConvertFrom-Json
+Assert-True ($report.provenance.source_url -eq 'https://example.invalid/build.zip' -and $report.provenance.source_status -eq 'caller-supplied; not verified') 'Supplied source was promoted to verified provenance.'
+Assert-True ($report.provenance.license.text.Trim() -eq 'Fixture license text' -and $report.provenance.license.sha256 -eq (Get-FileHash -LiteralPath $license).Hash.ToLowerInvariant()) 'Supplied license evidence changed.'
+Assert-True ($report.provenance.license_status -eq 'caller-supplied; applicability not verified') 'Supplied license was promoted to verified applicability.'
+Write-Output 'PASS supplied provenance remains unverified'
+
+$before = (Get-FileHash -LiteralPath (Join-Path $output.FullName 'build-inventory.json')).Hash
+$result = Invoke-Collector $output.FullName
+Assert-True ($result.exit_code -ne 0) 'Existing report was accepted.'
+Assert-True ((Get-FileHash -LiteralPath (Join-Path $output.FullName 'build-inventory.json')).Hash -eq $before) 'Existing report changed.'
+$result = Invoke-Collector $tools.FullName
+Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $tools.FullName 'build-inventory.json'))) 'Tool directory was writable.'
+$result = Invoke-Collector $PSScriptRoot
+Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $PSScriptRoot 'build-inventory.json'))) 'Repository output was accepted.'
+Write-Output 'PASS output guards preserve existing files and source locations'
+
+$failing = Join-Path $tools.FullName 'failing.ps1'
+'exit 9' | Set-Content -LiteralPath $failing
+$output = New-Item -ItemType Directory -Path (Join-Path $work 'failure')
+$result = Invoke-Collector $output.FullName $failing
+Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $output.FullName 'build-inventory.json'))) 'Failed tool produced a report.'
+$hanging = Join-Path $tools.FullName 'hanging.ps1'
+'Start-Sleep -Seconds 30' | Set-Content -LiteralPath $hanging
+$output = New-Item -ItemType Directory -Path (Join-Path $work 'timeout')
+$watch = [Diagnostics.Stopwatch]::StartNew()
+$result = Invoke-Collector $output.FullName $hanging 1
+Assert-True ($result.exit_code -ne 0 -and $result.messages -match 'timed out') 'Hung tool did not report timeout.'
+Assert-True ($watch.Elapsed.TotalSeconds -lt 15 -and -not (Test-Path (Join-Path $output.FullName 'build-inventory.json'))) 'Timeout did not bound collection.'
+Write-Output 'PASS failed and hung tools leave no inventory'
+Write-Output "Scratch results: $work"
```

## Step 3: Document use and evidence limits

Document paths, invocation, output safety, provenance limits and the distinction between build listings and runtime evidence. Review behavior and names before reviewing this prose. There are no source comments for owner approval in this change.

```diff
diff --git a/spikes/media-capabilities/README.md b/spikes/media-capabilities/README.md
new file mode 100644
index 0000000..4233100
--- /dev/null
+++ b/spikes/media-capabilities/README.md
@@ -0,0 +1,28 @@
+# Build inventory spike
+
+This PowerShell 7 collector records evidence from trusted local FFmpeg and ffprobe files. It runs only `-version`, `-buildconf`, `-filters` and `-encoders`. It does not download tools, open footage, run filters, encode video or test a GPU.
+
+Use explicit tool paths and an existing output directory outside this repository and both tool directories:
+
+```powershell
+pwsh -NoProfile -File ./spikes/media-capabilities/collect-build-inventory.ps1 `
+  -FfmpegPath 'C:/media-tools/ffmpeg.exe' `
+  -FfprobePath 'C:/media-tools/ffprobe.exe' `
+  -OutputDirectory 'C:/media-evidence/run-01'
+```
+
+The collector creates `build-inventory.json` without replacing an existing file. Use a separate output directory for each collection. Linked paths, including junctions and symbolic links in an ancestor, are rejected to keep the output boundary explicit. The directory must already exist; the collector does not create or remove directories.
+
+Optional `-SourceUrl` and `-LicensePath` preserve caller-supplied provenance and license text. The collector does not verify the URL, authenticity, license applicability, archive checksums or correspondence to source code. Missing information stays `unknown`. SHA-256 identifies the exact tool files and supplied license file; it is not a trusted-publisher check.
+
+The report preserves stdout and stderr separately for every command. It includes tool paths, SHA-256, UTC collection time, OS, architecture and PowerShell version. A before/after hash check rejects a tool file changed during collection. Command errors or a timeout stop collection before a report is created. Each command has a 15-second timeout by default (`-TimeoutSeconds`, 1-120). Do not run untrusted executable files or scripts.
+
+The lists describe what the build reports. An encoder such as `h264_nvenc` appearing in a list does not prove that a GPU, driver or actual encoding works. No Windows or macOS suitability, tone-mapping quality or packaging decision follows from this inventory alone. These need later runtime tests and provenance review under WP 1C.
+
+Run the bounded offline checks:
+
+```powershell
+pwsh -NoProfile -File ./spikes/media-capabilities/test-build-inventory.ps1
+```
+
+The checks launch local `.ps1` stand-ins through child PowerShell processes and test output safety, raw evidence capture, provenance labels, nonzero exits and timeout handling. They use real filesystem writes and subprocesses, but do not establish FFmpeg interoperability. The collector accepts `.ps1` paths for these trusted stand-ins. The checks print their temporary results directory and leave it available for inspection.
```

## Verification

- [x] Run `pwsh -NoProfile -File ./spikes/media-capabilities/test-build-inventory.ps1`; expect four PASS summaries and no exception. The command prints its temporary results directory.
- [x] Run `git diff --check` and inspect the cumulative changed-file list.
- [x] Have a fresh reviewer compare this complete plan with requirements and source before applying it. `planner` is unavailable; use the repository's independent-review fallback.
- [x] After implementation, have a different agent review source and tests, including low-value tests. Do not claim FFmpeg, encoder, GPU or macOS evidence from stand-ins.

## Notes for agents

1. `user-decided`: preserve original footage and do all lasting work in this repository (AGENTS.md, Working rules). This step opens no footage and its JSON reports live outside the repository; commit any reviewed findings later as prose rather than committing local reports containing paths.
2. `proposed`: PowerShell 7 supplies subprocesses, JSON and SHA-256 without a package installation. Trusted `.ps1` stand-ins use child PowerShell processes in the tests. Native FFmpeg and ffprobe interoperability remains unverified until actual binaries are available. This is a spike, not app infrastructure.
3. `proposed`: preserve stdout and stderr rather than parse transient CLI layouts. The inventory records six commands total: FFmpeg version/buildconf/filters/encoders, and ffprobe version/buildconf. Build selection, encoders, filters, HDR, gyro and media probing remain later WP 1C work.
4. `proposed`: allow an optional source URL and license file only as caller-supplied evidence. Unknown source/license fields remain unknown. Hashes identify collected files; no trusted publisher, source archive, license applicability or binary authenticity verification is implied. A later package provenance step must supply that verification.
5. `proposed`: an existing output directory outside the repo and tool directories, with no linked ancestor, is deliberately required. Create-new semantics prevent replacement even if a report appears after the initial existence check. Protection assumes no other process changes directory links during collection. A disk write failure can leave an incomplete new file; it cannot overwrite an earlier file.
6. `inferred from code`: no existing callers, package manager, test framework or make targets need updating. The test script uses four behavior groups and leaves uniquely named scratch evidence for inspection. It does not establish real FFmpeg behavior or platform suitability.
7. The generated implementation diff adds 231 lines across three files. Including this plan, the package remains below 700 lines. No generated lockfiles are introduced. Preserve recovery-doc changes outside this plan.
8. Planning validation: the proposed files were exercised in a temporary directory, not installed into the repository. All four behavior groups passed there. Fresh review is still required; scratch results are supporting evidence, not an approval. Diff blocks were generated from ordinary scratch source with `git diff --no-index`, because `planner` is unavailable under the project adaptation.
9. Required skill sources were read from `henrico813/personal-dev-env` at `64a2efecd10a7926755d502fb558e7ed424a4626`: `ai/AGENTS.md`, `create-plan`, `code-documentation`, `behavior-focused-testing`, and `plain-direct-english`. No skill files were copied into this repository.
10. Keep work bounded before the 16:30 PT stable-stop target. Check current account allowance before implementation. At 5% or below, reach a stable point, provide a handover and stop. No long uninterruptible task, push, PR or merge is authorized by this plan.
11. Independent plan review: the root agent reviewed the complete generated diffs against current source and Phase 1 requirements before implementation; no blocking findings. Generated patch applicability passed. The child-process fixture suite passed after implementation in the actual checkout, with scratch results at `C:/Users/bchen/AppData/Local/Temp/kuaide-inventory-tests-5dd2d432a43940f5acba68746ea7b92b`. Fresh independent implementation and test review approved the code and tests with no corrections or tests to delete; the reviewer independently reran all four behavior groups with exit 0.
