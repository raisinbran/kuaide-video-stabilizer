# Rules for Agents Working on Kuaide Video Stabilizer

These rules apply to every agent (Claude Code, Codex or any other) and to every subagent. Read this file, [dev-plan/STATUS.md](dev-plan/STATUS.md) and the current phase of [dev-plan/implementation-roadmap.md](dev-plan/implementation-roadmap.md) before doing anything else.

The owner is BJC. The owner is not a software specialist. Explain choices in plain words. Do tasks yourself by default. Give the owner a task only when it is much cheaper in time and credits for a person than for an agent, such as recording footage, a short visual check of video, a sign-in, or a form with personal details. Say why when you hand one over. Ask only about things that change scope, cost, time or what the app does, and give a recommended option. Decide backend details yourself, and record each decision in the current plan's notes as `proposed`.

## ChatGPT Chat delegation and preliminary-work rule (owner approved 2026-10-31)

- Default to ChatGPT Chat for independently executable `cloud-ok` tasks and separable cloud-only parts of mixed WPs. Claude Code remains lead integrator, hardware/desktop executor and final reviewer. Do not assume missing hardware evidence or unresolved Phase 1 decisions.
- **Every ChatGPT-authored change is preliminary.** Commit it to a named task branch; do not push to `main`. Open a draft PR. Claude Code must do a short independent QA of its scope, diff and relevant checks, and issues must be resolved before merge. Owner approval is still required to merge. Keep QA focused on actual risks and bugs, not optional polish.
- Standing permission: ChatGPT Chat may push its `cloud-ok` task branches and open draft PRs for work already approved by the owner. This is not permission to merge, release, alter owner-decided behavior, delete data or exceed task scope.
- **Early cloud work:** A `cloud-ok` task may precede a phase gate only if it does not depend on incomplete tests, undecided implementation choices, or unavailable owner media/hardware. Continue to enforce internal task prerequisites, eventual hardware acceptance tests and final phase approval; early code is not proof that a later phase passed.
- ChatGPT Chat is approved for Phase 4 cloud-only UI work after the owner selects a mockup; the agent-identity stop does not apply to ChatGPT Chat. Real playback and cross-OS approval still need hardware.
- Keep plans, tasks and QA lean. Prefer short relevant tests; when practical, run lengthy independent tests alongside other work rather than serially blocking the project.

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
3. Pushing, opening a PR and merging still need the owner's approval in chat each time, except the bounded ChatGPT Chat branch-push and draft-PR permission above or another standing approval recorded in STATUS.md.
4. Commits and PRs carry no AI attribution lines (personal-dev-env rule).
5. Never use emojis, or the words "canonical" or "contract", in docs, comments, commits or PRs.
6. Generated lockfiles do not count toward the 700-line PR size limit. They must still be committed and reviewed with the manifest changes that generated them.

## Stop-and-ask gates

**Gate 1: UI/UX phase.** Before Phase 4 visual implementation, show the owner 2-3 static layout mockups and obtain a selection. ChatGPT Chat may then do cloud-only UI work with the mock adapter; physical playback checks and Windows/macOS acceptance stay hardware-gated. Other agents without suitable visual tooling hand off that check rather than claiming it passed.

**Gate 2: Long tasks.** Before starting any single task that cannot be paused safely and is expected to take more than 1 hour, stop and ask. Examples: a full benchmark render batch, building FFmpeg from source, a long release build. Tell the owner: the estimated time, whether the task can be split into smaller parts with stable stopping points, and what those parts are. The only exception is an active standing permission in STATUS.md ("Long-task permissions"). Follow its limits, such as an end time or a maximum duration.

**Gate 3: Allowance deadline.** This owner rule applies immediately to all plans and future sessions in Codex and Claude Code. By the time either the five-hour or weekly limit reaches 1% remaining, a current handover document must already be ready and work must already have stopped at a stable stopping point. The 1% threshold is a hard deadline, not the point to begin wrapping up. Begin wrap-up at 5% remaining in either window, or earlier when task size or shared usage needs more reserve. After that trigger, start no new work packages, long commands or delegated tasks; preserve the current work, verify or document failures, provide the handover and stop before the 1% deadline. Maintain a current draft handover during sustained work. Check both limits at session start, before substantial/delegated work, during sustained work and at stable points. In Codex use `get_usage_limits` when available, preferring `rateLimitsByLimitId` and calculating remaining as 100 minus `usedPercent`; use `/status` as a fallback. In Claude Code use `/usage` or the available usage display. Missing values mean unknown, not zero. If an allowance that the executing agent actually consumes cannot be read, report the limitation, start no further work subject to that allowance, and prepare the handover and stable stop. A separate ChatGPT Chat session is not blocked merely because it cannot read Claude Code/Codex allowance counters; it must still honor any limits that apply to itself. Do not bypass push or merge permissions; record any inability to commit or publish. Resume after the applicable allowance refreshes or the owner confirms sufficient allowance.

