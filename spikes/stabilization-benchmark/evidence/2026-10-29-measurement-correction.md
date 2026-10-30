# WP 1A.2 measurement investigation

Date: 2026-10-29 (Pacific time). Starting commit: `d2b016c` on `feat/wp-1a-2-libvidstab`.

## Findings

The previous crop number measured brightness boundaries, not geometric image loss. On unchanged, byte-identical copies, the existing method reported the following values. Running its same calculation with only the cropdetect limit changed produced:

| Clip | Limit 24 | Limit 16 | Limit 1 |
|---|---:|---:|---:|
| 20261019_031753000_iOS.MOV | 42.66% | 0% | 0% |
| 20261030_033123000_iOS.MOV | 29.01% | 0% | 0% |
| Caltrain - Brisbane to SSF.mp4 | 8.91% | 0% | 0% |

Frame inspection showed dark picture content at the iPhone frame edges. The concert clip contains moving lights and people; the room clip contains dark furniture and a moving camera. A different threshold does not establish crop correctness. The source threshold therefore remains unchanged, and its result is now labeled `observed_dark_edges_pct`.

Independent review also demonstrated the opposite error: a rotated white rectangle with black corners yields a full-frame cropdetect box. The diagnostic is not an upper bound on required crop.

```powershell
& $ff -hide_banner -nostdin -f lavfi `
  -i 'color=white:s=320x180:r=30:d=0.2' `
  -vf 'rotate=0.1:fillcolor=black,cropdetect=limit=24:round=2:reset=1' `
  -f null -
```

Observed in the independent review: `crop=320:180:0:0`, despite the rotated corners.

The residual-motion calculation used `[int](15/2)`, which PowerShell rounds to 8. Inclusive bounds therefore used 17 frames. Version 2 uses a seven-frame radius and the intended 15-frame interior window. Both ends of a clip still use the available shorter window.

## Caltrain interpretation

Contact sheets sampled every five seconds show different Google Earth renderings and edits. The MP4 also contains live-action footage near its end. Their whole-clip scores cannot isolate a frame-rate effect. Both streams report 1280x720 and 60/1 for nominal and average frame rate. This does not establish whether either contains duplicated frames.

Reproduce a contact sheet locally, using the original file path as `$clip` and a new temporary destination as `$image`:

```powershell
& $ff -v error -nostdin -n -i $clip `
  -vf 'fps=1/5,scale=320:-2,tile=4x3' -frames:v 1 $image
```

No clip images or private source-folder paths are committed. A matched-source frame-rate test would need to derive both variants from one original.

## Correction and verification

- `crop_pct` reports zero added crop only after current input and output SHA-256 hashes match. Other outputs report `null` and `crop_status=geometric_measurement_unavailable`.
- `observed_dark_edges_pct` preserves the old brightness diagnostic for investigation. It is not suitable for engine ranking.
- Reports now carry `measurement_version=2`; old shake numbers must be remeasured before comparison.
- Before editing: `test-libvidstab.ps1 -FfmpegPath <pinned ffmpeg>` passed all six behavior groups. This showed the old suite missed the demonstrated crop problems.
- After editing: the same command passed all seven groups. The new dark-edge and rotated-output cases preserve unavailable crop. Copy, stabilization, unsafe-option refusal, frame-rate, frozen-output and missing-frame checks also passed. The synthetic auto output measured 38% of its original translation shake in this run.
- A fresh Codex reviewer approved the bounded correction and retained both added scenarios. `git diff --check` passed. Claude Code review has not occurred.
- The optional local commit-message checker and Python commands were absent from PATH. Commit text is checked manually against the loaded `git-messages` rules.

## Remaining work

Geometric crop remains unfinished. A future transform-mask method must find an all-valid interior rectangle and account for rotated corners, frame geometry and timing. Applying cropdetect to a white mask alone is insufficient.

The shake measure tracks translation with libvidstab, excludes large original-motion outliers and does not score rotation or blur. Moving subjects and lights can affect it. The concert clip's increased score remains an unresolved quality result; these observations do not prove its cause. Gyroflow, Resolve comparisons and the Phase 1 engine decision remain open.

## Version 2 real-clip results

Remeasurement is in progress. Original hashes and retained output hashes matched the manifest and previous run records before measurement. Earlier reports were preserved, and new reports use separate run directories with read-only use of linked output files.
