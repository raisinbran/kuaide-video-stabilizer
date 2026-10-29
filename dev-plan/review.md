# Review of the Draft Plan and Critique

Reviewed: [kuai-video-stabilizer_draft.md](kuai-video-stabilizer_draft.md) (the draft) and [kuai-video-stabilizer_draft-critiq.md](kuai-video-stabilizer_draft-critiq.md) (the critique), 2026-10-28, against `henrico813/personal-dev-env` at commit `64a2efecd10a7926755d502fb558e7ed424a4626` (skills: `review-plan`, `create-plan`, `design-doc`, `behavior-focused-testing`, `code-documentation`, `rust-development`, `delegate`, `roadmap-run`, `git-messages`, `plain-direct-english`).

The draft and the critique were written under the old name "Kuai". The app is now **Kuaide Video Stabilizer**, and the repository becomes `kuaide-video-stabilizer`.

## Verdict

Plan: **NEEDS UPDATES** (now applied in [design-brief.md](design-brief.md) and [implementation-roadmap.md](implementation-roadmap.md)).

The critique is accurate. I accept all 12 of its required corrections. The findings below are new or change a critique item. Each one says where it was applied.

## Required corrections (new)

1. **Repository sequencing conflicts with the owner's working model.** The draft and the critique both say to finish Phase 1 before "initializing the production repository". The owner now requires all work to live in this repository so any computer, local or cloud, can continue it. Applied: one repository. Phase 1 throwaway code lives in `spikes/`, and production code starts in `app/` only after the Phase 1 decision record is approved. See roadmap, Phase 0 and Phase 1.
2. **personal-dev-env assumes tools and folders this project does not have.** Its planning workflow expects `planner`, `nobs` (vault), `wt`, `vibe` and `pde-gh-write`. These are Linux-oriented and are not installed on the owner's Windows machine or in a default cloud session. It also puts plans in a vault, not the repository. Applied: [AGENTS.md](../AGENTS.md) lists each adaptation. Plans live in `dev-plan/`. Plans are checked by a fresh reviewer agent instead of `planner check` unless planner is available. Git and `gh` are used directly, with owner approval before any push or PR.
3. **Gyro footage is core, not optional.** The owner shoots with phones, GoPro/DJI/Insta360 and Sony cameras. The action cameras and Sony bodies embed gyro data, so gyro-based stabilization is likely the best result for much of the owner's footage. Phones rarely give usable gyro data through the normal camera app. Applied: the benchmark weights gyro and image-based paths equally. A dual strategy (gyro when eligible, image-based otherwise) is the expected result, still subject to evidence.
4. **HDR policy is now decided.** Modern phones record HDR (HLG or Dolby Vision) by default, so this affects most phone clips. Owner decision: v1 converts HDR to SDR with a clear notice. Applied: design brief, section 6. Tone mapping happens early in the processing order, so preview, stabilization and export all work on the same SDR frames.
5. **The live preview must match the export.** The draft wants live exposure, contrast, crop and rotation in the preview, while FFmpeg does the export. If the preview uses its own approximation (for example CSS filters), what the user sees will not match the file. Applied: the adjustment math is defined once in the design brief. The preview shader and the FFmpeg filter both implement it, and one parity test compares a rendered still frame from each.
6. **Stabilization strength should not force re-analysis.** Critique item 3 lists "stabilization settings" as an analysis key. For both Gyroflow and libvidstab, motion is measured once and smoothing is applied afterwards. Changing strength or crop policy should only redo the smoothing and render step, which is much faster. Applied: the design brief separates the analysis key from the render key.
7. **The UI cannot be built in a cloud session unless the backend can be faked.** Cloud sessions run Linux without a desktop. Tauri windows cannot be viewed there. Applied: the frontend talks to the backend through one small adapter. A mock adapter lets the UI run in a normal browser (and in Claude Code's browser pane) with recorded sample data. This is justified as a testing boundary, not as a speculative abstraction.
8. **Large video files must stay out of git.** Benchmark clips (4K, 30-60 s) are hundreds of MB each. Applied: clips live in an owner-chosen cloud folder. The repo keeps a manifest with file names, SHA-256 hashes and descriptions. Automated tests use small synthetic clips that FFmpeg scripts generate on demand.
9. **Some work can only happen on the owner's hardware or with the owner's eyes.** These are the DaVinci Resolve benchmark runs, blind visual scoring, WebView playback tests on Windows and macOS, and installer checks. Applied: every roadmap work package is labelled `cloud-ok`, `needs-windows`, `needs-mac` or `needs-owner`.
10. **A first-run macOS build on Apple Silicon must be signed.** Apple Silicon refuses unsigned arm64 binaries outright. Applied: use ad-hoc signing (no Apple account needed). The install notes describe "Open Anyway" in System Settings and do not suggest disabling Gatekeeper.
11. **Audio stream copy adds risk for little benefit.** Every export with trims or splits must re-encode audio at cut points anyway. Applied: v1 always re-encodes audio (AAC 48 kHz, or PCM for the archive preset). Stream copy moves to future scope.
12. **Wording rules.** personal-dev-env forbids the words "canonical" and "contract" and forbids emojis in agent-written text. The critique uses "media processing contract". Applied: new docs avoid these words.

## Changes to critique items

- Critique item 1 (rename the draft to a design brief): accepted. The revised document is [design-brief.md](design-brief.md). The original draft and critique stay unchanged for history.
- Critique item 9 (narrow export matrix): accepted. The proposed v1 matrix is in design brief section 8. Phase 1 can still narrow it further.
- Critique item 12 (iOS out of scope): accepted. iOS is listed only as a future feasibility study.
- Critique optional suggestions (capability matrix, binary provenance, Rust-owned media commands, one documentation source, YouTube preset details): all accepted.

## Optional suggestions

- Keep a "Recent projects" list so the user never has to manage project files by hand. Projects autosave to the app's data folder. "Save project as..." is available but not required. (Applied as an orchestrator-proposed decision.)
- Build `planner` from personal-dev-env's Go source on a machine with Go, if the owner wants the full guarded-plan workflow later. Not required.

## Decisions that remain unchanged

Local-first offline app; Tauri 2 + React/TypeScript + Rust (still provisional until Phase 1); FFmpeg/ffprobe; evidence-first engine choice; non-destructive editing; private use only; real-hardware acceptance.
