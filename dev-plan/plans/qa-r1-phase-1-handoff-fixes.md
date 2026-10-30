# QA-R1: Fix the findings from the Phase 1 handoff check

## Overview

On 2026-10-29 Claude Code checked the Codex handoff `dev-plan/handover/2026-10-29-phase-1-spikes.md`. Every claimed result reproduced, but the check found six problems: the handoff makes Phase 1 sound further along than it is, the scripts need PowerShell 7 that only exists inside Codex's private folder, the stabilization smoke never shows that stabilization reduces shake, the FFmpeg download script has two small defects, STATUS.md has stale and jargon-heavy notes, and five branches wait unmerged with no review by a second agent type. This plan fixes all six. It adds no new Phase 1 scope. Opening PRs and merging (Step 5) still need the owner's approval in chat, and the owner may need to approve one Windows administrator prompt in Step 1.

## Definition of Done

PowerShell 7 is installed for all users on the current Windows host. The download script no longer reuses PowerShell's reserved `$input` name, and it renames a verified download from `.zip.partial` to `.zip` without failing the run if the rename is blocked. The software smoke fails unless libvidstab cuts the leftover motion of a synthetic shaken video to a quarter or less, and its report states the ratio. STATUS.md opens with a plain-words Phase 1 progress table and has no stale machine, allowance or Git notes. A fresh Claude Code reviewer has reviewed all Codex-written scripts. With owner approval, the six branches are merged into `main` in the order below, and STATUS.md and a handover record the result.

### Goals

- [ ] Install PowerShell 7 system-wide so any agent or the owner can run the scripts.
- [ ] Fix the download script's variable name and archive naming.
- [ ] Prove with a measured check that the stabilizer reduces shake, and record it in the evidence.
- [ ] Rewrite the top of STATUS.md in plain words and remove stale notes.
- [ ] Get a fresh Claude Code review of all Codex-written scripts.
- [ ] Merge the branches into `main` after owner approval, resolving the known STATUS.md conflict.

## Current State
Base commit: 8d1eb0ae1b10acbd62004ec0bf21605d36c3be54

The base is the tip of `feat/wp-1c-software-smoke`, which adds this plan on top of `1d826d3`. That branch is stacked on `feat/wp-1c-windows-build` (`a4dff44`), `feat/wp-1c-build-inventory` (`dbe42b5`) and `docs/phase-1-recovery` (`9f2c01f`). `feat/wp-1a-clip-manifest` (`2daa176`) is a separate branch off `docs/phase-1-recovery`. `main` is still at `4dcb02c`. All four offline suites and the real smoke pass on this host when run with Codex's bundled `pwsh.exe`. Git for Windows 2.56 was installed and signed in to GitHub on 2026-10-29; PowerShell 7 is not installed system-wide.

## Module Shape

`app/third-party/get-windows-ffmpeg.ps1`
`app/third-party/README.md`
`spikes/media-capabilities/test-software-runtime.ps1`
`spikes/media-capabilities/SOFTWARE-SMOKE.md`
`spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`
`dev-plan/STATUS.md`

## Step 1: Install PowerShell 7

All project scripts start with `#requires -Version 7.0`. Install it once for this host from winget, which checks the installer hash. The machine-wide installer shows a Windows administrator prompt that the owner may need to approve. The current shell does not see the new PATH, so the check uses the full path. Work on `fix/qa-r1-handoff-fixes`, which was cut from the base commit and holds this revised plan.

```powershell
winget install --id Microsoft.PowerShell -e --source winget --accept-package-agreements --accept-source-agreements
& "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
git switch fix/qa-r1-handoff-fixes
```

Open a new terminal before Step 2 so `pwsh` is on PATH.

## Step 2: Fix the download script

`$input` is a PowerShell automatic variable; assigning it works today but can break silently. A verified archive kept its `.zip.partial` name, so nobody can tell a good download from a broken one. The rename runs only after the hash check and extraction succeed and the file is closed. If it is blocked, for example by antivirus, the script warns and still prints the tool paths, because the tools are already in place.

