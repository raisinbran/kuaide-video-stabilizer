# Status

Last updated: 2026-10-29 by Claude Code (QA-R1 fixes).

## Current position

In plain words: Phase 1 has started, but most of it is still ahead. So far the agents have a checked copy of FFmpeg for Windows, a script that lists clip files with their fingerprints, and a short test showing that FFmpeg can encode video and that its stabilizer reduces shake on a computer-made test video. No real footage has been tested, no stabilizer has been compared, and the preview test has not started.

| Phase 1 part | Done | Still to do |
|---|---|---|
| 1A Stabilization benchmark | A script that lists clip files with their fingerprints | Run the stabilizers (FFmpeg's, Gyroflow, DaVinci Resolve) on your clips, score them, and build the side-by-side comparison page |
| 1B Preview playback | Nothing | Build a small test version of the app window (Tauri) and measure how smoothly it plays and seeks video |
| 1C Media tools | One exact Windows FFmpeg build, downloaded and checked; tests that it can encode video and reduce shake on a computer-made video | A Mac FFmpeg build; video encoding on the graphics card; reading the settings of your camera files; choosing how to convert HDR (bright, wide-color) video to normal video; finishing the license check, which is partly done |
| Decision record | Nothing | Write `dev-plan/decision-record.md` for your approval |

- Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
- Phase 1 is approved. Bounded replacement spikes are implemented; no app UI or core implementation has started.
- The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. `docs/phase-1-start` shows they were committed on `feat/wp-1a-stabilization-benchmark`, `feat/wp-1b-preview-playback` and `feat/wp-1c-media-capabilities`, which were never pushed; they are most likely only on the original Windows PC. Replacements are explicitly labeled; compare any recovered plans before combining work.
- Recovery rules and documents: `docs/phase-1-recovery` at `9f2c01f`. WP 1C-R1 collector: `feat/wp-1c-build-inventory` at `dbe42b5`. WP 1A-R1 manifest: `feat/wp-1a-clip-manifest` at `957089c`, with status correction `2daa176`. Both packages passed independent review and their offline suites.
- WP 1C-R2 is committed at `a4dff44` on `feat/wp-1c-windows-build`, based on `dbe42b5`. The acquisition, real listing evidence, source and tests passed independent review.
- WP 1C-R3 is committed at `bbbb76f` on `feat/wp-1c-software-smoke`, based on `a4dff44`. It passed real synthetic encoding/filter checks and independent source/evidence review: nine zero-exit commands and three 320x180, 30-frame, one-second outputs. See `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`. No original footage or hardware encoder has been tested.
- The owner approved publishing the five completed branches. All five were published and their GitHub ref hashes verified against local commits on 2026-10-29. No PR or merge is authorized.
- QA-R1 (Claude Code check of the Codex handoff) is on `fix/qa-r1-handoff-fixes`: download-script fixes, a measured shake-reduction check, PowerShell 7 installed and on PATH, and this plain-words summary. Rebuilt Phase 1 plans: `dev-plan/plans/phase-1-wp-plans.md`. Plan: `dev-plan/plans/qa-r1-phase-1-handoff-fixes.md`.
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

- Approve pushing `fix/qa-r1-handoff-fixes`, opening the six PRs and merging them in the order in the QA-R1 plan. Each push, PR and merge needs a yes in chat.
- If the original Windows PC is available, push the three unpushed plan branches from it (see "Current position"). Compare any recovered work before combining it with replacements.

## Waiting for owner hardware

- Original Windows clips and hardware are unavailable in this session. Mac availability and exact clips path remain unverified.

## Handover log

- `dev-plan/handover/2026-10-29-phase-1-planning.md` (copied from the published coordination branch).
- `dev-plan/handover/2026-10-29-recovery-and-allowance.md` (current local recovery record).
- `dev-plan/handover/2026-10-29-phase-1-spikes.md` (latest continuation instructions and branch map).

## Verification and next work

- WP 1C-R1: all four offline behavior groups passed in the checkout and in independent review. The collector subsequently passed all six listing/identity commands against real verified FFmpeg and ffprobe binaries.
- WP 1A-R1: all three fixture behavior groups passed in the checkout and independently. A scratch mutation adding an absolute source path was rejected. No original clips were accessed. This source is on its separate named branch, not merged here.
- WP 1C-R2: checksum-rejection check passed independently; actual download, pinned hash/size check and extraction succeeded. Exact binary/license hashes, versions and full reported configuration are recorded in evidence. Required stabilization filters, x264/x265 and NVENC/QSV/AMF encoder names are listed.
- WP 1C-R3: x264, x265 and both libvidstab passes executed successfully on synthetic data. All three outputs passed ffprobe checks; independent review reran the smoke and confirmed an existing-output retry preserves the report. Timings are illustrative, not representative benchmarks. QA-R1 adds a measured shake check: on a synthetic shaken video the leftover motion fell from 20.67 to 1.88 (ratio 0.09, limit 0.25). No GPU encoding, original-media probing or quality scoring on real footage is established.
- Binaries and retained download are ignored under `app/third-party/bin/`; raw path-containing inventory is in system temp. No binaries or raw local report are staged. The extracted GPL v3 license file is observed; full source correspondence and dependency license applicability remain unverified.
- Next: recover or freshly plan WP 1B preview playback and verify its build prerequisites; continue source/dependency provenance review; run hardware/media tests when the original footage/reference machines are available. No Phase 1 engine or preview decision is made. Review integration bases before pushing or opening PRs: the WP 1C branches are stacked, while WP 1A is a separate sibling of the recovery branch.

## GitHub connection and publication

- Codex GitHub connector verified as `raisinbran`; repository read/write access works. GitHub Desktop also published using its existing sign-in. On 2026-10-29 the owner signed command-line Git in to GitHub through Git Credential Manager, so `git push` works from any terminal on the current Windows host.
- Verified remote heads before this publication-record commit: recovery `9f2c01f`, clip manifest `2daa176`, build inventory `dbe42b5`, Windows build `a4dff44`, software smoke `9079706`. This final record is a following documentation commit on the software-smoke branch; verify its remote HEAD after publication.
