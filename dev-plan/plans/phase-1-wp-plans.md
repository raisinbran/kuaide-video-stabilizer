# Phase 1 work-package plans (rebuilt)

## Overview

The original Phase 1 plans (WP 1A.1-1A.4 at `e1d7d4d`, WP 1B.1-1B.3 at `f63b6e6`, WP 1C-A to 1C-C at `3be84fb`) were committed only on the original Windows PC and never pushed; GitHub has no record of them. This file rebuilds them from the roadmap's Phase 1 section, the draft (`kuai-video-stabilizer_draft.md`), its critique (`kuai-video-stabilizer_draft-critiq.md`), the design brief and the replacement work done since. It keeps the original split and order. Each piece here gives the goal, files, tests and done-when; the exact code is written with `create-plan` just before that piece starts, because each one depends on results of the one before. If the original plans are ever found, compare them with this file before using either.

## Definition of Done

Phase 1 is done when `dev-plan/decision-record.md` covers every item in the critique's "Recommended Phase 1 Deliverable" (preview path, stabilizer strategy, FFmpeg/stabilizer integration, timestamp and VFR rules, HDR policy, import and export matrices, reference hardware, benchmark results, unsupported cases, licenses and provenance) and the owner approves it.

## Order and status

| Piece | Label | Depends on | Status |
|---|---|---|---|
| 1C-A Windows FFmpeg build and inventory | needs-windows | none | Done as replacements 1C-R1, 1C-R2, 1C-R3 (plus QA-R1) |
| 1A.1 Clip manifest and benchmark harness | needs-windows | 1C-A | Done: manifest (1A-R1, #10) and harness with synthetic clips |
| 1B.1 Tauri preview test app | needs-windows | none | Done on Windows (PR #8, `wp-1b-1-preview-app.md`) |
| 1C-B Camera-file probing and hardware encoders | needs-windows, needs-mac | 1C-A | Windows part done (`evidence/2026-10-30-clip-probes-and-encoders.md`); NVENC and Mac open |
| 1A.2 FFmpeg and Gyroflow runs | needs-windows | 1A.1 | Not started |
| 1B.2 Playback and seek measurements | needs-windows, needs-mac | 1B.1 | Not started |
| 1C-C Mac FFmpeg build and HDR-to-SDR method | needs-mac | 1C-B | Not started |
| 1A.3 DaVinci Resolve runs | needs-windows, desktop control | 1A.1 | Not started |
| 1B.3 Proxy and WebGL shader measurements | needs-windows, needs-mac | 1B.2 | Not started |
| 1A.4 Scoring and side-by-side comparison page | needs-windows, needs-owner (final look) | 1A.2, 1A.3 | Not started |
| Decision record | cloud-ok | all above | Not started |

The three tracks (1A, 1B, 1C) are independent and can run as parallel subagents, each owning its own `spikes/` folder.

## WP 1A: Stabilization benchmark (`spikes/stabilization-benchmark/`)

**1A.1 Manifest and harness.** Done: `write-clip-manifest.ps1` (on `feat/wp-1a-clip-manifest`) records name, size and SHA-256 of each clip in `KUAIDE_CLIPS_DIR`. Still to do: a harness script that takes the manifest, one engine name and one settings file, runs that engine on each clip into a new folder outside the repo, and writes a JSON result per clip (engine, settings, run time, exit code, output hash). Also build two synthetic clips the critique asks for: a shaken still (as in QA-R1) and a hard-cut clip made by joining two clips. Tests: harness on the synthetic clips with a fake engine that copies input; rejects existing output folders and missing clips. Done when the harness runs end to end on synthetic clips.

**1A.2 FFmpeg and Gyroflow runs.** Add engine adapters for libvidstab two-pass (automatic and tuned settings) and Gyroflow (CLI or core crate; gyro clips only, following the critique's gyro-eligibility rules). Measure run time, crop percentage and residual motion (the QA-R1 frame-difference method, extended to real clips). Tests: each adapter on the synthetic shaken clip must cut residual motion; Gyroflow must refuse a clip without usable gyro data. The full batch over all clips is LONG (1-3 h per machine): split it per clip and get Gate 2 approval first.

**1A.3 DaVinci Resolve runs.** A script in Resolve's Workspace > Scripts > Utility folder imports clips, builds one timeline per clip and queues renders. The Stabilize click is done by Claude Code desktop control (no API exists), about 5-10 minutes per clip. Results use the same JSON format as 1A.2. Done when every manifest clip has a Resolve output and result file.

**1A.4 Scoring and comparison page.** Score all outputs with the design brief section 7 metrics and frame reviews, including the critique's failure cases: tripod clip (no added motion or needless crop), hard cut (no motion bleeding across the cut), parallax clip. Build a local HTML page that plays the top candidates side by side. Owner task: 10-15 minute final look. Done when scores and the owner's choice are recorded.

## WP 1B: Preview playback (`spikes/preview-playback/`)

**1B.1 Tauri test app.** A minimal Tauri 2 app that opens a local video by both delivery methods: a custom protocol and a local HTTP server. Commit generated lockfiles (they do not count toward the 700-line limit). The first build takes 10-20 minutes. Needs Rust, Node.js and the Tauri prerequisites, which are not installed on the current laptop. Done when both methods play a 1080p H.264 file on Windows.

**1B.2 Playback measurements.** Measure start time, steady frame rate, seek latency and memory for a 5-minute 1080p H.264 file and its proxy, by both methods, on Windows and Mac. Write results as JSON. If Tauri fails, stop and give the owner the alternatives in plain words (roadmap stop point).

**1B.3 Proxy and shader measurements.** Measure proxy generation speed and stabilized 720p proxy render speed, and run the WebGL adjustment shader over the playing video while measuring frame rate. Done when the numbers exist for both machines.

## WP 1C: Media capabilities and provenance (`spikes/media-capabilities/`, `app/third-party/`)

**1C-A Windows FFmpeg.** Done (1C-R1, 1C-R2, 1C-R3, QA-R1): pinned BtbN GPL static build, hash-checked download, build inventory, software encode and a measured shake check.

**1C-B Camera files and hardware encoders.** Probe each manifest clip with ffprobe: codec, size, frame rate, VFR, rotation, HDR flags, color data and gyro tracks (critique items 6-8). Test NVENC and Quick Sync on Windows and VideoToolbox on Mac with short encodes, including whether hardware decode still helps once CPU stabilization is in the chain. Write the critique's capability matrix per machine. Done when every clip has a probe record and each machine has a capability-matrix row.

**1C-C Mac build and HDR method.** Pick a Mac arm64 GPL static FFmpeg with libvidstab and VideoToolbox, pinned by hash like the Windows one. Building from source is LONG (1-2 h) and needs Gate 2. Compare HDR-to-SDR tone-mapping methods on the HDR phone clip by frame comparison and pick one. Finish the license and source-provenance record for both builds (critique "binary provenance").

## Decision record

Write `dev-plan/decision-record.md` with `design-doc`: narrative, alternatives and the chosen direction for each item in the Definition of Done. Owner approval closes Phase 1 (Gate 5).

## Notes for agents

1. `orchestrator-proposed`: the piece names and order follow the original handover `2026-10-29-phase-1-planning.md` (on `docs/phase-1-start`); the content of each piece is rebuilt from the roadmap, draft, critique and design brief, not copied from the lost plans.
2. The original plan budgets (source lines, excluding lockfiles) were 1A: 464/358/265/492, 1B: 604/646/641, 1C: 487/539/446. Expect similar sizes; split any piece that goes over 700 lines.
3. Clips available now: `IMG_0225.MOV` and two Caltrain files (see roadmap). The engine choice also needs the owner's extra clips listed in STATUS.md.
