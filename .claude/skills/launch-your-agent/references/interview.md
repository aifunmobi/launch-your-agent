<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Founder interview → local agent config

> How the skill turns a short, iterative interview with a technical founder into a concrete, runnable local Claude Code agent.
> Companion to `local-agent-primitives.md` (the inventory of what we can configure).

## The shape of the thing

The interview is not a form — it's a **mapping exercise**. Every answer locks in one or more primitive decisions. The output is a **build sheet** (`build-sheet.json` + the `my-agent/` files) that fully determines:

| Decision | Primitive(s) |
|---|---|
| Who the agent is, what it does, what it must never do | 🤖 Agent (subagent): frontmatter `name` + system-prompt body + `model` |
| What "done" looks like | 🎯 Outcome: `outcome.md` rubric + the local grader subagent + `max_revisions` |
| What it needs to read/know | Tools (`WebSearch`/`WebFetch`), local files, a 🔌 local MCP server + 🔐 `.env` secret, 🧠 memory folder |
| What it produces and where | 📄 Document output (xlsx/docx/pptx/pdf libs), `outputs/` conventions |
| When it runs | ▶️ On-demand `/<name>` vs 🗓️ local cron/launchd vs an event trigger script |
| What software the task needs | 📦 Environment: `environment.md` (installed libs, runtime) |
| What it's allowed to touch | 📦 `settings.json` permissions (allow/ask/deny), `read_only` memory folder |
| One worker or several | Single subagent vs a coordinator subagent calling specialist subagents |
| Whether it gets smarter | 🧠 Memory folder(s) |
| Who interacts with it, and how | Their interface: terminal `/<name>` / a generated local HTML viewer / their own app shelling out to `claude -p` |

**Start from the defaults, build what the job needs.** The interview's job is to find what the founder's v0 actually requires beyond the starting point — not to ask about every primitive, and not to gatekeep the ones the job genuinely needs.

## How the architecture maps onto our constructs

The useful framing is still **brain / hands / session**: the *brain* is the model + system prompt (decision logic, tool routing), the *hands* are the local tools and the machine they run on, and the *session* is the record of one run. Locally these become:

- **Brain** ↔ what the interview's Q1/Q4/Q6/Q8 produce → the **subagent file** (`.claude/agents/<name>.md`: frontmatter + system-prompt body) → the **Agent**, **Tools**, **Document-output** cards.
- **Hands** ↔ Q3 (libs) + Q6 (permissions) → `environment.md` + the `permissions` block in `settings.json` → the **Environment** card.
- **Session** ↔ each **run** — one `/<name>` invocation (or one `claude -p` headless run), logged as a file in `runs/`; Q5 decides who starts it (the founder, a launchd/cron job, or a local trigger script) → `LAUNCH.md` + the header's On-demand/Scheduled status.
- The thing we add beyond brain/hands/session — the **Outcome grader** — is what Q2/Q2b feed, and it's why the `my-agent/` folder treats `outcome.md` + the grader subagent + `evals/` as first-class files rather than prompt text. There is no server-side grader: a local **grader subagent** reads the deliverable and the rubric and returns a per-criterion verdict.

### Primitive-by-primitive map

