# Kuai Video Stabilizer — Draft Development Plan

**Status:** Planning only; no application implemented or stabilization benchmarks executed.  
**Author (where applicable):** BJC  
**Purpose:** Private, solo-developed video stabilization and lightweight editing application.

## 1. Goals and scope

Build a responsive, highly reliable desktop application focused on **high-quality, one-click automatic video stabilization**, with a few simple manual refinements and basic video editing. It should run on Windows 11 and recent macOS versions. iOS is a nonessential bonus and should not compromise the desktop product.

Typical workloads are up to **five minutes of 4K/60 fps** or **three minutes of 4K/120 fps**, with no arbitrary file-size cap. Smooth editing and playback of a five-minute 1080p video is a baseline requirement. Video stays local, and the application must function offline once installed.

The initial release is intentionally **not** a full nonlinear editor, commercial product, or cloud service. Prioritize stabilization quality, UI responsiveness, export reliability, and crash recovery over feature quantity.

## 2. Core user workflow

1. Launch from an obvious Windows shortcut or macOS application icon.
2. Import a video using a file picker or drag and drop. Inspect container, streams, resolution, frame rate, orientation, color metadata, audio, and gyroscope metadata when present.
3. Play and optionally trim/split the video and adjust exposure, contrast, crop, or rotation.
4. Click **Auto-Stabilize**. Analyze motion, choose appropriate engine/settings, and generate a stabilized preview.
5. Compare before/after. Optionally adjust stabilization strength and crop preference; expose technical settings only in an Advanced section.
6. Choose an export preset, destination, and filename; optionally change basic export details.
7. Export a synchronized video/audio file. Show progress, support cancellation, and retain the original unchanged.

Editing is non-destructive: persist instructions in a small project file, not changes to the source. Provide undo/redo and automatically save recoverable edits.

## 3. Proposed architecture (subject to proof of concept)

- **Desktop shell:** Tauri 2, for local-first access and comparatively modest shell overhead.
- **UI:** React + TypeScript with compact, accessible panels, toolbar, timeline, responsive video preview, and light/dark/system theme.
- **Native orchestration:** Rust, using background processes or workers so media failures do not terminate the UI.
- **Media inspection, decoding, editing filters, encoding:** FFmpeg/ffprobe or an equivalent validated backend, with hardware acceleration where reliable and software fallback.
- **Stabilization:** engine selected only after comparative testing; Gyroflow (particularly gyro-aware material), FFmpeg/libvidstab, DaVinci Resolve as a benchmark reference, and possibly OpenCV are candidates. Do not assume DaVinci Resolve can be embedded or redistributed.
- **Data:** locally stored project metadata, bounded preview proxies and cache, temporary export files, and finished outputs.

A browser-only app is **not** the default recommendation because large/high-frame-rate video processing and native codecs benefit from local native integration. The Tauri/WebView playback path itself must pass Windows/macOS performance tests before the framework decision is finalized. An alternative desktop architecture remains permissible if evidence favors it.

Keep code organized around real responsibilities: application shell/UI, import and metadata, timeline/edit state, preview/proxies, stabilization, export, persistence, and targeted tests. Avoid premature abstractions, unnecessary plugins and redundant wrapper layers.

## 4. Auto-stabilization: essential feature

Auto-Stabilize is the primary mode. Analyze unintended shake versus intentional pan/tilt, stabilize conservatively while preserving natural motion and field of view, and automatically select smoothing and crop policies. Use gyro metadata when supported; provide image-based stabilization for ordinary video. Where justified, analyze separate motion segments without visible discontinuities.

Default user-facing refinement controls:

- Stabilization strength.
- Crop strategy: Automatic, Minimize Crop, or Smoother Result.
- Before/after comparison, preferably synchronized and optionally split-screen.
- Advanced technical controls hidden unless needed.

Warn when extremely shaky, blurry, rolling-shutter-distorted, or low-texture footage cannot be stabilized satisfactorily. Do not present an unprocessed preview as a completed stabilization result. No particular engine or quality claim is considered verified yet.

### Mandatory comparative stabilization benchmark

