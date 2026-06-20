<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Local Claude Code Agent — Features & Primitives Inventory

> Source: how Claude Code is configured and run on the founder's own machine, verified 2026-06-14.
> Truth order if anything here drifts: **the real Claude Code behavior on the machine wins** over this file.
> This is the design substrate for the "launch your agent in ~60 min" skill.

## What a local agent is

A **portable folder you run with the Claude Code you're already signed into**. You define an agent (a subagent: model + system prompt + tools), Claude Code runs the agent loop, tool execution, and file I/O **on your own machine**, inside the session you already have. The alternative is doing the work by hand in chat every time. A local agent is for **repeatable, gradeable, schedulable** work.

- **No API key:** the agent runs on your **existing Claude Code login** (subscription or whatever sign-in you already use). There is no `ANTHROPIC_API_KEY`, no key to create, no key to hand over. Nothing is billed per run.
- **Where it lives:** a single `my-agent/` folder. Everything that makes the agent an agent — the subagent file, the grader, the slash command, the permissions — lives in `my-agent/.claude/`. Drop the folder anywhere Claude Code runs, type `claude`, and `/<name>` works. That portability is the local equivalent of "it keeps working after the session."
- **Two surfaces:** **interactive** (`claude` in the folder, then `/<name>`) and **headless** (`claude -p "<prompt>"`, non-interactive, same signed-in session). A scheduler runs the headless surface on a clock.
- **Observability is the filesystem:** `runs/` (one markdown log per run), `outputs/` (the deliverables), and `agent-overview.html` (the live-schema page). There is no separate dashboard — the folder *is* the record.

---

## The core primitives

| Primitive | What it is locally | Where it lives |
|---|---|---|
| **🤖 Agent** | A Claude Code **subagent**: model + system prompt + allowed tools, "versioned" by git | `.claude/agents/<name>.md` |
| **📦 Environment** | Your machine + Claude Code permissions: installed tools/libs + the networking allow-list + tool gating | `environment.md` + `.claude/settings.json` |
| **▶️ Run** | One invocation of the agent: typing `/<name>`, or one headless `claude -p` run; logged as a file | `runs/<date>.md` |
| **🎯 Outcome** | A rubric (3–6 binary criteria) graded by a **local grader subagent** in its own context | `outcome.md` + `.claude/agents/<name>-grader.md` |

Minimal launch = write the subagent file → set permissions in `settings.json` → invoke `/<name>` (or `run.sh`) → the agent runs the loop, executes tools, writes the deliverable to `outputs/`, and the grader scores it against `outcome.md`.

---

## 🤖 Agent (a subagent)

A subagent is a single markdown file: **YAML frontmatter** on top, the **system prompt as the markdown body** below.

```markdown
---
name: competitor-digest
description: Researches the 5 named competitors and writes a weekly digest to outputs/digest.md
tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
model: inherit
---

You are Acme Analytics' competitor-research agent. Each run, research the five named
competitors' public sites, pricing pages, and changelogs, and write this week's digest to
outputs/digest.md. Never contact anyone or post anywhere — research and drafting only.
Never present a guess as a fact; mark anything unverified.
```

