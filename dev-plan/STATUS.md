# Status

Last updated: 2026-10-29 15:32 PT by Codex.

## Current position

- Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
- Phase 1 is approved. Bounded replacement spikes are implemented; no app UI or core implementation has started.
- The original plans at `e1d7d4d`, `f63b6e6`, and `3be84fb` remain unavailable. Replacements are explicitly labeled; compare any recovered plans before combining work.
- Recovery rules and documents: `docs/phase-1-recovery` at `9f2c01f`. WP 1C-R1 collector: `feat/wp-1c-build-inventory` at `dbe42b5`. WP 1A-R1 manifest: `feat/wp-1a-clip-manifest` at `957089c`, with status correction `2daa176`. Both packages passed independent review and their offline suites.
- Current branch `feat/wp-1c-windows-build` starts from `dbe42b5`. Its reviewed WP 1C-R2 script acquired and checksum-verified one Windows candidate. All six real collector commands passed, and observed build evidence is recorded in `spikes/media-capabilities/evidence/2026-10-29-windows-candidate.md`. The source/test review and factual evidence review both approved it.
- Elevated Git execution resolves metadata write restrictions. Branches are local only. No push, PR or merge is authorized.
- Account allowance at about 15:31 PT: 49% remains in the five-hour window and 64% in the weekly window. These are point-in-time readings; recheck at each stable point. Stop and provide a handover at 5% or below in any applicable window.

## Machines

| Machine | Details | Availability |
|---|---|---|
| Original Windows PC | Historic inventory: Intel Core i7-14700K, RTX 3080 + UHD 770, 32 GB RAM; Rust, Node.js, Python, Git and Resolve. Clips: `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`. This session uses `C:\Users\bchen`; the original `C:\Users\brand` path and clips drive are absent. Original hardware is not verified here. | Owner's temporary window: available until about 17:00 PT on 2026-10-29; asleep about 17:00-17:20 PT. Stable-stop target: 16:30 PT. Availability after 17:20 awaits owner details. No push permission is implied. |
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
| 2026-10-29 | At 5% or below remaining Codex or Claude Code allowance, stop at a stable point and provide a handover. This applies immediately and to all future tasks in this plan. |

## Standing permissions

- Mandatory allowance rule, effective immediately for all future plan tasks: at 5% or below remaining Codex or Claude Code allowance, stop at the next stable point and provide the owner a handover document. See AGENTS.md Gate 3.
- Long-task permissions (Gate 2): none.
- Push / PR permissions: none.
- Installing DaVinci Resolve (free): allowed. The download form asks for personal details, and accepting the license is the owner's call, so the owner fills in that form (about 2 minutes) unless they say otherwise at the time.

## Open questions for the owner

- None needed for bounded replacement planning. Original reviewed plans can still be recovered later; compare any recovered work before combining it with replacements.

## Waiting for owner hardware

- Original Windows clips and hardware are unavailable in this session. Mac availability and exact clips path remain unverified.

## Handover log

- `dev-plan/handover/2026-10-29-phase-1-planning.md` (copied from the published coordination branch).
- `dev-plan/handover/2026-10-29-recovery-and-allowance.md` (current local recovery record).

## Verification and next work

- WP 1C-R1: all four offline behavior groups passed in the checkout and in independent review. The collector subsequently passed all six listing/identity commands against real verified FFmpeg and ffprobe binaries.
- WP 1A-R1: all three fixture behavior groups passed in the checkout and independently. A scratch mutation adding an absolute source path was rejected. No original clips were accessed. This source is on its separate named branch, not merged here.
- WP 1C-R2: checksum-rejection check passed independently; actual download, pinned hash/size check and extraction succeeded. Exact binary/license hashes, versions and full reported configuration are recorded in evidence. Required stabilization filters, x264/x265 and NVENC/QSV/AMF encoder names are listed. No encode, filter execution or GPU validation has run yet.
- Binaries and retained download are ignored under `app/third-party/bin/`; raw path-containing inventory is in system temp. No binaries or raw local report are staged. The extracted GPL v3 license file is observed; full source correspondence and dependency license applicability remain unverified.
- Next: bounded runtime encoder/filter checks with synthetic inputs, plus source/dependency provenance review. WP 1B preview work, actual footage probing, Windows reference-machine tests and macOS evidence remain open. No Phase 1 engine or preview decision is made.
