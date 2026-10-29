# WP 1C-R3: Check short synthetic software paths

## Overview

Run a small real integration smoke against the verified Windows FFmpeg candidate. Exercise libx264, libx265, vidstabdetect and vidstabtransform on one-second synthetic inputs, then check the resulting videos with ffprobe. This supplies runtime evidence beyond component listings without opening footage, testing a GPU or making a quality comparison.

## Definition of Done

A standalone PowerShell 7 integration script creates only new external outputs, runs bounded child commands, and verifies three generated videos. Each must have the expected codec, 320x180 dimensions, 30 decoded frames and duration within 0.05 seconds of one second. A successful JSON report appears only after every command, output check and final tool-hash comparison passes. Failed runs remain labeled failed.

### Goals

- [x] Exercise actual H.264/HEVC software encoding and both libvidstab passes with trusted verified tools.
- [x] Verify expected codecs, frame count, size, duration and a nonempty transform file.
- [x] Preserve command evidence, timings, binary identity and host OS/architecture in JSON.
- [x] Reject preexisting/protected output directories and use `-n` with fixed relative names.
- [x] Run the real smoke and obtain independent source review without adding a fake test framework.

## Current State
Base commit: a4dff4409f50f5c74560ad6142f8bc0c26354c6c

The base has the pinned acquisition script, local build collector and observed Windows candidate evidence. The archive passed its pinned hash gate, but the committed evidence establishes only component listings, not real encoding/filter operation. The candidate exists locally under the ignored binary directory. The current session host differs from the original i7/RTX 3080 reference PC; this run does not validate that original machine or macOS. No app code changes are needed.

## Module Shape

`spikes/media-capabilities/test-software-runtime.ps1`
`spikes/media-capabilities/SOFTWARE-SMOKE.md`

## Step 1: Add the real bounded integration smoke