| Local primitive | Decided by | Lands in `my-agent/` as | Card on agent-overview.html | Materialized at run time | Closest local pattern |
|---|---|---|---|---|---|
| 🤖 **Agent** (name, model, system prompt) | Q1 job, Q6 behavioral never-dos, Q8 model | `.claude/agents/<name>.md` (frontmatter + body) | Agent | a subagent invoked by `/<name>` (or `claude -p --agent <name>`) | a Claude Code subagent definition |
| **Tools + permissions** | Q3 inputs, Q4 outputs, Q6 approvals | subagent `tools:` line + `permissions` in `settings.json` | Tools | tool gating enforced by Claude Code | `settings.json` allow/ask/deny rules |
| 📄 **Document output** (xlsx/docx/pptx/pdf) | Q4 outputs | a `Bash`-invoked local lib, noted in `environment.md`; a reusable house format → a project skill | Document output | the agent runs `openpyxl`/`python-docx`/`python-pptx`/`pandoc` via `Bash` | local doc-generation libraries |
| 🔌 **Connectors** (local MCP) + 🔐 **secrets** | Q3 inputs behind logins, Q4 delivery | `mcp_servers` in `settings.json`/`.mcp.json` + a token in `.env` | Connectors & secrets | a local MCP server the agent calls; default is **mock** (outbox) | local MCP server + `.env` (chmod 600) |
| **Coordinator + specialists** | Q8 shape | a coordinator subagent that calls specialist subagents (only when earned) | Agent (roster note) | the coordinator subagent dispatches the specialists | a subagent that invokes other subagents |
| 📦 **Environment** (libs, networking) | Q3 heavy inputs, Q6 hardening | `environment.md` + `permissions` networking rules | Environment | locally installed libs; `WebFetch(domain:…)` allow-list | `environment.md` + `settings.json` permissions |
| ▶️ **Run** | Q5 = on-demand; also every eval run | `run.sh`, `/<name>` command, a file in `runs/` | header status | `/<name>` in this session, or `claude -p` headless | the slash command / `run.sh` |
| **The task** (kickoff, steering, confirmations) | Q2 (kickoff content), Q6 (confirmations) | `first_prompt.txt`, the `/<name>` command body | — (run history lives in `runs/`) | the prompt handed to the subagent; ask-gates via `settings.json` | `first_prompt.txt` + slash-command body |
| 🎯 **Outcome** (rubric + grader + revision bound) | Q2 done, Q2b evidence | `outcome.md`, `first_prompt.txt`, the grader subagent | Outcome | the grader subagent scores the deliverable locally | `outcome.md` + `.claude/agents/<name>-grader.md` |
| **The filesystem** (inputs & deliverables) | Q2b eval cases, Q3 on-hand inputs, Q4 output retrieval | `evals/` inputs, `outputs/`, output lines in `LAUNCH.md` | Evals | the agent reads/writes plain files | `outputs/` + `evals/` folders |
| 🧠 **Memory** | Q7 learning | `memory/` folder; seeded at first run | Memory | markdown files the agent reads/writes with file tools | a local `memory/` folder |
| 🗓️ **Schedule** | Q5 = recurring | a launchd plist + a crontab line in `schedule/` | Schedule | `launchd`/`cron` runs `claude -p` headless | launchd `StartCalendarInterval` / `crontab` |
| **Event trigger** | Q5 = event-driven, or unattended monitoring | NEXT-DIRECTIONS entry (a local trigger script) | Next directions | a small local script that fires `claude -p` on an event | a watcher/trigger script |
| **Memory hygiene** | Q7 when memory will grow messy | NEXT-DIRECTIONS entry (a periodic consolidation run) | Next directions | a scheduled "tidy memory" run | a consolidation pass over `memory/` |
| **Locked-down networking** | Q6 compliance/least-privilege | NEXT-DIRECTIONS entry | Next directions | tighten `settings.json` to deny everything but named domains | `permissions.deny` + scoped `WebFetch(domain:…)` |

Reading the table by column: the **interview** column is where the decision gets made, the **`my-agent/`** column is the founder's editable copy, the **card** column is how it shows up on the overview page, and the **run-time** column is what actually happens when the agent runs. Anything that ends up in the Next-directions column of the page is deferred — that's the definition of "not in v0."

### The starting point (what every build begins from)

