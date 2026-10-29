# Kuai Video Stabilizer Draft Critique

## Overall Assessment

The concept is technically credible and the draft is stronger than a typical pre-implementation plan. It appropriately keeps Tauri and the stabilization engine provisional, requires comparative stabilization testing before committing to an engine, treats edits as non-destructive, calls for separate media processing, anticipates cancellation, disk-full, and crash cases, and includes real Windows and macOS acceptance testing.

This critique applies the planning, testing, documentation, and review principles from the referenced `personal-dev-env` repository, especially its emphasis on correctness, simplicity, explicit failure modes, state and persistence boundaries, and verification of observable behavior.

Because no application exists yet, the items below are plan-level correctness risks rather than confirmed implementation bugs.

## Required Corrections

### 1. Treat this document as a design brief, not the repository's final implementation plan

The repository's planning guidance defines an implementation plan as repository-grounded, tied to a base commit, containing exact proposed diffs, module shape, verification steps, and agent notes. It specifically distinguishes an implementation plan from a design brainstorm.

The current draft already anticipates creating a fresh repository and then producing a repository-grounded implementation plan. That sequencing is appropriate.

**Suggested change:** Rename the current artifact to something like:

- `Technical Design Brief and Acceptance Requirements`
- `Pre-Implementation Technical Design`
- `Architecture and Acceptance Criteria`

Reserve the term `implementation plan` for the later repository-grounded planning artifact.

### 2. Define the video processing order explicitly

The draft allows trimming, splitting, cropping, rotation, exposure adjustment, and stabilization, but it does not define the operation order or coordinate system.

This can create real correctness defects:

- Cropping can remove features needed for motion estimation.
- Rotation metadata can alter coordinates used by stabilization.
- Hard cuts can allow motion transforms to bleed across unrelated segments.
- Exposure and color adjustments should usually not invalidate motion analysis.

**Suggested pipeline:**

1. Source decode
2. Orientation normalization
3. Source-time edit decisions and cut boundaries
4. Stabilization analysis per continuous source segment
5. Stabilization transform
6. User framing, crop, and manual rotation
7. Exposure, contrast, and color processing
8. Resize and encode

The exact order can change after proof-of-concept testing, but it should be explicitly decided before implementation.

### 3. Define stabilization-analysis invalidation rules

The draft says valid stabilization analysis should be reused, but it does not define what makes prior analysis invalid.

This matters especially for two-pass stabilization workflows that generate transform artifacts for later reuse.

**Suggested rule:** Key stabilization analysis to at least:

- Source identity
- Source geometry
- Source orientation
- Analyzed time ranges
- Timeline discontinuities
- Stabilization engine and version
- Stabilization settings

Changes to downstream-only settings such as exposure or export codec should not trigger re-analysis.

Changes to source content, geometry, relevant rotation, timeline structure, stabilization engine, or analysis parameters should invalidate the cached analysis.

### 4. Require true process isolation for crash-prone media jobs

The phrase `background processes or workers so media failures do not terminate the UI` is too ambiguous.

A Rust thread or async task does not isolate the application from a native process crash.

**Suggested change:** Require child-process isolation for FFmpeg, external stabilizers, and other crash-prone native media work unless an embedded implementation has been independently shown to have acceptable failure behavior.

Also require cancellation to terminate the entire child-process tree rather than only the immediate process.

### 5. Define the Tauri preview boundary before adopting Tauri

Keeping Tauri provisional is appropriate, but the proof of concept should test a specific playback architecture rather than only general WebView playback.

Windows and macOS use different underlying WebView engines and therefore do not provide identical media support.

**Suggested change:** Require the proof of concept to demonstrate one of these paths:

- A known-format proxy media path that both target platforms can reliably play
- A native or GPU-backed preview surface

Avoid an architecture that continuously pushes full-resolution decoded frames through frontend IPC.

Also define what `usable preview within 5 seconds` means when proxy generation is required.

### 6. Make the timeline timestamp-based and define VFR behavior

The draft promises variable-frame-rate correctness and synchronized audio while also supporting trimming, splitting, fixed output frame rates, and audio stream copy.

That requires an explicit timing model.

**Suggested requirements:**

- Internal edit operations use source timestamps or time ranges, not `frame_number / fps`.
- `Match Source` retains source timing where the selected pipeline permits it.
- Selecting 30, 60, or 120 fps explicitly means conversion to that output cadence.
- Audio stream copy is permitted only when edit boundaries, codec, timing, and container constraints make it safe.
- Add a numeric A/V synchronization acceptance tolerance to test fixtures rather than relying only on visual judgment.

### 7. Define gyro eligibility instead of checking only for gyro metadata

The existence of gyro telemetry does not by itself prove that gyro-based stabilization is valid.

Reliable gyro stabilization may depend on:

- Gyro-to-video synchronization
- Supported camera model
- Lens profile information
- Known sensor orientation
- Accurate timing metadata

**Suggested rule:**

Use gyro stabilization only when the source meets a defined support threshold, for example:

- Recognized camera
- Supported telemetry
- Valid lens and timing information

If synchronization is required, support it explicitly or fall back to image-based stabilization with a clear user-facing explanation.

### 8. Resolve the HDR policy before v1

The draft says presets adapt to HDR, `Match Source` preserves source properties, and import should avoid silently converting HDR to SDR, while HDR capabilities remain undecided.

This is not only a metadata issue. Stabilization and visual adjustment modify pixels.

