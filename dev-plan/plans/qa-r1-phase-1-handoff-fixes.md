# QA-R1: Fix the findings from the Phase 1 handoff check

## Overview

On 2026-10-29 Claude Code checked the Codex handoff `dev-plan/handover/2026-10-29-phase-1-spikes.md`. Every claimed result reproduced, but the check found six problems: the handoff makes Phase 1 sound further along than it is, the scripts need PowerShell 7 that only exists inside Codex's private folder, the stabilization smoke never shows that stabilization reduces shake, the FFmpeg download script has two small defects, STATUS.md has stale and jargon-heavy notes, and five branches wait unmerged with no review by a second agent type. This plan fixes all six. It adds no new Phase 1 scope. Opening PRs and merging (Step 5) still need the owner's approval in chat.

## Definition of Done

PowerShell 7 is installed for all users on the current Windows host. The download script no longer reuses PowerShell's reserved `$input` name and renames a verified download from `.zip.partial` to `.zip`. The software smoke fails unless libvidstab cuts the leftover motion of a synthetic shaken video to a quarter or less. STATUS.md opens with a plain-words Phase 1 progress table and has no stale machine or Git notes. A fresh Claude Code reviewer has reviewed all Codex-written scripts. With owner approval, the six branches are merged into `main` in order.

### Goals

- [ ] Install PowerShell 7 system-wide so any agent or the owner can run the scripts.
- [ ] Fix the download script's variable name and archive naming.
- [ ] Prove with a measured check that the stabilizer reduces shake.
- [ ] Rewrite the top of STATUS.md in plain words and remove stale notes.
- [ ] Get a fresh Claude Code review of all Codex-written scripts.
- [ ] Merge the branch stack into `main` after owner approval.

## Current State
Base commit: 1d826d3f4ff15b8af0c2ee2409891e4e867950d5

The base is the tip of `feat/wp-1c-software-smoke`, stacked on `feat/wp-1c-windows-build`, `feat/wp-1c-build-inventory` and `docs/phase-1-recovery`. `feat/wp-1a-clip-manifest` is a separate branch off `docs/phase-1-recovery`. `main` is still at `4dcb02c`. All four offline suites and the real smoke pass on this host when run with Codex's bundled `pwsh.exe`. Git for Windows 2.56 was installed and signed in to GitHub on 2026-10-29; PowerShell 7 is not installed system-wide.

## Module Shape

`app/third-party/get-windows-ffmpeg.ps1`
`app/third-party/README.md`
`spikes/media-capabilities/test-software-runtime.ps1`
`spikes/media-capabilities/SOFTWARE-SMOKE.md`
`dev-plan/STATUS.md`

## Step 1: Install PowerShell 7

All project scripts start with `#requires -Version 7.0`. Install it once for this host from winget, which checks the installer hash. Work on a new branch `fix/qa-r1-handoff-fixes` cut from the base commit.

```powershell
winget install --id Microsoft.PowerShell -e --source winget --accept-package-agreements --accept-source-agreements
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
git switch -c fix/qa-r1-handoff-fixes 1d826d3f4ff15b8af0c2ee2409891e4e867950d5
```

## Step 2: Fix the download script

`$input` is a PowerShell automatic variable; assigning it works today but can break silently. A verified archive kept its `.zip.partial` name, so nobody can tell a good download from a broken one.

