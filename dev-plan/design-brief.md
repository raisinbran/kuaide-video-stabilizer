# Kuaide Video Stabilizer: Technical Design Brief and Acceptance Requirements

**Status:** Revision 2, 2026-10-28. This revision combines the original draft, its critique and [review.md](review.md). No application code exists yet, and no benchmarks have run.
**Author:** BJC
**Purpose:** A private desktop app, developed solo, for one-click video stabilization and light editing.

This document says what the app must do and which design rules it must follow. The step-by-step build order is in [implementation-roadmap.md](implementation-roadmap.md). Decision labels: `owner-decided` means BJC chose it. `proposed` means an agent proposed it and BJC has not confirmed it. `phase-1` means Phase 1 evidence must settle it.

## 1. Goals and scope

Kuaide Video Stabilizer is a responsive, reliable desktop app for Windows 11 and recent macOS on Apple Silicon (`owner-decided`). Its main feature is high-quality automatic stabilization in one click. It also offers a few manual refinements and basic edits.

Typical work is up to five minutes of 4K/60 or three minutes of 4K/120, with no file-size cap. Smooth editing and playback of a five-minute 1080p video is the baseline. Video never leaves the computer, and the app works offline once installed.

Footage sources (`owner-decided`): phones (iPhone, Android), action cameras and drones (GoPro, DJI, Insta360), and Sony or other mirrorless cameras.

Out of scope for v1: a full multitrack editor, commercial release, cloud features, accounts, telemetry, auto-update, Intel Macs, iOS (a possible future feasibility study, which places no requirement on v1 architecture), and HDR output.

Priorities, in order: stabilization quality, UI responsiveness, export reliability, crash recovery, then feature count.

## 2. Core user workflow

1. Launch from the Windows Start Menu or the macOS Applications folder.
2. Import a video by file picker or drag and drop. The app inspects streams, codecs, resolution, frame rate, rotation, color/HDR metadata, audio and gyro data.
3. Play, trim or split, and adjust exposure, contrast, crop or rotation.
4. Click **Auto-Stabilize**. The app picks the engine and settings and renders a stabilized preview.
5. Compare before and after. Optionally change strength and crop strategy. Technical settings sit in a collapsed Advanced section.
6. Pick an export preset, a destination and a filename.
7. Export, with progress and cancel. The source file is never changed.

Editing is non-destructive. Every edit is stored as an instruction in the project, with undo/redo and autosave.

## 3. Architecture (provisional until the Phase 1 gate)

| Part | Choice | Notes |
|---|---|---|
| Desktop shell | Tauri 2 | `phase-1`: must pass the preview tests in section 5 on both OSes. Fallback: a native shell with a native video surface. |
| UI | React + TypeScript (Vite) | Talks to the backend only through one small adapter (`BackendAdapter`). A mock adapter lets the UI run in a plain browser for cloud work and UI tests. |
| Core (app process) | Rust inside the Tauri app | Owns projects, the job queue, file paths and all process launching. The UI never builds FFmpeg commands. |
| Worker | Separate Rust program `kuaide-worker` | One process per heavy job (probe, proxy, analysis, render, export). Links the stabilizer library and starts FFmpeg/ffprobe. A crash kills only the worker. |
| Media tools | Bundled FFmpeg + ffprobe binaries | Exact builds and their provenance are recorded in Phase 1. |
| Stabilization | `phase-1` | Candidates: Gyroflow core (gyro and possibly image-based), FFmpeg libvidstab (image-based), OpenCV if both fall short. DaVinci Resolve is only a quality reference and is never bundled. |

**Process isolation rule.** All FFmpeg, stabilizer and native media work runs in a child process, never in a thread of the app process. Cancel kills the whole process tree: a Job Object on Windows and a process group on macOS. A worker that crashes or hangs (no progress for a set time) is reported as a failed job with a readable message. The project stays intact.

**Worker messages.** The core starts the worker with a JSON job file. The worker writes one JSON line per event to stdout: `progress`, `log`, `result` or `error`. This keeps the boundary easy to test and to read in logs.

## 4. Processing order and coordinates

Every preview render and every export applies operations in this order (`proposed`, confirmed or adjusted in Phase 1):

1. Decode the source.
2. Normalize orientation (apply rotation metadata so "up" is up).
3. Convert HDR to SDR when the source is HDR (`owner-decided` policy, see section 6).
4. Apply time edits: the kept source ranges after trims, splits and removed segments.
5. Analyze motion separately for each continuous source range. A cut always ends a stabilization segment, so no motion carries across it.
6. Apply the stabilization transform.
7. Apply the user's crop and manual rotation.
8. Apply exposure and contrast.
9. Scale to the output size and encode.