- **One subagent**, `model: inherit` (runs on the Claude Code login you're already in), full built-in toolset (`Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch`)
- **Your machine + a `settings.json`** that allows the obvious read/web tools and asks before anything risky; no extra libs unless the task needs them
- **An outcome** (`outcome.md` rubric) graded by a local grader subagent, `max_revisions: 3`
- Outputs written to `outputs/`; each run logged to `runs/<date>.md`

From there, **build what the job needs — scoped into versions, not gatekept by primitive**. Any primitive (a local MCP connector, a `.env` secret, a memory folder, a document-output lib, a schedule, even a coordinator + specialists) belongs in v0 if the core job doesn't work without it and it's wireable now (e.g. the connector token is on hand). Everything the job wants but doesn't need on the first pass is laid out explicitly as **v1, v2, …** in NEXT-DIRECTIONS — a numbered sequence of planned increments, each with its mechanism — so "not in v0" reads as "scheduled for v1", never "cut".

The standing recommendation (not a rule): v0 is **read/analyze/draft only** — write-actions into external systems (send/post/merge/delete/place orders) usually ship in a later version behind an ask-before-acting gate (`settings.json` `ask` on the connector), once the founder trusts the output. If the founder explicitly wants a write-action in v0, wire it gated (an `ask` rule, or a sandbox/paper variant) rather than refusing — say what the recommendation is and why, then build what they choose.

---

## The interview

Eight question clusters, run **iteratively** — never as a form. Open light: a couple of warm sentences, 2–3 archetype examples from the examples bank, then Q1 — no boundaries block, no process talk. After their first answer, let them keep explaining (one open follow-up) before any suggestions or option menus; a founder telling their story usually answers 2–4 clusters at once, so only ask what's still open. Whenever the answer space is enumerable (which task, sources, schedule time, scope options, connector now vs later), use AskUserQuestion with concrete options; keep open-ended questions to one per turn. Boundaries and caveats are raised in context, briefly, when they matter. For each cluster below: what to ask, what you're listening for, and the mapping rules.

### Q1. The job — "Tell me about yourself and what you'd like to build."

Open and unrestrictive — they can bring anything an agent can do: their own task, a piece of their product, a customer-facing worker, an experiment. Listening for: a job with (a) real judgment+tool work in it and (b) inputs they can actually provide. Whether it recurs only decides the cadence question later (Q5) — it is not a requirement, and "this is for my product / my users" is just as good a starting point as "this eats my week".

**Maps to:** the subagent `name`, the core of the system-prompt body, and the archetype (ops chore / research-analyst / product probe / customer-facing worker).

Rules:
- **Let them explain first.** One open follow-up ("what would it actually do? what does a great first version look like to you?") before any reshaping, boundaries, or AskUserQuestion menus — respond to their picture, don't pre-empt it.
- If the ask needs things agents truly can't do (live phone calls, sub-second real-time reaction) → say so honestly and reshape to the nearest can-do. Keep hard limits separate from defaults: building a UI on top of the agent is fine (that's the generated-interface extension); gated write-actions (send/post/place orders behind an `ask` rule, or paper/sandbox variants) are possible, even in v0 if they want them — don't undersell.
- If they describe a *pipeline* of many jobs → capture the whole pipeline, build **stage one** today; the rest goes into Next directions (and may justify a coordinator + specialists later, see Q8).

### Q2. Done — "Show me what a good result looks like. Concretely. What would you check to know it's right?"

Ask this **after** the job is understood, under its own clearly-named step ("Outcome & evals") — never in the opening message.

Listening for: checkable, binary-ish criteria. Push past "a useful summary" to "a markdown file with the 5 most important items, each with a link and one line of why".

**Maps to:** the **Outcome** — `outcome.md` (the task description + rubric, per-criterion checks) + the grader subagent + `max_revisions`.

Rules:
- 3–6 explicit criteria; each independently gradeable. Vague criteria → noisy grading.
- If they have a known-good past example → use it: derive the rubric from what makes that example good.
- `max_revisions`: default 3 — the cap on the local grade→fix loop. Raise toward 5–10 only when the task is genuinely hard to nail.
- The rubric lives in `outcome.md`, **not** the subagent's system prompt — so sharpening it later is free (no agent version bump / no git change to the subagent file).

### Q2b. Evidence — "Do you have real examples we can test against? Past cases where you know what the right answer was?"

Asked in the same "Outcome & evals" step as Q2, not upfront. Listening for: real historical inputs **with known-good outputs** — last month's actual emails and how they triaged them, a competitor report they wrote by hand, the spreadsheet a contractor produced, tickets they already answered. This is the founder's eval set, and most founders have one without realizing it.

**Maps to:** the test/eval harness for v0 and beyond (`evals/` + `run-evals.sh`).

| What they have | What we do with it |
|---|---|
| 2–5 real past cases with known-good results | **Golden set.** Use one as the v0 kickoff input; hold the rest back. After the rubric passes on case 1, run the held-back cases as additional runs and compare against what they actually did. |
| One known-good artifact, no inputs | Derive the rubric *from* it and use it as the reference when grading run #1. |
| Real inputs but no "right answers" | The founder is the grader: run it, they mark each rubric criterion pass/fail by hand on run #1 — that judgment becomes sharper rubric criteria for run #2. |
| Nothing real on hand (stealth, no data yet) | Synthesize 2–3 plausible test inputs *with them* during the interview; flag in NEXT-DIRECTIONS that the first week of real usage is the eval. |
| Fresh-data recurring task (news, raises, monitoring) — golden answers age out by design | The rubric IS the eval. Today's first verified output gets saved as `evals/case-01/expected.md` at close — it's the regression baseline for the next agent version, not a permanent golden answer. |
| Sensitive real data | Use it only if they're comfortable; otherwise have them hand-redact or synthesize look-alikes — the structure matters more than the values. (It all stays on their machine, but treat it as they'd treat any local file.) |