```diff
diff --git a/app/third-party/get-windows-ffmpeg.ps1 b/app/third-party/get-windows-ffmpeg.ps1
index 4ef8859..a0a036a 100644
--- a/app/third-party/get-windows-ffmpeg.ps1
+++ b/app/third-party/get-windows-ffmpeg.ps1
@@ -42,14 +42,14 @@ if ($ArchivePath) {
     $client = [Net.Http.HttpClient]::new()
     $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromMinutes(5))
     $response = $null
-    $input = $null
+    $download = $null
     try {
         $response = $client.GetAsync($url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancel.Token).GetAwaiter().GetResult()
         $response.EnsureSuccessStatusCode() | Out-Null
-        $input = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
-        $input.CopyToAsync($output, 81920, $cancel.Token).GetAwaiter().GetResult() | Out-Null
+        $download = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
+        $download.CopyToAsync($output, 81920, $cancel.Token).GetAwaiter().GetResult() | Out-Null
     } finally {
-        if ($null -ne $input) { $input.Dispose() }
+        if ($null -ne $download) { $download.Dispose() }
         if ($null -ne $response) { $response.Dispose() }
         $output.Dispose()
         $cancel.Dispose()
@@ -81,5 +81,7 @@ try {
     $sha.Dispose()
     $file.Dispose()
 }
+# A verified, fully extracted download is complete, so drop the .partial suffix.
+if (-not $ArchivePath) { [IO.File]::Move($archiveFile, ($archiveFile -replace '\.partial$', '')) }
 Write-Output (Join-Path $destination "$asset/bin/ffmpeg.exe")
 Write-Output (Join-Path $destination "$asset/bin/ffprobe.exe")
diff --git a/app/third-party/README.md b/app/third-party/README.md
index 3e3b5b5..210b600 100644
--- a/app/third-party/README.md
+++ b/app/third-party/README.md
@@ -21,7 +21,7 @@ pwsh -NoProfile -File ./app/third-party/get-windows-ffmpeg.ps1
 
 For an already downloaded local archive, add `-ArchivePath 'C:/downloads/candidate.zip'`. The same pinned digest is required. No alternate URL or checksum override is available. The script opens the archive read-only and keeps that handle open through checksum verification and extraction. No archive entry is extracted before the digest matches. .NET's ZIP extraction checks entry paths and refuses existing files.
 
-All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.
+All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. A downloaded archive is named `download-<id>.zip.partial` until it passes the hash check and extraction, then renamed to `download-<id>.zip`; a `.partial` file is always unverified or incomplete. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.
 
 The HTTP transfer has a five-minute cancellation deadline. This approximately 195 MB archive should be a bounded acquisition task; extraction and inventory are separate stopping points. No source build or long render batch is part of this script.
 
```

## Step 3: Show that stabilization reduces shake

The current smoke runs libvidstab on `testsrc2`, which does not shake, so it proves only that the filter runs. The new check pans one still frame along a fixed sine path, stabilizes it, and compares the mean frame-to-frame difference in the center. A prototype on 2026-10-29 measured 20.7 for the shaky video and 1.9 after stabilization, so the 0.25 ratio leaves a wide margin.

