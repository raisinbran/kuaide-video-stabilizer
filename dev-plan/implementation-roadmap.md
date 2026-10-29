# Kuaide Video Stabilizer: Implementation Roadmap

**Status:** Proposed, 2026-10-28. Waiting for owner approval.
**Requirements:** [design-brief.md](design-brief.md). **Agent rules:** [../AGENTS.md](../AGENTS.md). **Live progress:** [STATUS.md](STATUS.md).

This roadmap splits the build into phases and pull-request-sized work packages (WPs). It names the frontend and backend parts, which WPs can run in parallel with subagents, and where agents must stop. Each WP gets its own implementation plan in `dev-plan/plans/` just before it starts. personal-dev-env's `create-plan` skill writes that plan against the code as it exists then. This roadmap holds no code diffs, because there is no code yet.

## How to read the labels

- **Where:** `cloud-ok` runs in any session, including a Linux cloud session. `needs-windows` and `needs-mac` need the owner's physical machine. `needs-owner` needs BJC's eyes, footage or a manual app (for example DaVinci Resolve).
- **Est.:** rough agent working time. Any single step that cannot be paused and is expected to take over 1 hour is marked **LONG**. AGENTS.md says the agent must ask before starting it.
- **Size rule:** a PR changes at most 700 lines (personal-dev-env `roadmap-run`). A WP that grows past that splits into two PRs.

## Repository layout (target)

```text
AGENTS.md                 rules for every agent (Claude Code, Codex, others)
CLAUDE.md                 points Claude Code at AGENTS.md
dev-plan/                 design brief, roadmap, status, plans, handovers, decision record
spikes/                   Phase 1 throwaway experiments, never imported by app code
  stabilization-benchmark/
  preview-playback/
  media-capabilities/
app/
  src-tauri/              Rust core: Tauri app, commands, projects, job queue
  worker/                 Rust crate kuaide-worker: probe, proxy, analysis, render, export
  media-model/            Rust crate shared by core and worker: job specs, events, edit model
  ui/                     React + TypeScript frontend (Vite)
    src/backend/          BackendAdapter interface, Tauri adapter, mock adapter
    src/state/            project store, undo/redo, job tracking
    src/components/       visual components (UI/UX phase)
    src/features/         import, player, timeline, inspector, export, help
  third-party/            download scripts, checksums, license texts for FFmpeg etc. (binaries git-ignored)
docs/
  user-guide.md           the only user guide source; bundled into the app
  install.md
tests/fixtures/           scripts that generate small synthetic test clips with FFmpeg
.github/workflows/        CI
```

## Backend design (Rust)

**Core (`app/src-tauri`).** It runs inside the Tauri app process and stays light. Its jobs:

- Tauri commands the UI calls: `open_video`, `get_project`, `apply_edit`, `undo`, `redo`, `start_stabilize`, `start_export`, `cancel_job`, `list_recent_projects`, `restore_project`, `get_capabilities`. Rust and TypeScript share types through generated bindings (`tauri-specta`, `proposed`), so the two sides cannot drift.
- **Project store:** loads, validates and atomically saves `.kuaide` JSON. Autosaves, keeps the `.bak` copy, and runs the recovery check at launch.
- **Job queue:** one heavy job per kind at a time, and a bounded total. It writes the job file and starts `kuaide-worker` inside a Windows Job Object or a Unix process group. It reads JSON event lines, sends progress to the UI as Tauri events, enforces the hang timeout, and on cancel kills the whole process tree. It drops results whose project revision is stale.
- **Cache manager:** keys from design brief section 7, the 20 GB LRU cap, and "Clear cache".
- **Media server:** delivers source and proxy files to the WebView with range requests, using the method chosen in Phase 1. It serves only files registered with the current project.

**Worker (`app/worker`, binary `kuaide-worker`).** It is a separate program, so native crashes cannot take down the app. Subcommands match job kinds:

