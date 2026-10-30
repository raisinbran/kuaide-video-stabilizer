# Clip probes and graphics-card encoders (WP 1C-B, Windows part)

Date: 2026-10-30. Host: the current Dell Precision 7760 laptop (not the i7/RTX 3080 reference PC). Tools: the pinned FFmpeg/ffprobe build (`ffmpeg-n9.0.2-37-gae19868753-win64-gpl-9.0`). Scripts: `probe-clips.ps1`, `test-hardware-encoders.ps1`; offline check `test-probe-clips.ps1`.

## Clip probes

All three clips matched the size and SHA-256 in `spikes/stabilization-benchmark/clips.manifest.json` before probing.

| Clip | Container, codec | Size, rotation | Frame rate | Color | Audio | Other tracks | Gyro |
|---|---|---|---|---|---|---|---|
| `Caltrain - Brisbane to SSF.mp4` | MP4, H.264 | 1280x720, 0 | 60 fps steady, 42.5 s | BT.709 SDR | none | none | no |
| `Caltrain - Brisbane to SSF.webm` | WebM, VP9 | 1280x720, 0 | 60 fps steady, 60.7 s | untagged, SDR | none | none | no |
| `IMG_0225.MOV` | QuickTime, H.264 | 1920x1080, -90 (portrait) | 30 fps steady, 6.0 s | BT.709 SDR | AAC | 2 Apple metadata (`mebx`) | no |

Corrections to the roadmap: `IMG_0225.MOV` is H.264, not HEVC, and is recorded in portrait (stored landscape with a -90 degree display rotation). Both Caltrain files are 60 fps.

"Steady" means the gap between frame timestamps varies by 2 ms or less. WebM stores whole milliseconds, so its 16/17 ms gaps are rounding. None of the three clips is HDR, has variable frame rate or carries gyro data, so these cases still need the owner's extra clips (STATUS.md "Owner tasks").

## Graphics-card encoders

3-second synthetic 1080p clip, 8 Mbit/s, each encoder alone and after `vidstabtransform`. Times are single short runs including process start, not benchmarks.

| Encoder | Result | Time alone / after libvidstab |
|---|---|---|
| `h264_qsv`, `hevc_qsv` (Intel Quick Sync, UHD Graphics) | works, 90 frames decode | 1.1 s / 1.4 s; 1.7 s / 1.9 s |
| `h264_nvenc`, `hevc_nvenc` (NVIDIA RTX A3000) | fails: this FFmpeg needs NVIDIA driver 610 or newer (NVENC API 13.1); the laptop has 581.95 (API 13.0) | - |
| `h264_amf`, `hevc_amf` (AMD) | fails: no AMD GPU | - |
| `libx264` (software, for comparison) | works | 0.9 s / 1.8 s |

The NVENC result matters for the build choice: a very new FFmpeg build drops users whose NVIDIA driver is older than its NVENC headers. Phase 1 must either pick a build with older NVENC headers or set and check a minimum driver version. The NVENC test must be repeated on a machine with driver 610+ or with such a build.

## Capability matrix

| Machine | OS | CPU | GPU | Hardware encode that works | 10-bit / HDR input tested | Stabilizer | Throughput |
|---|---|---|---|---|---|---|---|
| Dell Precision 7760 (current laptop) | Windows 11 (10.0.26300) | Xeon W-11855M | Intel UHD + RTX A3000 | Quick Sync H.264/HEVC; NVENC blocked by driver 581.95 | no; a synthetic HEVC 10-bit PQ clip was only probed | libvidstab (pinned build) | not measured |
| i7-14700K / RTX 3080 reference PC | - | - | - | not tested | - | - | - |
| Apple Silicon Mac | - | - | - | not tested (VideoToolbox) | - | - | - |

Hardware decoding was not tested. Whether hardware decode still helps once CPU stabilization is in the chain belongs with the throughput runs in WP 1A.2 and 1B.2.