```diff
diff --git a/spikes/media-capabilities/test-software-runtime.ps1 b/spikes/media-capabilities/test-software-runtime.ps1
index bc166a7..ccdb499 100644
--- a/spikes/media-capabilities/test-software-runtime.ps1
+++ b/spikes/media-capabilities/test-software-runtime.ps1
@@ -87,6 +87,21 @@ try {
         if ($stream.codec_name -ne $codec -or $stream.width -ne 320 -or $stream.height -ne 180 -or [int]$stream.nb_read_frames -ne 30 -or [Math]::Abs($duration - 1.0) -gt 0.05) { throw "Output does not match expected codec, size, frame count or duration: $name" }
         $checks.Add([ordered]@{ file_name = $name; codec = $stream.codec_name; width = $stream.width; height = $stream.height; decoded_frame_count = [int]$stream.nb_read_frames; duration_seconds = $duration; sha256 = (Get-FileHash -LiteralPath (Join-Path $output $name)).Hash.ToLowerInvariant() })
     }
+    # A still frame panned by a known sine path has only camera shake, so the
+    # frame-to-frame difference in the center measures leftover motion.
+    $null = Invoke-SmokeCommand 'still-frame' $ffmpeg ($common + @('-f', 'lavfi', '-i', 'testsrc2=size=400x260', '-frames:v', '1', 'still.png'))
+    $null = Invoke-SmokeCommand 'encode-shaky' $ffmpeg ($common + @('-loop', '1', '-framerate', '30', '-t', '2', '-i', 'still.png', '-vf', "crop=320:180:'40+30*sin(2*PI*3*t)':'40+20*sin(2*PI*2*t+1)'", '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18', '-pix_fmt', 'yuv420p', '-threads', '2', 'shaky.mp4'))
+    $null = Invoke-SmokeCommand 'detect-shake' $ffmpeg ($common + @('-i', 'shaky.mp4', '-vf', 'vidstabdetect=shakiness=10:accuracy=15:result=shaky.trf', '-f', 'null', '-'))
+    $null = Invoke-SmokeCommand 'transform-shake' $ffmpeg ($common + @('-i', 'shaky.mp4', '-vf', 'vidstabtransform=input=shaky.trf:smoothing=30:optzoom=0:crop=black', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18', '-pix_fmt', 'yuv420p', '-threads', '2', 'steadied.mp4'))
+    $motion = [ordered]@{}
+    foreach ($name in @('shaky.mp4', 'steadied.mp4')) {
+        $measure = Invoke-SmokeCommand "measure-$name" $ffmpeg @('-nostdin', '-hide_banner', '-v', 'error', '-i', $name, '-vf', 'crop=160:90:80:45,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-', '-f', 'null', '-')
+        $values = @([regex]::Matches($measure.stdout, 'YAVG=([0-9.]+)') | ForEach-Object { [double]::Parse($_.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) })
+        if ($values.Count -ne 59) { throw "Expected 59 frame differences, got $($values.Count): $name" }
+        $motion[$name] = ($values | Measure-Object -Average).Average
+    }
+    $report.shake_check = [ordered]@{ shaky_mean_difference = $motion['shaky.mp4']; steadied_mean_difference = $motion['steadied.mp4']; required_ratio_at_most = 0.25 }
+    if ($motion['shaky.mp4'] -lt 5 -or $motion['steadied.mp4'] -gt 0.25 * $motion['shaky.mp4']) { throw "Stabilization did not reduce synthetic shake enough: $($motion['shaky.mp4']) -> $($motion['steadied.mp4'])" }
     foreach ($tool in $tools.Values) {
         if ($tool.sha256 -ne (Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant()) { throw 'A tool changed during the smoke run.' }
     }
diff --git a/spikes/media-capabilities/SOFTWARE-SMOKE.md b/spikes/media-capabilities/SOFTWARE-SMOKE.md
index 287da76..dd04d2d 100644
--- a/spikes/media-capabilities/SOFTWARE-SMOKE.md
+++ b/spikes/media-capabilities/SOFTWARE-SMOKE.md
@@ -9,7 +9,7 @@ pwsh -NoProfile -File ./spikes/media-capabilities/test-software-runtime.ps1 `
   -OutputDirectory 'C:/media-evidence/new-software-smoke'
 ```
 
-The smoke generates one second of synthetic `testsrc2` at 320x180 and 30 fps. It encodes H.264 with libx264 and HEVC with libx265, runs libvidstab detection and transformation, then decodes/counts frames with ffprobe. Every resulting video must have the expected codec, 320x180 dimensions, 30 decoded frames and duration within 0.05 seconds of one second. A nonempty transform file is also required. Native commands use a 30-second timeout and fixed relative filenames in the new working directory. FFmpeg receives `-n` to refuse overwriting.
+The smoke generates one second of synthetic `testsrc2` at 320x180 and 30 fps. It encodes H.264 with libx264 and HEVC with libx265, runs libvidstab detection and transformation, then decodes/counts frames with ffprobe. Every resulting video must have the expected codec, 320x180 dimensions, 30 decoded frames and duration within 0.05 seconds of one second. A nonempty transform file is also required. A second check shows that stabilization reduces motion: it pans one still `testsrc2` frame along a fixed sine path for two seconds (`shaky.mp4`), stabilizes it with libvidstab (`steadied.mp4`), and measures the mean frame-to-frame brightness difference in the center of each video. The shaky video must reach a difference of at least 5, and the steadied video must be at most a quarter of the shaky one. A first run on 2026-10-29 measured 20.7 and 1.9. Native commands use a 30-second timeout and fixed relative filenames in the new working directory. FFmpeg receives `-n` to refuse overwriting.
 
 Success writes `software-smoke.json` after all checks and before/after tool-hash comparisons pass. A pipeline failure writes `software-smoke-failed.json` with failed status and the commands completed so far, then exits with an error. Input-path rejection creates no report. The JSON preserves exact arguments, exit codes, stdout, stderr, elapsed milliseconds, versions, tool/output hashes and host OS/architecture. Keep output files outside the repository; retain the JSON for inspection. A disk write failure may leave an incomplete new report.
 
```

## Step 4: Rewrite the top of STATUS.md in plain words

Add a plain-words summary and a progress table so the owner can see how much of Phase 1 is left. Remove the stale machine window and the out-of-date Git notes. Also set the `Last updated` line to the date, time and agent of the commit.

