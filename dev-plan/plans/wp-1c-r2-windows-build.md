# WP 1C-R2: Acquire one pinned Windows media-tool candidate

## Overview

Acquire one proposed Windows x64 GPL static FFmpeg candidate for build-inventory evidence. Pin a fixed release asset and verify its hardcoded SHA-256 before extracting or using it. The files remain ignored under `app/third-party/bin/`; this is not a global installation or the final Phase 1 build choice.

## Definition of Done

A Windows x64 operator can download or supply the exact pinned archive, reject mismatched bytes before extraction, and obtain a new local directory containing the candidate FFmpeg and ffprobe files. Existing files remain unchanged. The acquisition script runs no downloaded programs. A real successful acquisition and subsequent collector run produce separate factual evidence without claiming hardware support or redistribution readiness.

### Goals

- [x] Pin the release URL, SHA-256 and byte size in the acquisition script.
- [x] Verify the exact archive bytes before any extraction or use.
- [x] Keep all downloaded/staged files ignored, refuse existing destinations and perform no deletion or global install.
- [x] Prove offline checksum rejection without extraction or modifying local archive input.
- [x] Independently review the plan, then verify actual acquisition and collect versions, listings and license evidence.

## Current State
Base commit: dbe42b5c4d04e45fdc6daed8241a0d351b7e504f

The base contains the WP 1C-R1 collector but no FFmpeg binary. The existing `.gitignore` already ignores `app/third-party/bin/`. AGENTS.md requires downloads to go through scripts under `app/third-party/` with checksum verification. The approved Phase 1 roadmap calls for a Windows GPL static candidate and evidence of versions, configure flags, sources, licenses and eventually hardware encoding. This plan adds acquisition only; later hardware and media work remains separate.

## Module Shape

`app/third-party/get-windows-ffmpeg.ps1`
`app/third-party/test-windows-ffmpeg.ps1`
`app/third-party/README.md`

## Step 1: Acquire and verify the pinned candidate

Use the fixed publisher asset. Stream downloads into a create-new ignored file with a five-minute cancellation deadline, or accept a supplied local archive. Keep the archive handle open between hashing and extraction. Use .NET ZIP extraction without overwrites, check the expected executable paths without running them, then move the unique staging directory to a new fixed candidate location.
```diff
diff --git a/app/third-party/get-windows-ffmpeg.ps1 b/app/third-party/get-windows-ffmpeg.ps1
new file mode 100644
index 0000000..4ef8859
--- /dev/null
+++ b/app/third-party/get-windows-ffmpeg.ps1
@@ -0,0 +1,85 @@
+#requires -Version 7.0
+[CmdletBinding()]
+param([string]$ArchivePath)
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
+    throw 'This candidate is for Windows x64 only.'
+}
+$asset = 'ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0'
+$url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-28-19-47/$asset.zip"
+$expectedHash = 'cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed'
+$expectedSize = 195092333
+
+function Assert-UnlinkedPath([IO.FileSystemInfo]$Item) {
+    $cursor = $Item
+    while ($null -ne $cursor) {
+        if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
+            throw "Linked paths are not supported: $($Item.FullName)"
+        }
+        $cursor = if ($cursor -is [IO.DirectoryInfo]) { $cursor.Parent } else { $cursor.Directory }
+    }
+}
+
+Assert-UnlinkedPath (Get-Item -LiteralPath $PSScriptRoot -Force)
+$bin = Join-Path $PSScriptRoot 'bin'
+if (Test-Path -LiteralPath $bin) {
+    $binItem = Get-Item -LiteralPath $bin -Force
+    if (-not $binItem.PSIsContainer) { throw 'The binary path is not a directory.' }
+    Assert-UnlinkedPath $binItem
+}
+$destination = Join-Path $bin 'ffmpeg-win64-gpl-9.0-cd9b8df51452'
+if (Test-Path -LiteralPath $destination) { throw "Candidate directory already exists: $destination" }
+if ($ArchivePath) {
+    $archive = Get-Item -LiteralPath $ArchivePath -Force
+    if ($archive.PSIsContainer) { throw 'ArchivePath must name a file.' }
+    Assert-UnlinkedPath $archive
+    $archiveFile = $archive.FullName
+} else {
+    [IO.Directory]::CreateDirectory($bin) | Out-Null
+    $archiveFile = Join-Path $bin ('download-' + [Guid]::NewGuid().ToString('N') + '.zip.partial')
+    $output = [IO.File]::Open($archiveFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
+    $client = [Net.Http.HttpClient]::new()
+    $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromMinutes(5))
+    $response = $null
+    $input = $null
+    try {
+        $response = $client.GetAsync($url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancel.Token).GetAwaiter().GetResult()
+        $response.EnsureSuccessStatusCode() | Out-Null
+        $input = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
+        $input.CopyToAsync($output, 81920, $cancel.Token).GetAwaiter().GetResult() | Out-Null
+    } finally {
+        if ($null -ne $input) { $input.Dispose() }
+        if ($null -ne $response) { $response.Dispose() }
+        $output.Dispose()
+        $cancel.Dispose()
+        $client.Dispose()
+    }
+}
+$file = [IO.File]::Open($archiveFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
+$sha = [Security.Cryptography.SHA256]::Create()
+$zip = $null
+try {
+    $actualHash = [BitConverter]::ToString($sha.ComputeHash($file)).Replace('-', '').ToLowerInvariant()
+    if ($actualHash -ne $expectedHash) { throw "SHA256 mismatch; archive not extracted: $archiveFile" }
+    if ($file.Length -ne $expectedSize) { throw 'Archive length differs from the pinned asset.' }
+    $file.Position = 0
+    [IO.Directory]::CreateDirectory($bin) | Out-Null
+    $staging = Join-Path $bin ('extract-' + [Guid]::NewGuid().ToString('N'))
+    [IO.Directory]::CreateDirectory($staging) | Out-Null
+    $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Read, $true)
+    [IO.Compression.ZipFileExtensions]::ExtractToDirectory($zip, $staging)
+    $candidate = Join-Path $staging $asset
+    foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
+        if (-not (Test-Path -LiteralPath (Join-Path $candidate "bin/$name") -PathType Leaf)) {
+            throw "Pinned archive lacks expected executable: $name"
+        }
+    }
+    [IO.Directory]::Move($staging, $destination)
+} finally {
+    if ($null -ne $zip) { $zip.Dispose() }
+    $sha.Dispose()
+    $file.Dispose()
+}
+Write-Output (Join-Path $destination "$asset/bin/ffmpeg.exe")
+Write-Output (Join-Path $destination "$asset/bin/ffprobe.exe")
```