- **Frontmatter fields:** `name`* (the `/<name>` and `@<name>` handle), `description`* (when Claude should reach for it / what it does), `tools` (comma-separated — **omit to inherit all** of the session's tools), `model` (`sonnet` / `opus` / `haiku` / `inherit`). (*required)
- **model:** `inherit` uses the model your Claude Code session is already signed into — no key, no per-run cost. Pin `opus` or `sonnet` only if a step genuinely needs a different one.
- **Where it lives:** **project** subagents live in `.claude/agents/` (shipped in the portable folder); personal ones can live in `~/.claude/agents/`. Project agents win on name collisions.
- **"Versioning" = git.** Every change to the subagent file is a commit. `git log` is the version history; `git revert`/`git checkout` is the rollback. There is no version number to pass and no concurrency guard — just the file and its history.
- **How it's invoked:** Claude Code can delegate to it automatically (description match), you can call it explicitly (`@competitor-digest …`), the `/<name>` slash command runs it, or `claude -p --agent <name>` / `run.sh` runs it headless. Each invocation runs in its **own context window**, isolated from the main session.

---

## 📦 Environment (your machine + Claude Code settings)

Two parts: **what's installed** (the machine) and **what the agent is allowed to do** (the permissions).

**What's installed** is captured in `environment.md` — the runtimes and libraries the task needs plus the one-line install. For the competitor digest that's `python3 with requests` (`pip install requests`). Anything the agent shells out to (pandoc, openpyxl, a CLI) is listed here so the folder is reproducible on another machine.

**What the agent is allowed to do** is the `permissions` block in `.claude/settings.json` — the local "networking allow-list + tool gating." Three arrays of rules:

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(python3 run.py)",
      "WebFetch(domain:competitor-a.com)",
      "WebFetch(domain:competitor-b.com)",
      "Read(./**)",
      "Write(./outputs/**)"
    ],
    "ask":  [ "Bash(rm:*)" ],
    "deny": [ "WebFetch", "Read(./.env)" ]
  }
}
```

- **`allow`** — runs without prompting. **`ask`** — pauses for your confirmation. **`deny`** — never runs (and overrides `allow`).
- **Rule shapes:** `Bash(<cmd>)` (exact or prefix with `:*`), `WebFetch(domain:<host>)`, `Read(<glob>)`, `Write(<glob>)`, or a bare tool name for the whole tool. A trailing `WebFetch` in `deny` with specific domains in `allow` is the least-privilege networking pattern: only the competitor domains are reachable; everything else asks or is denied.
- **Settings precedence:** enterprise/managed → command-line flags → local project (`.claude/settings.local.json`, gitignored) → shared project (`.claude/settings.json`, committed) → user (`~/.claude/settings.json`). The folder ships the *shared* project settings so the allow-list travels with it.
- **No sandbox container, no package manager run order, no `allow_mcp_servers` toggle.** It's your machine; `environment.md` documents what to install, and `settings.json` decides what the agent may touch.

---

## ▶️ Run

One run = one invocation of the agent end-to-end.

- **Interactive:** `claude` in the folder, then type `/<name>`. Simplest path during the build — you watch it work in the same session.
- **Headless:** `claude -p "<prompt>"` runs non-interactively using the **existing signed-in session — no separate API key**. This is what a scheduler calls. `run.sh` wraps it: hand the agent `first_prompt.txt`, write the deliverable to `outputs/`, then grade. (`run.sh` sources `no-api-key-guard.sh` first, so it stops rather than silently bill as API if a key is set — see Headless mode below.)
- **The task / kickoff** is the prompt text in `first_prompt.txt` — the local equivalent of the kickoff message. Keep **relative dates only** ("today", "the last 7 days") so a scheduled run is correct whenever it fires.
- **Each run is logged** to `runs/<date>.md` — what was asked, what the agent did, where the deliverable landed, the grader verdict. The `runs/` folder is the history (this replaces any external dashboard).
- **No statuses to poll, no checkpoints to keep alive, no `usage` token accounting.** A run finishes when the agent stops; the record is the files it left behind.

---

## 🎯 Outcome (rubric + local grader)

This is what turns "the agent did something" into "the agent did the *right* thing." Two pieces:

**`outcome.md`** — the rubric: 3–6 **binary** criteria, each independently checkable. For the digest:

```markdown
# Outcome: this week's competitor digest (outputs/digest.md)
- [ ] digest.md exists and covers all 5 competitors listed in the task
- [ ] Each competitor has a pricing line and a "what changed since last week" line
- [ ] Every claimed change cites the source URL it came from
- [ ] Anything unverified is explicitly marked, not stated as fact
- [ ] The digest is ≤ 1 page and leads with the most material change
```

**The grader subagent** — `.claude/agents/<name>-grader.md` — reads the deliverable and the rubric in its **own context window** (isolated from the agent that produced the work, so it doesn't rubber-stamp its own choices) and returns a **per-criterion verdict**: criterion | pass/fail | evidence. Claude Code grades **locally**; there is no server grader.

```markdown
---
name: competitor-digest-grader
description: Grades outputs/digest.md against outcome.md and returns a per-criterion verdict
tools: Read, Grep, Glob
model: inherit
---