How evals actually run locally (no separate eval product needed):
- **The Outcome rubric IS the per-run eval** — the grader subagent scores every run against it and the verdict (per criterion: pass / needs-revision, with a one-line evidence note) is written into that run's file in `runs/`.
- **A golden-set pass = N runs, same agent version, one per test case** (`evals/run-evals.sh` loops over the case folders, runs the agent on each input via `claude -p`, runs the grader, collects verdicts + outputs into `evals/results-v<N>.md`). The "version" is the current `.claude/agents/<name>.md` (git-tracked), so results are comparable.
- **Regression check after iteration:** after any change to the subagent file (v2, v3…), re-run the golden set and diff verdicts — catches "fixed one case, broke another".

Rules:
- Don't gate v0 on a big eval set — **one real case to build against + 2–4 held back** is plenty; more goes in Next directions.
- If they picked a schedule (Q5), the golden-set re-run becomes the pre-flight check before promoting a changed subagent file to the scheduled run.
- Record in the build sheet: where the eval cases live, which run files were the eval runs, and the verdict per case.

### Q3. Inputs — "What does it need to read or know to do this well?"

Triage every input they name into one of these buckets (this is the heart of the config):

| Input type | Maps to |
|---|---|
| Content they have on hand (docs, samples, exports) | **Local files** the agent reads (`Read`/`Glob`), dropped into the working dir, or pasted into `first_prompt.txt` |
| Live public information (sites, competitors, news, docs) | `WebSearch` / `WebFetch` (already in the toolset; scope domains in `settings.json`) |
| Their code | A local checkout the agent reads with `Read`/`Grep`/`Glob` |
| A SaaS behind a login that has an MCP server (Slack, Linear, Notion, GitHub…) | A **local MCP server** entry in `settings.json`/`.mcp.json` + a **token in `.env`** |
| Any API/CLI keyed by a token (their own backend, Stripe, Airtable…) | A `Bash`-invoked CLI/script reading a **token from `.env`** (+ a scoped `Bash`/`WebFetch` permission) |
| Internal-only services not reachable from the laptop | A local MCP server pointed at the service over the VPN/SSH tunnel — flag the setup, don't promise it for v0 |
| Knowledge that should accumulate across runs (preferences, past decisions, what worked) | A 🧠 **memory folder** (see Q7) |

Rules:
- **Connector test:** if the token isn't available *right now*, v0 does without it — substitute public web or pasted samples, or **mock the connector** (outbox / endpoint schemas in `mock-connectors.md`) so the agent's behaviour is already shaped for the real thing; the credentialed version is the swap — add the MCP server to `settings.json` and drop the token into `.env`.
- Anything sensitive stays on their machine; remind them the only secret that ever leaves a file is a third-party connector token, which lives in `.env` (chmod 600, gitignored) — never in chat. There is no Anthropic API key to manage; the agent runs on their existing Claude Code login.
- If an input requires heavy parsing libraries (PDFs, spreadsheets, specific SDKs) → list it in `environment.md` and install it locally (pip/npm/brew…).

### Q4. Outputs — "What artifact comes out, and where does it need to land?"

| Output | Maps to |
|---|---|
| Markdown / text / JSON report | default — written straight to `outputs/` |
| Spreadsheet, deck, doc, PDF | 📄 **a local lib via `Bash`**: `openpyxl`/`pandas` (xlsx), `python-pptx` (pptx), `python-docx` (docx), `pandoc`/`weasyprint`/`md-to-pdf` (pdf) — noted in `environment.md` |
| A draft inside another system (PR, ticket, email draft, CRM note) | A local MCP write tool — **gated with an `ask` rule** in v0, or draft-text-only output |
| Triggering something in *their* product/backend | A `Bash`-invoked call into their own CLI/endpoint (token from `.env`), or a mocked outbox they wire up |
| Something a human must review before it goes anywhere | keep the agent draft-only; the review step lives in their interface (Q6/Q8) |
| A repeatable house format or procedure (report template, triage checklist, brand voice) | A **project skill** (`.claude/skills/<name>/SKILL.md`) the agent loads — author it now if small, otherwise NEXT-DIRECTIONS with the skill outline |