1. Obtain at least four representative **30–60-second** clips: walking/handheld, severe shake, deliberate pan, and gyro-metadata footage; include low-light footage when available.
2. Compare the same sources using Gyroflow, FFmpeg/libvidstab, and DaVinci Resolve; examine OpenCV if primary candidates are inadequate.
3. Test each engine's automatic/recommended settings **without manual tuning**, then a best-practical manually tuned version.
4. Match resolution, frame rate, and comparable export quality; retain originals and outputs for side-by-side inspection.
5. Review unwanted motion removed (30%), warping/wobble/artifacts (25%), crop/field-of-view retention (15%), detail (10%), speed/resource usage (10%), and integration/reliability (10%). Include blind visual comparisons and record limitations of any automated metric.
6. Record if/how often automatic results need user intervention. Benchmark on actual Windows and macOS hardware, including end-to-end 4K/60 and 4K/120 samples when available.
7. Document engine selection, licensing, packaging feasibility, performance and fallback behavior. A dual gyro/image-based strategy is acceptable only if justified by the results.

**Gate:** Do not lock the stabilization implementation until quality, automatic behavior, platform integration and legal feasibility are demonstrated. These benchmarks have **not yet been run**.

## 5. Video import

Support common file containers and the compatible codecs within them. Required/import-target formats:

| Container | Typical codecs / notes | Priority |
|---|---|---|
| MP4 | H.264, HEVC/H.265, AV1 where supported | Essential |
| MOV | H.264, HEVC, ProRes | Essential |
| MKV | H.264, HEVC, VP9, AV1 and others | Essential |
| M4V | H.264, HEVC | High |
| AVI | Legacy MPEG-4 variants | High |
| WebM | VP8, VP9, AV1 | High |
| MTS/M2TS | Camera/AVCHD recordings | Secondary |
| MPG/MPEG | MPEG-1/2 | Secondary |

Inspect actual codecs and streams instead of accepting solely by filename extension. On unsupported codecs, explain clearly and offer conversion when feasible. Preserve audio sync, source orientation, appropriate timing for variable-frame-rate material, and color/HDR metadata where supported. Avoid silently misrepresenting HDR as SDR.

## 6. Basic editing and preview

- Exposure and contrast via sliders and precise optional numeric fields.
- Crop with an on-preview visual rectangle and aspect-ratio options.
- Rotate with buttons and angle field.
- Timeline: trim start/end, split into clips, remove segments, scrub, zoom, undo/redo.
- One clear editing workflow, not a full multitrack editor.
- Efficient playback using hardware decoding where viable, bounded frame caching and generated preview proxies for heavy source files.
- Reuse valid stabilization analysis when adjustments do not invalidate it. Avoid repeated lossy intermediates.

UI direction: a compact, panel-oriented layout inspired by Discord and AutoCAD—source/video preview centrally, editing/stabilization inspector alongside, timeline below, import/export clearly visible, light/dark/system themes. Do not copy third-party product branding or UI assets.

## 7. Export: presets first, customization secondary

The **normal use case is selecting a recommended preset**, not fine-tuning codecs or bitrates. Export customization is retained in the plan but **may be deprioritized** if numerous controls introduce significant UI complexity, dependencies, maintenance burden or app sluggishness. The implementing AI agent should make and justify that tradeoff based on engineering evidence. Do not remove the underlying capability entirely.

### Recommended presets

| Preset | Illustrative default (adapt to source/device) |
|---|---|
| Mobile / Messaging | MP4, H.264, 1080p or source-limited, 30 fps or source, AAC |
| Desktop / General use | MP4, H.264, up to source resolution, match frame rate, AAC |
| Web / General sharing | MP4, H.264, 1080p, source fps, AAC |
| YouTube | MP4, H.264, source fps, up to 4K, bitrate based on platform guidance |
| Full-screen TV | MP4, HEVC where compatible, up to 4K, match fps, AAC |
| High-quality Archive | MOV/compatible high-quality codec such as ProRes when available; preserve source properties |
| Match Source | Preserve source dimensions and frame rate and use suitable output codec/quality |

Presets must adapt to portrait orientation, source resolution, frame rate, HDR and device compatibility. Do not upscale automatically or fabricate high-frame-rate detail. Use tested hardware-aware codec fallbacks.

### Retained basic controls

- Container/output extension (e.g. MP4, MOV, MKV, WebM where encoder/container combinations are supported).
- Resolution: match source, 360p (640×360), 480p (about 854×480), 720p (1280×720), 1080p (1920×1080), 1440p (2560×1440), 4K UHD (3840×2160), and custom dimensions if practical. Retain aspect ratio; support portrait equivalents, fit/crop/pad policies.
- Frame rate: match source (default), 23.976, 24, 25, 29.97, 30, 50, 59.94, 60, 119.88, 120 fps where encoder permits.
- Quality: simple Recommended/Smaller File/Higher Quality control (or equivalent).