````diff
diff --git a/app/third-party/README.md b/app/third-party/README.md
index 3e3b5b5..210b600 100644
--- a/app/third-party/README.md
+++ b/app/third-party/README.md
@@ -21,7 +21,7 @@ pwsh -NoProfile -File ./app/third-party/get-windows-ffmpeg.ps1
 
 For an already downloaded local archive, add `-ArchivePath 'C:/downloads/candidate.zip'`. The same pinned digest is required. No alternate URL or checksum override is available. The script opens the archive read-only and keeps that handle open through checksum verification and extraction. No archive entry is extracted before the digest matches. .NET's ZIP extraction checks entry paths and refuses existing files.
 
-All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.
+All downloaded and extracted files stay under ignored `app/third-party/bin/`. Success places the archive's root inside `bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/` and prints paths to both executables. A downloaded archive is named `download-<id>.zip.partial` until it passes the hash check and extraction, then renamed to `download-<id>.zip`; a `.partial` file is always unverified or incomplete. An existing candidate directory makes the script fail. It creates uniquely named download/staging paths and never deletes or replaces previous files. A failed run may leave ignored partial downloads or extraction directories; inspect them before any later owner-approved cleanup. Do not change directory links concurrently. Linked paths are rejected.
 
 The HTTP transfer has a five-minute cancellation deadline. This approximately 195 MB archive should be a bounded acquisition task; extraction and inventory are separate stopping points. No source build or long render batch is part of this script.
 
diff --git a/app/third-party/get-windows-ffmpeg.ps1 b/app/third-party/get-windows-ffmpeg.ps1
index 4ef8859..266f983 100644
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
@@ -81,5 +81,11 @@ try {
     $sha.Dispose()
     $file.Dispose()
 }
+# A verified, fully extracted download is complete, so drop the .partial suffix.
+# The tools are already in place, so a failed rename only warns.
+if (-not $ArchivePath) {
+    try { [IO.File]::Move($archiveFile, ($archiveFile -replace '\.partial$', '')) }
+    catch { Write-Warning "Verified archive kept its .partial name: $($_.Exception.Message)" }
+}
 Write-Output (Join-Path $destination "$asset/bin/ffmpeg.exe")
 Write-Output (Join-Path $destination "$asset/bin/ffprobe.exe")
````

## Step 3: Show that stabilization reduces shake

The current smoke runs libvidstab on `testsrc2`, which does not shake, so it proves only that the filter runs. The new check pans one still frame along a fixed sine path, stabilizes it, and compares the mean frame-to-frame difference in the center. A run on 2026-10-29 measured 20.67 for the shaky video and 1.88 after stabilization (ratio 0.09), so the 0.25 limit leaves a wide margin. The report now includes the ratio, and the evidence file records the result.

````diff
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
 
diff --git a/spikes/media-capabilities/evidence/2026-10-29-software-smoke.md b/spikes/media-capabilities/evidence/2026-10-29-software-smoke.md
index 3512d1a..cd28911 100644
--- a/spikes/media-capabilities/evidence/2026-10-29-software-smoke.md
+++ b/spikes/media-capabilities/evidence/2026-10-29-software-smoke.md
@@ -44,6 +44,10 @@ All output checks passed. This demonstrates that these software encoder and two-
 
 Timings describe only these tiny commands on this host, including process startup. They are not representative encoding-speed results and cannot be compared with Phase 1 performance targets.
 
+## Shake-reduction check (added by QA-R1)
+
+A later version of the script adds a measured check. It pans one still `testsrc2` frame along a fixed sine path for two seconds, stabilizes it with libvidstab and compares the mean frame-to-frame brightness difference in the center. On the same host and tools, the shaky video measured 20.67 and the steadied video 1.88, a ratio of 0.09 against a required 0.25 or less. This shows the stabilizer removes simple synthetic panning shake. It says nothing about rotation, rolling shutter, parallax or real footage.
+
 ## Reproduction and limits
 
 Run `spikes/media-capabilities/test-software-runtime.ps1` with the verified executable paths and a new output directory outside the repository and tool directories. The committed script contains the exact arguments and output assertions. It records stdout, stderr, timing and hashes in JSON; it uses a 30-second timeout per command and refuses preexisting output directories.