## Step 2: Prove rejection before extraction

Invoke the public acquisition script in an isolated temporary tree with known wrong archive bytes. Require a checksum-specific failure, no binary/extraction directory, and unchanged archive bytes. Do not download or execute a real binary in this offline check.

```diff
diff --git a/app/third-party/test-windows-ffmpeg.ps1 b/app/third-party/test-windows-ffmpeg.ps1
new file mode 100644
index 0000000..d005d46
--- /dev/null
+++ b/app/third-party/test-windows-ffmpeg.ps1
@@ -0,0 +1,23 @@
+#requires -Version 7.0
+$ErrorActionPreference = 'Stop'
+Set-StrictMode -Version Latest
+if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
+    throw 'Run this check on Windows x64.'
+}
+$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-download-test-' + [Guid]::NewGuid().ToString('N'))
+$copy = New-Item -ItemType Directory -Path (Join-Path $work 'app/third-party')
+$script = Join-Path $copy.FullName 'get-windows-ffmpeg.ps1'
+Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'get-windows-ffmpeg.ps1') -Destination $script
+$archive = Join-Path $work 'wrong archive.zip'
+[IO.File]::WriteAllBytes($archive, [Text.Encoding]::ASCII.GetBytes('wrong archive bytes'))
+$before = (Get-FileHash -LiteralPath $archive).Hash
+$messages = & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -File $script -ArchivePath $archive 2>&1
+if ($LASTEXITCODE -eq 0 -or ($messages -join "`n") -notmatch 'SHA256 mismatch') {
+    throw 'Wrong bytes did not fail at the checksum gate.'
+}
+if (Test-Path -LiteralPath (Join-Path $copy.FullName 'bin')) {
+    throw 'Checksum rejection created a binary or extraction directory.'
+}
+if ((Get-FileHash -LiteralPath $archive).Hash -ne $before) { throw 'Local archive changed.' }
+Write-Output 'PASS checksum rejection precedes extraction and preserves input'
+Write-Output "Scratch results: $work"
```

## Step 3: Document source evidence and operating limits

Record the publisher's fixed asset identity and the provenance limits. Document download, offline reuse, ignored leftovers, output paths, and the separate collector step. Review behavior and names before prose. No source comments require owner approval in this change.

```diff
diff --git a/app/third-party/README.md b/app/third-party/README.md
new file mode 100644
index 0000000..59210d2
--- /dev/null
+++ b/app/third-party/README.md
@@ -0,0 +1,36 @@
+# Windows media-tool candidate
+
+This is one proposed Windows x64 GPL static FFmpeg candidate for Phase 1 evidence. It is not the final selected build. The script downloads and extracts files locally; it does not install globally, change PATH, run the downloaded programs, process footage or test hardware encoders.
+
+[FFmpeg's download page](https://ffmpeg.org/download.html) links to BtbN's Windows builds. The [publisher release](https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2026-10-28-19-47) labels this asset GPL, static. The [GitHub release API](https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/autobuild-2026-10-28-19-47) reported these values on 2026-10-29:
+
+| Field | Pinned value |
+|---|---|
+| Asset | `ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0.zip` |
+| Size | `195092333` bytes |
+| SHA-256 | `cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed` |
+| Release tag | `autobuild-2026-10-28-19-47` |
+
+The release API says the release is not immutable. The script pins bytes with the hardcoded hash instead of trusting a tag or a `latest` URL. The publisher's [checksum file](https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-28-19-47/checksums.sha256) is additional publisher evidence; its API-reported SHA-256 is `72b4c1fe06bfb3aea6aecc1f1647d2d4c26a80760253f1931ef46f18ed09d9bc`. These publisher hashes do not establish correspondence to source code, complete dependency licenses or readiness to redistribute.
+
+Run on Windows x64 with PowerShell 7:
+
+```powershell
+pwsh -NoProfile -File ./app/third-party/get-windows-ffmpeg.ps1
+```
+
+For an already downloaded local archive, add `-ArchivePath 'C:/downloads/candidate.zip'`. The same pinned digest is required. No alternate URL or checksum override is available. The script opens the archive read-only and keeps that handle open through checksum verification and extraction. No archive entry is extracted before the digest matches. .NET's ZIP extraction checks entry paths and refuses existing files.
+
+All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.
+
+The HTTP transfer has a five-minute cancellation deadline. This approximately 195 MB archive should be a bounded acquisition task; extraction and inventory are separate stopping points. No source build or long render batch is part of this script.
+
+Run the offline rejection check:
+
+```powershell
+pwsh -NoProfile -File ./app/third-party/test-windows-ffmpeg.ps1
+```
+
+The check copies the acquisition script to a unique temporary tree, supplies known wrong bytes and verifies rejection at the checksum gate without a binary/extraction directory or input modification. It uses no network and runs no downloaded program. The real successful path must still be checked with the pinned archive.
+
+After acquisition, run the separate `spikes/media-capabilities/collect-build-inventory.ps1` against the printed paths and an existing evidence directory outside the repository. Supply the asset URL as `-SourceUrl`; inspect the extracted license files and supply the actual appropriate file as `-LicensePath`. If a relevant license file is absent, record that evidence gap. Record executable and license-file hashes, versions, configure flags and reported filters/encoders in reviewed evidence prose. Listings do not prove runtime GPU support. No hardware, codec quality, source correspondence or complete licensing conclusion follows from this step.
```

## Verification

- [x] Have a fresh reviewer compare the complete proposed diffs with the base and requirements. Use the repository's independent-review fallback because `planner` is unavailable.
- [x] Run `pwsh -NoProfile -File ./app/third-party/test-windows-ffmpeg.ps1`; expect one PASS summary and no exception. No network or executable extraction occurs.
- [x] Run `pwsh -NoProfile -File ./app/third-party/get-windows-ffmpeg.ps1` on Windows x64 with approved network access. Expected transfer is about 195 MB and bounded by a five-minute cancellation deadline. Inspect the printed executable paths and extracted license files. Do not start if time before the stable stop is insufficient.
- [x] Run the existing `collect-build-inventory.ps1` from this base against both printed executable paths, an existing external evidence directory, the pinned asset URL as `SourceUrl`, and the actual inspected license file as `LicensePath`. Record versions, configure flags, reported filters/encoders and executable/license hashes in separate evidence prose after observing them. Do not prefill unknown results or check this box for fixture output.
- [x] Verify that `vidstabdetect`, `vidstabtransform`, `libx264`, `libx265` and the candidate hardware encoder names are reported, or record missing capabilities as evidence against the candidate. Lists do not establish runtime hardware success. Record any absent license file as a gap.
- [x] Run `git check-ignore` on the acquired paths, `git diff --check`, and inspect staged files to ensure no archive, executable, local report or extraction directory is included.
- [x] Obtain independent source/test review. Keep real evidence checks incomplete until actually observed. No encoder, media, benchmark or source build runs are part of this plan.

## Notes for agents

1. `user-decided`: scripts under `app/third-party/` acquire binary files and check checksums; binaries are never committed (AGENTS.md, Working rules). The base `.gitignore` covers the complete download/extraction area, so no ignore change is needed.
2. `proposed`: evaluate the publisher's GPL static Windows x64 asset `ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0.zip` from tag `autobuild-2026-10-28-19-47`. This is a candidate for evidence, not a final build decision. The script does not accept alternate hashes or URLs.
3. Source verification: the GitHub release API was fetched on 2026-10-29. The named asset has size `195092333` and digest `sha256:cd9b8df51452d21b24b108de3cb11a9ad6770d7f3a8fd676222829b86d8e59ed`. The API says `immutable: false`; byte pinning prevents silently accepting changed content under that tag. Source: `https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/autobuild-2026-10-28-19-47`.
4. The publisher labels the variant GPL, static. FFmpeg's official download page links to BtbN Windows builds. These are source-attribution facts, not binary-source correspondence verification, a complete license assessment or permission to redistribute. The checksum-file digest is supplementary publisher evidence; the script verifies the pinned archive digest directly.
5. `proposed`: use create-new download files, unique extraction staging and a non-overwriting directory move. .NET ZIP extraction provides entry-path checks and defaults to refusing existing files. The exact archive handle used for hashing is used for extraction. Source/global environment remain untouched. No other process may replace directory links during the run.
6. `proposed`: preserve failed downloads and extraction directories under the ignored binary area. Do not add deletion or cleanup behavior. A repeat download uses a new file; a repeat successful installation fails on the existing candidate directory. Partial acquisition is resumable by rerunning, not HTTP range resume.
7. `inferred from code`: the WP 1C-R1 collector at this base can consume the final local paths. Its output preserves raw CLI evidence but marks caller-supplied source and license data unverified. This plan does not modify that collector or assume another unmerged plan.
8. Planning validation exercised only the offline wrong-bytes path in a system-temp copy. It passed with a checksum-specific failure before creating the binary/extraction directory and preserved input bytes. Generated diffs passed `git apply --check`; actual download, ZIP layout, executable output and license applicability remain unchecked until implementation verification.
9. The package adds 144 source/test/doc lines. Including this plan it remains comfortably below 700 lines. No package dependencies, generated lockfiles, source build, installer, media fixture or hardware execution is added. Keep all existing owner decisions unchanged.
10. Required skills were read from `henrico813/personal-dev-env` pinned at `64a2efecd10a7926755d502fb558e7ed424a4626`: `ai/AGENTS.md`, `create-plan`, `code-documentation`, `behavior-focused-testing`, and `plain-direct-english`. `planner` is unavailable, so generated diffs and independent review implement the project fallback.
11. Check account allowance before implementation and at stable points. Begin wrap-up at 5% or earlier; before either limit reaches 1%, the handover must already be ready and work already stopped at a stable point. Respect the current 16:30 PT stable-stop target. No long uninterruptible task, push, PR or merge is authorized by this plan.
12. Root independently reviewed the complete plan before application. The implemented offline check and fresh independent review passed; the reviewer found no tests to delete. The optional noisy CopyToAsync task result was suppressed, its exact plan diff regenerated from source, and the reviewer reapproved the change.
13. Actual acquisition succeeded with the exact pinned archive size and SHA-256, followed by six successful real collector commands. The evidence file `spikes/media-capabilities/evidence/2026-10-29-windows-candidate.md` records observed versions, full reported configuration, listed components, exact executable/license hashes and remaining provenance limits. A separate factual review verified that prose against the retained archive and raw report. No encoder or filter execution has been tested by this package.