Rules:
- v0 never *sends/posts/merges/deletes* in external systems. Drafting is the deliverable; the send button stays human (or `ask`-gated) until they trust it. **Say what the guardrail actually is** — "the agent drafts to `outputs/`; sending is wired later through a local MCP connector with an ask-before-send gate" — not just "it can't email".
- When the founder names a delivery destination, name the connector route back: which local MCP server, what token it needs (in `.env`), and whether it's wireable today or Next direction #1. Slack and email both take real setup (app creation, OAuth/webhook, token), so default to **mocking the connector in v0** and wiring it for real as v1; if the founder wants to do it now, go for it — pull the latest connector/MCP docs first.
- Can't wire it now but they want the behaviour? **Mock it** (`mock-connectors.md`): the agent writes schema-true payloads to an `outputs/outbox/` folder, and the real connector becomes a one-step swap in v1.
- When delivery is the point of the agent, **the v0 deliverable is the message itself** — the exact Slack message / email / ticket text (or schema-true payload) as the output file, ready to paste or send by hand. The next version then only adds the sending; the content and format are already proven.

### Q5. Cadence — "When should this run: when you ask, on a schedule, or when something happens?"

| Answer | Maps to |
|---|---|
| "When I ask" | The **`/<name>` slash command** (or `run.sh`). Fine for v0 and for testing — type `/<name>` in Claude Code and it runs. |
| "Every Monday at 7" / "nightly" / "weekly" | A 🗓️ **local schedule**: a `launchd` plist (macOS, `StartCalendarInterval`) or a `crontab` line running `claude -p` headless in the folder. Claude Code's own `/schedule` is the native alternative. Trigger it manually once before trusting the timer. |
| "When a customer signs up / when a PR opens / when an email arrives" | Event-driven: a **small local trigger script** (a webhook handler, a file/queue watcher, a polling loop) that fires `claude -p` when the event lands. |