All crop and rotation values are stored in normalized coordinates of the frame after step 6 (0.0-1.0 of width and height, angle in degrees). They stay valid when the preview size or export size changes.

**Adjustment math (shared by preview and export).** Values use 8-bit SDR RGB scaled to 0-1. Exposure `e` in stops: `x' = x * 2^e`. Contrast `c` from -1 to 1 around mid-gray: `x'' = (x' - 0.5) * (1 + c) + 0.5`. Clamp to 0-1. The preview WebGL shader and the FFmpeg filter both implement exactly this formula. A parity test compares one frame from each, with a tolerance of 2/255 per channel.

## 5. Preview

- **Playable source** (H.264 8-bit SDR in MP4/MOV, up to 1080p, constant frame rate): play the original file directly. "Usable preview within 5 seconds" applies to this case.
- **Any other source** (HEVC, ProRes, MKV, VP9/AV1, HDR, above 1080p, high frame rate, VFR): generate an H.264 720p or 1080p SDR proxy in the background. Show progress. Playback starts as soon as the first part of the proxy is ready, if Phase 1 shows that is reliable. Otherwise it starts when the proxy is done.
- **Stabilized preview:** a background-rendered stabilized proxy. While it renders, the preview is labelled "Rendering stabilized preview". An unprocessed preview is never shown as a stabilized result.
- **Live adjustments:** the video draws through a WebGL canvas that applies the section 4 math and the crop/rotation transform in real time.
- **Delivery to the WebView:** `phase-1` picks between a Tauri custom protocol with HTTP range support and a localhost-only streaming server inside the core. Full-resolution decoded frames are never sent through UI messages.
- **Before/after:** two synchronized players side by side, plus a split-screen wipe if cheap.

## 6. Color and HDR policy (`owner-decided`)

v1 converts HDR (HLG, PQ/HDR10, Dolby Vision base layer) to SDR BT.709 with a fixed tone-mapping method chosen in Phase 1. The import panel and the export dialog both show "HDR source: output will be standard (SDR) color." No HDR metadata is ever written to an SDR file. 10-bit SDR sources (for example Sony 10-bit) are processed in at least 10 bits where the chosen filters allow, and output in 8 bits unless the preset is Archive. Log footage is passed through as-is, with no automatic LUT.

Future scope: an HDR-preserving path, end to end in 10 bits, for HDR TVs and HDR uploads.

## 7. Stabilization

Auto-Stabilize is the main feature. It tells shake apart from intended pans and tilts, keeps natural motion and field of view, and picks smoothing and crop automatically.

**Gyro eligibility.** Gyro stabilization is used only when all of these are true: the camera model is recognized, the telemetry format is supported, a lens profile is available (built in or embedded), and the timing data is usable (embedded sync, or automatic sync that passes a quality threshold). Otherwise the app uses image-based stabilization and says why, for example "No lens profile for this camera; using image-based stabilization."

**User controls.** Strength (0-100, default chosen by Auto). Crop strategy: Automatic, Minimize Crop, or Smoother Result. Advanced (collapsed): engine override, smoothing window, horizon lock if the engine supports it, rolling-shutter correction if supported.

**Warnings.** Show a warning when the analysis finds very high shake, heavy blur, strong rolling-shutter wobble, or too little texture to track. The result is still shown, labelled with the warning.

**Analysis reuse.** Stabilization has two cached stages:

| Stage | Cache key | Becomes stale when |
|---|---|---|
| Motion analysis (gyro data or measured motion per frame) | source fingerprint, orientation, analyzed source range, engine and engine version, analysis parameters (for example tracking accuracy) | source content, rotation, cut boundaries, engine or analysis parameters change |
| Smoothed transform and stabilized proxy | analysis key, strength, crop strategy, smoothing parameters | any of those change |

Exposure, contrast, user crop and export settings never make either stage stale. The source fingerprint is file size, modification time, duration, and a SHA-256 of the first and last 4 MB.

### Mandatory comparative benchmark (Phase 1)

