# Handover: WP 1A.2 measurement continuation
Date: 2026-10-29. From: Codex (GPT-6). Reason: current session draft; measurement correction verified, real-clip remeasurement running.

## Where things stand
- Phase and WP: Phase 1, WP 1A.2. Measurement investigation resumed.
- Branch and last commit: `feat/wp-1a-2-libvidstab`, starting at `d2b016c`.
- Pushed: no session changes pushed; the starting handover is one commit ahead of the remote-tracking branch.
- Allowance at session start: five-hour 97% remaining; weekly 57% remaining. Owner permits use of the full current five-hour allowance for this session. Weekly deadline remains in force.

## Done since the last handover
- Confirmed the clean starting checkout and read both 2026-10-30 handovers, project rules, status and Phase 1 roadmap.
- Loaded the pinned project workflow skills from GitHub. Shell network access needed an approved sandbox escalation.
- Git is installed but absent from this shell PATH; use `C:\Program Files\Git\cmd\git.exe`.
- Found retained five-clip benchmark outputs in local temporary storage. Original clip directory discovery is in progress; KUAIDE_CLIPS_DIR is unset in this shell.
- Corrected the shake window from 17 to 15 frames and versioned reports. Geometric crop is unavailable except zero added crop for verified identical bytes; the previous darkness measure is a diagnostic only.
- All seven updated libvidstab behavior groups passed, including dark-edge and rotated-output regressions. Independent Codex review approved this bounded correction; Claude Code review is pending.
- Evidence and limitations: `spikes/stabilization-benchmark/evidence/2026-10-29-measurement-correction.md`.

## Next steps (in order)
1. Inspect original and output frames before changing the crop measurement.
2. Reproduce false crop on unchanged dark/HDR footage and establish a defensible metric.
3. Investigate the first iPhone clip's increased shake and the Caltrain disagreement.
4. Run relevant tests and request independent review. Claude Code review remains required before a PR or merge.
5. Obtain owner approval before push, PR or merge.

## Open questions for the owner
- Owner confirmed no shutdown deadline this session.
- Existing questions about more footage, Mac, reference PC and NVIDIA driver support remain.

## Known problems and failing tests (with commands to reproduce)
- Prior handover reports false crop of 29-43% on unchanged HDR copies. No new test run yet.
- Reproduction: run `run-benchmark.ps1` with `settings/copy-baseline.json`, then `measure-run.ps1` with that run directory and the pinned FFmpeg executable.
- Other prior measurement limitations remain documented in `2026-10-30-wp-1a-2-paused.md`.

## Hardware or owner tasks waiting
- Additional gyro, running, pan, tripod and low-light footage; Mac and original Windows reference PC.