Use explicit trusted tool paths and create a new external working directory. Generate synthetic inputs, encode with the software libraries, run both stabilization passes and probe each result. Preserve actual command evidence and output checks. Emit a passed report only at the end; record a failed report for an incomplete pipeline.
```diff
diff --git a/spikes/media-capabilities/test-software-runtime.ps1 b/spikes/media-capabilities/test-software-runtime.ps1
new file mode 100644
index 0000000..ec9ff5a
--- /dev/null
+++ b/spikes/media-capabilities/test-software-runtime.ps1
@@ -0,0 +1,105 @@
+#requires -Version 7.0
+[CmdletBinding()]
+param(
+    [Parameter(Mandatory)][string]$FfmpegPath,
+    [Parameter(Mandatory)][string]$FfprobePath,
+    [Parameter(Mandatory)][string]$OutputDirectory
+)
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+
+function Resolve-PlainPath([string]$Path, [bool]$Directory) {
+    $item = Get-Item -LiteralPath $Path -Force
+    if ($item.PSIsContainer -ne $Directory) { throw "Unexpected path kind: $Path" }
+    $cursor = $item
+    while ($null -ne $cursor) {
+        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Linked path rejected: $Path" }
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
+function Invoke-SmokeCommand([string]$Name, [string]$Path, [string[]]$Arguments) {
+    $start = [Diagnostics.ProcessStartInfo]::new()
+    $start.FileName = $Path
+    $start.WorkingDirectory = $output
+    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
+    $start.UseShellExecute = $false
+    $start.CreateNoWindow = $true
+    $start.RedirectStandardOutput = $true
+    $start.RedirectStandardError = $true
+    $process = [Diagnostics.Process]::new()
+    $process.StartInfo = $start
+    $watch = [Diagnostics.Stopwatch]::StartNew()
+    try {
+        if (-not $process.Start()) { throw "Could not start $Name" }
+        $stdout = $process.StandardOutput.ReadToEndAsync()
+        $stderr = $process.StandardError.ReadToEndAsync()
+        $timedOut = -not $process.WaitForExit(30000)
+        if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
+        $entry = [ordered]@{ name = $Name; arguments = $Arguments; exit_code = $process.ExitCode; timed_out = $timedOut; elapsed_ms = $watch.ElapsedMilliseconds; stdout = $stdout.GetAwaiter().GetResult(); stderr = $stderr.GetAwaiter().GetResult() }
+        $commands.Add($entry)
+        if ($timedOut -or $entry.exit_code -ne 0) { throw "Smoke command failed: $Name (exit $($entry.exit_code), timed_out $timedOut)" }
+        return $entry
+    } finally { $process.Dispose() }
+}
+
+$ffmpeg = Resolve-PlainPath $FfmpegPath $false
+$ffprobe = Resolve-PlainPath $FfprobePath $false
+$output = [IO.Path]::GetFullPath($OutputDirectory)
+if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must not exist; choose a new external directory.' }
+$null = Resolve-PlainPath ([IO.Path]::GetDirectoryName($output)) $true
+$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
+foreach ($directory in @($repo, [IO.Path]::GetDirectoryName($ffmpeg), [IO.Path]::GetDirectoryName($ffprobe))) {
+    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside repository and tool directories.' }
+}
+$tools = [ordered]@{}
+foreach ($entry in @(@('ffmpeg', $ffmpeg), @('ffprobe', $ffprobe))) {
+    $tools[$entry[0]] = [ordered]@{ path = $entry[1]; sha256 = (Get-FileHash -LiteralPath $entry[1]).Hash.ToLowerInvariant() }
+}
+[IO.Directory]::CreateDirectory($output) | Out-Null
+$commands = [Collections.Generic.List[object]]::new()
+$checks = [Collections.Generic.List[object]]::new()
+$report = [ordered]@{ status = 'failed'; failure = $null; generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o'); host = [ordered]@{ os = [Runtime.InteropServices.RuntimeInformation]::OSDescription; architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); powershell = $PSVersionTable.PSVersion.ToString() }; tools = $tools; commands = $commands; checks = $checks; evidence = 'Short synthetic software smoke only; no hardware, footage, quality or source-provenance validation.' }
+try {
+    $null = Invoke-SmokeCommand 'ffmpeg-version' $ffmpeg @('-version')
+    $null = Invoke-SmokeCommand 'ffprobe-version' $ffprobe @('-version')
+    $common = @('-nostdin', '-hide_banner', '-n')
+    $source = @('-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=30:duration=1', '-an')
+    $null = Invoke-SmokeCommand 'encode-h264' $ffmpeg ($common + $source + @('-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '20', '-pix_fmt', 'yuv420p', '-threads', '2', 'h264.mp4'))
+    $null = Invoke-SmokeCommand 'encode-hevc' $ffmpeg ($common + $source + @('-c:v', 'libx265', '-preset', 'ultrafast', '-crf', '28', '-pix_fmt', 'yuv420p', '-x265-params', 'pools=1:frame-threads=1', 'hevc.mp4'))
+    $null = Invoke-SmokeCommand 'detect-motion' $ffmpeg ($common + @('-i', 'h264.mp4', '-vf', 'vidstabdetect=shakiness=5:accuracy=9:result=transforms.trf', '-an', '-f', 'null', '-'))
+    if (-not (Test-Path -LiteralPath (Join-Path $output 'transforms.trf') -PathType Leaf) -or (Get-Item -LiteralPath (Join-Path $output 'transforms.trf')).Length -eq 0) { throw 'Motion analysis did not create a nonempty transform file.' }
+    $null = Invoke-SmokeCommand 'transform-motion' $ffmpeg ($common + @('-i', 'h264.mp4', '-vf', 'vidstabtransform=input=transforms.trf:smoothing=10:optzoom=0', '-an', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '20', '-pix_fmt', 'yuv420p', '-threads', '2', 'stabilized.mp4'))
+    foreach ($expected in @(@('h264.mp4', 'h264'), @('hevc.mp4', 'hevc'), @('stabilized.mp4', 'h264'))) {
+        $name, $codec = $expected
+        $probe = Invoke-SmokeCommand "probe-$name" $ffprobe @('-v', 'error', '-select_streams', 'v:0', '-count_frames', '-show_entries', 'stream=codec_name,width,height,nb_read_frames:format=duration', '-of', 'json', $name)
+        $metadata = $probe.stdout | ConvertFrom-Json
+        if (@($metadata.streams).Count -ne 1) { throw "Expected one selected video stream: $name" }
+        $stream = $metadata.streams[0]
+        $duration = [double]::Parse($metadata.format.duration, [Globalization.CultureInfo]::InvariantCulture)
+        if ($stream.codec_name -ne $codec -or $stream.width -ne 320 -or $stream.height -ne 180 -or [int]$stream.nb_read_frames -ne 30 -or [Math]::Abs($duration - 1.0) -gt 0.05) { throw "Output does not match expected codec, size, frame count or duration: $name" }
+        $checks.Add([ordered]@{ file_name = $name; codec = $stream.codec_name; width = $stream.width; height = $stream.height; decoded_frame_count = [int]$stream.nb_read_frames; duration_seconds = $duration; sha256 = (Get-FileHash -LiteralPath (Join-Path $output $name)).Hash.ToLowerInvariant() })
+    }
+    foreach ($tool in $tools.Values) {
+        if ($tool.sha256 -ne (Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant()) { throw 'A tool changed during the smoke run.' }
+    }
+    $report.status = 'passed'
+} catch {
+    $report.failure = $_.Exception.Message
+    throw
+} finally {
+    $reportPath = Join-Path $output $(if ($report.status -eq 'passed') { 'software-smoke.json' } else { 'software-smoke-failed.json' })
+    $file = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
+    try {
+        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 12) + [Environment]::NewLine)
+        $file.Write($bytes, 0, $bytes.Length)
+    } finally { $file.Dispose() }
+}
+Write-Output $reportPath
```