```diff
diff --git a/dev-plan/STATUS.md b/dev-plan/STATUS.md
index 9a7cf5a..56b5cdf 100644
--- a/dev-plan/STATUS.md
+++ b/dev-plan/STATUS.md
@@ -4,20 +4,29 @@ Last updated: 2026-10-29 15:59 PT by Codex.
 
 ## Current position
 
+In plain words: Phase 1 has started, but most of it is still ahead. So far the agents have a checked copy of FFmpeg for Windows, a script that lists clip files with their fingerprints, and a short test showing that FFmpeg can encode video and that its stabilizer reduces shake on a computer-made test video. No real footage has been tested, no stabilizer has been compared, and the preview test has not started.
+
+| Phase 1 part | Done | Not started |
+|---|---|---|
+| 1A Stabilization benchmark | Clip fingerprint list script | Benchmark runs, Gyroflow, Resolve, scoring, comparison page |
+| 1B Preview playback | Nothing | Tauri test app and all measurements |
+| 1C Media tools | Windows FFmpeg pinned and checked; software encode and synthetic stabilization tests | Mac FFmpeg, hardware encoders, probing your camera files, HDR-to-SDR method, license review |
+| Decision record | Nothing | `dev-plan/decision-record.md` |
+
 - Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
 - Phase 1 is approved. Bounded replacement spikes are implemented; no app UI or core implementation has started.
 - The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. Replacements are explicitly labeled; compare any recovered plans before combining work.
 - Recovery rules and documents: `docs/phase-1-recovery` at `9f2c01f`. WP 1C-R1 collector: `feat/wp-1c-build-inventory` at `dbe42b5`. WP 1A-R1 manifest: `feat/wp-1a-clip-manifest` at `957089c`, with status correction `2daa176`. Both packages passed independent review and their offline suites.
 - WP 1C-R2 is committed at `a4dff44` on `feat/wp-1c-windows-build`, based on `dbe42b5`. The acquisition, real listing evidence, source and tests passed independent review.
 - WP 1C-R3 is committed at `bbbb76f` on the current branch, `feat/wp-1c-software-smoke`, based on `a4dff44`. It passed real synthetic encoding/filter checks and independent source/evidence review: nine zero-exit commands and three 320x180, 30-frame, one-second outputs. See `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`. No original footage or hardware encoder has been tested.
-- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. Elevated Git execution resolves metadata write restrictions. No PR or merge is authorized.
+- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. No PR or merge is authorized.
 - Account allowance at about 15:59 PT: 11% remains in the five-hour window and 58% in the weekly window. These are point-in-time readings; recheck at each stable point. Begin wrap-up at 5% remaining or earlier; the handover must be ready and work already stopped at a stable point before either the five-hour or weekly allowance reaches 1%.
 
 ## Machines
 
 | Machine | Details | Availability |
 |---|---|---|
-| Current Windows host | Verified by CIM: Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, 67,865,284,608 bytes RAM, SSSTC 1 TB NVMe. Session path `C:\Users\bchen`; original clips drive is absent. Bundled Git, Python and PowerShell work by absolute paths. Pinned FFmpeg candidate is local and ignored. | Owner's temporary window: available until about 17:00 PT on 2026-10-29; asleep about 17:00-17:20 PT. Stable-stop target: 16:30 PT. Availability after 17:20 awaits owner details. No push permission is implied. |
+| Current Windows host | Verified by CIM: Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, 67,865,284,608 bytes RAM, SSSTC 1 TB NVMe. Session path `C:\Users\bchen`; original clips drive is absent. Git for Windows and PowerShell 7 are installed system-wide and on PATH; command-line Git is signed in to GitHub. Pinned FFmpeg candidate is local and ignored. | Unknown; ask the owner at session start. No push permission is implied. |
 | Original Windows reference PC | Historic inventory: i7-14700K, RTX 3080 + UHD 770, 32 GB RAM; Rust, Node.js, Python, Git and Resolve. Clips expected at `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`. This machine and its clips are not accessible here. | Unknown; current host results do not satisfy its evidence requirement. |
 | Apple Silicon Mac | Not checked yet | Unknown |
 
@@ -76,5 +85,5 @@ Last updated: 2026-10-29 15:59 PT by Codex.
 
 ## GitHub connection and publication
 
-- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. Command-line Git Credential Manager has no usable sign-in and cannot push noninteractively; do not confuse that with the healthy Codex connector.
+- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. On 2026-10-29 the owner signed command-line Git in to GitHub through Git Credential Manager, so `git push` works from any terminal on the current Windows host.
 - Verified remote heads before this publication-record commit: recovery `9f2c01f`, clip manifest `2daa176`, build inventory `dbe42b5`, Windows build `a4dff44`, software smoke `9079706`. This final record is a following documentation commit on the software-smoke branch; verify its remote HEAD after publication.
```

