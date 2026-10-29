# Handover: Phase 1 bounded spikes
Date: 2026-10-29, 15:40 PT. From: Codex. Reason: Stable end of bounded work before the machine sleep window. Updated at 15:59 PT after owner-approved branch publication.

## Where things stand
- Phase and WP: Phase 1 approved. Replacement WP 1A-R1 and WP 1C-R1/R2/R3 are implemented, verified and independently reviewed. The Phase 1 gate remains open; no app UI/core or Phase 2 work has started.
- Branch and last implementation commit: `feat/wp-1c-software-smoke` at `bbbb76f`; this handover and its status update are a following documentation commit on that branch.
- Pushed: yes. The owner approved publication of the five completed branches, and all five remote ref hashes were verified. The completion status/handover record is a following documentation commit on the software-smoke branch. No PR or merge was authorized.

| Branch | Package commit | Base |
|---|---|---|
| `docs/phase-1-recovery` | `9f2c01f` | `4dcb02c` |
| `feat/wp-1c-build-inventory` | `dbe42b5` | `9f2c01f` |
| `feat/wp-1a-clip-manifest` | `957089c`; status correction `2daa176` | `9f2c01f` |
| `feat/wp-1c-windows-build` | `a4dff44` | `dbe42b5` |
| `feat/wp-1c-software-smoke` | `bbbb76f`; see HEAD for the following documentation commit | `a4dff44` |

## Done since the last handover

- Found bundled Git/Python/PowerShell. Git metadata writes require approved elevated execution; read-only Git works normally by absolute path.
- Updated the immediate allowance rule in AGENTS.md and STATUS.md: at 5% or earlier begin wrap-up; by 1% remaining in either the five-hour or weekly limit, the handover must already be ready and work stopped at a stable point. This applies to all plans and future sessions and is also saved in local user-wide Codex and Claude Code instructions. Codex can read allowance through `get_usage_limits`; the earlier unavailable claim was corrected. At 15:40 PT, 30% five-hour and 61% weekly allowance remained. Recheck before work.
- Confirmed the original plan commits `e1d7d4d`, `f63b6e6`, `3be84fb` are unavailable locally and on GitHub. Prepared explicitly labeled replacement plans within approved Phase 1 scope, with independent review before implementation.
- WP 1A-R1: full-file SHA-256, size and filename manifest from `KUAIDE_CLIPS_DIR`; no media guesses or absolute source paths. Byte-fixture tests passed independently. No original footage was accessed.
- WP 1C-R1: offline build identity/listing collector with exact executable hashes, raw command output, timeout handling and explicitly unverified provenance. Four behavior groups passed independently.
- WP 1C-R2: pinned BtbN Windows x64 GPL static candidate downloaded and matched its exact archive hash and size before extraction. Six real inventory commands passed. Build configuration, component listings and executable/license hashes are recorded in `spikes/media-capabilities/evidence/2026-10-29-windows-candidate.md`.
- WP 1C-R3: real one-second synthetic x264/x265 encode and two-pass libvidstab smoke passed. All nine commands exited zero, and all three outputs decoded as 320x180, 30 frames, 1.000 seconds. Independent rerun, output-preservation check and factual evidence review passed. Results are in `spikes/media-capabilities/evidence/2026-10-29-software-smoke.md`.
- Each package is below the 700-line limit against its own stated base. Keep the stacked WP 1C PR bases separate; their combined diff exceeds that limit. No binary, footage, generated video or raw local report is committed.

## Next steps (in order)

1. Read AGENTS.md, STATUS.md and Phase 1 roadmap; check allowance and the current machine window. Begin wrap-up at 5% remaining in either allowance window, or earlier when needed. Before either limit reaches 1%, the handover must already be ready and work already stopped at a stable point. If usage cannot be read, start no further plan work and prepare the handover and stable stop.
2. Fetch the five published branches and read the latest software-smoke branch for current rules and this handover. The owner approved their publication; that approval is not standing permission for future pushes, PRs or merges. Review branch bases before opening PRs: WP 1A is a sibling and WP 1C packages form a stack. Reconcile STATUS.md during later approved integration.
3. Recover the old plans if available and compare before reusing them; replacements do not claim to reproduce their contents.
4. Recover or prepare a fresh bounded WP 1B preview-playback plan and check Rust, Node, build tools and Tauri prerequisites. Current session PATH does not expose those development tools. Do not assume the original PC inventory describes this host.
5. Continue FFmpeg source/dependency provenance review and bounded hardware tests on the required reference machines. Full license applicability, binary/source correspondence, macOS builds and encoders remain open.
6. When original clips are accessible, set `KUAIDE_CLIPS_DIR`, collect the manifest, then plan probe/benchmark work. Do not run an unpausable task over one hour without Gate 2 approval. No final engine, preview or tone-mapping choice has been made.

## Open questions for the owner

- Publication of the five branches is complete. Future pushes, PRs and merges still need the applicable owner approval.
- Availability after approximately 17:20 PT, plus original Windows PC and Mac access, remains unspecified.

## Known problems and failing tests (with commands to reproduce)

- No failing checks in the completed packages. Offline suites are `test-build-inventory.ps1`, `test-clip-manifest.ps1` and `test-windows-ffmpeg.ps1` in their package folders. Run the manifest suite from its separate branch. The real integration test is `test-software-runtime.ps1`; use verified executable paths and a new external output directory.
- `planner` is unavailable. Plans used generated exact diffs, applicability checks and fresh independent reviews under the project adaptation.
- Native FFmpeg candidate and retained archive are ignored under `app/third-party/bin/`; they are not transported by Git. The committed acquisition script verifies the pinned archive before extraction on another Windows x64 machine.
- Raw path-containing reports and generated media are in unique system-temp directories recorded in the evidence. They may disappear; the committed evidence contains the observed identity, configuration and results needed for continuation.
- These short synthetic runs do not establish stabilization quality, representative performance, audio sync, HDR, gyro, GPU encoding or five-minute preview behavior.

## Hardware or owner tasks waiting

- Current host is a Dell Precision 7760, Xeon W-11855M, Intel UHD + RTX A3000 Laptop GPU, distinct from the original i7/RTX 3080 reference PC. Hardware details are recorded in the smoke evidence. No GPU encode was attempted.
- Original clips drive and `C:\Users\brand` path are absent here. Do not invent a replacement footage path or mark the original reference-machine tests complete.
- Current machine is available until about 17:00 PT, asleep about 17:00-17:20 PT; stable-stop target is 16:30 PT. No availability after 17:20 is presumed.
- Existing sample-footage requests and Mac path/availability are still open in STATUS.md.

## Publication and connection update

- On 2026-10-29 the owner explicitly approved publishing all five completed branches. GitHub ref hashes matched `9f2c01f`, `2daa176`, `dbe42b5`, `a4dff44`, and `9079706` before this final record. The software-smoke branch receives this following documentation update.
- Codex GitHub connection was verified as `raisinbran`, with read/write access. GitHub Desktop used its existing authenticated connection for local Git object uploads; the other published refs point to the exact uploaded commits. CLI Git credential-manager authentication remains unavailable, which does not affect the Codex GitHub connector.
- At about 15:59 PT, 11% five-hour and 58% weekly allowance remained. Wrap-up is in progress. Do not start new plan work before reading fresh usage and the current machine window.
