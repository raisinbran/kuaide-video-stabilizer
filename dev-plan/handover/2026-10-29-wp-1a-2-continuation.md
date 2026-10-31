# Handover: WP 1A.2 measurement continuation
Date: 2026-10-29 (Pacific time). From: Codex (GPT-6). Reason: stable checkpoint after measurement correction and real-clip verification.

## Where things stand
- Phase and WP: Phase 1, WP 1A.2 remains incomplete. The bounded measurement correction is tested and independently reviewed by Codex. Geometric crop, concert quality investigation and Gyroflow remain open.
- Branch and last commit: `feat/wp-1a-2-libvidstab`; code correction at `3d271df`, followed by the documentation commit containing this final handover. Session started at `d2b016c`.
- Pushed: no session changes pushed. The preceding session handover was also unpushed. No push, PR or merge approval was given.
- Allowance at session start: five-hour 97% remaining; weekly 57% remaining. Owner permits the full current five-hour allowance this session. The weekly deadline remains in force. The latest check before final documentation showed five-hour 19% and weekly 45% remaining; check fresh before resuming.
- Owner confirmed no laptop shutdown deadline this session.

## Done since the last handover
- Inspected frames before changing measurement. Unchanged HDR copies reported 29-43% crop because dark scenery crossed the brightness threshold. Lowering the threshold produced 0%, but does not prove a valid geometric crop method.
- Independent review demonstrated that cropdetect also misses rotated black corners. Its result is now `observed_dark_edges_pct`, a diagnostic unsuitable for ranking engines.
- `crop_pct` is zero added crop only when fresh input/output hashes match. Transformed outputs have `null` crop and an explicit unavailable status.
- Fixed PowerShell rounding that made the claimed 15-frame shake window use 17 frames. Reports now carry `measurement_version=2`.
- All seven updated libvidstab behavior groups passed. Independent Codex review approved the correction and retained both new crop-uncertainty scenarios. Claude Code review has not occurred.
- Verified all five original hashes and retained output hashes, then remeasured all 15 clip/settings pairs successfully. Copies measured ratio 1 and zero added crop. Concert ratios remain worse at 1.727 auto / 1.997 tuned; room-walk ratios improved to 0.709 / 0.418. No output triggered the frozen-output flag.
- The two Caltrain files show different renderings and edits, not matched frame-rate controls. Both report 60 fps. The MP4 includes live-action footage near its end.
- Probed the concert output: it retains HLG/BT.2020 tags in 8-bit H.264. These benchmark outputs do not establish HDR-to-SDR conversion.
- Full results, reproduction guidance and limits: `spikes/stabilization-benchmark/evidence/2026-10-29-measurement-correction.md`.

## Next steps (in order)
1. Check both allowances and read current STATUS.md and the evidence above. Use this handover after the earlier files dated 2026-10-30; the date difference reflects Pacific time.
2. Develop and review a geometric crop method. A transform-mask approach must find an all-valid interior rectangle, handle rotated corners and preserve frame geometry/timing. Reusing cropdetect on a white mask is insufficient. Keep unknown crop explicit until this is verified.
3. Investigate the concert result with a motion/visual check independent of libvidstab's translation estimator. Moving subjects and lights are observed, but are not a proven cause. Do not tune the score merely to make it improve.
4. If testing frame-rate effects, derive both variants from the same source. Do not use the different Caltrain files as matched controls.
5. Obtain Claude Code review or rerun of the Codex changes before a PR or merge, as AGENTS.md requires. Then request owner approval separately for push, PR and merge.
6. Continue Gyroflow, Resolve and preview measurements in roadmap order. Phase 1 remains open.

## Open questions for the owner
- Additional gyro, running, pan, tripod, low-light and 4K footage; Mac and original reference PC availability.
- NVIDIA build/driver support remains undecided.
- No approval request is pending from this session. Publishing still needs explicit approval.

## Known problems and failing tests (with commands to reproduce)
- No failing tests in the touched area. Run `spikes/stabilization-benchmark/test-libvidstab.ps1 -FfmpegPath <pinned ffmpeg>` in PowerShell 7. Before correction six groups passed; after correction seven passed. `git diff --check` passed.
- Geometric crop is unavailable for transformed outputs. The translation-only shake estimator does not score rotation or blur; dropped outliers do not prove cuts. The concert score remains worse after stabilization.
- Raw version 2 reports are under local temp `kuaide-measure-v2-3ef7908cdfc64fa98c90ae0873c93f4e`, one settings folder each. Results are preserved in the committed evidence table; raw media remains outside Git. Regenerate with the harness into new folders, then `measure-run.ps1`.
- `KUAIDE_CLIPS_DIR` is unset in a fresh shell. Set it to the owner's local original-clips folder; its private path is intentionally omitted. The five clips were found and verified in this session.
- Git is installed but absent from this shell PATH; use `C:\Program Files\Git\cmd\git.exe`. The pinned FFmpeg executable is under `app/third-party/bin/`.
- The optional local commit-message checker and Python commands were unavailable on PATH; commit-message formatting was checked manually. Shell network access and Git index writes needed approved sandbox escalations.

## Hardware or owner tasks waiting
- Extra footage, Mac and original Windows reference PC. Two HDR/VFR iPhone clips are already available on this laptop.