Rules:
- Even for scheduled work, run everything on-demand first; the schedule is created **last**, once a run has passed the rubric.
- Capture the cron line + IANA timezone verbatim in the build sheet; warn about the 1–3am DST window only if they pick it.
- **Cadence vs lookback consistency check:** if the run frequency and the data window disagree (e.g. daily run, 14-day lookback → mostly repeated content every run), resolve it now with one question (shorter window, less frequent run, or a memory folder that tracks what's already been reported) rather than deferring it silently.
- Anything reused on a schedule (`first_prompt.txt`, the system prompt) must use **relative dates** ("today", "the last N days as of this run"), never a literal date — the scheduled job replays the same task every run.

### Q6. Boundaries — "What must it never do?"

Two things are handled quietly, as defaults — not a discussion:
- **Revision bound** via `outcome.md`'s `max_revisions` (default 3) — the built-in stop on the local grade→fix loop. No spend-limit step; nothing is billed per run.
- Behavioral never-dos ("never contact anyone", "never present guesses as facts") → lines in the subagent's system-prompt body. Cheap, do them now.

Everything else a founder raises here is **hardening, not v0** — capture it in **Next directions** (see below) with the exact mechanism so they can apply it after the session:

| Concern raised | Next-direction entry (mechanism) |
|---|---|
| "Only touch these specific sites/APIs" | `settings.json` `permissions`: `deny` broad web, `allow` only `WebFetch(domain:…)` on the named hosts (+ scope the allowed MCP servers) |
| "Ask me before it runs commands / posts anywhere" | `settings.json` `ask` rules on `Bash(…)` or the relevant MCP write tool — needs an interface that surfaces confirmations (the terminal does) |
| "Don't let it rewrite our reference docs" | A `read_only` memory folder — the subagent's instructions say never to edit it (and `permissions.deny` a `Write`/`Edit` rule scoped to that path) |
| Least-privilege / compliance posture | Tighten `settings.json` to an allow-list-only `permissions` block; keep the folder portable and auditable in git |

### Q7. Learning — "Should run #10 be smarter than run #1? What should it remember?"

| Answer | Maps to |
|---|---|
| "No, each run is independent" | No memory folder. Simpler. Done. |
| "It should remember my preferences / past decisions / what it already processed" | One **memory folder** (`memory/<topic>/`), `read_write`, that the subagent reads at the start of every run and updates at the end; seed it with 2–3 starter notes at first run |
| "There's reference material it should always consult but never change" | A second folder, `read_only` (the instructions forbid edits; `permissions` can enforce it) — cheap insurance against poisoning |
| "Per-customer memory" (their product) | One folder **per end user/customer** (`memory/<customer-id>/`), selected per run — pairs with a per-user `.env` / token (Q8) |
| "Memory will get messy over time" | Roadmap note: a periodic **consolidation run** that tidies and de-duplicates the `memory/` files |

Keep it focused: small, single-purpose markdown files the agent can read fast — not one giant log.

### Q8. Shape & surface — "Who uses this — just you, your team, or your customers? And where do they interact with it?"

This determines two things: **single subagent or coordinator + specialists**, and **what their interface is** (the founder's own product surface — see note at bottom).

Shape rules (default is single subagent):
- One job, one context → **single subagent**. Always start here.
- Genuinely separable specializations (different tools/credentials/models per role), or fan-out over many independent items, or an escalation tier → **a coordinator subagent that calls specialist subagents**, one level deep. Build the single most valuable specialist first; the coordinator comes after at least one specialist works alone.

Interface mapping:
| "Who/where" | What it implies |
|---|---|
| Just the founder, terminal is fine | The **`/<name>` slash command** (and `run.sh`) ARE the interface; nothing more to build. Complete on its own. |
| Founder + small team, want visibility | The **agent-overview.html** page we generate, plus a **generated local HTML viewer over `outputs/` + `runs/`** (Claude Code builds it in a follow-up session — a results browser and run history, opened from a local file) is the standard tailored-extension offer here when it suits the need — v1, not v0. |
| Their customers, inside their product | **Productized**: their own app shells out to `claude -p` per user/job (folder-per-user with its own `.env`/memory, headless invocation, parsing the output) and owns the UX — streaming, rendering, confirmations. That's their build, not ours; the build sheet gives them the invocation map for it. |

Also captured here: model posture — default `model: inherit` (runs on the Claude Code login you're already in, no key, nothing billed per run); pin `opus` for the hardest reasoning or `sonnet`/`haiku` for faster/cheaper runs only if they explicitly want it.

---

## Output of the interview: the build sheet

Everything above lands in `./my-agent/`:

| File | Contents |
|---|---|
| `build-sheet.json` | The full structured mapping (every primitive decision + rationale) — **this is what the primitives UI renders** |
| `.claude/agents/<name>.md` | 🤖 the subagent: frontmatter (`name`, `description`, `tools`, `model`) + the system prompt as the markdown body |
| `.claude/agents/<name>-grader.md` | 🎯 the local grader subagent: reads the deliverable + `outcome.md`, returns a per-criterion verdict |
| `.claude/commands/<name>.md` | ▶️ the `/<name>` slash command: runs the agent on the task |
| `.claude/settings.json` | 📦 environment: tool `permissions` (allow/ask/deny) + networking allow-list + any 🔌 MCP servers |
| `outcome.md` | 🎯 the rubric (3–6 binary criteria) + `max_revisions` |
| `first_prompt.txt` | the kickoff task — **relative dates only** |
| `environment.md` | 📦 what the task needs installed locally + how to install it |
| `evals/` | The golden set: one folder per test case (`input.*` + `expected.md` or known-good artifact), plus `run-evals.sh` (loop: run the agent on each case via `claude -p`, run the grader, collect verdicts + outputs into `evals/results-v<N>.md`) |
| `memory/` | 🧠 the local memory folder (only if the agent learns across runs) |
| `outputs/` | where each run writes its deliverable |
| `runs/` | ▶️ the run log — one markdown file per run (this replaces any console) |
| `schedule/` | 🗓️ launchd plist + crontab line (only if Q5 = scheduled) |
| `run.sh` | one run end-to-end: invoke the agent on `first_prompt.txt`, then grade |
| `agent-overview.html` | The "spec sheet" page: a static, self-contained view of every primitive in use (agent, rubric, tools, connections, memory, schedule, evals, next directions). **Claude Code generates and regenerates it directly** — it's a workflow step in the skill (after the interview, after the first run, after every iteration), not a script the founder runs. Template/example: `references/overview-template.html`. No console — `runs/` and `outputs/` are the live record. |
| `LAUNCH.md` | How to run it locally + how to put it on a schedule |
| `NEXT-DIRECTIONS.md` | The version plan. **Whenever something doesn't belong in v0 — at any point in the session — it goes here, in the moment**, slotted into a numbered later version (v1, v2, …) with the exact mechanism: write-actions behind ask-gates, network allow-lists in `settings.json`, read-only memory, connector tokens not in hand, coordinator+specialist stages, the local HTML viewer, the productized `claude -p` interface, memory consolidation. It reads as a sequence of planned releases, not a list of cuts. |
| `.env` | 🔐 ONLY if a third-party connector is wired (chmod 600, gitignored). Never an Anthropic key — there is none. |
| `.gitignore` | contains `.env` and any `*.txt` transcript exports |

The folder is **portable**: drop `my-agent/` anywhere, run `claude` in it, and `/<name>` works — that portability is the local equivalent of "it lives in your account and keeps working after the session." `build-sheet.json` is the source of truth; the other files are projections of it. As objects come to life — the subagent file, the first run, a wired connector, an installed schedule — the build sheet and overview page are regenerated to match; there are no external ids to track, runs are keyed by date in `runs/`.

## Sequencing (v0 first, upgrades after)

1. **Light open + interview** → warm welcome, 2–3 examples, the open question, then let them explain before steering; the iterative interview with boundaries raised only in context; the design read back as the brief (primitives table · v1/v2 section · eval table) and approved via AskUserQuestion; **agent-overview.html generated and opened immediately on approval** (something to look at while the rest is built), then build sheet + files emitted. Eval cases (Q2b) collected into `evals/` — case 1 becomes the v0 input, the rest held back. **No "grab the API key" step** — there is no Anthropic key; if (and only if) the design wires a third-party connector now, name that one optional `.env` secret.
2. **Materialize** → write the subagent file, the grader subagent, the `/<name>` command, `settings.json`, `run.sh`, `environment.md`, `.gitignore`. If a connector is wired now: pre-create `my-agent/.env` (chmod 600) and have the founder paste the connector token into it via its absolute path — never into the chat. Model pick happens here (`inherit` by default; pin `opus`/`sonnet`/`haiku` only if asked).
3. **Run v0** → invoke the `/<name>` command in this very Claude Code session (or `run.sh`, which calls `claude -p` headless) **on eval case 1**. There's no credential step and no waiting on the founder — they're already signed in. The agent writes the deliverable to `outputs/`; the run is logged to `runs/<date>.md`.
4. **While it runs** → regenerate agent-overview.html; draft NEXT-DIRECTIONS; seed the memory folder if planned.
5. **Grade & iterate** → the grader subagent reads the deliverable + `outcome.md` and returns a per-criterion verdict; present it as a table (criterion | verdict | evidence) *and against the known-good answer for case 1*; read the output yourself too; pick the next move via AskUserQuestion; change ONE thing (rubric edit in `outcome.md` = free; subagent instructions/tools change = a new git-tracked version); re-run. Once a version passes, fire the held-back eval cases (`evals/run-evals.sh`) against the winning subagent file.
6. **Make it theirs** → if scheduled: write the launchd plist (macOS) / crontab line with relative dates, install it, and **trigger it once manually** so they see it fire (the run lands in `runs/`); offer `/schedule` as the native alternative. Event-driven → a small local trigger script (named in NEXT-DIRECTIONS). On-demand → `run.sh` / the slash command is the interface; confirm it re-runs from a fresh terminal. Eval results recorded per version; Next directions finalized (incl. "re-run `evals/run-evals.sh` before promoting any new subagent version to the schedule"); then invoke `/wrap-up` — it owns the close: overview page reopened, primitives recap table, run log, 1–2 tailored extensions, hygiene sweep.

---

## Note on the founder's *own* interface (the FYI)

The thing built here is the **worker**. How the founder (or their users) talk to it afterwards is a separate, deliberate choice captured in Q8 and written into NEXT-DIRECTIONS:

- **Terminal-only** is legitimate and complete for a solo founder — the `/<name>` slash command and `run.sh` are the whole interface.
- **Internal surface**: the agent-overview page we generate doubles as a minimal spec/status view; a **generated local HTML viewer over `outputs/` + `runs/`** is offered as a tailored extension when it suits the need — a results browser and run history, built by Claude Code in a follow-up session and opened from a local file.
- **Productized**: their app owns the UX — shelling out to `claude -p` per user/job (folder-per-user with its own `.env`/memory), parsing the output, streaming, rendering, surfacing confirmations. That's their build, not ours; the build sheet gives them the invocation map for it.
