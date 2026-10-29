# WP 1A-R1: Identify benchmark inputs without altering them

## Overview

Add a small read-only manifest harness for benchmark inputs. It records exact file identities before later media probing or engine comparisons. This replaces a bounded first part of the missing WP 1A plan; it does not claim to recover that plan or finish the benchmark. PowerShell 7 is the proposed runtime and no other replacement package is a dependency.

## Definition of Done

A caller points `KUAIDE_CLIPS_DIR` at the original-clips directory and receives a JSON manifest in a separate output directory. Every top-level file has its exact filename, byte size and full SHA-256. The manifest stores no absolute source paths, media metadata guesses or unsupported camera-originality claims. Collection leaves source files and earlier reports unchanged. Tests use temporary bytes only.

### Goals

- [x] Read source location only from `KUAIDE_CLIPS_DIR` and hash every top-level regular file.
- [x] Preserve spaced and Unicode filenames without absolute source paths.
- [x] Leave media format, camera, originality and footage categories unknown.
- [x] Refuse existing reports and output inside the repository or original-clips directory.
- [x] Verify behavior with isolated temporary fixtures and obtain independent review before implementation.

## Current State
Base commit: 9f2c01fd4d836a4df31a3fb8f2f8400acd59939c

The repository has no benchmark source at the base commit. The roadmap requires `spikes/stabilization-benchmark/clips.manifest.json` with SHA-256, and AGENTS.md requires source paths to come from `KUAIDE_CLIPS_DIR`. The missing WP 1A commit `e1d7d4d` is unavailable. This plan introduces only an offline input inventory; subsequent probe, render and scoring work remains unplanned here. No app source or owner-decided behavior changes.

## Module Shape

`spikes/stabilization-benchmark/write-clip-manifest.ps1`
`spikes/stabilization-benchmark/test-clip-manifest.ps1`
`spikes/stabilization-benchmark/README.md`

## Step 1: Add the read-only manifest harness

Resolve the environment source directory and explicit output directory. Hash top-level files, preserve basename-only identities and record unknown media evidence. Check size and modification time across hashing. Publish with create-new semantics outside protected directories.
```diff
diff --git a/spikes/stabilization-benchmark/write-clip-manifest.ps1 b/spikes/stabilization-benchmark/write-clip-manifest.ps1
new file mode 100644
index 0000000..8c701fe
--- /dev/null
+++ b/spikes/stabilization-benchmark/write-clip-manifest.ps1
@@ -0,0 +1,73 @@
+#requires -Version 7.0
+[CmdletBinding()]
+param([Parameter(Mandatory)][string]$OutputDirectory)
+Set-StrictMode -Version Latest
+$ErrorActionPreference = 'Stop'
+
+function Resolve-PlainPath([string]$Path, [bool]$Directory) {
+    $item = Get-Item -LiteralPath $Path -Force
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
+if ([string]::IsNullOrWhiteSpace($env:KUAIDE_CLIPS_DIR)) { throw 'Set KUAIDE_CLIPS_DIR to the original-clips directory.' }
+$clips = Resolve-PlainPath $env:KUAIDE_CLIPS_DIR $true
+$output = Resolve-PlainPath $OutputDirectory $true
+$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
+foreach ($directory in @($clips, $repo)) {
+    if (Test-WithinDirectory $output $directory) { throw 'Output must be outside the repository and original-clips directory.' }
+}
+$reportPath = Join-Path $output 'clips.manifest.json'
+if (Test-Path -LiteralPath $reportPath) { throw "Output already exists: $reportPath" }
+$names = [string[]]@(Get-ChildItem -LiteralPath $clips -File -Force | ForEach-Object Name)
+[Array]::Sort($names, [StringComparer]::Ordinal)
+if ($names.Count -eq 0) { throw 'No top-level files found in the original-clips directory.' }
+$entries = @(
+    foreach ($name in $names) {
+        $path = Resolve-PlainPath (Join-Path $clips $name) $false
+        $before = Get-Item -LiteralPath $path -Force
+        $size = $before.Length
+        $modified = $before.LastWriteTimeUtc
+        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
+        $after = Get-Item -LiteralPath $path -Force
+        if ($after.Length -ne $size -or $after.LastWriteTimeUtc -ne $modified) { throw "File changed during hashing: $name" }
+        [ordered]@{
+            file_name = $name
+            size_bytes = $size
+            sha256 = $hash
+            media_format = 'unknown'
+            camera = 'unknown'
+            originality = 'unknown'
+            footage_categories = @()
+            evidence = 'Full file bytes hashed; media content and metadata not probed.'
+        }
+    }
+)
+$manifest = [ordered]@{
+    schema_version = 1
+    created_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
+    source = 'KUAIDE_CLIPS_DIR; top-level regular files only'
+    files = $entries
+}
+$json = $manifest | ConvertTo-Json -Depth 8
+$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
+try {
+    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
+    $stream.Write($bytes, 0, $bytes.Length)
+} finally {
+    $stream.Dispose()
+}
+Write-Output $reportPath
```