diff --git a/spikes/media-capabilities/test-software-runtime.ps1 b/spikes/media-capabilities/test-software-runtime.ps1
index bc166a7..be390ac 100644
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
+    $report.shake_check = [ordered]@{ shaky_mean_difference = $motion['shaky.mp4']; steadied_mean_difference = $motion['steadied.mp4']; ratio = $motion['steadied.mp4'] / [Math]::Max($motion['shaky.mp4'], 1e-9); required_ratio_at_most = 0.25 }
+    if ($motion['shaky.mp4'] -lt 5 -or $motion['steadied.mp4'] -gt 0.25 * $motion['shaky.mp4']) { throw "Stabilization did not reduce synthetic shake enough: $($motion['shaky.mp4']) -> $($motion['steadied.mp4'])" }
     foreach ($tool in $tools.Values) {
         if ($tool.sha256 -ne (Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant()) { throw 'A tool changed during the smoke run.' }
     }
````

## Step 4: Rewrite the top of STATUS.md in plain words

Add a plain-words summary and a progress table so the owner can see how much of Phase 1 is left. Record where the original plans most likely are, remove the stale machine window, allowance reading and Git notes, and list the approvals Step 5 needs.

````diff
diff --git a/dev-plan/STATUS.md b/dev-plan/STATUS.md
index 9a7cf5a..2e60b61 100644
--- a/dev-plan/STATUS.md
+++ b/dev-plan/STATUS.md
@@ -1,23 +1,33 @@
 # Status
 
-Last updated: 2026-10-29 15:59 PT by Codex.
+Last updated: 2026-10-29 by Claude Code (QA-R1 fixes).
 
 ## Current position
 
+In plain words: Phase 1 has started, but most of it is still ahead. So far the agents have a checked copy of FFmpeg for Windows, a script that lists clip files with their fingerprints, and a short test showing that FFmpeg can encode video and that its stabilizer reduces shake on a computer-made test video. No real footage has been tested, no stabilizer has been compared, and the preview test has not started.
+
+| Phase 1 part | Done | Still to do |
+|---|---|---|
+| 1A Stabilization benchmark | A script that lists clip files with their fingerprints | Run the stabilizers (FFmpeg's, Gyroflow, DaVinci Resolve) on your clips, score them, and build the side-by-side comparison page |
+| 1B Preview playback | Nothing | Build a small test version of the app window (Tauri) and measure how smoothly it plays and seeks video |
+| 1C Media tools | One exact Windows FFmpeg build, downloaded and checked; tests that it can encode video and reduce shake on a computer-made video | A Mac FFmpeg build; video encoding on the graphics card; reading the settings of your camera files; choosing how to convert HDR (bright, wide-color) video to normal video; finishing the license check, which is partly done |
+| Decision record | Nothing | Write `dev-plan/decision-record.md` for your approval |
+
 - Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
 - Phase 1 is approved. Bounded replacement spikes are implemented; no app UI or core implementation has started.
-- The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. Replacements are explicitly labeled; compare any recovered plans before combining work.
+- The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. `docs/phase-1-start` shows they were committed on `feat/wp-1a-stabilization-benchmark`, `feat/wp-1b-preview-playback` and `feat/wp-1c-media-capabilities`, which were never pushed; they are most likely only on the original Windows PC. Replacements are explicitly labeled; compare any recovered plans before combining work.
 - Recovery rules and documents: `docs/phase-1-recovery` at `9f2c01f`. WP 1C-R1 collector: `feat/wp-1c-build-inventory` at `dbe42b5`. WP 1A-R1 manifest: `feat/wp-1a-clip-manifest` at `957089c`, with status correction `2daa176`. Both packages passed independent review and their offline suites.
 - WP 1C-R2 is committed at `a4dff44` on `feat/wp-1c-windows-build`, based on `dbe42b5`. The acquisition, real listing evidence, source and tests passed independent review.
-- WP 1C-R3 is committed at `bbbb76f` on the current branch, `feat/wp-1c-software-smoke`, based on `a4dff44`. It passed real synthetic encoding/filter checks and independent source/evidence review: nine zero-exit commands and three 320x180, 30-frame, one-second outputs. See `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`. No original footage or hardware encoder has been tested.
-- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. Elevated Git execution resolves metadata write restrictions. No PR or merge is authorized.
-- Account allowance at about 15:59 PT: 11% remains in the five-hour window and 58% in the weekly window. These are point-in-time readings; recheck at each stable point. Begin wrap-up at 5% remaining or earlier; the handover must be ready and work already stopped at a stable point before either the five-hour or weekly allowance reaches 1%.
+- WP 1C-R3 is committed at `bbbb76f` on `feat/wp-1c-software-smoke`, based on `a4dff44`. It passed real synthetic encoding/filter checks and independent source/evidence review: nine zero-exit commands and three 320x180, 30-frame, one-second outputs. See `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`. No original footage or hardware encoder has been tested.
+- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. No PR or merge is authorized.
+- QA-R1 (Claude Code check of the Codex handoff) is on `fix/qa-r1-handoff-fixes`: download-script fixes, a measured shake-reduction check, PowerShell 7 installed system-wide, and this plain-words summary. Plan: `dev-plan/plans/qa-r1-phase-1-handoff-fixes.md`.
+- Account allowance: read it fresh at session start and at each stable point. Begin wrap-up at 5% remaining or earlier; the handover must be ready and work already stopped at a stable point before either the five-hour or weekly allowance reaches 1%.
 
 ## Machines
 
 | Machine | Details | Availability |
 |---|---|---|
-| Current Windows host | Verified by CIM: Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, 67,865,284,608 bytes RAM, SSSTC 1 TB NVMe. Session path `C:\Users\bchen`; original clips drive is absent. Bundled Git, Python and PowerShell work by absolute paths. Pinned FFmpeg candidate is local and ignored. | Owner's temporary window: available until about 17:00 PT on 2026-10-29; asleep about 17:00-17:20 PT. Stable-stop target: 16:30 PT. Availability after 17:20 awaits owner details. No push permission is implied. |
+| Current Windows host | Verified by CIM: Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, 67,865,284,608 bytes RAM, SSSTC 1 TB NVMe. Session path `C:\Users\bchen`; original clips drive is absent. Git for Windows and PowerShell 7 are installed system-wide and on PATH; command-line Git is signed in to GitHub. Pinned FFmpeg candidate is local and ignored. | Unknown; ask the owner at session start. No push permission is implied. |
 | Original Windows reference PC | Historic inventory: i7-14700K, RTX 3080 + UHD 770, 32 GB RAM; Rust, Node.js, Python, Git and Resolve. Clips expected at `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`. This machine and its clips are not accessible here. | Unknown; current host results do not satisfy its evidence requirement. |
 | Apple Silicon Mac | Not checked yet | Unknown |
 
@@ -53,7 +63,8 @@ Last updated: 2026-10-29 15:59 PT by Codex.
 
 ## Open questions for the owner
 
-- None needed for bounded replacement planning. Original reviewed plans can still be recovered later; compare any recovered work before combining it with replacements.
+- Approve pushing `fix/qa-r1-handoff-fixes`, opening the six PRs and merging them in the order in the QA-R1 plan. Each push, PR and merge needs a yes in chat.
+- If the original Windows PC is available, push the three unpushed plan branches from it (see "Current position"). Compare any recovered work before combining it with replacements.
 
 ## Waiting for owner hardware
 
@@ -70,11 +81,11 @@ Last updated: 2026-10-29 15:59 PT by Codex.
 - WP 1C-R1: all four offline behavior groups passed in the checkout and in independent review. The collector subsequently passed all six listing/identity commands against real verified FFmpeg and ffprobe binaries.
 - WP 1A-R1: all three fixture behavior groups passed in the checkout and independently. A scratch mutation adding an absolute source path was rejected. No original clips were accessed. This source is on its separate named branch, not merged here.
 - WP 1C-R2: checksum-rejection check passed independently; actual download, pinned hash/size check and extraction succeeded. Exact binary/license hashes, versions and full reported configuration are recorded in evidence. Required stabilization filters, x264/x265 and NVENC/QSV/AMF encoder names are listed.
-- WP 1C-R3: x264, x265 and both libvidstab passes executed successfully on synthetic data. All three outputs passed ffprobe checks; independent review reran the smoke and confirmed an existing-output retry preserves the report. Timings are illustrative, not representative benchmarks. No GPU encoding, original-media probing or quality scoring is established.
+- WP 1C-R3: x264, x265 and both libvidstab passes executed successfully on synthetic data. All three outputs passed ffprobe checks; independent review reran the smoke and confirmed an existing-output retry preserves the report. Timings are illustrative, not representative benchmarks. QA-R1 adds a measured shake check: on a synthetic shaken video the leftover motion fell from 20.67 to 1.88 (ratio 0.09, limit 0.25). No GPU encoding, original-media probing or quality scoring on real footage is established.
 - Binaries and retained download are ignored under `app/third-party/bin/`; raw path-containing inventory is in system temp. No binaries or raw local report are staged. The extracted GPL v3 license file is observed; full source correspondence and dependency license applicability remain unverified.
 - Next: recover or freshly plan WP 1B preview playback and verify its build prerequisites; continue source/dependency provenance review; run hardware/media tests when the original footage/reference machines are available. No Phase 1 engine or preview decision is made. Review integration bases before pushing or opening PRs: the WP 1C branches are stacked, while WP 1A is a separate sibling of the recovery branch.
 
 ## GitHub connection and publication
 
-- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. Command-line Git Credential Manager has no usable sign-in and cannot push noninteractively; do not confuse that with the healthy Codex connector.
+- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. On 2026-10-29 the owner signed command-line Git in to GitHub through Git Credential Manager, so `git push` works from any terminal on the current Windows host.
 - Verified remote heads before this publication-record commit: recovery `9f2c01f`, clip manifest `2daa176`, build inventory `dbe42b5`, Windows build `a4dff44`, software smoke `9079706`. This final record is a following documentation commit on the software-smoke branch; verify its remote HEAD after publication.
````

## Step 5: Review, then merge with owner approval

AGENTS.md asks for a Claude Code review of Codex work before any PR. Start one fresh Claude Code reviewer (not the agent that wrote Steps 2-4) with `review-plan` and `behavior-focused-testing` on every PowerShell script in `app/third-party/` and `spikes/`, including `spikes/stabilization-benchmark/` from `feat/wp-1a-clip-manifest`. Fix confirmed findings on `fix/qa-r1-handoff-fixes` before opening PRs.

Then ask the owner to approve pushing `fix/qa-r1-handoff-fixes` and opening the PRs. Open and squash-merge one PR at a time, each with base `main`, in the order below. Before each PR after the first, move its branch onto the new `main`, dropping the commits of the parent that was already squash-merged:

| Order | Branch | Old parent tip to drop |
|---|---|---|
| 1 | `docs/phase-1-recovery` | none (already based on `main` at `4dcb02c`) |
| 2 | `feat/wp-1c-build-inventory` | `9f2c01f` |
| 3 | `feat/wp-1c-windows-build` | `dbe42b5` |
| 4 | `feat/wp-1c-software-smoke` | `a4dff44` |
| 5 | `fix/qa-r1-handoff-fixes` | `8d1eb0a` |
| 6 | `feat/wp-1a-clip-manifest` | `9f2c01f` |

```powershell
git fetch origin
git rebase --onto origin/main <old-parent-tip> <branch>
git push --force-with-lease origin <branch>
```

Steps 2-5 of the table move a straight stack and should rebase cleanly. Step 6 conflicts in `dev-plan/STATUS.md`, because every branch edits it (checked with `git merge-tree --write-tree --merge-base 9f2c01f 2daa176 dbe42b5`). Resolve it by keeping the `main` version and making sure its WP 1A-R1 line names the clip-manifest commit; the manifest branch's own STATUS.md change was only a status correction. Run `spikes/stabilization-benchmark/test-clip-manifest.ps1` after that rebase.

Each push, force push, PR and merge needs its own owner approval unless STATUS.md records a standing approval. After the last merge, update STATUS.md to say all six are on `main`, and write a handover with the handover template in AGENTS.md.

## Verification

Run on the current Windows host in a new terminal with PowerShell 7 on PATH. Every suite must print PASS lines and exit 0. The smoke report must show `status` `passed` and a `shake_check.ratio` of 0.25 or less. The clip-manifest suite exists only on `feat/wp-1a-clip-manifest`, so run it there, or on `main` after merge 6.

```powershell
pwsh -NoProfile -File ./app/third-party/test-windows-ffmpeg.ps1
pwsh -NoProfile -File ./spikes/media-capabilities/test-build-inventory.ps1
$bin = (Resolve-Path './app/third-party/bin/ffmpeg-win64-gpl-9.0-cd9b8df51452/ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0/bin').Path
$out = Join-Path $env:TEMP ('kuaide-smoke-' + [guid]::NewGuid().ToString('N'))
pwsh -NoProfile -File ./spikes/media-capabilities/test-software-runtime.ps1 -FfmpegPath "$bin/ffmpeg.exe" -FfprobePath "$bin/ffprobe.exe" -OutputDirectory $out
(Get-Content "$out/software-smoke.json" -Raw | ConvertFrom-Json).shake_check
pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-clip-manifest.ps1
```

## Notes for agents

1. `orchestrator-proposed`: put Steps 2-4 on one new branch stacked on `feat/wp-1c-software-smoke`, rather than amending the five published branches. Evidence: those branches were published with verified hashes, and rewriting them would void that record.
2. `orchestrator-proposed`: extend `test-software-runtime.ps1` instead of adding a new script, so the shake check reuses `Invoke-SmokeCommand`, its timeout and the report.
3. `orchestrator-proposed`: merge `feat/wp-1a-clip-manifest` last, so the only STATUS.md conflict happens once, at the end, instead of in the middle of the stack.
4. `inferred from code`: the Steps 2-4 diffs were generated with `git diff` from a scratch worktree at the base commit. On 2026-10-29 the edited suites passed there: `test-windows-ffmpeg.ps1` PASS, real smoke `passed` with shake 20.67 to 1.88, ratio 0.091. `planner` is not installed; a fresh reviewer replaces `planner check` (AGENTS.md adaptation 2).
5. Review history: a fresh Claude Code reviewer checked revision 1 of this plan on 2026-10-29. All three diffs applied, all verification passed, and mutation checks showed the shake check fails an inverted transform (37.8) and a heavy blur (9.74). This revision fixes its findings: the broken code fence (a context line ```` ``` ```` closed the block; diffs now use four-backtick fences), the missing STATUS.md merge conflict and wrong rebase parents, the `pwsh` PATH and administrator prompt in Step 1, the branch base (now `8d1eb0a`, which includes this plan), the stale STATUS.md lines, the missing evidence update and clip-manifest suite, the missing ratio field, the rename failure path, and jargon in the STATUS.md table.
6. The rename in Step 2 runs only on the network download path. No offline test covers it, because a real pass needs the 195 MB pinned archive. A first draft used `[IO.Path]::ChangeExtension($path, $null)`, which leaves a trailing dot (`download-x.zip.`); the `-replace '\.partial$'` form was checked to give `download-x.zip`. The existing local file `app/third-party/bin/download-c0741458811d411fba5146739512e1a0.zip.partial` matches the pinned hash and can be renamed by hand.
7. `vidstabtransform` with `optzoom=0` prints a warning that L1 path optimization needs a zoom budget, then completes with exit 0. `optzoom=1` avoids the warning but its zoom resampling raises the measured residual to 8.5 (ratio 0.41), so the plan keeps `optzoom=0`.
8. Known limit of the shake check: it measures only frame-to-frame change, so a frozen output would pass (the reviewer measured 0.0015). The 59-difference count guards against a short or empty output but not a frozen one. libvidstab is unlikely to freeze frames, so no extra guard is added. The check also covers only synthetic two-axis panning of a still frame, not rotation, rolling shutter, parallax, real footage or quality scoring; those stay in WP 1A.
9. Diff sizes: Steps 2-4 change about 66 lines. The software-smoke PR, which includes revision 1 of this plan, is about 684 lines, just under the 700-line limit. So this revision is committed on `fix/qa-r1-handoff-fixes`, not on `feat/wp-1c-software-smoke`; add nothing more to that branch.
10. Commits and PRs carry no AI attribution lines (AGENTS.md adaptation 4).
