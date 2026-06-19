<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# launch-your-agent — one-page user guide

Build a **local Claude Code agent** that does a real job for you — research, drafting, analysis, a recurring digest — and (if you want) runs itself on a schedule. **No API key, no cloud, nothing billed per run.** It runs on the Claude Code you're already signed in to.

---

## 1. Install (30 seconds)

```bash
git clone https://github.com/aifunmobi/launch-your-agent.git
cd launch-your-agent
claude
```

Then type `/launch-your-agent`. The skill is picked up automatically — nothing else to set up.

**Want it everywhere on this machine?** Copy both skills into your user skills folder once:

```bash
cp -R .claude/skills/launch-your-agent .claude/skills/wrap-up ~/.claude/skills/
```

Now `/launch-your-agent` works in any directory.

**The only requirement:** Claude Code, installed and signed in. There is no `ANTHROPIC_API_KEY` to create and no `platform.claude.com` step — your Claude Code login is all it uses.

---

## 2. The menu

`/launch-your-agent` opens with a small menu:

| Choose | You get |
|---|---|
| 🚀 **Build a new agent** | A guided interview that scopes and builds an agent from scratch |
| 📋 **Start from a template** | A known-good archetype (data analyst, ops responder, recurring digest, issue→PR, …) pre-filled, then a quick customize |
| 🔧 **Run or check an existing agent** | Run the `my-agent/` in this folder, or see where it stands |
| 📖 **What can this do?** | A 4-line explainer, then back to the menu |

Already know what you want? Skip the menu — say it on the invocation line:
`/launch-your-agent build me a weekly competitor digest`.

---

## 3. What happens (the four phases)

1. **Interview → plan.** A short, friendly back-and-forth: what should it do, what does "done" look like, what does it read, what does it produce, and should it run on a clock. You approve a one-screen **brief** before anything is built.
2. **Materialize & run.** The skill writes your agent as real Claude Code files and **runs it right there** so you watch it work. No credential step, no waiting.
3. **Grade & iterate.** A **local grader** scores the output against your rubric, criterion by criterion. You change one thing, re-run, and watch it improve.
4. **Run without you.** If the job recurs, it's put on a **local schedule** (launchd on macOS, or cron) that runs the agent headless — and fires once by hand so you see it work before trusting the clock.

It closes with `/wrap-up`: a recap of everything you built and the next 1–2 upgrades worth doing.

---

## 4. What you walk away with — a portable `my-agent/` folder

Drop it anywhere, run `claude` in it, type `/<your-agent>`, and it works. Inside:

| File / folder | What it is |
|---|---|
| `.claude/agents/<name>.md` | 🤖 **the agent** — a Claude Code subagent (its instructions are the file) |
| `.claude/agents/<name>-grader.md` | 🎯 **the grader** — scores each run against your rubric |
| `.claude/commands/<name>.md` | ▶️ **`/<name>`** — the command that runs it |
| `.claude/settings.json` | 📦 **permissions** — which tools/sites it may use without asking |
| `outcome.md` | 🎯 your binary **definition of done** |
| `outputs/` · `runs/` | where each run writes its result · the run log (your record) |
| `evals/` | 🧪 held-back test cases + a local run loop |
| `memory/` | 🧠 what it remembers across runs (if it learns) |
| `schedule/` | 🗓️ the launchd plist / cron line (if it's recurring) |
| `agent-overview.html` | a live one-page schema of the whole thing — open it in a browser |
| `NEXT-DIRECTIONS.md` | 🧭 the v1/v2 plan for everything beyond today |

Because the whole agent is just files, it's **version-controlled, inspectable, and yours** — edit the subagent file to change behavior, commit to keep a version, revert to roll back.

---

## 5. Running it later

- **On demand:** `cd my-agent && ./run.sh`, or type `/<name>` in Claude Code, or `claude -p "$(cat first_prompt.txt)"`.
- **On a schedule:** it's already installed (launchd/cron). Check `runs/` for what it's done.
- **Check status / next steps any time:** `/wrap-up`.

---

## 6. Connectors & secrets (optional)

If your agent needs to read or post somewhere behind a login (Slack, Notion, GitHub…), that's a **local MCP connector** plus a token in a local `my-agent/.env` (never in chat, never committed). The default is to **mock** it first — the agent writes the exact message/payload it *would* send to `outputs/` — and wire the real connector later as a planned upgrade. Those tokens are third-party credentials, not an Anthropic API key.

---

*Reference implementation, Apache-2.0. The deeper reference docs live in `local-agent-primitives.md` and `.claude/skills/launch-your-agent/references/`.*
