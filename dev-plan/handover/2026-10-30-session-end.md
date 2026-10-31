# Handover: end of the QA-to-1A.2 session
Date: 2026-10-30. From: Claude Code (Opus 5.5). Reason: end of session; WP 1A.2 paused at the owner's request.

## Where things stand
- Phase and WP: Phase 1. Done: 1C-A (Codex replacements, QA-R1 fixes), 1A.1 harness, 1B.1 Tauri test app, 1C-B Windows part. In progress and paused: 1A.2 (libvidstab engine and measurement). Not started: 1A.3, 1A.4, 1B.2, 1B.3, 1C-B Mac part, 1C-C, decision record. Phase 1 gate open.
- `main` at `89e57df` (PR #13). All work through WP 1A.1 is merged; STATUS.md on `main` is current up to that point.
- WP 1A.2 branch: `feat/wp-1a-2-libvidstab` at `689c2a8` plus this handover commit, based on `89e57df`. Not merged, no PR yet.
- Pushed: `main` and `feat/wp-1a-2-libvidstab` at `689c2a8` yes; this handover commit needs owner approval to push.

## Done in this session
- QA of the Codex handoff: every claim reproduced; six problems found and fixed (QA-R1, PR #5). Owner note recorded in AGENTS.md: Codex is more error-prone, so Claude Code reviews Codex work before PRs.
- Original Phase 1 plans confirmed lost (never pushed); rebuilt at outline level in `dev-plan/plans/phase-1-wp-plans.md`.
- PRs #1-#13 merged in order; every work package got a fresh-agent review and its findings were fixed with tests.
- Tools installed on this laptop: Git 2.56, PowerShell 7.6.9, GitHub CLI (signed in), Rust 1.99.1, Node.js 26 LTS.
- Clips: five in the owner's OneDrive folder on this laptop (path kept out of the public repo; set `KUAIDE_CLIPS_DIR`). `spikes/stabilization-benchmark/clips.manifest.json` lists them. Two are the owner's own iPhone recordings (HEVC 10-bit HLG HDR, portrait, variable frame rate), used with permission.
- WP 1A.2 so far: `engines/libvidstab.ps1`, `settings/libvidstab-auto.json` and `-tuned.json`, `measure-run.ps1` (shake reduction, frozen-output flag, crop), `test-libvidstab.ps1` (6 PASS). Details and the five-clip results table: `dev-plan/handover/2026-10-30-wp-1a-2-paused.md`.

## Next steps (in order)
1. Read AGENTS.md, STATUS.md, this file and `2026-10-30-wp-1a-2-paused.md`. Check allowance.
2. WP 1A.2 open problems, in the order the paused handover gives: crop is wrong on unchanged iPhone HDR copies (29-43%) and Caltrain .mp4; libvidstab raises shake on `20261019_031753000_iOS.MOV`; Caltrain .mp4 and .webm disagree. View frames before changing the measure.
3. Second fresh-agent review of WP 1A.2, then PR and merge with owner approval, then update STATUS.md.
4. Gyroflow engine (no gyro clip exists yet), then WP 1A.3 (Resolve, desktop control) and WP 1B.2.

## Open questions for the owner
- More clips: GoPro/DJI/Insta360 with gyro data, 4K/60, a deliberate pan, tripod, running, low light.
- Mac availability; original i7/RTX 3080 PC availability.
- FFmpeg build choice must handle older NVIDIA drivers (the pinned build needs 610+; this laptop has 581.95).

## Known problems and failing tests (with commands to reproduce)
- No failing tests. Suites (PowerShell 7, pinned FFmpeg in `app/third-party/bin/`): `spikes/stabilization-benchmark/test-run-benchmark.ps1 -FfmpegPath <ffmpeg>`, `test-libvidstab.ps1 -FfmpegPath <ffmpeg>`, `test-clip-manifest.ps1`; `spikes/media-capabilities/test-probe-clips.ps1 -FfmpegPath <ffmpeg> -FfprobePath <ffprobe>`, `test-build-inventory.ps1`; `app/third-party/test-windows-ffmpeg.ps1`; `cargo test` in `spikes/preview-playback/src-tauri`.
- WP 1A.2 numbers are not usable yet (see step 2). The shake measure uses libvidstab's own motion search and does not detect blur.
- Old shells may not see the new PATH; open a new terminal or call tools by full path.

## Hardware or owner tasks waiting
- Extra clips (above). Mac. Original reference PC.
