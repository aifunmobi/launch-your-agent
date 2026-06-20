<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Inspiration & example bank — local Claude Code agents

> Reference points for the skill: the real Claude Code capabilities each archetype is built on, the closest known-good config shapes to lift from, and officially-grounded archetypes to offer as opening examples in the interview.
> **Sourcing rule:** every archetype in §3 maps to a real Claude Code primitive (subagents, slash commands, settings/permissions, headless mode, MCP, local scheduling) — that's its grounding. Our own unvalidated ideas live in §5 (backlog); don't offer those in the interview menu.
> Collected 2026-06-14. The live Claude Code docs win over this file.

## How the skill uses this bank

- **In the opening (and any time during Q1):** offer the 2–3 closest archetypes (§3) as concrete examples of what a local agent can be; if the founder wants a menu, AskUserQuestion with the closest few.
- **When emitting the agent folder:** if the founder's problem rhymes with an archetype (§3), lift its config shape — which 🤖 subagent body, which `tools:` line, what 🎯 rubric, whether it 🗓️ schedules — rather than inventing one. The closest archetype is the known-good shape; the Claude Code primitives it names (§1) are what it actually rests on.
- **When a founder asks "can Claude Code really do this locally?":** the answer is the primitive each archetype maps to — a subagent file, a slash command, a `settings.json` permission, a `claude -p` headless run on a launchd/cron schedule. No cloud, no key, runs on the login they already have.

---

## 1. The Claude Code primitives every archetype rests on

These are the real, local building blocks. Each archetype below is just a particular arrangement of them. When you scope a v0, you're choosing which of these to use and how to wire them.

| Primitive | What it is locally | Where it lives | Archetypes that lean on it |
|---|---|---|---|
| **🤖 Subagent** | A scoped agent definition — YAML frontmatter (`name`, `description`, `tools`, `model`) + the system prompt as the markdown body. "Versioning" = git history of the file. | `.claude/agents/<name>.md` | all |
| **▶️ Slash command** | The kickoff task. Type `/<name>` and the body is sent as the prompt; supports `$ARGUMENTS`. | `.claude/commands/<name>.md` | all |
| **📦 Settings / permissions** | Tool gating + networking allow-list: `allow` / `ask` / `deny` rules like `WebFetch(domain:…)`, `Bash(python3 run.py)`. | `.claude/settings.json` | all (esp. ops responder, recurring scan) |
| **🎯 Local grader** | A grader subagent that reads the deliverable + `outcome.md` and returns a per-criterion verdict. No server grader — Claude Code grades locally. | `.claude/agents/<name>-grader.md` | document analyst, recurring scan, data analyst |
| **🧪 Headless mode** | `claude -p "<prompt>"` runs non-interactively on the **existing signed-in session — no separate API key**. The basis of `run.sh` and every scheduled run. Stays key-free only if no Anthropic credential is in the env, so every runner sources `no-api-key-guard.sh` (stops the run if a key is set — see `local-runtime.md` §5b). | `run.sh`, scheduled jobs, `no-api-key-guard.sh` | all |
| **🔌 Local MCP** | Connector servers configured in `settings.json` / `.mcp.json` (Slack, Notion, GitHub, …), with 🔐 secrets in a local `.env` (chmod 600, gitignored). Default is still to **mock** (outbox) when not wireable now. | `.claude/settings.json`, `.env` | ops responder, issue→PR, assistant-that-remembers |
| **🗓️ Scheduling** | A `launchd` plist (macOS, `StartCalendarInterval`) or a `crontab` line that runs `claude -p` headless on a schedule; Claude Code's own `/schedule` is the native alternative. | `schedule/` | recurring scan, document analyst refresh |
| **🧠 File-based memory** | A local folder of markdown the agent reads/writes with normal file tools across runs. | `memory/` | assistant-that-remembers, recurring scan |
| **📄 Document output / project skill** | The agent runs local libraries via `Bash` (`openpyxl`/`pandas`, `python-docx`, `python-pptx`, `pandoc`/`weasyprint`) to produce xlsx/docx/pptx/pdf; a reusable house format can be a project skill. | `.claude/skills/<name>/SKILL.md` | document-producing analyst |
| **🤖×N Subagent roster** | A coordinator subagent that delegates to a small set of scoped specialist subagents, each with its own `tools:` / `model:`. | `.claude/agents/*.md` | specialist team |

**Mapping to our interview:** Q2/Q2b ↔ 🎯 outcome + local grader · Q3 connectors ↔ 🔌 local MCP + 🔐 `.env` · Q5 event-driven ↔ a local trigger script + headless run · Q7 memory ↔ 🧠 `memory/` folder · Q8 multiagent ↔ 🤖×N subagent roster · iteration/eval regression ↔ git history of the subagent file + `evals/run-evals.sh`.

### Known-good shapes worth keeping in mind

- **Weekly competitor digest** (our running example: Lamis Mukta / Acme Analytics) — a research subagent (`WebSearch`/`WebFetch` only, `settings.json` allow-listed to the competitor domains) writes `outputs/digest.md`, a grader scores it against a 4-criterion rubric, a launchd plist fires it `0 7 * * 1` America/Los_Angeles. This is the canonical recurring-scan shape.
- **Graded spreadsheet deliverable** — a subagent that runs `openpyxl` via `Bash` to build an `.xlsx`, judged against a file-based rubric by the local grader. The canonical document-analyst shape.
- **Approve-then-act** — a subagent that investigates and drafts but never executes the consequential step; the consequential tool (a `🔌` MCP call) is left in the `ask` list in `settings.json` so the founder confirms each one. The canonical ops-responder shape.

---

## 2. Why this works without a key or a cloud

