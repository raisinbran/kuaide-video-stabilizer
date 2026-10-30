# Preview playback spike (WP 1B.1)

A minimal Tauri 2 app that plays one local video by two delivery methods, so WP 1B.2 can measure them:

- **Custom protocol:** `media://` (on Windows WebView2 shows it as `http://media.localhost/<token>`). Rust answers each byte-range request from memory, at most 4 MB per reply.
- **Local server:** a loopback HTTP server on `127.0.0.1` with a random port, at most 8 MB per reply.

Both URLs carry a random token and serve only the one file last opened in the window. The page plays the file with a plain `<video>` element. No WebGL shader yet (WP 1B.3).

## Build and test

Needs Rust (stable), the Microsoft C++ build tools and WebView2. No Node.js or npm: the `custom-protocol` feature embeds `ui/` in every build.

```powershell
cd spikes/preview-playback/src-tauri
cargo test
cargo build
```

Self-test: set two environment variables and start the app. It plays each method to 1 second, seeks to the middle, writes a JSON report to a new file and exits with 0 if both worked, 1 if not.

```powershell
$env:KUAIDE_SELFTEST_VIDEO = 'C:/path/to/sample-1080p.mp4'
$env:KUAIDE_SELFTEST_REPORT = 'C:/new/folder/report.json'
./target/debug/kuaide-preview-playback.exe
```

A test video can be made with the pinned FFmpeg: `ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=30:duration=10 -c:v libx264 -pix_fmt yuv420p -movflags +faststart sample-1080p.mp4`. Keep videos outside the repo.

## Limits

The self-test times are single runs in a debug build and are not measurements. Steady frame rate, memory, 5-minute files, proxies and the Mac are WP 1B.2. Video that WebView2 cannot decode (for example HEVC without the Windows extension) is out of scope here.
