# Clip manifest spike

This PowerShell 7 script hashes top-level files from the directory named by `KUAIDE_CLIPS_DIR`. It records filenames, byte sizes and full-file SHA-256. It never modifies the input files. It does not probe, decode or classify media and does not run FFmpeg.

Set the environment variable to the local original-clips directory. Keep only original clips there, as AGENTS.md requires. Supply an existing output directory outside this repository and the clips directory:

```powershell
$env:KUAIDE_CLIPS_DIR = 'C:/original-clips'
pwsh -NoProfile -File ./spikes/stabilization-benchmark/write-clip-manifest.ps1 `
  -OutputDirectory 'C:/benchmark-evidence/run-01'
```

The script creates `clips.manifest.json` with create-new semantics. It refuses an existing report. It rejects linked paths, including junctions or symbolic links in ancestors. Cloud-storage placeholders (OneDrive, Google Drive files-on-demand) are reparse points without a link target and are accepted; hashing them downloads the full file. It does not create or remove directories. A disk write failure can leave a new incomplete report, but cannot overwrite an earlier file.

The manifest uses filenames only, so it can later be reviewed for inclusion at `spikes/stabilization-benchmark/clips.manifest.json` without committing a computer-specific source directory. Review filenames for private information before sharing. Do not commit original footage or local output directories. Future benchmark scripts must resolve the filenames against `KUAIDE_CLIPS_DIR`.

All top-level regular files are candidates, regardless of extension, except hidden or system files such as `desktop.ini`; nested directories are not scanned. A file listed here is not proven to be playable video or a camera original. Format, camera, originality and footage categories remain unknown until later probe or owner evidence. Full hashes identify exact bytes; they do not establish how those bytes were recorded or edited.

Do not change input files or directory links while collection runs. Size and modification time are checked before and after hashing, but this is not a filesystem snapshot. Hashing large footage can take time; cancellation before the final write leaves existing files intact.

Run the offline checks:

```powershell
pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-clip-manifest.ps1
```

The checks create temporary byte fixtures with spaced and Unicode names, invoke the public script in child PowerShell processes and verify hashes, unknown evidence, output guards and the environment requirement. They do not access real footage or prove media validity. They print and preserve the unique temporary results directory for inspection.

## Benchmark harness (WP 1A.1)

`run-benchmark.ps1` runs one engine with one settings file on every clip in `clips.manifest.json` (clips read from `KUAIDE_CLIPS_DIR`). Before starting it checks every clip's size and SHA-256 and that no two clips map to the same output folder, and refuses an output folder inside the repository or the clips directory. It then runs the engine once per clip in its own process with a timeout (`-TimeoutSeconds`, default 1800; the whole process tree is killed). Engine output goes to a log file, not a pipe, so a program the engine leaves running cannot hold the run; engines must still wait for the programs they start. Each clip gets a folder named after its full file name, holding the engine output, a `work` folder, `engine.log` and `result.json` (status, exit code, timeout, run time, output hash, last 20 log lines). After each clip the original is hashed again; if an engine changed it, that clip is marked `input_changed`, the run stops and exits 2. Otherwise the run exits 1 if any clip failed; one failure does not stop the others. `run.json` is written even when the run stops early.

```powershell
pwsh -NoProfile -File ./spikes/stabilization-benchmark/run-benchmark.ps1 `
  -SettingsPath ./spikes/stabilization-benchmark/settings/copy-baseline.json `
  -OutputDirectory 'C:/benchmark-runs/copy-01' -FfmpegPath 'C:/verified-tools/ffmpeg.exe'
```

An engine is `engines/<name>.ps1`. It takes `-InputPath`, `-OutputPath`, `-SettingsPath`, `-WorkDirectory` and `-FfmpegPath`, and exits 0 after writing `-OutputPath`. A settings file is JSON with `engine` and `name`; the engine reads its own options from it. Outputs are MP4 unless the settings say `"output_extension": "same"`. `engines/copy.ps1` copies the input unchanged and is the no-stabilization reference.

`make-synthetic-clips.ps1` makes two test clips in a new folder: `shaken-still.mp4` (one still image panned along a fixed sine path, 4 s) and `hard-cut.mp4` (two different shaken stills joined by a cut at 2.0 s). Point `KUAIDE_CLIPS_DIR` at that folder and run `write-clip-manifest.ps1` to list them.

Check: `pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-run-benchmark.ps1 -FfmpegPath <ffmpeg.exe>`.

Measuring crop and leftover shake is WP 1A.2.

## libvidstab engine and measurement (WP 1A.2)

`engines/libvidstab.ps1` runs FFmpeg's two-pass libvidstab: `vidstabdetect`, then `vidstabtransform` and a libx264 encode, keeping the first audio track as AAC. Its settings files hold `detect` and `transform` option strings, `preset` and `crf`; option strings that name files or add filters are refused. `settings/libvidstab-auto.json` is near-default; `settings/libvidstab-tuned.json` uses stronger detection and about 1 s of smoothing. Both use the Gaussian camera path (`optalgo=gauss`; the default path needs a zoom budget) and keep black borders (`optzoom=0`) so the crop can be measured.

`measure-run.ps1 -RunDirectory <run> -FfmpegPath <ffmpeg>` writes `metrics.json` into a finished run. Both the original and the output are measured in one analysis form: 30 fps, the central 70% of the frame, scaled to 640 px wide, 8-bit.

- `shake_px`: libvidstab's frame-to-frame translation estimate minus a 15-frame (0.5 s) moving average, as RMS analysis pixels. Large original-motion outliers are dropped from both clips (`frames_dropped`); those outliers do not prove cuts.
- `reduction`: output shake / original shake. 1 is unchanged; lower is steadier.
- `frozen_output`: true when the output has over 1 s more frozen picture than the original; such a result is not a real reduction. An output whose frame count differs from the original's by more than 1% is refused.
- `crop_pct`: the share of the frame outside the largest rectangle of the frame's shape that is picture in every frame, for one fixed framing over the whole clip. It comes from the engine's `work/border-union.pgm` through `get-valid-crop.ps1` (`crop_status=geometric_mask`). Byte-identical copies are 0 (`unchanged_bytes`); an engine without that image gives null (`geometric_measurement_unavailable`). `observed_dark_edges_pct` is a diagnostic only.
- `frame_change_ratio`: output / original mean frame-to-frame picture change, which needs no tracking. `shake_score_suspect` is true when shake rises by over 10% but picture change does not.
- `observed_dark_edges_pct`: a diagnostic from `cropdetect`, with black frames skipped and 99th-percentile edges. Dark scenery produces false borders, and rotated black corners may be missed. This number is neither a crop score nor an upper bound; do not use it to rank engines.

Reports carry `measurement_version=4`. Version 1 used a 17-frame window despite labeling it 15 and reported the dark-edge diagnostic as crop; version 2 had no crop for transformed outputs; version 3 had no frame-change check. Rerun measurements before comparing versions.

Limits: the shake estimate uses libvidstab's own translation search, so it may favor libvidstab; rotation and blur are not scored. Dropped outliers do not prove cuts, and moving subjects or lights can affect tracking. WP 1A.4 adds frame reviews. Check: `pwsh -NoProfile -File ./spikes/stabilization-benchmark/test-libvidstab.ps1 -FfmpegPath <ffmpeg.exe>`.