### Optional Advanced controls (nonblocking for first release)

- Video codec: H.264, HEVC, AV1, VP9, ProRes where supported.
- Quality-based encoding or target bitrate; supported constant/variable bitrate modes and GPU/CPU encoder selection.
- Audio codec: AAC (default), Opus, MP3, FLAC, PCM as container permits; sample rates 44.1/48 kHz; supported mono/stereo/multichannel; 128/192/256/320 kbps where appropriate.
- Audio stream copy where compatible; mute; replacement audio only if scope justifies it.

Reference **YouTube SDR upload bitrates** (not universally optimal output rates): 360p 1/1.5 Mbps; 480p 2.5/4; 720p 5/7.5; 1080p 8/12; 1440p 16/24; 4K 35–45/53–68 (standard/high frame rate). Other codecs, HDR and 120 fps require separate testing and recommendations.

Always prevent invalid container/codec combinations and clearly present destination/filename, estimated size where reasonably predictable, progress and cancellation. Offer a short test export if inexpensive. Use safe temporary outputs and atomically finalize where possible; never overwrite originals or corrupt prior valid outputs.

**Release requirement:** multiple practical export presets, common formats and resolution choices work reliably. Fine-grained expert settings can be deferred by the agent with a documented reason.

## 8. Performance and crash-resilience requirements

Provisional targets on documented reference hardware (not measurements):

| Scenario | Target |
|---|---|
| Startup | Under 3 seconds |
| 5-minute 1080p H.264 import | Usable preview within 5 seconds, except explicit proxy generation |
| 1080p preview | Sustained smooth 30 fps playback on reference machines |
| UI during analysis/export | Controls remain responsive; target <100 ms interaction latency |
| 5-minute 1080p workflow | No crashes or uncontrolled memory growth |
| 4K/60 and 4K/120 | Finishes or reports recoverable failure, with bounded resources |
| Export cancellation | Safe, stops work and preserves source/project |

These are acceptance **targets**, not guarantees across every machine. Full-speed 4K/120 preview is not required if scrubbing remains usable. Record CPU/GPU/RAM/OS/storage and actual timings. Offload heavy video work to separate processes; autosave and recover projects; bound concurrency and caches; validate available disk space; maintain readable error messages and logs without exposing private media unnecessarily.

## 9. Private use, ownership and packaging

- Solo development for private individual use only; no public release requirements, accounts, login, subscriptions, payment, telemetry, hosted backend, cloud sync or auto-update service by default.
- Offline operation and local-only media handling.
- Windows 11 installer with Start Menu launcher (desktop shortcut optional); macOS `.app` and convenient local installation package (e.g. DMG); documented development launcher.
- Record **BJC** as author where metadata or notices appropriately call for authorship. Do not add redundant headers/comments against language or repo norms; preserve third-party author and copyright attributions.
- Check Gyroflow, FFmpeg, codecs and other components for applicable licensing/redistribution obligations. Private use does not automatically eliminate all restrictions.
- Document installation behavior on unsigned/unnotarized builds without suggesting disabling system-wide security protections.

## 10. Built-in documentation

Include an offline **User Guide** accessible in the app (Help → User Guide) and a matching maintained Markdown document. Explain import, Auto-Stabilize, before/after, crop/strength adjustments, editing, presets, exporting, supported files, hardware/performance guidance, shortcuts and troubleshooting. Add screenshots once the actual UI is implemented.

Include an **About** screen with app name, version, build ID, BJC authorship, OS support, selected stabilization engine, media backend version, third-party acknowledgments/licenses, and a link to the manual. Keep documentation accurate and concise.

## 11. Implementation phases and optimal subagent deployment

Use subagents only for independent, bounded work that can be verified. The counts below indicate **useful maximum parallelism**, not mandatory staffing. One lead agent owns integration, acceptance criteria and decisions.

| Phase | Work | Suggested subagents | Phase gate |
|---|---|---:|---|
| 1. Comparative research/proof of concept | Stabilization quality benchmark; app/playback architecture; codecs/licensing | 3 (independent lines of research) | Evidence-backed engine/framework choice |
| 2. Application foundation | Shell, UI/theme/timeline; video import, metadata, preview/proxies | 2 (separate file ownership) | Smooth five-minute 1080p Windows/macOS preview |
| 3. Editing and stabilization | Stabilization integration and automatic settings; editing state and timeline | 2 | Reliable one-click preview, fine-tuning and non-destructive editing |
| 4. Export and documentation | Encoding/presets; manual/About and install instructions | 2 | Valid output metadata/playback/audio sync and accurate docs |
| 5. Independent validation | Video correctness; performance/stability; code/documentation review | 2–3 reviewers distinct from original authors | Critical findings resolved and native desktop acceptance passed |

