# Windows software smoke: observed runtime evidence

Date: 2026-10-29. Scope: a one-second synthetic integration run on the current Dell host. This is not a stabilization-quality or performance benchmark.

## Host and tool identity

- Host: Dell Precision 7760; Intel Xeon W-11855M at 3.20 GHz, 6 cores and 12 logical processors.
- Physical memory reported by Windows: 67,865,284,608 bytes.
- GPUs reported by Windows: Intel UHD Graphics (driver 32.0.101.7088) and NVIDIA RTX A3000 Laptop GPU (driver 32.0.15.8195). Neither GPU was used or validated by this software smoke.
- Storage reported by Windows: NVMe CA6-8D1024-Q11 NVMe SSSTC 1024GB, 1,024,203,640,320 bytes. Scratch outputs were on the system C: volume.
- Hardware fields above were observed using read-only Windows CIM queries before the run.
- OS reported by .NET: `Microsoft Windows 10.0.26300`; architecture `X64`; PowerShell `7.6.5`.
- FFmpeg/ffprobe build and source evidence: [Windows candidate record](2026-10-29-windows-candidate.md).
- FFmpeg SHA-256: `0b832615861f6881117c0b6041ef3525f94f08efb62604d0a06ace8495767efa`.
- ffprobe SHA-256: `8dae9a12ecc2943b7d9ed35164b55bd0fa1392d6e83e62cae60d59c4a0769a0f`.
- Tool hashes matched before and after the run. The current host is distinct from the planned i7/RTX 3080 reference PC; it does not satisfy that reference-machine gate.

## Observed results

- UTC run timestamp: `2026-10-29T22:36:52.0484413+00:00`.
- Overall report status: `passed`.
- Synthetic source: `testsrc2`, 320x180, 30 fps, one second, no audio.
- Motion-transform file: `11652` bytes, nonempty.

| Output | Reported codec | Dimensions | Decoded frames | Duration, seconds |
|---|---|---|---|---|
| `h264.mp4` | `h264` | 320x180 | 30 | 1.000 |
| `hevc.mp4` | `hevc` | 320x180 | 30 | 1.000 |
| `stabilized.mp4` | `h264` | 320x180 | 30 | 1.000 |

All output checks passed. This demonstrates that these software encoder and two-pass filter paths loaded and produced decodable short outputs with this build. It does not show how much shake is removed or whether camera footage looks good.

| Command | Exit code | Timed out | Observed elapsed milliseconds |
|---|---|---|---|
| `ffmpeg-version` | 0 | false | 86 |
| `ffprobe-version` | 0 | false | 83 |
| `encode-h264` | 0 | false | 104 |
| `encode-hevc` | 0 | false | 176 |
| `detect-motion` | 0 | false | 118 |
| `transform-motion` | 0 | false | 130 |
| `probe-h264.mp4` | 0 | false | 86 |
| `probe-hevc.mp4` | 0 | false | 95 |
| `probe-stabilized.mp4` | 0 | false | 119 |

Timings describe only these tiny commands on this host, including process startup. They are not representative encoding-speed results and cannot be compared with Phase 1 performance targets.

## Reproduction and limits

Run `spikes/media-capabilities/test-software-runtime.ps1` with the verified executable paths and a new output directory outside the repository and tool directories. The committed script contains the exact arguments and output assertions. It records stdout, stderr, timing and hashes in JSON; it uses a 30-second timeout per command and refuses preexisting output directories.

- Raw local report: `C:/Users/bchen/AppData/Local/Temp/kuaide-software-smoke-dc71d0a1352745a48f0dc8b8490d1177/software-smoke.json` (temporary; not committed).
- Raw report SHA-256: `ad1116998701b61fec8560e159a1423ed879ede507c049701259f35f2d8303fb`.
- Generated media, transforms and raw reports remain outside the repository.
- No original footage, audio sync, HDR conversion, gyro parsing, hardware encode, macOS execution or stabilization-quality scoring was tested.
- Complete source/dependency/license provenance, five-minute preview performance and original reference-machine evidence remain open. No final engine or preview decision follows from this run.