## Step 2: Document use and evidence limits

Document invocation, output checks and failed-run handling. Explain that this small integration smoke proves neither real-footage quality nor hardware support, representative performance, provenance or reference-machine suitability. Review behavior and names before prose; no source comments require owner approval.

```diff
diff --git a/spikes/media-capabilities/SOFTWARE-SMOKE.md b/spikes/media-capabilities/SOFTWARE-SMOKE.md
new file mode 100644
index 0000000..797b3f7
--- /dev/null
+++ b/spikes/media-capabilities/SOFTWARE-SMOKE.md
@@ -0,0 +1,16 @@
+# Software runtime smoke
+
+Run this PowerShell 7 integration smoke only against trusted, checksum-verified FFmpeg and ffprobe files. Supply both paths explicitly and choose a new output directory whose parent already exists. Output must be outside the repository and both tool directories. Existing output directories and linked paths are rejected.
+
+```powershell
+pwsh -NoProfile -File ./spikes/media-capabilities/test-software-runtime.ps1 `
+  -FfmpegPath 'C:/verified-tools/ffmpeg.exe' `
+  -FfprobePath 'C:/verified-tools/ffprobe.exe' `
+  -OutputDirectory 'C:/media-evidence/new-software-smoke'
+```
+
+The smoke generates one second of synthetic `testsrc2` at 320x180 and 30 fps. It encodes H.264 with libx264 and HEVC with libx265, runs libvidstab detection and transformation, then decodes/counts frames with ffprobe. Every resulting video must have the expected codec, 320x180 dimensions, 30 decoded frames and duration within 0.05 seconds of one second. A nonempty transform file is also required. Native commands use a 30-second timeout and fixed relative filenames in the new working directory. FFmpeg receives `-n` to refuse overwriting.
+
+Success writes `software-smoke.json` after all checks and before/after tool-hash comparisons pass. A pipeline failure writes `software-smoke-failed.json` with failed status and the commands completed so far, then exits with an error. Input-path rejection creates no report. The JSON preserves exact arguments, exit codes, stdout, stderr, elapsed milliseconds, versions, tool/output hashes and host OS/architecture. Keep output files outside the repository; retain the JSON for inspection. A disk write failure may leave an incomplete new report.
+
+The smoke does not open user footage, test hardware encoders, assess stabilization quality, measure representative performance or establish source/license provenance. Its timings describe this small run only. The generated test pattern is not a benchmark clip. Do not change directory links or binaries concurrently. The check records file identity but does not authenticate arbitrary executable files supplied by a caller.
```

## Verification

- [x] Obtain fresh independent plan review under the project fallback for unavailable `planner`.
- [x] Run `test-software-runtime.ps1` with both executable paths from the verified acquisition and a unique new external output directory. Expect `software-smoke.json` with status `passed`, nine zero-exit commands and three successful output checks. Check versions and hashes against the existing candidate evidence.
- [x] Confirm H.264, HEVC and transformed H.264 each report 320x180, 30 decoded frames and duration 1.0 seconds within the stated 0.05-second tolerance. Confirm the transform file is nonempty. Record observed command timings as illustrative, not benchmark results.
- [x] Inspect the JSON and generated artifacts, and record factual evidence in separate prose after the implementation run. No failed or fixture result may be called a pass. Do not commit generated videos or raw local reports.
- [x] Run `git diff --check`, inspect changed-file scope and obtain fresh independent source review. This script is itself the real integration test; add no fake or mirrored unit suite.

## Notes for agents

1. `user-decided`: original footage must remain intact, binary/media files must not be committed, and native media operations belong in child processes (AGENTS.md and design brief sections 3, 7 and 11). This smoke uses only generated test patterns in a new external directory and does not access the clips folder.
2. `proposed`: use a standalone PowerShell 7 script with no shared abstraction or test dependency. A local concrete process runner preserves stdout/stderr separately, waits at most 30 seconds per command and kills the process tree on timeout. Nine commands make the nominal timeout budget 270 seconds; ordinary execution is expected to finish much sooner. Cancellation or errors leave generated scratch files for inspection, never earlier user outputs.
3. `proposed`: use relative `h264.mp4`, `hevc.mp4`, `transforms.trf` and `stabilized.mp4` names with the process working directory set to the new output directory. This avoids Windows drive-colon parsing in filter arguments. `-nostdin` and `-n` prevent interactive prompts and overwrites. No other process may change directory links concurrently.
4. `proposed`: a 320x180@30fps one-second testsrc2 pattern is sufficient to demonstrate these software paths load and produce decodable video. It is not an intentional-shake sample and cannot quantify stabilization quality or crop behavior. HEVC uses one x265 pool/frame thread for a bounded small run. No hardware encoder name is requested.
5. `proposed`: validate decoded frame count with ffprobe `-count_frames`, reported codec, dimensions and container duration within 0.05 seconds. Record output SHA-256 as artifact identity, not repeatability or quality guarantees. Record binary hashes before and after commands, but do not treat arbitrary caller paths as authenticated.
6. Actual planning validation ran the ordinary scratch script against the verified candidate executables without changing them or installing repo source. All nine commands exited zero. The three outputs each reported 320x180, 30 decoded frames and 1.000 seconds; the transform file was nonempty. Raw report: `C:/Users/bchen/AppData/Local/Temp/kuaide-software-smoke-plan-48abbb061b084513bf4cb6fb10805e1e/software-smoke.json`. This supports the draft, but a fresh source review and implementation verification are still required.
7. Observed planning-run command timings in milliseconds were version 459/481, H.264 encode 101, HEVC encode 157, detection 117, transformation 124, and probes 365/124/97. These describe this run only and are not comparable benchmark evidence. No source correspondence, complete licensing, camera footage or hardware capability was tested.
8. Generated diffs passed `git apply --check`; PowerShell parsed and executed the scratch script successfully. Required pinned skills were read: `ai/AGENTS.md`, `create-plan`, `code-documentation`, `behavior-focused-testing`, and `plain-direct-english` from `henrico813/personal-dev-env` at `64a2efecd10a7926755d502fb558e7ed424a4626`. `planner` is unavailable; use fresh independent review under the repository adaptation.
9. Keep the implementation source/doc additions below 180 lines and the full plan/source/evidence package below 700 lines. Do not edit acquisition, collector, existing evidence or another package's source as part of applying these diffs. No dependency or generated lockfile is introduced.
10. Check allowance before implementation and at stable points. At 5% or below, reach a stable point and provide a handover. Respect the current 16:30 PT stable-stop target. No long uninterruptible task, push, PR, merge or phase transition is authorized here.
11. Root independently reviewed the complete generated plan against the current base and requirements before application; no blocking findings. The implementation run passed nine commands and three output checks. A fresh reviewer independently reran the smoke, verified that an existing-output retry preserved the earlier report hash, approved source/evidence and found no low-value tests to delete.
12. Actual run evidence is recorded in `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`, with current host hardware observed through read-only CIM. Root raw report: `C:/Users/bchen/AppData/Local/Temp/kuaide-software-smoke-dc71d0a1352745a48f0dc8b8490d1177/software-smoke.json`. These results do not satisfy footage-quality, original reference-machine, GPU, macOS or preview gates.
