# Handover: QA of the Codex handoff and merge into main
Date: 2026-10-29. From: Claude Code (Opus 5.5). Reason: end of a stable work package.

## Where things stand
- Phase and WP: Phase 1. Replacement work 1A-R1, 1C-R1 to 1C-R3 and QA-R1 are merged into `main`. Phase 1 gate is open.
- Branch and last commit: `main` at `22726ea` (PRs #1-#6, squash-merged). This record is on `docs/phase-1-merge-record`.
- Pushed: `main` yes; this record branch needs owner approval to push and merge.

## Done since the last handover
- Checked the Codex handoff: every claimed result reproduced. Found six problems; fixed them per `dev-plan/plans/qa-r1-phase-1-handoff-fixes.md` (reviewed by a fresh agent).
- Confirmed the original Phase 1 plans were never pushed; GitHub has no record of them. Rebuilt them in `dev-plan/plans/phase-1-wp-plans.md` at outline level.
- Installed Git for Windows, PowerShell 7.6.9 and GitHub CLI on this laptop; the owner signed Git and `gh` in to GitHub.
- A fresh agent reviewed all PowerShell scripts: no blocking bugs; four findings fixed.
- Merged PRs #1-#6 in order. The STATUS.md conflict in #6 was resolved by keeping `main`'s version.
- On `main`: download test, inventory suite (4), clip-manifest suite (3) and the real smoke all pass; shake ratio 0.09 (limit 0.25).

## Next steps (in order)
1. Pick the next Phase 1 piece from `dev-plan/plans/phase-1-wp-plans.md` and write its exact-code plan with `create-plan`. Recommended: 1B.1 after installing Rust, Node.js and Tauri prerequisites.
2. When the real clips folder is available, run `write-clip-manifest.ps1` once against it and check the Google Drive folder is not rejected as a linked path (open review finding).
3. Optional review findings left: tests for linked-path rejection, the tool-changed check and the smoke failure path; fixture copies for the output-guard tests; Windows short-path guard.

## Open questions for the owner
- Which Phase 1 piece to start next.
- Whether the original Windows PC still has the three unpushed plan branches.

## Known problems and failing tests (with commands to reproduce)
- None failing. The `.zip` rename in the download script runs only during a real 195 MB download and is untested.
- In an old shell, `gh` may report Git missing until the terminal is reopened (PATH refresh).

## Hardware or owner tasks waiting
- Extra benchmark clips (STATUS.md "Owner tasks"). Mac availability and clips path.