For each delegation specify purpose, exact scope/files, required applicable `personal-dev-env` skills, constraints, expected artifacts, test commands and measurable evidence. Use isolated branches/worktrees where warranted and avoid concurrent edits to the same files. Fresh independent reviewers inspect important code and benchmarks. The primary agent resolves disagreements and integrates changes. Avoid agent orchestration overhead for small sequential edits; no autonomous public push/merge/release or destructive operations.

## 12. Coding and quality standards

Apply applicable guidance from [henrico813/personal-dev-env](https://github.com/henrico813/personal-dev-env), which supersedes conflicting individual preferences. Pertinent resources include:

- [`ai/AGENTS.md`](https://github.com/henrico813/personal-dev-env/blob/main/ai/AGENTS.md) — workflow defaults and routing.
- [`ai/skills/create-plan/SKILL.md`](https://github.com/henrico813/personal-dev-env/blob/main/ai/skills/create-plan/SKILL.md) — grounded implementation plans; exact code diffs once a real app repository exists.
- [`planner/`](https://github.com/henrico813/personal-dev-env/tree/main/planner) — plan creation and guarded checking when available in the development environment.
- [`ai/skills/behavior-focused-testing/SKILL.md`](https://github.com/henrico813/personal-dev-env/blob/main/ai/skills/behavior-focused-testing/SKILL.md) — high-value tests of observable behavior, not fragile internals.
- [`ai/skills/code-documentation/SKILL.md`](https://github.com/henrico813/personal-dev-env/blob/main/ai/skills/code-documentation/SKILL.md) — concise comments explaining purpose, invariants and nonobvious design.
- [`ai/skills/review-plan/SKILL.md`](https://github.com/henrico813/personal-dev-env/blob/main/ai/skills/review-plan/SKILL.md) and [`delegate`](https://github.com/henrico813/personal-dev-env/blob/main/ai/skills/delegate/SKILL.md) — review and task handoff.
- [`skill-lessons/`](https://github.com/henrico813/personal-dev-env/tree/main/skill-lessons) — installed corrections where available.

Load matching Rust/language, implementation and testing skills during those phases; do not assume remote repository standards have already been installed locally. Choose precise descriptive identifiers, avoid generic placeholders, keep functions and responsibilities small, fix root causes rather than adding individual-case overrides, and place resources in sensible folders. Comments should help an unfamiliar journeyman developer follow major workflow steps, not restate self-evident code. Apply code/behavior and tests first, naming refinement next, comment changes and owner review last.

Before implementing, establish a fresh app repository and baseline commit; create the repository-grounded implementation plan according to the prescribed planning workflow rather than inventing exact code diffs without a source tree. Do not build this app as part of this draft.

## 13. Release verification

Prioritize tests that catch likely or expensive failures:

- Import representative MP4/MOV/MKV and other supported formats, including different codecs, portrait rotation, variable-frame-rate and audio tracks.
- Confirm automatic stabilization quality against the original and manually optimized benchmarks without excessive wobble/crop.
- Verify non-destructive edits, undo/redo, project recovery and preservation of original sources.
- Test high-resolution sources, 1080p preview responsiveness, resource bounds and crash-isolation behavior on actual Windows 11 and recent macOS hardware.
- Verify preset exports by inspecting resulting codecs, dimensions, frame rate, audio synchronization and playback in common players.
- Verify invalid combinations are prevented and cancellation/disk-full/worker-crash conditions leave no corrupted prior output.
- Install/launch offline on both operating systems; verify light/dark/system setting, User Guide, About, and shortcuts.

## 14. Decisions deliberately open

1. Which stabilization engine or combination wins real comparative tests?
2. Does Tauri 2 plus the selected preview pipeline meet responsiveness on both operating systems, or should another shell be used?
3. Which codecs, ProRes/HDR workflows and hardware encoders are technically available on each reference computer?
4. Which optional advanced export controls can be delivered without meaningful complexity or lag, and which should be deferred?
5. Is iOS compatibility practical as a later optional enhancement without weakening desktop quality?

**Guiding decision rule:** Deliver professional-looking stabilization with minimal user input. Keep export presets useful and robust, avoid unnecessary complexity, and require direct verification before declaring an engine or optimization superior.
