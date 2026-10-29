# Rules for Agents Working on Kuaide Video Stabilizer

These rules apply to every agent (Claude Code, Codex or any other) and to every subagent. Read this file, [dev-plan/STATUS.md](dev-plan/STATUS.md) and the current phase of [dev-plan/implementation-roadmap.md](dev-plan/implementation-roadmap.md) before doing anything else.

The owner is BJC. The owner is not a software specialist. Explain choices in plain words. Ask only about things that change scope, cost, time or what the app does, and give a recommended option. Decide backend details yourself, and record each decision in the current plan's notes as `proposed`.

## Standards

Follow [henrico813/personal-dev-env](https://github.com/henrico813/personal-dev-env), pinned at commit `64a2efecd10a7926755d502fb558e7ed424a4626`. Its skills are probably not installed on the machine you are using. Read each needed `ai/skills/<name>/SKILL.md` from GitHub at that commit, or from a temporary clone outside this repo. Do not copy them into this repo.

Load the skills that match the work, as `ai/AGENTS.md` in that repo says:

- Planning a WP: `create-plan`. Reviewing a plan or code: `review-plan`. Implementing an approved plan: `implement-plan`. Phase 1 decision record: `design-doc`.
- Rust code: `rust-development`. Tests: `behavior-focused-testing`. Any source or test change: `code-documentation`.
- Commits and PRs: `git-messages`, `pull-request`. Prose: `plain-direct-english`.
- Running a subagent and reviewing its work: `delegate`.

There is no TypeScript or React skill. For frontend code, apply the same principles: small clear modules, behavior tests, and comments only where they add facts.

### Project adaptations of personal-dev-env

These override the matching personal-dev-env rules for this project only:

1. Plans, design docs, status and handovers live in this repo under `dev-plan/`, not in a vault, so any computer can continue the work. `nobs` is not used.
2. `planner`, `wt`, `vibe` and `pde-gh-write` are usually not installed. If `planner` is missing, the plan check is done by a fresh reviewer agent with `review-plan`. Use plain `git worktree` and `gh` instead of `wt` and `pde-gh-write`.
3. Pushing, opening a PR and merging still need the owner's approval in chat each time, unless STATUS.md records a standing approval that has not expired.
4. Commits and PRs carry no AI attribution lines (personal-dev-env rule).
5. Never use emojis, or the words "canonical" or "contract", in docs, comments, commits or PRs.

## Stop-and-ask gates

**Gate 1: UI/UX phase.** Before starting Phase 4 (UI/UX) work, check which agent you are. If you are not Claude Code, stop and ask the owner how to proceed. Offer these options: (a) prepare handoff documents so Claude Code can run the UI/UX phase, (b) continue with the current agent, (c) pause. For option (a), write `dev-plan/handover/ui-ux-handoff.md` with the handover template below, plus the visual direction, the mock adapter and sample data, and the state of every Phase 4 WP. If you are Claude Code, show the owner the layout mockups first, as the roadmap says.

**Gate 2: Long tasks.** Before starting any single task that cannot be paused safely and is expected to take more than 1 hour, stop and ask. Examples: a full benchmark render batch, building FFmpeg from source, a long release build. Tell the owner: the estimated time, whether the task can be split into smaller parts with stable stopping points, and what those parts are. The only exception is an active standing permission in STATUS.md ("Long-task permissions"). Follow its limits, such as an end time or a maximum duration.

**Gate 3: Low credits.** Check usage at the start of each session and at each stable stopping point. In Claude Code, use `/usage` or the desktop app's usage tool. In Codex, use `/status`. If Claude Code or Codex credits are critically low (below 5% remaining), stop at the next stable stopping point and write a handover document. Do not start new work after that. If you cannot read your usage, assume it may run out at any time, and keep STATUS.md current at every stable stopping point.

**Gate 4: Scope and risk.** Stop and ask before: changing anything the design brief marks `owner-decided`; adding a feature that is not in the roadmap; choosing an option that adds a lot of work; any push, merge, release, deletion of owner data, or other hard-to-undo action.

**Gate 5: Phase gates.** Each roadmap phase ends with a gate. Do not start the next phase until the gate's evidence is recorded in STATUS.md and, where the roadmap says so, the owner approves.

## Stable stopping points

A stable stopping point means all of these are true:

- All work is committed on a named branch, and pushed if the owner has allowed pushing. Nothing important exists only on the local disk.
- The tests for the touched area pass, or the failures are written down in STATUS.md with their output.
- STATUS.md says what was done, what is next, and any open questions for the owner.

Aim for a stable stopping point at least every 1-2 hours of work, and at the end of every WP.

## Handover template

Write handovers to `dev-plan/handover/YYYY-MM-DD-<short-topic>.md`:

```markdown
# Handover: <topic>
Date: YYYY-MM-DD. From: <agent and model>. Reason: <low credits / UI-UX gate / end of session / other>.

## Where things stand
- Phase and WP:
- Branch and last commit:
- Pushed: yes/no

## Done since the last handover

## Next steps (in order)

## Open questions for the owner

## Known problems and failing tests (with commands to reproduce)

## Hardware or owner tasks waiting
```

## Working rules

- Do all lasting work in this repo. Use only short-lived temporary files outside it, in your session's scratch folder. The owner moves between computers and cloud sessions.
- Never commit video clips or FFmpeg binaries. Clips are listed in manifests with SHA-256 hashes. Binaries are downloaded by scripts in `app/third-party/` that check their checksums.
- Every WP in the roadmap is labelled `cloud-ok`, `needs-windows`, `needs-mac` or `needs-owner`. In a cloud session, do only `cloud-ok` work. Queue the rest in STATUS.md under "Waiting for owner hardware".
- Branch names follow `<type>/<words>`, for example `feat/wp-2-3-job-queue`. Merge with squash merges only.
- Subagents: give each one the WP goal, the folders it owns, the folders it must not touch, an `Applicable skills:` line with exact skill names, test commands, and the report it must return. Parallel subagents never edit the same files. The agent that wrote the code never reviews it.