1. Clips, 30-60 s each, from the owner's own cameras: walking handheld, severe shake, deliberate pan, gyro footage (GoPro or DJI, plus Sony if available), low light, tripod or near-static, a clip with a hard cut, and strong parallax or foreground motion. Include at least one HDR phone clip.
2. Engines: Gyroflow, FFmpeg libvidstab, and DaVinci Resolve (free version) as a reference. The agent installs and runs Resolve (`owner-decided`), using a script run inside Resolve where possible. Add OpenCV only if the first two are inadequate.
3. For each engine, run automatic or recommended settings with no tuning, then a best practical tuned version.
4. Match resolution, frame rate and export quality. Keep the originals and outputs for side-by-side review.
5. Scoring weights: shake removed 30%, warping/wobble/artifacts 25%, crop and field of view kept 15%, detail 10%, speed and resources 10%, integration and reliability 10%. The agent does the scoring (`owner-decided`). It uses automated measures (residual shake, crop and field-of-view kept, sharpness, run time) and reviews extracted frame sequences and difference images for wobble and warping, then writes down the limits of each measure. The owner only watches a short side-by-side of the top two or three candidates (about 10-15 minutes) to confirm the ranking, because judging wobble by eye is much cheaper for a person than for an agent.
6. Record how often automatic results needed a manual fix. Run on the owner's Windows PC and Apple Silicon Mac, including 4K/60 and 4K/120 samples.
7. Write up the engine choice, licenses, packaging, performance and fallbacks in `dev-plan/decision-record.md`.

**Gate:** the engine is chosen only after quality, automatic behavior, platform integration and license feasibility are shown.

## 8. Import and export

**Import (v1).** MP4, MOV, MKV and M4V are essential. AVI, WebM, MTS/M2TS and MPG are accepted when FFmpeg can decode them. The app checks the actual streams, not the extension. Unsupported codecs get a clear message. Rotation, VFR timing and audio sync are preserved.

**Timing model.** All edit times are stored as integer microseconds of source time, never as frame number divided by fps. "Match Source" keeps the source frame timing (VFR stays VFR) where the pipeline allows. Choosing 30, 60 or 120 fps means converting to that constant rate. Acceptance: audio/video offset at the end of an exported 5-minute clip is within 20 ms, measured with a generated flash-and-beep test clip.

**Export presets (v1, `proposed`).**

| Preset | Output |
|---|---|
| Mobile / Messaging | MP4, H.264, max 1080p, source fps up to 60, AAC 48 kHz 160 kbps |
| Desktop / General | MP4, H.264, source resolution, source fps, AAC 48 kHz 192 kbps |
| Web / Sharing | MP4, H.264, max 1080p, source fps, AAC 48 kHz 192 kbps |
| YouTube | MP4, H.264, source resolution up to 4K, source fps, YouTube SDR bitrates, AAC 48 kHz 384 kbps stereo |
| Full-screen TV | MP4, HEVC (falls back to H.264), up to 4K, source fps, AAC 48 kHz 256 kbps |
| High-quality Archive | MOV, ProRes 422 HQ, source resolution and fps, PCM 48 kHz |
| Match Source | Source container family, H.264 or HEVC matching the source codec family, source size and timing, high quality |

YouTube bitrates (SDR, standard/high frame rate, Mbps): 360p 1/1.5, 480p 2.5/4, 720p 5/7.5, 1080p 8/12, 1440p 16/24, 4K 35-45/53-68. 48, 50 and 60 fps count as high frame rate. 120 fps uses Match Source rules, not extrapolated rates. Presets never upscale and swap width and height for portrait clips.

**Basic controls (v1).** Container (MP4 or MOV), resolution (Match Source, 720p, 1080p, 1440p, 4K, with portrait equivalents), frame rate (Match Source, 24, 25, 30, 50, 60, 120, never above the source), and quality (Smaller File / Recommended / Higher Quality). The UI only offers valid combinations.

**Encoders.** Use hardware encoders where Phase 1 shows they work: NVENC, Quick Sync or AMF on Windows, VideoToolbox on macOS. Fall back to libx264/libx265 in software. ProRes uses FFmpeg's `prores_ks` on both OSes.

**Future scope (not v1):** MKV/WebM output, AV1/VP9, custom bitrate, CBR/VBR modes, encoder selection, extra audio codecs and channel layouts, audio stream copy, replacement audio.

**Safe output.** Check free disk space before starting (estimated size x 1.2). Write to `<name>.partial` in the destination folder. Rename to the final name only after the worker exits cleanly and ffprobe confirms the file. Never overwrite the source. Never overwrite an existing file without confirmation. Cancel or failure deletes the partial file.

## 9. Projects, persistence and recovery

