# Status

Last updated: 2026-10-30 by Claude Code (WP 1B.1, 1C-B, 1A.1).

## Current position

In plain words: Phase 1 has started, but most of it is still ahead. So far the agents have a checked copy of FFmpeg for Windows, a script that lists clip files with their fingerprints, and a short test showing that FFmpeg can encode video and that its stabilizer reduces shake on a computer-made test video. No real footage has been tested, no stabilizer has been compared, and the preview test has not started.

| Phase 1 part | Done | Still to do |
|---|---|---|
| 1A Stabilization benchmark | A list of the clips with their fingerprints; a harness that runs one stabilizer on every clip safely and records the results; two computer-made test clips (shaken still, hard cut) | Run FFmpeg's stabilizer, Gyroflow and DaVinci Resolve on your clips, score them, and build the side-by-side comparison page |
| 1B Preview playback | A small test version of the app window (Tauri) that plays and skips through a 1080p video in two ways (WP 1B.1) | Measure how smoothly it plays and seeks on Windows and Mac, and test the WebGL color shader |
| 1C Media tools | One exact Windows FFmpeg build, checked; it encodes video and reduces shake on a computer-made video; your three clips read (format, rotation, frame rate, color); Intel Quick Sync encoding works on this laptop | NVIDIA encoding (this FFmpeg needs a newer NVIDIA driver than the laptop has); a Mac FFmpeg build; HDR, varying-frame-rate and gyro clips; choosing how to convert HDR video to normal video; finishing the license check |
| Decision record | Nothing | Write `dev-plan/decision-record.md` for your approval |

- Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
- Phase 1 is approved. Bounded replacement spikes are implemented; no app UI or core implementation has started.
- The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. `docs/phase-1-start` shows they were committed on `feat/wp-1a-stabilization-benchmark`, `feat/wp-1b-preview-playback` and `feat/wp-1c-media-capabilities`, which were never pushed; they are most likely only on the original Windows PC. Replacements are explicitly labeled; compare any recovered plans before combining work.
- On 2026-10-29 the owner approved, and Claude Code squash-merged, PRs #1-#6 into `main`: recovery rules `373b8ac`, WP 1C-R1 `d80c3ba`, WP 1C-R2 `f0e7929`, WP 1C-R3 `9ef172e`, QA-R1 `a324897`, WP 1A-R1 `22726ea`. All four test suites and the real smoke pass on `main`. The branch hashes in the next lines are the pre-merge history.
- Recovery rules and documents: `docs/phase-1-recovery` at `9f2c01f`. WP 1C-R1 collector: `feat/wp-1c-build-inventory` at `dbe42b5`. WP 1A-R1 manifest: `feat/wp-1a-clip-manifest` at `957089c`, with status correction `2daa176`. Both packages passed independent review and their offline suites.
- WP 1C-R2 is committed at `a4dff44` on `feat/wp-1c-windows-build`, based on `dbe42b5`. The acquisition, real listing evidence, source and tests passed independent review.
- WP 1C-R3 is committed at `bbbb76f` on `feat/wp-1c-software-smoke`, based on `a4dff44`. It passed real synthetic encoding/filter checks and independent source/evidence review: nine zero-exit commands and three 320x180, 30-frame, one-second outputs. See `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`. No original footage or hardware encoder has been tested.
- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. Later PRs and merges each need a new owner approval.
- QA-R1 (Claude Code check of the Codex handoff), merged as `a324897`: download-script fixes, a measured shake-reduction check, PowerShell 7 installed and on PATH, and this plain-words summary. Rebuilt Phase 1 plans: `dev-plan/plans/phase-1-wp-plans.md`. Plan: `dev-plan/plans/qa-r1-phase-1-handoff-fixes.md`.
- WP 1B.1 (Tauri preview test app), merged as `f6ced85` (PR #8): plays and seeks a 1080p H.264 file by custom protocol and by a loopback HTTP server on Windows; 8 Rust tests pass; reviewed by a fresh agent. Record: `dev-plan/plans/wp-1b-1-preview-app.md`. Rust 1.99.1 and Node.js 26 LTS are installed on the current laptop.
- Clip folder support and clip list, merged as `663ae7c` (PR #10). WP 1C-B Windows part, merged as `4e1c609` (PR #11): see `spikes/media-capabilities/evidence/2026-10-30-clip-probes-and-encoders.md`. `IMG_0225.MOV` is H.264 in portrait, not HEVC; no current clip is HDR, variable-rate or has gyro data. NVENC fails with the pinned FFmpeg because it needs NVIDIA driver 610+ (laptop: 581.95); Quick Sync works. WP 1A.1 benchmark harness, merged as `058461b` (PR #12). Each was reviewed by a fresh agent and its findings fixed.
- Account allowance: read it fresh at session start and at each stable point. Begin wrap-up at 5% remaining or earlier; the handover must be ready and work already stopped at a stable point before either the five-hour or weekly allowance reaches 1%.

## Machines

| Machine | Details | Availability |
|---|---|---|
| Current Windows host | Verified by CIM: Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, 67,865,284,608 bytes RAM, SSSTC 1 TB NVMe. Session path `C:\Users\bchen`; original clips drive is absent. Git for Windows (system-wide) and PowerShell 7.6.9 (winget package for this user) are installed and on PATH; command-line Git is signed in to GitHub. Pinned FFmpeg candidate is local and ignored. | Unknown; ask the owner at session start. No push permission is implied. |
| Original Windows reference PC | Historic inventory: i7-14700K, RTX 3080 + UHD 770, 32 GB RAM; Rust, Node.js, Python, Git and Resolve. Clips expected at `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`. This machine and its clips are not accessible here. | Unknown; current host results do not satisfy its evidence requirement. |
| Apple Silicon Mac | Not checked yet | Unknown |

## Owner tasks

- Add more benchmark clips to the clips folder. Priority order and reasons are in the roadmap ("Benchmark clip coverage"): an original GoPro/DJI/Insta360 clip with gyro data, a recent HDR phone clip, 4K/60 (and 4K/120 if possible), a deliberate pan, a tripod or resting clip, a running clip, low light, and a Sony clip with gyro data. Each 30-60 s. Copy the original camera files: from a GoPro or DJI, copy straight from the SD card. From an iPhone, use a cable (Windows Photos app or the Mac's Image Capture) or the Google Drive app's file upload. Do not send them through messaging apps or Google Photos, which re-compress video and drop gyro data.

## Owner decisions

| Date | Decision |
|---|---|
| 2026-10-28 | App name: Kuaide Video Stabilizer. Repo name: `kuaide-video-stabilizer`. |
| 2026-10-28 | Footage: phones, GoPro/DJI/Insta360, Sony/mirrorless. |
| 2026-10-28 | v1 converts HDR to SDR with a clear notice. Full HDR is future scope. |
| 2026-10-28 | Test hardware: Windows PC and Apple Silicon Mac. Intel Mac not supported. |
| 2026-10-28 | Test clips go in Google Drive `My Drive/Agentic projects/kuaide-video-stabilizer_temp` (Windows: `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`). Mac path: not recorded yet. |
| 2026-10-28 | Owner tasks agreed: provide sample clips, fill in the Resolve download form, do the 10-15 minute final look at the top benchmark candidates. |
| 2026-10-28 | DaVinci Resolve 21.1 (free) installed by the owner on the Windows PC. |
| 2026-10-28 | First clips received: `IMG_0225.MOV` (iPhone 7, 6 s) and two Caltrain files. The WebM (60 s) is the main clip; the MP4 (42 s, re-encoded) is a shorter copy. |
| 2026-10-28 | Within 1-2 hours of the 7-day credit refresh, agents may spend extra credits on parallel analysis (see AGENTS.md Gate 3). |
| 2026-10-28 | Agents install and run DaVinci Resolve (free) and do the benchmark scoring. Owner does only a short final look at the top candidates. |
| 2026-10-28 | Agents do tasks by default; the owner gets a task only when it is much cheaper for a person (see AGENTS.md). |
| 2026-10-28 | Owner approved the start of Phase 1. Long tasks still require a separate Gate 2 approval. |
| 2026-10-29 | Generated lockfiles do not count toward the 700-line PR size limit, but they must be committed and reviewed. |
| 2026-10-29 | All plans and future sessions: by 1% remaining in either the five-hour or weekly allowance, a handover must already be ready and work already stopped at a stable point. Keep 5% as the early wrap-up trigger, or start earlier when needed. |

## Standing permissions

- Mandatory allowance deadline for all plans and future sessions: by 1% remaining in either limit, the handover is ready and the agent has already stopped at a stable point. Begin wrap-up at 5% or earlier. See AGENTS.md Gate 3. The same rule is saved in local user-wide Codex and Claude Code instruction files on this computer.
- Long-task permissions (Gate 2): none.
- One-time owner approval: publish the five completed branches, including the completion status/handover record. All five are now published. No standing permission for further work, PRs or merges is implied.
- Installing DaVinci Resolve (free): allowed. The download form asks for personal details, and accepting the license is the owner's call, so the owner fills in that form (about 2 minutes) unless they say otherwise at the time.

## Open questions for the owner

- Which Phase 1 piece to start next. Recommended: 1A.2 (FFmpeg stabilizer and Gyroflow runs in the harness); it is larger, so start it with plenty of allowance left. Also open: 1B.2 playback measurements. See `dev-plan/plans/phase-1-wp-plans.md`.
- The FFmpeg build choice must handle older NVIDIA drivers: pick a build with older NVENC headers, or set and check a minimum driver version.
- If the original Windows PC is available, push the three unpushed plan branches from it (see "Current position"). Compare any recovered work before combining it with replacements.

## Waiting for owner hardware

- On 2026-10-30 the owner gave a copy of the first three clips in a OneDrive folder on the current laptop (full path kept out of this public repo; set `KUAIDE_CLIPS_DIR` to it). Their names, sizes and SHA-256 are in `spikes/stabilization-benchmark/clips.manifest.json`. The original Windows reference PC and the Mac are still unavailable; the Mac clips path is unverified.

## Handover log

- `dev-plan/handover/2026-10-29-phase-1-planning.md` (copied from the published coordination branch).
- `dev-plan/handover/2026-10-29-recovery-and-allowance.md` (current local recovery record).
- `dev-plan/handover/2026-10-29-phase-1-spikes.md` (Codex continuation instructions and branch map, before QA).
- `dev-plan/handover/2026-10-29-qa-and-merge.md` (QA, rebuilt plans and merges into `main`).
- `dev-plan/handover/2026-10-30-1b1-1cb-1a1.md` (latest: WP 1B.1, 1C-B Windows part and 1A.1).

## Verification and next work

- WP 1C-R1: all four offline behavior groups passed in the checkout and in independent review. The collector subsequently passed all six listing/identity commands against real verified FFmpeg and ffprobe binaries.
- WP 1A-R1: all three fixture behavior groups passed in the checkout and independently. A scratch mutation adding an absolute source path was rejected. No original clips were accessed. This source is on its separate named branch, not merged here.
- WP 1C-R2: checksum-rejection check passed independently; actual download, pinned hash/size check and extraction succeeded. Exact binary/license hashes, versions and full reported configuration are recorded in evidence. Required stabilization filters, x264/x265 and NVENC/QSV/AMF encoder names are listed.
- WP 1C-R3: x264, x265 and both libvidstab passes executed successfully on synthetic data. All three outputs passed ffprobe checks; independent review reran the smoke and confirmed an existing-output retry preserves the report. Timings are illustrative, not representative benchmarks. QA-R1 adds a measured shake check: on a synthetic shaken video the leftover motion fell from 20.67 to 1.88 (ratio 0.09, limit 0.25). No GPU encoding, original-media probing or quality scoring on real footage is established.
- Binaries and retained download are ignored under `app/third-party/bin/`; raw path-containing inventory is in system temp. No binaries or raw local report are staged. The extracted GPL v3 license file is observed; full source correspondence and dependency license applicability remain unverified.
- Next: WP 1A.2 (libvidstab and Gyroflow engines, crop and leftover-shake measurement), then 1A.3 Resolve and 1B.2. Owner clips for HDR, gyro, 4K and other cases are still needed for the engine choice. No Phase 1 engine or preview decision is made.

## GitHub connection and publication

- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. On 2026-10-29 the owner signed command-line Git in to GitHub through Git Credential Manager, so `git push` works from any terminal on the current Windows host.
- Verified remote heads before this publication-record commit: recovery `9f2c01f`, clip manifest `2daa176`, build inventory `dbe42b5`, Windows build `a4dff44`, software smoke `9079706`. This final record is a following documentation commit on the software-smoke branch; verify its remote HEAD after publication.