Read outcome.md and outputs/digest.md. For each rubric criterion, return PASS or FAIL with
one line of evidence (a quote or a missing-item note). Do not fix anything. End with an
overall verdict and, if any criterion failed, the single most important thing to change.
```

- **The grade→fix loop** is bounded by `max_revisions` (the local equivalent of an iteration cap, default 3): run → grade → change ONE thing → re-run, up to the cap. Sharpening `outcome.md` is free; editing the subagent's instructions or tools is a new git-tracked version.
- **One outcome per agent**, but you can re-point `first_prompt.txt`/`outcome.md` to chain follow-on work.
- **Verdicts live in the run log** (`runs/<date>.md`) and, for the held-back cases, in `evals/results-v<N>.md`.

---

## 🛠️ Tools (Claude Code built-ins)

The subagent's `tools:` line declares which built-ins it may use; **omit the line to inherit all** of them.

| Tool | What it does |
|---|---|
| `Bash` | Run shell commands (gated by `settings.json` `Bash(...)` rules) |
| `Read` | Read a file |
| `Write` | Write a new file / overwrite |
| `Edit` | Exact-string edit of an existing file |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `WebFetch` | Fetch a URL's content (gated by `WebFetch(domain:...)` rules) |
| `WebSearch` | Search the web |

- **Gating vs. enabling are two layers:** `tools:` decides which tools *exist* for the agent; `settings.json` `permissions` decides which specific *invocations* run without asking. A digest agent has `WebFetch` in `tools:` but only the competitor domains in `allow`.
- **Local MCP tools** (see Connectors) show up as additional tools named `mcp__<server>__<tool>`; add them to `tools:` and to `permissions` to use them.
- There is no "toolset version," no custom-tool round-trip protocol, no auto-spill-to-sandbox — large output just goes to a file you choose.

---

## 📄 Document output (local libraries) & project skills

When the deliverable is a real document, the agent **runs a local library via `Bash`** rather than calling a hosted document skill:

| Format | Local mechanism (run via `Bash`) |
|---|---|
| **xlsx** | `openpyxl` / `pandas` |
| **docx** | `python-docx` |
| **pptx** | `python-pptx` |
| **pdf** | `pandoc` / `weasyprint` / `md-to-pdf` |

- Whatever the agent needs is listed in `environment.md` with its install line, so the folder reproduces.
- A reusable house format (e.g. "Acme's branded weekly-digest PDF") can be packaged as a **project skill**: `.claude/skills/<name>/SKILL.md` (frontmatter `name` + `description`, body = the procedure, plus any helper scripts/templates alongside). The agent invokes it on demand the same way Claude Code reaches for any skill. Project skills ship inside `my-agent/`, so the house format travels with the folder.

---

## 🔌 Connectors (local MCP) & 🔐 secrets (local `.env`)

When the agent needs to reach a third-party system (Notion, Slack, a database), wire a **local MCP server** — a process on your machine that Claude Code talks to.

- **Declare it** in `my-agent/.claude/settings.json` (or a `.mcp.json` in the folder): the server's command/URL and how to launch it. Its tools then appear as `mcp__<server>__<tool>` — add them to the subagent's `tools:` and to `permissions` (default any new connector to **`ask`** so it can't act unapproved).
- **Secrets live in `my-agent/.env`** — `chmod 600`, listed in `.gitignore`, **never pasted into chat**. This is the *only* secret-hygiene line that applies: third-party connector tokens (a Slack token, a Notion token) go in `.env`. There is no Anthropic vault and no Anthropic key, so there is nothing else to register, refresh, or rotate.
- **Default is still to mock.** If a connector isn't wireable right now, the agent writes to an **outbox** (e.g. `outputs/outbox/slack-message.md`) instead of sending — the deliverable is real, the side effect is staged for later. Promoting a mock to a live connector is a NEXT-DIRECTIONS item: add the MCP server + a token in `.env`, keep it gated.

For the digest, v0 uses **public web only** (no MCP, no secrets). Next step in the example: a local Notion MCP server + a token in `.env` to read the internal strategy page.

---

## 🧠 Memory (a local folder)

Without memory, every run starts fresh. With it, run #10 is smarter than run #1.

- **It's just a folder:** `my-agent/memory/`, markdown files the agent reads and writes with the normal `Read`/`Write`/`Edit` tools — exactly like Claude Code's own file-based memory.
- **Access is a convention, enforced by instructions + permissions.** A `read_write` store (e.g. `memory/competitor-history/`) is where the agent records last week's snapshot per competitor so each run reports *changes*, not re-descriptions. A `read_only` reference folder is one the agent's instructions tell it never to edit (and `settings.json` can back that up with a `deny` on `Write` to that path).
- **No size caps, no per-write versioning, no audit log to manage** — it's the filesystem, so `git` is your history and your restore. Keep many small focused files; treat any folder fed by untrusted input as a prompt-injection surface and prefer `read_only` for reference material.

---

## 🗓️ Schedule (local cron / launchd)

"Runs without you" = a local scheduler firing the headless agent on a clock. No cloud deployment, no deployment id.

- **launchd (macOS, lead option):** a plist at `~/Library/LaunchAgents/<label>.plist` with `StartCalendarInterval` that runs `claude -p` (via `run.sh`) in the folder. For the digest: `com.acme.competitor-digest`, Mondays at 7:00 AM Pacific.
- **crontab (portable option):** `crontab -e` → `0 7 * * 1 cd /path/to/my-agent && ./run.sh` (5-field POSIX cron, minute granularity). Cron caveats that still bite: it runs with a **bare environment** (set `PATH` so `claude` is found, use **absolute paths**), and it fires on the machine's **local wall-clock** (DST shifts the real time — avoid 1–3 AM or pin to UTC if that matters).
- **Claude Code's own `/schedule`** is offered as the **native alternative** — it registers the recurring run for you without hand-editing a plist or crontab. (Depending on the setup it may run as a managed/cloud routine rather than purely on-machine; `launchd`/`cron` is the route that keeps execution fully local and key-free.)
- **Test it once, manually.** After installing the schedule, trigger one run by hand (`./run.sh`, or `launchctl start <label>`) so the founder sees it fire and the run lands in `runs/` — before trusting the clock.
- **Event-driven** work uses a small local trigger script (named in NEXT-DIRECTIONS) instead of a clock; **on-demand** work just uses `run.sh` / the slash command, and the test is that it re-runs cleanly from a fresh terminal.

The schedule artifacts (plist + the crontab line) live in `my-agent/schedule/`, created only when the agent is recurring.

---

## Headless mode (`claude -p`)

The non-interactive surface — what `run.sh` and the scheduler call.

```bash
claude -p "$(cat first_prompt.txt)"
```

- Uses the **existing signed-in Claude Code session. No separate API key, nothing billed per run** — *as long as no Anthropic credential is in the environment.*
- **⚠️ Billing caveat for this path.** Two things make the headless/scheduled path the exposed one: (1) Anthropic announced (May 2026) then **paused (June 15, 2026)** a change that would bill Agent-SDK/headless usage separately at API rates — paused, not cancelled, with advance notice promised; and (2) a current bug bills headless runs as **API usage** if `ANTHROPIC_API_KEY`/`ANTHROPIC_AUTH_TOKEN` is set (anthropics/claude-code #43333, #37686). Mitigation: every generated agent ships `no-api-key-guard.sh`, which `run.sh`/`run-evals.sh`/the scheduled job source before any `claude` call — it stops the run if a key/token is present in the env or written into `.env`/`settings.json`. After an unattended run, verify it landed on your subscription, not the API dashboard at platform.claude.com.
- Useful flags to reach for (describe the capability if a flag name has drifted):
  - `--permission-mode` — how it handles permission prompts in a non-interactive run (so a scheduled run doesn't block waiting for a confirmation).
  - `--allowedTools` — restrict the run to a specific tool set, on top of `settings.json`.
  - `--output-format` — plain text vs. structured (JSON) output, handy for capturing into `runs/`.
  - `--append-system-prompt` — bolt extra instructions onto the run without editing the subagent file.
  - `--agent <name>` (select a subagent you've defined in `.claude/agents/`) / invoking it by name in the prompt — run *this* agent (and its grader) headless. (The plural `--agents` is a different flag that *defines* inline agents from JSON.)
- Pair these in `run.sh`: invoke the agent on `first_prompt.txt`, capture output to `runs/<date>.md`, then invoke the grader subagent on the deliverable + `outcome.md` and append its verdict.

---

## Evals (the local loop)

- `evals/` holds **case folders** — each with an input and an `expected.md` — plus `run-evals.sh`.
- `run-evals.sh` is the local loop: for each case, run the agent on the input, run the grader, collect verdicts into `evals/results-v<N>.md`.
- **No golden set yet?** Save the first human-verified output as `evals/case-01/expected.md` and grow the set from there.
- **Before promoting a new agent version to the schedule:** run `evals/run-evals.sh` against the new subagent file and promote only when the verdicts hold.

---

## ⚠️ Notable constraints

- **Scheduling is local** — a launchd plist or crontab line running `claude -p`, not a hosted cron (Claude Code's `/schedule` is the convenience alternative). The machine has to be on (or the schedule has to live on a box that is). That's the real trade vs. a cloud worker.
- **The signed-in session is the budget.** There's no per-agent spend cap to set and nothing billed per run; the limit is whatever your Claude Code plan already gives you. **One exposure:** the headless/scheduled path bills as API usage if an Anthropic key/token is in the environment, and Anthropic has a paused-for-now plan to bill that path separately. `no-api-key-guard.sh` (sourced by every unattended runner) stops a keyed run; the residual risk is the deferred policy change, so keep an eye on Anthropic's billing notices.
- **Permissions are the guardrail.** Least-privilege networking (`deny` bare `WebFetch`, `allow` only the needed domains), `ask` on destructive `Bash`, and `read_only` memory are the local equivalents of safety rails — set them in `settings.json` and the subagent body, not in a console.
- **A scheduled headless run can't ask you a question.** Pre-resolve permissions (`allow` what it needs, `--permission-mode`) so it doesn't stall waiting for a confirmation no one will give at 7 AM.
- **Portability depends on `environment.md` being honest** — anything the agent shells out to must be listed with its install line, or the folder won't reproduce on the next machine.

---

## Design implications for the 60-minute skill (technical founder)

1. **Happy path is short and key-free:** write the subagent → set `settings.json` permissions → invoke `/<name>` (or `run.sh`). The founder is already signed in, so there's no credential step and no waiting — expose the raw flow, don't hide it.
2. **The payoff = Outcome + Memory.** The grader subagent gives a self-checking stop condition (the quality loop + safety rail). A `memory/` folder is what makes run #10 smarter than run #1 — the strongest headline differentiator vs. doing it by hand in chat.
3. **Safety rails are the permissions file:** least-privilege `WebFetch` domains, `ask` on destructive `Bash`, `read_only` memory, a bounded `max_revisions` loop. Use `settings.json` + the subagent body instead of hand-rolled guardrails.
4. **"Runs without you" is local and concrete** — a launchd plist or crontab line running `claude -p` headless (or Claude Code's `/schedule`) is the "this is a *worker*, not a chat" moment. The 60-min arc can credibly end with the agent live on a recurring schedule. **Trigger it once by hand** to prove it fires before trusting the clock.
5. **Iteration is cheap and git-safe:** a sharper rubric = edit `outcome.md` (free, no version bump); a prompt/tool change = edit the subagent file (a new git commit you can revert). The whole agent is a folder under version control, so every change is reversible.
