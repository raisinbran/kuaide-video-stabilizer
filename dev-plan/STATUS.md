# Status

Last updated: 2026-10-28 23:10 PT by Codex.

## Current position

- Phase 0 (repository setup) is complete. The GitHub repo is renamed to `kuaide-video-stabilizer`. No app code yet.
- Phase 1 is approved. Planning has started for WP 1A, WP 1B, and WP 1C on separate branches.
- No long benchmark render or other unpausable task has been approved yet.

## Machines

| Machine | Details | Availability |
|---|---|---|
| Windows PC | Intel Core i7-14700K, NVIDIA RTX 3080 (NVENC) + Intel UHD 770 (Quick Sync), 32 GB RAM, Windows 11. Installed: Rust (cargo), Node.js, Python 3.13, git, DaVinci Resolve 21.1 (free). Not installed: FFmpeg, GitHub CLI. Clips: `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp` | Must be off by 2026-10-29 07:00 PT. Stable stop and handover pushed by 06:30 PT. |
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

## Standing permissions

- Long-task permissions (Gate 2): none.
- Push / PR permissions: none.
- Installing DaVinci Resolve (free): allowed. The download form asks for personal details, and accepting the license is the owner's call, so the owner fills in that form (about 2 minutes) unless they say otherwise at the time.

## Open questions for the owner

- None right now.

## Waiting for owner hardware

- None yet.

## Handover log

- None yet.
