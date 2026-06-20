<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# launch-your-agent

A [Claude Code](https://code.claude.com) skill that helps a technical founder build whatever they want as a **local Claude Code agent** — an internal worker, a piece of their product, a customer-facing agent. It interviews you about what you want to build, scopes a v0, materializes it as Claude Code primitives on your own machine, runs it, grades it against your own definition of done, iterates, and (if it should run on a clock) puts it on a local cron/launchd schedule — with everything bigger laid out as an explicit v1/v2 plan.

The agent runs inside the Claude Code you're already signed in to — no separate Anthropic API key to manage, nothing billed per run. (One nuance on the headless/scheduled path — see [What you need](#what-you-need).)

> **Fork note.** This is a community fork of [`anthropics/launch-your-agent`](https://github.com/anthropics/launch-your-agent), reworked to run **entirely locally with no Anthropic API key**. The *upstream* repo builds a cloud Claude Managed Agent and **does** require a key you create at platform.claude.com — so if a page tells you to make an API key, you're reading the original, not this fork.

> Reference implementation, adapted. Licensed under [Apache 2.0](./LICENSE).

**New here?** [`USER-GUIDE.md`](./USER-GUIDE.md) is a one-page walkthrough: install → menu → build → run → schedule.

## Install (one line)

Clone it and install both skills into your user skills folder so `/launch-your-agent` works in **any** directory:

```bash
git clone https://github.com/aifunmobi/launch-your-agent.git && mkdir -p ~/.claude/skills && cp -R launch-your-agent/.claude/skills/launch-your-agent launch-your-agent/.claude/skills/wrap-up ~/.claude/skills/
```

Then open Claude Code anywhere and type `/launch-your-agent`. (No API key — it runs on your existing Claude Code login.)

## Quickstart (no install)

Prefer to just try it in the repo folder? The skills in `.claude/skills/` are picked up automatically when you run Claude Code inside it:

```bash
git clone https://github.com/aifunmobi/launch-your-agent.git
cd launch-your-agent
claude
```

Then type:

```
/launch-your-agent
```

You'll get a small **menu** — build a new agent, start from a template, run/check an existing one, or just see what this does — then it takes you from there. (Already know what you want? Say it on the same line, e.g. `/launch-your-agent build me a weekly competitor digest`, and it skips straight to building.)

When you're done (or any time later), `/wrap-up` regenerates the overview page, recaps every primitive you now own, and suggests the next 1–2 upgrades.

## What you need

- **Claude Code, installed and signed in.** That's it. The agent runs on your existing Claude Code login (subscription or whatever login you already use).
- **No Anthropic API key.** Nothing to create at platform.claude.com, no key to paste into the chat. Your Claude Code login is not an "API token" and we never ask for one.
- **Nothing billed per run.** There's no per-run cost — the agent uses the session you already have.

(If your design eventually wants a *third-party* connector — say a Slack token — that's a separate, optional thing. It lives in a local `.env`, it is not an Anthropic key, and the default is to mock it until you choose to wire it.)

> ⚠️ **One caveat, on the headless/scheduled path only.** Unattended runs (`claude -p`, cron/launchd) draw from your subscription *today*, but this is the path to watch: Anthropic announced (May 2026) then **paused (June 15)** a change that would bill Agent-SDK/headless usage separately at API rates — paused, not cancelled — and a current Claude Code bug bills headless runs as API usage if an Anthropic key/token is set in your environment ([#43333](https://github.com/anthropics/claude-code/issues/43333), [#37686](https://github.com/anthropics/claude-code/issues/37686)). So: this fork **never creates or installs an Anthropic key**, and every generated agent ships a guard (`no-api-key-guard.sh`) that **stops any unattended run** if it finds one. Interactive `/<name>` runs are unaffected. After a scheduled run, confirm it shows up on your subscription, not the API dashboard at `platform.claude.com`.

## What you walk away with

A portable `my-agent/` folder you can drop anywhere Claude Code runs — `cd` into it, run `claude`, and `/<name>` works. It contains:

- the **agent** — a Claude Code subagent (`.claude/agents/<name>.md`);
- its **local grader** — a grader subagent that scores each run against your rubric;
- a **`/<name>` slash command** that runs the agent on the task;
- an **outcome rubric** (`outcome.md`) — your binary definition of done;
- an **eval scaffold** (`evals/`) — held-back cases plus a local run loop;
- a **`runs/` log** — one markdown file per run (this is your record; there's no Console);
- a live **overview page** (`agent-overview.html`);
- a **`NEXT-DIRECTIONS.md`** laying out v1/v2;
- and, if the task recurs, a **local cron/launchd schedule** that runs the agent headless on a clock.

## Repo layout

| Path | What it is |
|---|---|
| `USER-GUIDE.md` | One-page walkthrough: install → menu → build → run → schedule |
| `.claude/skills/launch-your-agent/` | The main skill: 4 phases (interview → materialize & run → grade & iterate → run without you), preceded by a Phase 0 menu, + `references/` (interview mapping, local runtime command shapes, examples bank, mock connectors, overview template, example build sheet) |
| `.claude/skills/launch-your-agent/references/interview.md` | How interview answers map to local Claude Code primitives |
| `.claude/skills/launch-your-agent/references/local-runtime.md` | Verified Claude Code command shapes: subagent files, slash commands, `settings.json` permissions, headless `claude -p`, `run.sh`, scheduling |
| `.claude/skills/launch-your-agent/references/examples-bank.md` | Sourced example agents and known-good config shapes |
| `.claude/skills/launch-your-agent/references/mock-connectors.md` | The outbox pattern for mocking connectors until you wire them |
| `.claude/skills/launch-your-agent/references/overview-template.html` | Template for the live-schema overview page |
| `.claude/skills/launch-your-agent/references/build-sheet.example.json` | Worked example build sheet (byte-identical to `ui/build-sheet.example.json`) |
| `.claude/skills/wrap-up/` | Companion skill: explicit close-out / status check for a built agent |
| `local-agent-primitives.md` | Inventory of the local Claude Code primitives this skill builds on: subagents, slash commands, `settings.json`/permissions, project skills, local MCP, headless `claude -p`, cron/launchd scheduling, the local grader pattern, file-based memory |
| `ui/` | Example overview page + build sheet |

For the Claude Code primitives themselves, see the subagent and settings docs: https://docs.claude.com/en/docs/claude-code/sub-agents and https://docs.claude.com/en/docs/claude-code/settings
