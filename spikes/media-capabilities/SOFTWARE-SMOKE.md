# Software runtime smoke

Run this PowerShell 7 integration smoke only against trusted, checksum-verified FFmpeg and ffprobe files. Supply both paths explicitly and choose a new output directory whose parent already exists. Output must be outside the repository and both tool directories. Existing output directories and linked paths are rejected.

```powershell
pwsh -NoProfile -File ./spikes/media-capabilities/test-software-runtime.ps1 `
  -FfmpegPath 'C:/verified-tools/ffmpeg.exe' `
  -FfprobePath 'C:/verified-tools/ffprobe.exe' `
  -OutputDirectory 'C:/media-evidence/new-software-smoke'
```

The smoke generates one second of synthetic `testsrc2` at 320x180 and 30 fps. It encodes H.264 with libx264 and HEVC with libx265, runs libvidstab detection and transformation, then decodes/counts frames with ffprobe. Every resulting video must have the expected codec, 320x180 dimensions, 30 decoded frames and duration within 0.05 seconds of one second. A nonempty transform file is also required. A second check shows that stabilization reduces motion: it pans one still `testsrc2` frame along a fixed sine path for two seconds (`shaky.mp4`), stabilizes it with libvidstab (`steadied.mp4`), and measures the mean frame-to-frame brightness difference in the center of each video. The shaky video must reach a difference of at least 5, and the steadied video must be at most a quarter of the shaky one. A first run on 2026-10-29 measured 20.7 and 1.9. Native commands use a 30-second timeout and fixed relative filenames in the new working directory. FFmpeg receives `-n` to refuse overwriting.

Success writes `software-smoke.json` after all checks and before/after tool-hash comparisons pass. A pipeline failure writes `software-smoke-failed.json` with failed status and the commands completed so far, then exits with an error. Input-path rejection creates no report. The JSON preserves exact arguments, exit codes, stdout, stderr, elapsed milliseconds, versions, tool/output hashes and host OS/architecture. Keep output files outside the repository; retain the JSON for inspection. A disk write failure may leave an incomplete new report.

The smoke does not open user footage, test hardware encoders, assess stabilization quality, measure representative performance or establish source/license provenance. Its timings describe this small run only. The generated test pattern is not a benchmark clip. Do not change directory links or binaries concurrently. The check records file identity but does not authenticate arbitrary executable files supplied by a caller.