## Step 2: Verify identity and output protection

Use known byte fixtures rather than video files. Invoke the actual public script through child PowerShell processes. Compare exact hashes of known bytes, Unicode and spaced names, unchanged source contents, unknown evidence labels and rejection of protected destinations or missing environment input.

```diff
diff --git a/spikes/stabilization-benchmark/test-clip-manifest.ps1 b/spikes/stabilization-benchmark/test-clip-manifest.ps1
new file mode 100644
index 0000000..36057f1
--- /dev/null
+++ b/spikes/stabilization-benchmark/test-clip-manifest.ps1
@@ -0,0 +1,56 @@
+#requires -Version 7.0
+$ErrorActionPreference = 'Stop'
+Set-StrictMode -Version Latest
+$writer = Join-Path $PSScriptRoot 'write-clip-manifest.ps1'
+$work = Join-Path ([IO.Path]::GetTempPath()) ('kuaide-manifest-tests-' + [Guid]::NewGuid().ToString('N'))
+$originals = New-Item -ItemType Directory -Path (Join-Path $work 'originals')
+$output = New-Item -ItemType Directory -Path (Join-Path $work 'output')
+[IO.File]::WriteAllBytes((Join-Path $originals.FullName 'space clip.mp4'), [byte[]]@(97, 98, 99))
+[IO.File]::WriteAllBytes((Join-Path $originals.FullName '歩く clip.MOV'), [byte[]]@())
+$pwsh = (Get-Process -Id $PID).Path
+$priorClips = $env:KUAIDE_CLIPS_DIR
+
+function Assert-True([bool]$Condition, [string]$Message) {
+    if (-not $Condition) { throw $Message }
+}
+
+function Invoke-Manifest([string]$Directory) {
+    $messages = & $pwsh -NoProfile -NonInteractive -File $writer -OutputDirectory $Directory 2>&1
+    return @{ exit_code = $LASTEXITCODE; messages = ($messages -join "`n") }
+}
+
+try {
+    $env:KUAIDE_CLIPS_DIR = $originals.FullName
+    $result = Invoke-Manifest $output.FullName
+    Assert-True ($result.exit_code -eq 0) $result.messages
+    $manifestPath = Join-Path $output.FullName 'clips.manifest.json'
+    $json = Get-Content -LiteralPath $manifestPath -Raw
+    $manifest = $json | ConvertFrom-Json
+    Assert-True ($manifest.files.Count -eq 2) 'Wrong number of files.'
+    $ascii = $manifest.files | Where-Object file_name -eq 'space clip.mp4'
+    $unicode = $manifest.files | Where-Object file_name -eq '歩く clip.MOV'
+    Assert-True ($ascii.size_bytes -eq 3 -and $ascii.sha256 -eq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') 'Full byte hash or size was incorrect.'
+    Assert-True ($unicode.size_bytes -eq 0 -and $unicode.sha256 -eq 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') 'Unicode file was lost or changed.'
+    Assert-True (-not $json.Contains($originals.FullName) -and -not $json.Contains($originals.FullName.Replace('\', '\\'))) 'Manifest contains an absolute source directory.'
+    Assert-True ($ascii.media_format -eq 'unknown' -and $ascii.originality -eq 'unknown' -and $ascii.camera -eq 'unknown' -and $ascii.footage_categories.Count -eq 0) 'Filename was promoted to media evidence.'
+    Assert-True ([Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $originals.FullName 'space clip.mp4'))) -eq 'abc') 'Original bytes changed.'
+    Write-Output 'PASS names, full hashes and unknown evidence survive collection'
+
+    $hashBefore = (Get-FileHash -LiteralPath $manifestPath).Hash
+    $result = Invoke-Manifest $output.FullName
+    Assert-True ($result.exit_code -ne 0 -and (Get-FileHash -LiteralPath $manifestPath).Hash -eq $hashBefore) 'Existing output was replaced.'
+    foreach ($directory in @($originals.FullName, $PSScriptRoot)) {
+        $result = Invoke-Manifest $directory
+        Assert-True ($result.exit_code -ne 0 -and -not (Test-Path (Join-Path $directory 'clips.manifest.json'))) 'Protected directory received a report.'
+    }
+    Write-Output 'PASS output guards preserve reports and source directories'
+
+    $env:KUAIDE_CLIPS_DIR = ''
+    $emptyOutput = New-Item -ItemType Directory -Path (Join-Path $work 'missing-environment')
+    $result = Invoke-Manifest $emptyOutput.FullName
+    Assert-True ($result.exit_code -ne 0 -and $result.messages -match 'KUAIDE_CLIPS_DIR' -and -not (Test-Path (Join-Path $emptyOutput.FullName 'clips.manifest.json'))) 'Missing environment was accepted.'
+    Write-Output 'PASS missing source environment fails without output'
+    Write-Output "Scratch results: $work"
+} finally {
+    $env:KUAIDE_CLIPS_DIR = $priorClips
+}
```

## Step 3: Document collection and limits

Document how to set the source environment variable and choose an output directory. Explain that byte identity does not establish video validity, category or camera originality. Review behavior and names before this prose. This change adds no source comments that require owner approval.

```diff
diff --git a/spikes/stabilization-benchmark/README.md b/spikes/stabilization-benchmark/README.md
new file mode 100644
index 0000000..30218bb
--- /dev/null
+++ b/spikes/stabilization-benchmark/README.md
@@ -0,0 +1,27 @@
+# Clip manifest spike
+
+This PowerShell 7 script hashes top-level files from the directory named by `KUAIDE_CLIPS_DIR`. It records filenames, byte sizes and full-file SHA-256. It never modifies the input files. It does not probe, decode or classify media and does not run FFmpeg.
+
+Set the environment variable to the local original-clips directory. Keep only original clips there, as AGENTS.md requires. Supply an existing output directory outside this repository and the clips directory:
+
+```powershell
+$env:KUAIDE_CLIPS_DIR = 'C:/original-clips'
+pwsh -NoProfile -File ./spikes/stabilization-benchmark/write-clip-manifest.ps1 `
+  -OutputDirectory 'C:/benchmark-evidence/run-01'
+```
+
+The script creates `clips.manifest.json` with create-new semantics. It refuses an existing report. It rejects linked paths, including junctions or symbolic links in ancestors. It does not create or remove directories. A disk write failure can leave a new incomplete report, but cannot overwrite an earlier file.
+
+The manifest uses filenames only, so it can later be reviewed for inclusion at `spikes/stabilization-benchmark/clips.manifest.json` without committing a computer-specific source directory. Review filenames for private information before sharing. Do not commit original footage or local output directories. Future benchmark scripts must resolve the filenames against `KUAIDE_CLIPS_DIR`.
+
+All top-level regular files are candidates, regardless of extension; nested directories are not scanned. A file listed here is not proven to be playable video or a camera original. Format, camera, originality and footage categories remain unknown until later probe or owner evidence. Full hashes identify exact bytes; they do not establish how those bytes were recorded or edited.
+
+Do not change input files or directory links while collection runs. Size and modification time are checked before and after hashing, but this is not a filesystem snapshot. Hashing large footage can take time; cancellation before the final write leaves existing files intact.
+
+Run the offline checks:
+
+```powershell
+pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-clip-manifest.ps1
+```
+
+The checks create temporary byte fixtures with spaced and Unicode names, invoke the public script in child PowerShell processes and verify hashes, unknown evidence, output guards and the environment requirement. They do not access real footage or prove media validity. They print and preserve the unique temporary results directory for inspection.
```

## Verification

- [x] Run `pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-clip-manifest.ps1`; expect three PASS summaries and no exception. The command prints its temporary results directory.
- [x] Run `git diff --check` and inspect the changed-file list for this package only.
- [x] Have a fresh reviewer compare every proposed diff with the base and requirements. Use the independent-review fallback because `planner` is unavailable.
- [x] After implementation, obtain a fresh source/test review. Do not claim actual footage, benchmark or media-probe evidence from the byte fixtures.

## Notes for agents

1. `user-decided`: keep original clips unchanged, read the local clips folder from `KUAIDE_CLIPS_DIR`, and commit no video clips (AGENTS.md, Working rules). This script reads full file bytes for hashing only; it does not invoke a media decoder. No real clips were accessed while preparing this plan.
2. `proposed`: use a standalone PowerShell 7 script, not app infrastructure. It has no dependency on the separate WP 1C inventory plan or unmerged code. Repeated small path checks are deliberate isolation between spikes, not a shared utility proposal.
3. `proposed`: collect every top-level regular file rather than infer media type from its extension. The owner's originals folder is expected to contain only clips, but the manifest does not assert that. Source filenames use ordinal sorting. Symlink/reparse paths are rejected rather than followed; nested directories are not scanned.
4. `proposed`: JSON stores filenames only. A later reviewed manifest can be committed at the roadmap's target location; future consumers resolve filenames against the environment directory. Reports stay outside the repo and original directory by default. Sharing or committing a manifest still requires filename review and applicable Git approval.
5. `proposed`: an existing output directory and a new fixed report name avoid replacing data. No directory links may be changed concurrently. Size/mtime checks catch ordinary concurrent modifications but are not a snapshot guarantee. A write failure may leave an incomplete newly created report; preexisting files are never replaced.
6. `inferred from code`: there are no existing benchmark callers, test framework or build targets at this base commit. Three tests groups cover byte identities and evidence limits, protected output locations, and missing source environment. Real media validity, camera metadata, runtime hashing performance and concurrent writers remain unverified.
7. Planning checks were performed against ordinary scratch source in the system temporary directory. The three behavior groups passed there, and generated diffs passed `git apply --check` against the repository. These checks support the draft; fresh independent review remains required before implementation. No source was installed into the repository by the plan author.
8. Applicable skills were read from `henrico813/personal-dev-env` at `64a2efecd10a7926755d502fb558e7ed424a4626`: `ai/AGENTS.md`, `create-plan`, `code-documentation`, `behavior-focused-testing`, and `plain-direct-english`. `planner` is unavailable, so diffs were generated with `git diff --no-index` under the repository adaptation.
9. Check current account allowance before implementation and at stable points. At 5% or below, reach a stable point, provide a handover and stop. Finish bounded work by the current 16:30 PT stable-stop target. No long uninterruptible run, push, PR or merge is authorized here.
10. Independent plan review by the root agent required hidden-file enumeration and metadata access to use `-Force`; the author regenerated the diff and revalidated it. Root confirmed corrected context and patch applicability before implementation.
11. The implemented suite passed all three behavior groups. A fresh source/test reviewer independently reran it with exit 0, approved the code, found no tests to delete, and demonstrated that an absolute-source-path mutation is caught by the privacy assertion in scratch. No actual footage was accessed. Root scratch results: `C:/Users/bchen/AppData/Local/Temp/kuaide-manifest-tests-f99419f7bda547dcb2724f91e657cb6f`.