The pitch to the founder, in one breath: the agent is **materialized as Claude Code primitives inside a portable `my-agent/` folder** and runs **on the Claude Code login they already have**. There is no Anthropic API key to create, nothing billed per run, and no server-side harness to wait on — drop the folder anywhere Claude Code runs, type `/<name>`, and it works. Scheduling is the same story: a `launchd`/`cron` job runs `claude -p` headless against that same login while they're away, and every run leaves a markdown file in `runs/` so they can see what happened. The "brain" (the subagent + its instructions) and the "hands" (the local tools the `tools:` line and `settings.json` permit) are both files in the folder — that's what makes it portable and inspectable.

---

## 3. Archetypes to offer (every one maps to a real Claude Code primitive)

| # | Archetype | v0 (today) | Built on (§1) | Natural next directions |
|---|---|---|---|---|
| 1 | **Data analyst** | Hand it a CSV/export → narrative report (Markdown or HTML) with charts: what's interesting, what changed. The subagent runs `pandas`/`plotly` via `Bash` and writes to `outputs/`. | 🤖 subagent + 📦 tools (`Bash`/`Read`/`Write`) + 🎯 local grader | 🗓️ launchd/cron run against a fresh export each week; 🔌 a Slack MCP to post the summary (gated); embed the HTML report wherever they want |
| 2 | **Ops responder with approval** | An alert/event → investigate → draft the fix or PR → stop and wait for human approval. The consequential step stays in the `ask` list so nothing fires unattended. | 🤖 subagent + 📦 `settings.json` (`ask` gating) + 🔌 local MCP | Wire to their alerting via a local trigger script; add the backend 🔌 MCP + 🔐 token in `.env`; keep the act step gated to `ask` |
| 3 | **Document-producing analyst** | A research/finance task whose deliverable is a graded artifact — e.g. a model in `.xlsx` (via `openpyxl`) judged against a rubric by the local grader. | 🤖 subagent + 📄 local libs + 🎯 local grader | File-based rubrics in `outcome.md`; pptx/docx variants (`python-pptx`/`python-docx`); a recurring 🗓️ refresh; promote the house format to a project skill |
| 4 | **Engineering agent: issue → PR** | Take an issue, fix it, open the PR, recover when CI or review pushes back. The subagent inherits `Bash`/`Read`/`Edit`/`Grep` and runs the repo's own test loop. | 🤖 subagent + 📦 tools + 🔌 GitHub MCP | Add the GitHub 🔌 MCP + 🔐 token in `.env`; trigger from their tracker via a local script; a grounding read of the repo first; keep `gh pr merge` in the `ask` list |
| 5 | **Assistant that remembers your users** | A helper whose 🧠 `memory/` folder accumulates each user's preferences across runs — it reads the folder at the start of every run and writes back what it learned. | 🤖 subagent + 🧠 `memory/` (read_write) | One subfolder per user under `memory/`; a periodic consolidation pass; a 🔌 MCP into wherever the conversations live |
| 6 | **Recurring digest / scan** | A scheduled sweep — weekly competitor digest, nightly data sync, daily summary — that runs `claude -p` headless and files its report to `outputs/` + `runs/` with nobody present. | 🗓️ launchd/cron + 🧪 headless + 🎯 local grader | Tighten 📦 `settings.json` to allow `WebFetch` only on the needed domains; add a 🧠 `memory/` snapshot so it reports *changes*; grade each run before it's trusted |
| 7 | **Specialist team** | A coordinator subagent that delegates to a small roster of scoped specialist subagents (research / review / write) working in parallel. | 🤖×N subagent roster + 📦 per-agent `tools:`/`model:` | Per-specialist `model:` (pin `opus` for the hard tier, `sonnet`/`haiku` for the rest); per-specialist `tools:` scoping; an escalation tier |

Personalization rule: change only the name/company/product slots, one sentence of domain context, and the output format — the underlying config shape (which subagent, which `tools:` line, which rubric, whether it schedules) comes from the archetype.

---

## 4. Where to point the founder to go deeper

Cite these generically — the live docs win, and exact flag names move.

- **Claude Code subagents docs** — how `.claude/agents/<name>.md` works: frontmatter (`name`/`description`/`tools`/`model`) and the markdown body as the system prompt. The grounding for 🤖.
- **Claude Code slash commands docs** — `.claude/commands/<name>.md`, `$ARGUMENTS`/`$1`, optional `description`/`argument-hint`/`allowed-tools`/`model`. The grounding for ▶️.
- **Claude Code settings & permissions docs** — the `permissions` object (`allow`/`ask`/`deny`) and rule syntax like `Bash(…)`, `WebFetch(domain:…)`, `Read(./outputs/**)`. The grounding for 📦.
- **Claude Code headless mode docs** — `claude -p` and its flags (`--permission-mode`, `--allowedTools`, `--output-format`, `--append-system-prompt`, invoking a subagent). The grounding for 🧪 and every scheduled run.
- **Claude Code MCP docs** — configuring local MCP servers in `settings.json`/`.mcp.json`. The grounding for 🔌.
- **Claude Code scheduling** — its native `/schedule`, plus the portable route of `launchd`/`crontab` running `claude -p`. The grounding for 🗓️.
- See `references/local-runtime.md` in this skill for copy-pasteable shapes of all of the above.

---

## 5. Other ideas backlog

Speculative — not yet a known-good local shape. Don't offer in the interview menu; if a founder lands here, scope it back to the nearest §3 archetype first.

- Inbox triage (bucket emails, draft replies, never send — would need a mail 🔌 MCP; default-mock until then)
- Competitive / market watch beyond a single digest (multi-source cited tracking)
- Support-ticket / review summarizer (cluster by root cause, top-3 fixes)
- Research-to-brief (one question → decision-ready brief with sources)
- Investor update drafter (monthly metrics + notes → update draft)
