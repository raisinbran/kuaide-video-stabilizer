# WP 1B.1: Tauri preview test app

## Overview

Build the smallest Tauri 2 app that plays one local video by the two delivery methods the roadmap names, a custom protocol and a local HTTP server, so WP 1B.2 can measure them. The code was written and checked first, as with QA-R1, so this record points at the exact code in the commit instead of repeating it. A fresh reviewer checks plan and code together before the PR.

## Definition of Done

Both methods play and seek a 1080p H.264 file on Windows, shown by the app's own self-test report, and the range-reading rules are covered by Rust tests.

### Goals

- [x] Tauri 2 app in `spikes/preview-playback/` with a plain HTML/JS page.
- [x] Custom protocol and loopback HTTP server, both with byte-range replies.
- [x] Self-test mode that plays, seeks, writes a JSON report and exits 0 or 1.
- [x] Rust tests for range parsing and reads.

## Current State
Base commit: b723b7cd

`main` after PR #7. Rust 1.99.1, Node.js 26 LTS, MSVC build tools (`C:\BuildTools`) and WebView2 156 are installed on the current laptop.

## Module Shape

`spikes/preview-playback/README.md`
`spikes/preview-playback/ui/index.html`
`spikes/preview-playback/ui/main.js`
`spikes/preview-playback/src-tauri/Cargo.toml`
`spikes/preview-playback/src-tauri/build.rs`
`spikes/preview-playback/src-tauri/tauri.conf.json`
`spikes/preview-playback/src-tauri/capabilities/default.json`
`spikes/preview-playback/src-tauri/icons/icon.ico`
`spikes/preview-playback/src-tauri/src/main.rs`
`spikes/preview-playback/src-tauri/src/range.rs`

## Verification

```powershell
cd spikes/preview-playback/src-tauri
cargo test
cargo build
```

Then run the self-test from the README with a 1080p H.264 file. Result on 2026-10-29: `passed: true`; both methods 1920x1080; custom protocol reached 1 s of play in 1910 ms and seeked in 161 ms, local server 1187 ms and 154 ms (single debug-build runs, not measurements).

## Notes for agents

1. `orchestrator-proposed`: no npm. The `custom-protocol` Cargo feature embeds `ui/` in every build, so `cargo build` is enough and no `package.json` or `package-lock.json` is needed. Add the Tauri CLI only when bundling is needed.
2. `orchestrator-proposed`: replies are read into memory and capped (4 MB protocol, 8 MB HTTP); the player asks again for the rest. A request without a range gets 200 only when the whole file fits, otherwise the first chunk as 206.
3. `orchestrator-proposed`: each URL carries a random token and serves only the last opened file. The token comes from `RandomState`, which is enough against other local pages but is not a security boundary for a shipped app.
4. The HTTP server sends no CORS header. WP 1B.3 needs one (or `crossorigin`) before drawing the video into WebGL.
5. `icons/icon.ico` is a 152-byte single-color icon made with the pinned FFmpeg, because Tauri needs an icon to build on Windows.
6. Size: about 523 lines excluding the generated `Cargo.lock`, which is committed (owner rule 2026-10-29).