- A project is a small JSON file (`.kuaide`). It holds `schema_version`, `project_id`, `revision` (incremented on every edit), sources (path plus fingerprint), the edit list, stabilization settings, and the last export settings. Caches are never stored in it.
- Projects autosave to the app data folder 2 seconds after the last edit, and before any job starts. Saves are atomic: write a temporary file, flush it, then rename it over the old file. The app keeps the previous version as `.bak`.
- At launch the app lists recent projects. A project that was not closed cleanly offers "Restore".
- If a source file has moved, the app asks the user to locate it. A different fingerprint means a changed file: the app warns and drops stale caches.
- Every job (probe, proxy, analysis, render, export) has a job ID and records the project revision it started from. Results whose inputs are no longer current are thrown away, never applied.
- Caches (proxies, analysis, stabilized proxies) live in the app cache folder, capped at 20 GB by default with least-recently-used cleanup. Settings has a "Clear cache" button.
- Undo/redo covers every edit in the project document, up to 200 steps.

## 10. Performance and resilience targets

| Scenario | Target (on the owner's reference machines) |
|---|---|
| Startup | Under 3 s |
| 5-min 1080p H.264 import | Playable within 5 s |
| 1080p preview | Steady 30 fps |
| UI while jobs run | Interactions respond within 100 ms |
| 5-min 1080p workflow | No crashes; memory stays bounded |
| 4K/60, 4K/120 | Finishes, or fails with a recoverable message; bounded memory and disk |
| Export cancel | Stops within 2 s; source, project and earlier outputs intact |

Record CPU, GPU, RAM, OS, storage and timings for every measurement. Full-speed 4K/120 preview is not required if scrubbing stays usable. Logs never include frame data, and they include file paths only at debug level.

## 11. Packaging, licensing, authorship

- Windows: NSIS installer, Start Menu shortcut, optional desktop shortcut. macOS (Apple Silicon): `.app` in a DMG, ad-hoc signed. The install guide covers the "unidentified developer" prompt using System Settings "Open Anyway", never by disabling Gatekeeper.
- Private use only. FFmpeg with libx264, libx265 and libvidstab is GPL, and Gyroflow core is GPL-3.0. That is fine for private use. Sharing the app with anyone else would bring GPL duties (offering the source code), so the About screen and README say so.
- Phase 1 records each third-party binary: its exact version, build configuration, enabled libraries, download source and license file.
- BJC is the author in app metadata, the About screen and the README. Third-party notices are kept. Source files get no author headers.

## 12. Built-in documentation

One Markdown user guide (`docs/user-guide.md`) is the only source. The app bundles it and renders it under Help > User Guide. Topics: import, Auto-Stabilize, before/after, strength and crop, editing, presets, export, supported files, hardware tips, keyboard shortcuts and troubleshooting. Screenshots are added after the UI is final.

The About screen shows the name, version, build ID, author BJC, supported OSes, stabilization engine and version, FFmpeg version, third-party licenses and a link to the guide.

## 13. Release verification

- Import samples from each of the owner's cameras, plus MKV and portrait, VFR and multi-audio files.
- Automatic stabilization quality matches the benchmark results, with no excessive wobble or crop.
- Non-destructive edits, undo/redo, crash recovery (kill the app mid-edit), and the source left unchanged.
- 1080p preview responsiveness, 4K/60 and 4K/120 runs, and killing the worker mid-job, on both machines.
- For each preset, the export's codec, size, frame rate and A/V sync are checked with ffprobe and with the 20 ms test clip. Each export plays in VLC and in the OS player (Windows Media Player or QuickTime).
- Invalid combinations cannot be chosen. Cancel, disk full and worker crash leave no corrupt files.
- Offline install and launch on both OSes. Theme switching, User Guide, About and shortcuts work.

## 14. Open questions for Phase 1

1. Which engine, or gyro/image combination, wins the benchmark?
2. Does Tauri 2 meet the preview targets on WebView2 (Windows) and WKWebView (macOS)? Which delivery method, custom protocol or local server?
3. Which FFmpeg builds (with libvidstab, x264, x265, hardware encoders) can be bundled per OS, and which hardware encoders work on the owner's machines?
4. Which tone-mapping method gives acceptable SDR output from iPhone Dolby Vision/HLG and Android HDR clips?
5. Can a stabilized 720p proxy render fast enough (target: at least real time for 1080p sources) to keep the preview loop pleasant?

**Guiding rule:** professional-looking stabilization with minimal input; useful, robust presets; no needless complexity; nothing is called better until it is measured.
