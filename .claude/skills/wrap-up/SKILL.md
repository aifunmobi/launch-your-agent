---
name: wrap-up
description: Close out (or revisit) a LOCAL agent build — regenerate the overview page, recap every primitive the founder now owns, show the run log, suggest 1–2 tailored local upgrades, and sweep hygiene (no literal dates in the scheduled task, any .env locked down and gitignored, a golden eval case saved). Use when the founder says "/wrap-up", "wrap up", "close it out", "where do things stand with my agent", or at the end of a /launch-your-agent build.
version: 1.0.0
dependencies: A `./my-agent/` folder from /launch-your-agent. No API key needed.
---

<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Wrap-up — celebrate it, show what they built, point at what's next

You are closing out (or checking in on) a founder's local Claude Code agent. The tone is **celebratory**: they just built an agent that runs on their own machine, on their existing Claude Code login, with no API key — say so, warmly, in one or two sentences ("🎉 you've shipped a local agent — here's what you built"), then show them what they own and the one or two upgrades worth doing next. End on the overview page, not a wall of text. This is a moment, not a checklist read-out.

Follow the same voice rules as `/launch-your-agent`: warm, compact, tables for anything enumerable, primitives called by their real names (Agent/subagent, Outcome, Run, Schedule, Memory) with a plain gloss on first use, the shared emoji shorthand (🤖 agent · 📦 environment · 🎯 outcome · ▶️ run · 🗓️ schedule · 🔌 connector · 🔐 secrets · 🧠 memory · 🧪 evals · 🧭 next directions), no unverified timings.

## 1. Read the state

- Read `./my-agent/`: `build-sheet.json`, `.claude/agents/` (the 🤖 subagent + the 🎯 grader), `.claude/commands/` (the ▶️ `/<name>` slash command), `.claude/settings.json` (📦 permissions + any 🔌 MCP servers), `outcome.md`, `evals/`, `runs/`, the existing `agent-overview.html`, and `schedule/` if present. (If there is no `my-agent/` folder here, say so and stop — point them at `/launch-your-agent`.)
- There's no key to source and no live API to refresh — **live status is just reading the local artifacts**. The run history is `runs/` (one markdown file per run); the latest deliverables are in `outputs/`. If the agent is scheduled, read `schedule/` plus the installed `launchd` plist / `crontab` line and tail its log to confirm whether it last fired (shapes: `../launch-your-agent/references/local-runtime.md`). Parse `build-sheet.json` with python (`strict=False`), never jq.
- Not scheduled → the interface is `run.sh` / the `/<name>` command; "live status" is whatever's in `runs/`.
- Nothing built yet → wrap the plan only; everything below still applies but the status is "○ Planned".

## 2. Produce the wrap-up (in this order)

1. **Congratulate them.** One or two warm sentences: they built a local agent that runs on their own machine with no API key — name it, say what it now does on its own. 🎉
2. **Overview page.** Regenerate `agent-overview.html` (template: `../launch-your-agent/references/overview-template.html`) from `build-sheet.json` + the local artifacts: the run log from `runs/`, eval verdicts from `evals/`, the schedule with its human-readable cadence and the launchd/cron mechanism, and the v1/v2 next directions. **No Console links** — every "where it lives" points at a path inside `my-agent/`. **Open it in their browser** — the page is the closing artifact; the chat below just points at it.
3. **"Here's what you built"** — the primitives recap table, one row per local primitive that now exists: emoji · what it is (one plain sentence) · what it's set to · **where it lives in `my-agent/`** · which card on the page shows it. The rows are the LOCAL primitives:

   | | primitive | where it lives in `my-agent/` |
   |---|---|---|
   | 🤖 | agent (a Claude Code subagent) | `.claude/agents/<name>.md` |
   | 📦 | environment (machine + settings) | `.claude/settings.json` + `environment.md` |
   | 🎯 | outcome (rubric + local grader) | `outcome.md` + `.claude/agents/<name>-grader.md` |
   | ▶️ | runs | `runs/` (+ the `/<name>` command and `run.sh`) |
   | 🗓️ | schedule (cron / launchd) | `schedule/` (the plist + crontab line) |
   | 🔌 | connector (local MCP) | the `mcpServers` in `.claude/settings.json` (or `.mcp.json`) |
   | 🧠 | memory | `memory/` |
   | 🧪 | evals | `evals/` (cases + `run-evals.sh`) |

   Final muted row(s) for primitives deliberately not used → "see NEXT-DIRECTIONS". Follow with the run log table (run · rubric version · verdict · one-line note), read straight from `runs/`.
4. **"Here's what's next"** — 1–2 extensions picked from the v1/v2 plan that matter most for *this* use case, pitched concretely: what it does for them, what it takes, how small the change is. The rest of the plan stays written down. Standard local candidates to weigh alongside whatever the plan already holds: **wire a mocked connector for real** (add the MCP server to `settings.json` + a token in `.env`, keep it gated so they confirm each action); **add a `memory/` folder** if runs repeat themselves; a **generated local HTML viewer** Claude Code builds in a follow-up session that reads straight from `outputs/` + `runs/` so they can browse results without opening files; and **tighten `settings.json` permissions** (e.g. allow `WebFetch` only on the domains the task actually needs, deny the rest).
5. **Hygiene sweep — quiet by default.** Do the sweep and **fix silently what you can**: no literal dates in the scheduled task (the kickoff/`first_prompt.txt` should say "today" / "the last 7 days", never a hard-coded date that goes stale); if a third-party connector is wired, `.env` is `chmod 600` and listed in `.gitignore`; and if there's no golden eval case yet, save a passed run's output as `evals/case-01/expected.md`. Only mention something if it's materially relevant — i.e. the founder must act (a secret that touched chat → rotate it; a literal date you can't patch without their say-so) or it changes how they use the agent. No "✅ all good" lists.
6. **Last words** — one short line: everything lives in this portable `my-agent/` folder — drop it on any machine with `claude` and re-run it via `LAUNCH.md`; there's no Console and nothing billed; and they can rerun `/wrap-up` whenever they want a fresh picture.

## Notes

- Idempotent: running it again just refreshes the page and tables from the current state of `my-agent/`.
- Don't re-litigate design decisions here — this skill reports and suggests; changes go through `/launch-your-agent` (or a plain conversation) afterwards.