## Step 5: Review, then merge the stack with owner approval

AGENTS.md now asks for a Claude Code review of Codex work before any PR. Start one fresh Claude Code reviewer (not the agent that wrote Steps 2-4) with `review-plan` and `behavior-focused-testing` on every PowerShell script in `app/third-party/` and `spikes/`, including `spikes/stabilization-benchmark/` from `feat/wp-1a-clip-manifest`. Fix confirmed findings on `fix/qa-r1-handoff-fixes` before opening PRs.

Then ask the owner to approve pushing and opening the PRs. Merge with squash merges, one at a time, in this order: `docs/phase-1-recovery`, `feat/wp-1a-clip-manifest`, `feat/wp-1c-build-inventory`, `feat/wp-1c-windows-build`, `feat/wp-1c-software-smoke`, `fix/qa-r1-handoff-fixes`. A squash merge leaves the next stacked branch carrying its parent's old commits, so after each merge move the next branch onto `main` before its PR is merged:

```powershell
git fetch origin
git rebase --onto origin/main <old-parent-tip> <next-branch>
git push --force-with-lease origin <next-branch>
```

Each merge and force push needs its own owner approval unless STATUS.md records a standing approval.

## Verification

Run on the current Windows host with PowerShell 7 on PATH. Every command must print PASS lines and exit 0. The smoke report must show `status` `passed` and a `shake_check` ratio of 0.25 or less.

```powershell
pwsh -NoProfile -File ./app/third-party/test-windows-ffmpeg.ps1
pwsh -NoProfile -File ./spikes/media-capabilities/test-build-inventory.ps1
$bin = (Resolve-Path './app/third-party/bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0/bin').Path
$out = Join-Path $env:TEMP ('kuaide-smoke-' + [guid]::NewGuid().ToString('N'))
pwsh -NoProfile -File ./spikes/media-capabilities/test-software-runtime.ps1 -FfmpegPath "$bin/ffmpeg.exe" -FfprobePath "$bin/ffprobe.exe" -OutputDirectory $out
(Get-Content "$out/software-smoke.json" -Raw | ConvertFrom-Json).shake_check
```

## Notes for agents

1. `orchestrator-proposed`: put Steps 2-4 on one new branch stacked on `feat/wp-1c-software-smoke`, rather than amending the five published branches. Evidence: those branches were published with verified hashes, and rewriting them would void that record.
2. `orchestrator-proposed`: extend `test-software-runtime.ps1` instead of adding a new script, so the shake check reuses `Invoke-SmokeCommand`, its timeout and the report.
3. `inferred from code`: Steps 2-4 diffs were generated with `git diff` from a scratch worktree at the base commit, and the edited suites passed there on 2026-10-29: `test-windows-ffmpeg.ps1` PASS, real smoke `passed` with shake 20.67 to 1.88. `planner` is not installed; a fresh reviewer replaces `planner check` (AGENTS.md adaptation 2).
4. The rename in Step 2 runs only on the network download path. No offline test covers it, because a real pass needs the 195 MB pinned archive. A first draft used `[IO.Path]::ChangeExtension($path, $null)`, which leaves a trailing dot (`download-x.zip.`); the `-replace '\.partial$'` form was checked to give `download-x.zip`. The existing local file `app/third-party/bin/download-c0741458811d411fba5146739512e1a0.zip.partial` matches the pinned hash and can be renamed by hand.
5. `vidstabtransform` with `optzoom=0` prints a warning that L1 path optimization needs a zoom budget, then completes with exit 0. `optzoom=1` avoids the warning but its zoom resampling raises the measured residual to 8.5 (ratio 0.41), so the plan keeps `optzoom=0`.
6. The shake check covers only synthetic two-axis panning of a still frame. It does not cover rotation, rolling shutter, parallax, real footage or quality scoring; those stay in WP 1A.
7. Diff sizes: Steps 2-4 change about 45 lines, well under the 700-line PR limit.
8. Commits and PRs carry no AI attribution lines (AGENTS.md adaptation 4).