- `probe`: runs ffprobe, then normalizes streams, rotation, HDR flags, VFR detection and gyro/telemetry detection (Gyroflow's telemetry parser if chosen).
- `proxy`: produces the H.264 SDR preview proxy, tone-mapping HDR when needed.
- `analyze`: measures motion per continuous source range with the chosen engine, and writes the analysis cache file.
- `render-preview`: produces the stabilized proxy from the analysis, strength and crop strategy.
- `export`: builds the full filter graph in design brief section 4 order. It encodes to `.partial`, verifies with ffprobe, and reports the result. The core does the final rename.
- **Filter graph builder:** one module shared by `render-preview` and `export`, which turns the edit model into FFmpeg filter arguments. This is the main place where bugs would show up as wrong output, so it gets the most tests.

**Shared model (`app/media-model`).** Plain Rust data types with serde: `Project`, `EditList`, `TimeRangeUs`, `CropRect`, `Adjustments`, `StabilizationSettings`, `ExportSettings`, `JobSpec`, `WorkerEvent`. These types do not do I/O.

## Frontend design (React + TypeScript)

- **`BackendAdapter`:** the only way the UI reaches the backend. `TauriAdapter` calls the real commands. `MockAdapter` returns recorded probe results, fake job progress and sample clips, so the UI runs in a normal browser, in cloud sessions and in UI tests.
- **State (`src/state`):** a Zustand store holds a mirror of the project document and the job states. The core is the source of truth. Each edit goes to the core with `apply_edit`, and the store updates from the revision the core returns. Undo/redo calls the core, which keeps the history next to the saved document.
- **Player:** an HTML `<video>` element drawn to a WebGL canvas. The shader applies exposure, contrast, crop and rotation (design brief section 4 math). Before/after uses two synchronized players.
- **Timeline:** DOM and canvas. Shows the time ruler, kept and removed ranges, split points, playhead, zoom, and thumbnails from the proxy.
- **Inspector panels:** Stabilize (button, status, strength, crop strategy, warnings, Advanced), Adjust (exposure, contrast, crop, rotate, each with a slider and a number field), Export (presets, basic controls, destination, estimate, progress).
- **Shell:** menus (File, Edit, View, Help), toolbar (Import, Auto-Stabilize, Export), light/dark/system theme from CSS variables, keyboard shortcuts, Help (renders the bundled user guide), About.
- **Libraries (`proposed`):** Radix UI primitives for accessible menus, sliders and dialogs. No full UI kit. Vitest for logic tests. Playwright against the mock adapter for a few UI behavior tests.

## Phases and work packages

### Phase 0: Repository setup (this session)

| WP | Work | Where | Est. |
|---|---|---|---|
| 0.1 | AGENTS.md, CLAUDE.md, .gitignore, dev-plan docs, STATUS.md | cloud-ok | done in this session |
| 0.2 | Owner renames the GitHub repo to `kuaide-video-stabilizer`; agent updates the git remote | needs-owner | 5 min |

**Stop point:** owner approves this roadmap.

### Phase 1: Evidence (spikes, mostly owner hardware)

These three tracks are independent. Run them as **3 parallel subagents**, each owning one folder in `spikes/`.

| WP | Work | Where | Est. |
|---|---|---|---|
| 1A | **Stabilization benchmark.** Scripts that run libvidstab (two-pass) and Gyroflow (CLI or core crate) on each clip with automatic and tuned settings. They collect run time, crop percentage and residual-motion numbers. The agent installs DaVinci Resolve (free) and runs it, scripted from inside Resolve where possible. The agent scores all results with the metrics and frame reviews in design brief section 7. A local comparison page plays the top candidates side by side for the owner's short confirmation (about 10-15 minutes). The owner only records and copies the clips into the clips folder (see AGENTS.md); they are listed in `spikes/stabilization-benchmark/clips.manifest.json` with SHA-256. | needs-windows, needs-mac; needs-owner only for clips and the final look | 6-10 h agent work. The batch render is **LONG** (est. 1-3 h per machine for all clips and engines; can split per clip) |
| 1B | **Preview playback.** A minimal Tauri 2 app that plays a 5-minute 1080p H.264 file and a proxy using both delivery methods (custom protocol, local server). It measures start time, steady fps, seek latency and memory, and runs the WebGL adjustment shader over the video. Also measures proxy generation speed and stabilized 720p proxy render speed. | needs-windows, needs-mac | 5-8 h. The first Tauri build takes about 10-20 min |
| 1C | **Media capabilities and provenance.** Picks FFmpeg builds per OS (Windows: a GPL static build that includes libvidstab, x264, x265 and hardware encoders; macOS arm64: a static GPL build with libvidstab and VideoToolbox). Records versions, configure flags, sources and licenses. Tests hardware encoders on both machines. Probes the owner's camera samples (HDR flags, rotation, VFR, gyro detection). Picks a tone-mapping method by comparing frames. | mostly cloud-ok; encoder tests need-windows and need-mac | 4-6 h. If no suitable macOS build exists, building FFmpeg from source is **LONG** (est. 1-2 h) |

**Benchmark clip coverage.** Clips in the folder on 2026-10-28, checked by reading their file headers (FFmpeg is not installed yet):

| File | What it is | Use |
|---|---|---|
| `IMG_0225.MOV` | iPhone 7 original, HEVC 1080p, 6 s, SDR, no gyro track | Short phone test; too short for the 30-60 s benchmark length, but fine for import and HEVC tests |
| `Caltrain - Brisbane to SSF.webm` | VP9, 60 s, written by an FFmpeg-based tool (likely a download) | Main "ordinary video" benchmark clip. Probably the earlier of the two files (older date, longer) |
| `Caltrain - Brisbane to SSF.mp4` | H.264 1280x720, 42 s, re-encoded by FFmpeg | Not the camera original. The content overlaps the WebM, but it is 18 s shorter. Use it for the MP4 import test only |

Neither Caltrain file is a camera original. Both were re-compressed, so they test "downloaded video", not best-case quality. 1A can start with these clips plus synthetic shaken clips, building and checking the harness. The engine choice at the Phase 1 gate also needs, in priority order: (1) an original GoPro, DJI or Insta360 clip with gyro data; (2) a recent phone clip recorded in HDR; (3) a 4K/60 clip, and 4K/120 if a camera can record it; (4) a handheld deliberate pan; (5) a tripod or resting-camera clip; (6) a running or severe-shake clip; (7) a low-light clip; (8) a Sony clip with gyro data, if available. The agent makes the hard-cut clip by joining two clips. The parallax case can come from any walking clip past nearby objects. STATUS.md holds this list as an owner task, with copying instructions.

**Resolve procedure (1A).** A script placed in Resolve's Workspace > Scripts > Utility folder imports clips, builds one timeline per clip and queues the renders. The agent clicks Stabilize in the Inspector for each clip through desktop control, because the scripting API has no stabilize command. Expect about 5-10 minutes of agent time per clip.

**Phase 1 output:** `dev-plan/decision-record.md`. It covers the preview path, the engine strategy, the FFmpeg/stabilizer integration method, timing and VFR rules, the tone-mapping method, the v1 import and export matrices, the reference hardware, benchmark results, unsupported cases, and licenses and provenance. Write it with `design-doc` (narrative, alternatives, chosen direction).

**Stop point (owner gate):** BJC approves the decision record. If Tauri fails the preview test, the agent stops, presents the alternatives in plain terms, and asks.

### Phase 2: Foundation (backend first, plain test UI)

| WP | Work | Where | Est. | Depends on |
|---|---|---|---|---|
| 2.1 | Workspace skeleton: Cargo workspace (`src-tauri`, `worker`, `media-model`), Vite React app, generated bindings, CI (Linux: fmt, clippy, tests; Windows and macOS: build only, run manually) | cloud-ok | 2-3 h | Phase 1 |
| 2.2 | `media-model` types and project JSON schema, with load, save, migration stub and atomic save | cloud-ok | 2-3 h | 2.1 |
| 2.3 | Job queue and worker launcher: job files, event stream, process-tree cancel (Job Object, process group), hang timeout, stale-revision drop | cloud-ok (Linux); Windows cancel test needs-windows | 4-6 h | 2.2 |
| 2.4 | Worker `probe` and `proxy`, plus test-clip generator scripts in `tests/fixtures` | cloud-ok | 3-5 h | 2.2 |
| 2.5 | Project store autosave, recovery, recent projects, source relink and fingerprint | cloud-ok | 3-4 h | 2.2 |
| 2.6 | Media server (Phase 1 method), and a plain unstyled test page that imports, plays and shows job progress. This page is test tooling only, not UI/UX work | needs-windows, needs-mac to confirm | 2-3 h | 2.3, 2.4 |

**Parallelism:** after 2.2 lands, run **3 subagents**: 2.3, 2.4 and 2.5. Each owns its own module folder. 2.6 follows.

**Stop point (gate):** the test page plays a 5-minute 1080p clip smoothly on both machines. Killing the worker mid-proxy leaves the app running and the project intact.

### Phase 3: Editing, stabilization and export engine (backend)

| WP | Work | Where | Est. | Depends on |
|---|---|---|---|---|
| 3.1 | Filter graph builder (section 4 order), edit model operations (trim, split, remove range, crop, rotate, exposure, contrast) in the core with undo/redo history, and the preview/export adjustment parity test | cloud-ok | 5-7 h (may split into 2 PRs) | Phase 2 |
| 3.2 | Stabilization: `analyze` and `render-preview` with the chosen engine(s), gyro eligibility check, automatic settings, warnings, two-stage cache | cloud-ok for logic; quality check needs-owner | 8-12 h (likely 2-3 PRs). The first build that compiles the stabilizer library may take about 20-40 min | 3.1 |
| 3.3 | Export: presets, valid-combination rules, encoder detection and fallback, disk-space check, `.partial` and verify-then-rename, cancel cleanup, A/V sync test clip | cloud-ok for software encoders; hardware encoders need-windows and need-mac | 6-8 h (2 PRs) | 3.1 |

**Parallelism:** 3.1 first, since both others use the filter graph builder. Then **2 subagents** run 3.2 and 3.3 in parallel. 3.2 owns `worker/src/stabilize/` and the cache module. 3.3 owns `worker/src/export/` and the preset rules.

**Stop point (gate):** from the test page, one click gives a stabilized preview. Strength changes re-render without re-analysis. All presets export files that pass the ffprobe checks and the 20 ms sync test.

### Phase 4: UI/UX (owner gate before starting)

**UI/UX gate.** Before any Phase 4 work starts, the running agent checks which agent it is. If it is not Claude Code, it must stop and ask the owner how to proceed, offering these options:

1. Prepare handoff documents so Claude Code can run the UI/UX phase. Write them to `dev-plan/handover/ui-ux-handoff.md` using the template in AGENTS.md, plus anything Claude Code needs: the mock adapter, sample data, the design notes below, and the state of every WP.
2. Continue the UI/UX work with the current agent anyway.
3. Pause the project here.

If the agent is Claude Code, it confirms the visual direction with the owner (see the first step below) and then proceeds. Claude Code can check the UI visually through the Vite dev server with the mock adapter in its browser pane.

**Visual direction (from the draft):** a compact, panel-based layout inspired by Discord and AutoCAD. The preview sits in the center, the inspector on the side, the timeline at the bottom, and Import and Export are always visible. Light, dark and system themes. No copied branding or assets. First step of Phase 4: show the owner 2-3 static layout mockups and get a pick before building.

| WP | Work | Where | Est. | Depends on |
|---|---|---|---|---|
| 4.1 | Design tokens (colors, spacing, type) for light and dark, app shell layout, menus, toolbar, theme switching, shortcuts framework | cloud-ok (mock adapter) | 4-6 h | owner picks a mockup |
| 4.2 | Player: WebGL canvas, transport controls, before/after compare, crop overlay with handles and aspect presets | cloud-ok; real playback check needs-windows and needs-mac | 6-8 h | 4.1 |
| 4.3 | Timeline: ruler, scrub, zoom, trim handles, split, remove, thumbnails | cloud-ok | 6-8 h | 4.1 |
| 4.4 | Inspector: Stabilize panel, Adjust panel, Export dialog, job progress and errors, recovery prompt, recent projects | cloud-ok | 6-8 h | 4.1 |

**Parallelism:** 4.1 first, since it holds the shared tokens and layout. Then **3 subagents** run 4.2, 4.3 and 4.4, each in its own `src/features/<name>/` folder. Shared components added after 4.1 go through the lead agent to avoid edit collisions.

**Stop point:** the owner tries the full workflow on both machines and gives feedback. Then one polish WP (4.5) handles that feedback.

### Phase 5: Documentation and packaging

| WP | Work | Where | Est. |
|---|---|---|---|
| 5.1 | User guide (one Markdown source) bundled and shown under Help, About screen, third-party notices | cloud-ok; screenshots needs-windows | 3-4 h |
| 5.2 | Installers: NSIS on Windows, ad-hoc signed DMG on macOS, bundled FFmpeg and worker sidecars, `docs/install.md`, release workflow (manual trigger) | needs-windows, needs-mac | 4-6 h. A release build of both installers takes about 20-40 min each |

**Parallelism:** **2 subagents** (5.1 and 5.2 touch different files).

### Phase 6: Independent validation

Reviewers are always fresh agents that did not write the code (personal-dev-env `review-plan` and `delegate`).

| WP | Work | Where |
|---|---|---|
| 6.1 | Video correctness review: filter order, timing, sync, HDR notice, export checks | cloud-ok |
| 6.2 | Code review, one agent per skill in parallel: `review-plan`, `rust-development`, `code-documentation`, `behavior-focused-testing` | cloud-ok |
| 6.3 | Release checklist (design brief section 13) on both machines, with the owner | needs-owner, needs-windows, needs-mac |
| 6.4 | Owner's comment review, last, as `code-documentation` requires | needs-owner |

**Parallelism:** 6.1 and 6.2 together (**up to 5 subagents**), then 6.3, then 6.4.

## Subagent rules (summary; AGENTS.md has the full rules)

- One lead agent owns integration, decisions and STATUS.md. Subagents get one WP each, with: the goal, exact folders they own, folders they must not touch, an `Applicable skills:` line, test commands, and the report to return.
- Parallel subagents never edit the same files. Each works in its own git worktree and branch, `<type>/<words>` (for example `feat/wp-2-3-job-queue`).
- The lead checks every subagent's claims against the actual files and test results. A different agent reviews the work.
- Skip subagents for small sequential edits; they cost more than they save.

## Rough total

About 110-160 hours of agent work, plus owner time for footage, scoring, hardware tests and approvals. The estimates are guesses until Phase 1 is done. The roadmap is re-estimated at the Phase 1 gate.