**Suggested v1 decision:** Choose one explicit policy:

- Verified end-to-end 10-bit HDR-preserving path
- HDR editing and stabilization unsupported, with a clear warning or refusal
- Explicit tone-mapped SDR output

Avoid promising `preserve source properties` until the path is demonstrated.

### 9. Reduce export scope to avoid speculative complexity

The export section describes support for many codecs, containers, audio options, CBR/VBR modes, CPU/GPU choices, multichannel audio, and stream copy while also calling advanced controls nonblocking.

Those positions conflict.

For a lightweight stabilizer, this breadth adds significant implementation and testing complexity and conflicts with the repository guidance to avoid speculative extensibility.

**Suggested change:** Define a narrow v1 export matrix after Phase 1 capability testing. Treat other codecs and advanced controls as true future scope rather than retaining hidden capability requirements.

### 10. Strengthen project recovery and stale-job protection

The draft calls for small project files, autosave, recovery, and cache reuse, but does not define the persistence invariants.

**Suggested additions:**

- Project schema version
- Source identity or fingerprint
- Source relinking behavior
- Detection of changed source files
- Atomic project saves
- Separation of user intent from disposable derived caches
- Project revision IDs
- Job IDs for analysis, preview, and export

Long-running work should verify that its project revision is still current before publishing results. Otherwise, a stale analysis or preview job could overwrite newer state.

### 11. Expand the stabilization benchmark with a few high-value failure cases

The existing walking, severe-shake, deliberate-pan, gyro, and optional low-light cases are useful.

Add a small number of distinct cases that target expensive correctness failures:

- Tripod or nearly static clip, to prove the stabilizer does not create artificial motion or unnecessary crop
- Hard scene cut or removed segment, to prove stabilization transforms do not bleed across discontinuities
- Strong parallax or foreground-motion clip, to expose optical-flow failure modes

This follows the repository's preference for a small, behavior-focused suite rather than exhaustive combinations.

### 12. Move iOS completely out of current architecture criteria

Calling iOS nonessential is good, but the current design should go further.

Desktop sidecars, FFmpeg packaging, filesystem behavior, process isolation, and installers differ materially from mobile deployment.

**Suggested change:** State that v1 architecture decisions do not need to preserve iOS compatibility. Treat iOS as a separate future feasibility study.

## Optional Suggestions

### Make Phase 1 produce a concrete capability matrix

For each reference computer, record:

- OS version
- CPU
- GPU
- Hardware decoder support
- Hardware encoder support
- Tested input pixel formats
- HDR and 10-bit support
- Stabilization backend and version
- Observed throughput

Do not treat hardware acceleration as a single interchangeable feature. Some hardware paths require supported decode and encode combinations and may lose their benefit once CPU-based filtering or stabilization is inserted.

### Make third-party binary provenance part of the Phase 1 gate

The licensing check is a good start, but tighten it by recording:

- Exact FFmpeg build
- Build configuration
- Enabled external libraries
- Stabilization dependencies
- Third-party notices
- Platform-specific binary source

This avoids licensing and redistribution surprises late in implementation.

### Keep media process invocation behind Rust

Do not let React directly own raw FFmpeg or stabilizer command construction.

A narrow Rust-owned media job interface should handle:

- File paths
- Allowed arguments
- Process spawning
- Progress parsing
- Cancellation
- Job IDs
- Error normalization
- Platform differences

This keeps the frontend simpler and reduces the attack and failure surface.

### Use one documentation source where practical

Instead of maintaining an in-app User Guide and separate Markdown documentation independently, consider making one content source authoritative and render or package it into the application.

This reduces documentation drift.

### Keep the current YouTube SDR bitrate table

The table itself does not appear to need correction.

For the preset behavior, make the following explicit:

- Use 48 kHz audio
- Preserve the recorded frame rate where appropriate
- Treat 48, 50, and 60 fps as high-frame-rate cases
- Treat 120 fps as a custom or match-source case rather than extrapolating blindly from 60 fps guidance

## Revision Scope

The overall architecture can remain:

- Tauri 2
- React and TypeScript
- Rust orchestration
- FFmpeg and ffprobe
- Stabilization backend selected through proof-of-concept testing

The following current principles should also remain:

- Evidence-first stabilization engine selection
- Non-destructive editing
- Local and offline operation
- Real-hardware benchmarking
- Conservative UI scope

The revisions should concentrate on:

- Media processing contract
- Operation ordering
- Timing and VFR behavior
- Cache invalidation
- Process isolation
- HDR policy
- Export scope
- Persistence and recovery
- Phase gates
- Behavior-focused verification

## Recommended Phase 1 Deliverable

Before initializing the production repository, produce a concise decision record containing:

- Selected preview path
- Selected stabilization backend strategy
- Exact FFmpeg and stabilizer integration method
- Timestamp and VFR rules
- HDR policy
- Supported v1 import matrix
- Supported v1 export matrix
- Reference hardware
- Benchmark results
- Known unsupported cases
- Licensing and binary provenance notes

Only after those decisions are supported by evidence should the application repository be initialized and the repository's formal implementation-planning workflow generate source-level implementation steps.

## Verdict

**NEEDS UPDATES**

There is no fundamental architectural blocker in the draft.

The primary risk is that several cross-cutting media invariants are currently implicit rather than executable requirements. Resolving those before implementation should prevent a large class of synchronization, stale-cache, wrong-preview, recovery, platform-specific, and export correctness problems without materially increasing architectural complexity.