**Credit refresh bonus.** The owner's credits run on a 7-day cycle. When the usage display shows that the cycle refreshes to 100% within the next 1-2 hours, unused credits would be lost, so you may spend more on extra value. Examples: your own parallel analysis of something the owner is also checking (such as the benchmark's final look), an extra independent review, or extra test runs. Do not start new scope or anything that needs owner approval just because credits are available.

**Gate 4: Scope and risk.** Stop and ask before: changing anything the design brief marks `owner-decided`; adding a feature that is not in the roadmap; choosing an option that adds a lot of work; any merge, release, deletion of owner data, or other hard-to-undo action. Pushing still needs approval except for the bounded ChatGPT Chat task-branch permission above.

**Gate 5: Phase gates.** Each roadmap phase ends with a gate. Do not accept or integrate the next phase until the gate's evidence is recorded in STATUS.md and, where the roadmap says so, the owner approves. Independent early `cloud-ok` work may proceed under the delegation rule above; this does not waive any acceptance gate.

## Stable stopping points

A stable stopping point means all of these are true:

- All work is committed on a named branch, and pushed if the owner has allowed pushing. Nothing important exists only on the local disk.
- The tests for the touched area pass, or the failures are written down in STATUS.md with their output.
- STATUS.md says what was done, what is next, and any open questions for the owner.

Aim for a stable stopping point at least every 1-2 hours of work, and at the end of every WP.

**Machine availability.** STATUS.md lists when each of the owner's computers must be turned off. Reach a stable stopping point, with the handover written and pushed, at least 30 minutes before that time. Do not start a task on that machine that cannot finish 30 minutes before the shutdown time. Gate 2 still applies to anything over 1 hour.

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

## Differences between agents

The plan works with Claude Code and Codex. Where an agent lacks a capability, it uses the fallback below instead of skipping the step:

- **Desktop control** (needed to click Stabilize in DaVinci Resolve): Claude Code in the desktop app can do this with computer use. If your agent cannot control the desktop, finish all scripted Resolve steps, then hand the clicking step to Claude Code with a handover. Only if no Claude Code session is available, ask the owner to do the clicks (about 1 minute per clip).
- **Subagents:** if your agent cannot run parallel subagents, do the parallel WPs one after another in the same order. The results must be the same; only the speed changes.
- **Cloud sessions** cannot reach the owner's drives, Windows/macOS desktop hardware or Resolve. They do `cloud-ok` tasks, including isolated cloud-only parts of mixed WPs, and must defer physical verification.
- **personal-dev-env skills:** read them from GitHub. If your session has no internet access, say so and ask the owner before working without them.
- **Usage checks** (Gate 3): Claude Code shows usage and reset times with `/usage`, and Codex with `/status`.
- **UI/UX phase:** Follow the owner mockup approval and hardware checks in Gate 1; ChatGPT Chat has standing permission for cloud-only UI work after mockup selection.
- **Code quality (owner observation, 2026-10-29):** ChatGPT/Codex code may need extra verification. All ChatGPT changes receive concise Claude Code QA before merge; reserve deeper Claude review for high-risk native code or demonstrated failures. Prefer ChatGPT for independent `cloud-ok` implementation to conserve Claude credits.

## Working rules

- Do all lasting work in this repo. Use only short-lived temporary files outside it, in your session's scratch folder. The owner moves between computers and cloud sessions.
- Never commit video clips or FFmpeg binaries. Clips are listed in manifests with SHA-256 hashes. Test clips live in the owner's Google Drive folder `My Drive/Agentic projects/kuaide-video-stabilizer_temp`. On the Windows PC that is `I:\My Drive\Agentic projects\kuaide-video-stabilizer_temp`. On the Mac, Google Drive for desktop usually mounts it under `~/Library/CloudStorage/GoogleDrive-<account>/My Drive/`. Record the exact Mac path in STATUS.md when first used. Scripts read the folder from the `KUAIDE_CLIPS_DIR` environment variable and never hard-code it. Keep only original clips there. Engine outputs go to a local folder outside the repo and can be deleted after scoring. Binaries are downloaded by scripts in `app/third-party/` that check their checksums.
- Every WP in the roadmap is labelled `cloud-ok`, `needs-windows`, `needs-mac` or `needs-owner`. Cloud sessions do only `cloud-ok` tasks or clearly isolated cloud-only portions of other WPs, without treating the unverified physical portion as complete. Queue the rest in STATUS.md under "Waiting for owner hardware".
- Branch names follow `<type>/<words>`, for example `feat/wp-2-3-job-queue`. Merge with squash merges only.
- Subagents: give each one the WP goal, the folders it owns, the folders it must not touch, an `Applicable skills:` line with exact skill names, test commands, and the report it must return. Parallel subagents never edit the same files. The agent that wrote the code never reviews it.
