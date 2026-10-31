# Geometric crop and the concert clip (WP 1A.2)

Date: 2026-10-30. Follows `2026-10-29-measurement-correction.md`. Reports: `measurement_version=4`. The shake ratios below were reproduced exactly from new runs, matching the version 2 table.

## Crop method

`engines/libvidstab.ps1` moves an all-white copy of the clip with the same motion file and transform options. It merges the borders of all frames into `work/border-union.pgm`. `get-valid-crop.ps1` then finds the largest rectangle with the frame's shape that avoids every border pixel. Dark scenery cannot read as border, and tilted corners count. Checks: a frame without borders gives 0%; a 10% band gives the exact 19%; a frame tilted by 0.1 radian gives 24.7%, which the old border detector scored as full frame.

`crop_pct` is the crop for one fixed framing over the whole clip, so one bad frame sets it for all frames. An engine that changes zoom over time, or a shorter section, would lose less. The mask image is 320 px wide, so results are accurate to about 1% of the frame width.

## Results

Shake is output / original (translation only, lower is steadier). Change is the same ratio for frame-to-frame picture change, which needs no tracking.

| Clip | Original shake (px) | Auto: shake, change, crop | Tuned: shake, change, crop |
|---|---:|---|---|
| 20261030_033123000_iOS.MOV (room walk) | 15.491 | 0.709, 0.934, 27.9% | 0.418, 0.874, 74.1% |
| Caltrain .webm | 1.701 | 0.275, 0.804, 0% | 0.289, 0.839, 9.5% |
| IMG_0225.MOV | 0.183 | 0.514, 0.815, 0% | 0.426, 0.795, 0% |
| Caltrain .mp4 | 1.576 | 1.035, 0.939, 19.8% | 1.098, 0.973, 31.2% |
| 20261019_031753000_iOS.MOV (concert) | 1.9 | 1.727, 0.974, 39.1% | 1.997, 0.969, 36.6% |

Unchanged copies: ratio 1, 0% crop. No output was flagged as frozen.

The tuned room-walk result keeps only 25.9% of the frame, which would not be usable as a fixed crop. That is less than the 49% analysis window, so black border enters the measured area and its 0.418 and 0.874 are affected; do not read them as a clean shake result. Automatic is the more usable result on this clip so far.

Caltrain .webm automatic (0.275 shake with 0% crop) is unexplained and needs a viewing check.

## Concert clip

The contact sheet shows sweeping stage lights, fog, a changing video wall and a moving crowd in the foreground, so few stable features exist for tracking. In 5-second sections the frame-to-frame change of auto and tuned outputs stays at or just below the original (whole clip 8.32 original, 8.10 auto, 8.06 tuned; 21.85, 21.75, 21.87 in the light burst at 20-25 s). Nothing shows the output getting twice as shaky, and moving scenery is a likely cause of the score. This is weak evidence, not proof: picture change is dominated by the scene itself on this clip, and every stabilized output in the table scores below 1, so a ratio of 0.97 says little. Whether stabilization helps this clip needs a viewing check (WP 1A.4). The 36-39% crop suggests that libvidstab also moved the frame a lot in response to the scenery, which does cost picture.

`shake_score_suspect` is a hint: shake rises by over 10% but picture change does not rise. It marks only this clip, under both settings. No test covers its true case.

## Limits

Shake covers translation only; rotation and blur are not scored. Original shake is under 2 px on four of five clips, so only the room walk tests real handheld shake. Picture change is a cross-check, not a score. HDR outputs keep HLG tags in 8-bit H.264 without tone mapping (WP 1C-C).
