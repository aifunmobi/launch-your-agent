<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Local runtime — how to build & run the agent

> The agent is a set of plain files inside `my-agent/.claude/`. There is **no API key, no API access, nothing billed per run** — everything below runs on the Claude Code the founder is already signed into. Drop the `my-agent/` folder anywhere, run `claude` in it, and `/<name>` works.
> If a flag name below has drifted in the founder's Claude Code version, `claude --help` (or `claude -p --help`) is the live source — check, adapt, retry once. The capability is what matters; the exact flag is the detail.

The running example throughout is **competitor-digest** — Lamis Mukta at Acme Analytics, who spends ~3 hours every Monday pulling competitor pricing and feature changes into a digest for her team. We materialize that as a subagent, a grader, a slash command, settings, a run script, and a schedule.

## 0. Where things live

```
my-agent/
  .claude/
    agents/competitor-digest.md           # 🤖 the agent (subagent: frontmatter + system prompt body)
    agents/competitor-digest-grader.md     # 🎯 the local grader
    commands/competitor-digest.md          # ▶️ /competitor-digest slash command
    settings.json                          # 📦 tool permissions + networking allow-list
  outcome.md            # 🎯 the rubric
  first_prompt.txt      # the kickoff task (relative dates only)
  environment.md        # 📦 what's installed locally
  run.sh                # one run end-to-end → grade → log
  evals/                # 🧪 cases + run-evals.sh
  memory/               # 🧠 local memory (only if it learns across runs)
  outputs/              # where each run writes its deliverable
  runs/                 # ▶️ one markdown file per run (this is the run log)
  schedule/             # 🗓️ launchd plist + crontab line (only if scheduled)
```

Project-scoped files in `my-agent/.claude/` are picked up automatically when you run `claude` with `my-agent/` as the working directory. That's the whole "deployment": the folder *is* the agent.

## 1. The agent — a subagent file

`.claude/agents/competitor-digest.md`. YAML frontmatter, then the markdown body **is the system prompt**.

```markdown
---
name: competitor-digest
description: Researches the 5 named competitors' public sites, pricing pages, and changelogs and writes a weekly digest. Use for the Monday competitor digest.
tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
model: inherit
---

You are the competitor-digest agent for Acme Analytics. Each run, you research five
named competitors and produce that week's digest.

The five competitors: Northstar, Pelldata, Quill, Rowan Metrics, Sift.

For each competitor, check the public site, the pricing page, and the changelog/blog.
Report what CHANGED since last run (pricing, packaging, notable features, launches) —
not a re-description of the company. Read memory/competitor-history/<name>.md first to
know last week's snapshot; update it after you write the digest.

Write the digest to outputs/digest.md with a section per competitor and a 3-bullet
"what matters this week" summary at the top. Use relative dates from the task ("the
last 7 days as of today"), never a hard-coded calendar date.

Never-dos:
- Never contact anyone or post anywhere. Research and drafting only.
- Never present guesses as facts. If something is unverified, mark it "(unverified)".

Always write your deliverable to outputs/ — never to the repo root or elsewhere.
```

Notes that keep this accurate:
- `name` must match the filename stem and is what you invoke. `description` is what tells Claude Code (and you) when this agent applies; write it in plain when-to-use language.
- `tools:` is a comma-separated list of Claude Code's built-in tools: `Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch`. **Omit the line entirely to inherit the full toolset.** Listing tools narrows the agent to exactly those.
- `model:` is optional: `inherit` (use the session's model — the default we want, no key, no per-run cost), or pin `opus` / `sonnet` / `haiku`.
- "Versioning" is just git: every edit to this file is a new tracked version. `git log` is the version history; `git diff` shows what changed between two attempts.

## 2. The grader — a second subagent

`.claude/agents/competitor-digest-grader.md`. It reads the deliverable + `outcome.md` and returns a per-criterion verdict. Give it only read tools so it can't "fix" the output it's judging.

```markdown
---
name: competitor-digest-grader
description: Grades a competitor-digest run against outcome.md. Returns a per-criterion PASS/FAIL table.
tools: Read, Glob, Grep
model: inherit
---

You are a strict grader. You do not write or edit anything — you only judge.

1. Read outcome.md — it lists the binary rubric criteria.
2. Read the deliverable at outputs/digest.md.
3. For EACH criterion, decide PASS or FAIL on the evidence in the file alone. A
   criterion passes only if it is unambiguously met; when in doubt, FAIL it.

Output exactly one markdown table and nothing else before it:

| # | Criterion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | ...       | PASS    | "<quote or location from outputs/digest.md>" |

End with one line: VERDICT: PASS (all criteria pass) or VERDICT: NEEDS-REVISION
(one or more FAIL), and if NEEDS-REVISION, the single highest-leverage fix.
```

`outcome.md` it reads against (3–6 binary criteria):

```markdown
# Outcome — this week's competitor digest

Produce outputs/digest.md such that:
1. The file exists and has a section for all 5 competitors (Northstar, Pelldata, Quill, Rowan Metrics, Sift).
2. Each competitor section reports what CHANGED, not a static description.
3. Every pricing claim is either sourced to a URL or marked "(unverified)".
4. A "what matters this week" summary of at most 3 bullets is at the top.
```

## 3. The slash command — the kickoff task

`.claude/commands/competitor-digest.md`. The body is the prompt sent when you type `/competitor-digest`. `$ARGUMENTS` carries whatever you type after the command (and `$1`, `$2` for positional args).

```markdown
---
description: Run this week's competitor digest.
argument-hint: "[optional: extra focus, e.g. 'pricing only']"
---

Use the competitor-digest agent to produce this week's digest.

Window: the last 7 days as of today. Cover all five competitors. Write the result to
outputs/digest.md. Extra focus for this run, if any: $ARGUMENTS
```

When invoked, Claude Code reads this body as the task and (because the body names the agent) hands the work to the `competitor-digest` subagent. Keep dates relative here too — this same text gets reused on every scheduled run.

`first_prompt.txt` holds the standalone version of this task (no slash, no frontmatter) for `run.sh` and the schedule to feed to `claude -p`:

```
Use the competitor-digest agent to produce this week's digest. Window: the last 7 days
as of today. Cover all five competitors (Northstar, Pelldata, Quill, Rowan Metrics,
Sift). Write the result to outputs/digest.md.
```

## 4. settings.json — the environment & networking allow-list

`.claude/settings.json` is the local equivalent of "environment networking + tool gating." The `permissions` object has three arrays — `allow` (run without asking), `ask` (prompt first), `deny` (never) — of rules scoped per tool.

```json
{
  "permissions": {
    "allow": [
      "Read(./**)",
      "Write(./outputs/**)",
      "Write(./memory/**)",
      "Write(./runs/**)",
      "Bash(python3:*)",
      "WebSearch",
      "WebFetch(domain:northstar.com)",
      "WebFetch(domain:pelldata.io)",
      "WebFetch(domain:quill.app)",
      "WebFetch(domain:rowanmetrics.com)",
      "WebFetch(domain:sift.ai)"
    ],
    "ask": [
      "Bash(rm:*)"
    ],
    "deny": [
      "Read(./.env)",
      "WebFetch"
    ]
  }
}
```

How to read this:
- `WebFetch(domain:...)` rules whitelist exactly the competitor domains; the bare `WebFetch` in `deny` means **any other domain is refused** — that's the local "limited networking, allowed_hosts" tightening.
- `Bash(python3:*)` allows any `python3 …` invocation without a prompt; scope it tighter (e.g. `Bash(python3 build_digest.py)`) if you want one exact command. Rules are matched specifically, so `deny` wins over `allow`.
- `Read(./.env)` is denied so the agent (and the grader) can't read connector secrets even if asked.
- Local MCP connectors, when you add them, are declared here too (or in a sibling `.mcp.json`) under an `mcpServers` block; their secrets live in `my-agent/.env` (chmod 600, gitignored), never in chat. v0 uses public web only — no `.env` needed yet.

## 5. Running the agent (no API key)

**Interactively** — from inside `my-agent/`, run `claude`, then type the slash command. Add an argument if the command takes one:

```
/competitor-digest
/competitor-digest pricing only
```

The agent runs in this session, on your signed-in login, and writes `outputs/digest.md`.

**Headless** — for scripts and schedules, `claude -p` runs non-interactively against the **same signed-in session, with no API key**:

```bash
claude -p "$(cat first_prompt.txt)"
```

Useful flags:
- `--permission-mode acceptEdits` — auto-accept file edits so a headless run doesn't stall on a prompt. (`plan` plans without acting; `default` prompts as usual.) For a fully unattended run you can use `--dangerously-skip-permissions`, but prefer a tight `settings.json` allow-list so you don't have to.
- `--allowedTools "Read,Write,Bash(python3:*),WebFetch"` — restrict the tools for this run, on top of `settings.json`.
- `--output-format json` (or `stream-json`) — machine-readable result instead of plain text, handy for `run.sh` to capture.
- `--append-system-prompt "…"` — bolt one extra instruction onto the agent for this run without editing the subagent file.
- `--agent <name>` (select a defined subagent) / naming the agent in the prompt body — routes the work to a specific subagent. (Note: `--agents` with an `s` is a different flag that *defines* inline agents from JSON; to run one you already defined in `.claude/agents/`, use the singular `--agent <name>` or just let the prompt delegate by description match.)

Because there is no key, the only prerequisite is that `claude` is on `PATH` and the founder is signed in. A headless run inherits that login.

## 6. run.sh — one run end-to-end

Runs the agent on the task → confirms the deliverable → invokes the grader → appends a dated entry to `runs/`. Run it from inside `my-agent/`.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"                      # always operate from my-agent/, even under cron
DATE="$(date +%F)"                        # e.g. 2026-06-19 — relative, never hard-coded in the task
mkdir -p outputs runs

# 1. run the agent on the task (headless, signed-in session, no key)
claude -p "$(cat first_prompt.txt)" --permission-mode acceptEdits

# 2. the deliverable must exist
test -s outputs/digest.md || { echo "no outputs/digest.md — agent wrote nothing"; exit 1; }

# 3. grade it locally
GRADE="$(claude -p 'Use the competitor-digest-grader agent to grade outputs/digest.md against outcome.md.')"

# 4. append to the run log (one markdown file per run = your run history)
{
  echo "## Run ${DATE}"
  echo
  echo "Deliverable: outputs/digest.md ($(wc -l < outputs/digest.md) lines)"
  echo
  echo "$GRADE"
  echo
} >> "runs/${DATE}.md"

echo "✅ ▶️ run complete → runs/${DATE}.md"
```

`chmod +x run.sh` once. A single `./run.sh` now produces the digest, grades it, and logs the verdict — the same shape whether a human or cron triggers it.

## 7. The iterate loop

You change exactly one thing, re-run, re-grade. Two kinds of change:
- **Sharpen `outcome.md`** — free, no version churn. Tightening a criterion ("every pricing claim sourced to a URL") often fixes more than touching the agent.
- **Edit the subagent** (`.claude/agents/competitor-digest.md`) — its instructions or `tools:` line. Each edit is a new **git-tracked version**:

```bash
git add .claude/agents/competitor-digest.md outcome.md
git commit -m "competitor-digest: require sourced pricing; drop WebSearch"
git log  --oneline -- .claude/agents/competitor-digest.md   # the version history
git diff HEAD~1 -- .claude/agents/competitor-digest.md       # what changed since last attempt
```

There's no version-number field and no concurrency guard to manage — `git` is the entire versioning story. Re-run with `./run.sh` (or `/competitor-digest`) and read the new grader table.

## 8. evals/run-evals.sh — run the held-back cases

Once a version passes on the v0 input, run the held-back cases locally: loop the cases, run the agent on each input, grade, collect verdicts into `results-v<N>.md`.

```
evals/
  case-01/  input.txt  expected.md     # the v0 input + its verified output (the golden set)
  case-02/  input.txt  expected.md     # week-of-… held back
  case-03/  input.txt  expected.md     # week-of-… held back
  run-evals.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."                   # run from my-agent/
V="${1:?usage: run-evals.sh <version-number>}"
OUT="evals/results-v${V}.md"
echo "# Eval results — agent v${V} ($(date +%F))" > "$OUT"

for d in evals/case-*/; do
  case="$(basename "$d")"
  claude -p "$(cat "$d/input.txt")" --permission-mode acceptEdits
  verdict="$(claude -p "Use the competitor-digest-grader agent to grade outputs/digest.md against outcome.md, treating ${d}expected.md as the reference for what a good digest covers.")"
  {
    echo "## ${case}"
    echo "$verdict"
    echo
  } >> "$OUT"
done

echo "✅ 🧪 evals done → ${OUT}"
```

No golden set yet? After a run you're happy with, save it: `cp outputs/digest.md evals/case-01/expected.md`. Promote a new agent version to the schedule only when the verdicts in `results-v<N>.md` hold.

## 9. memory/ — local files

If the agent learns across runs, `my-agent/memory/` is just markdown the agent reads and writes with normal file tools — exactly how Claude Code uses its own file memory. No store to create, no ids.

```
memory/competitor-history/
  northstar.md   pelldata.md   quill.md   rowan-metrics.md   sift.md
```

The subagent's instructions tell it to read last week's snapshot from here, then update it after writing the digest — that's what turns "describe the company" into "report what changed." A **read-only** reference is just a folder the instructions say never to edit (and you can back that up in `settings.json` with a `deny` rule, e.g. `Write(./memory/reference/**)`).

## 10. Scheduling — local cron / launchd

Only when the job actually repeats on a clock (the Monday digest does). On-demand or event-driven → skip this; `run.sh` / the slash command is the interface. The kickoff task must use **relative dates** — the scheduled job replays `first_prompt.txt` verbatim every time.

### launchd (macOS — lead with this)

`~/Library/LaunchAgents/com.acme.competitor-digest.plist`, running `run.sh` weekly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>            <string>com.acme.competitor-digest</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/lamis/my-agent/run.sh</string>
  </array>
  <key>WorkingDirectory</key> <string>/Users/lamis/my-agent</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key> <integer>1</integer>   <!-- Monday -->
    <key>Hour</key>    <integer>7</integer>
    <key>Minute</key>  <integer>0</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key> <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StandardOutPath</key>  <string>/Users/lamis/my-agent/runs/launchd.out.log</string>
  <key>StandardErrorPath</key><string>/Users/lamis/my-agent/runs/launchd.err.log</string>
</dict>
</plist>
```

Load and test it:

```bash
launchctl load  ~/Library/LaunchAgents/com.acme.competitor-digest.plist
launchctl list | grep competitor-digest            # confirm it's registered
launchctl start com.acme.competitor-digest         # fire it once now, manually
# → check runs/<today>.md appeared and the digest is in outputs/
launchctl unload ~/Library/LaunchAgents/com.acme.competitor-digest.plist   # to stop/edit
```

`launchd` will also catch up a missed run if the Mac was asleep at the scheduled minute — a nice property of `StartCalendarInterval`.

`✅ 🗓️ scheduled → launchd com.acme.competitor-digest (Mondays 7:00 PT)`

### crontab (portable option)

`crontab -e`, then one line. Use absolute paths and pin `PATH` at the top of the crontab:

```cron
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
0 7 * * 1  cd /Users/lamis/my-agent && ./run.sh >> runs/cron.log 2>&1
```

`0 7 * * 1` = 07:00 every Monday, **in the machine's local timezone** (cron has no timezone field — it follows the system clock). Test immediately by running the exact line by hand: `cd /Users/lamis/my-agent && ./run.sh`.

### Claude Code's own scheduler (native route)

If the founder prefers not to touch cron/launchd, Claude Code can register a recurring run itself — describe the cadence and the task to `/schedule` and let it manage the timer. Same task text, same relative-date rule. (Depending on the setup, `/schedule` may run the agent as a managed/cloud routine rather than purely on-machine; `launchd`/`cron` is the route that keeps execution entirely local and key-free.)

### Cron / launchd gotchas (field-tested)

- **`claude` not on the cron PATH.** Cron and launchd run with a minimal environment, so the `claude` your interactive shell finds is invisible to them. Pin `PATH` (as above) or call `claude` by absolute path (`which claude` to find it). This is the #1 reason a schedule "didn't fire."
- **Relative working dir.** Cron starts in `$HOME`, not your project. `cd /abs/path/my-agent` (or `WorkingDirectory` in the plist, plus the `cd "$(dirname "$0")"` already in `run.sh`).
- **Always use absolute paths** for `run.sh`, the plist `ProgramArguments`, and any file the job reads.
- **DST.** `launchd`/cron fire at wall-clock time, so a 07:00 job stays 07:00 through a daylight-saving shift (the absolute time moves by an hour). For the weekly digest that's fine; note it if exact UTC timing ever matters.
- **Signed-in session.** The scheduled run uses the founder's existing Claude Code login. If they ever sign out, the headless run can't authenticate — re-running `claude` interactively once re-establishes the session.

## Troubleshooting quick hits

- **Agent didn't write the deliverable** → re-read the subagent body: does it say *write to `outputs/digest.md`* in plain words? Confirm `Write(./outputs/**)` is in `settings.json` `allow`. Re-run; if `run.sh` exits at the `test -s outputs/digest.md` line, the agent produced nothing — the instruction or the permission is the cause.
- **A tool got blocked / the run stalled on a prompt** → it's `settings.json`. Add the rule to `allow` (e.g. a new `WebFetch(domain:…)` or a `Bash(python3:*)`), or for a one-off headless run pass `--allowedTools`/`--permission-mode acceptEdits`. Remember `deny` beats `allow`.
- **Schedule didn't fire** → check `runs/launchd.err.log` (or `runs/cron.log`). Almost always `claude` isn't on the job's `PATH`, or the working dir is wrong. Pin `PATH`, use absolute paths, and `launchctl start` / run the cron line by hand to reproduce.
- **Grader disagrees with you** → the rubric is the contract. If the grader is too lenient, tighten the criterion wording in `outcome.md`; if too strict, the criterion is ambiguous — make it binary. Then re-grade. The grader only judges what `outcome.md` says.
- **Permission prompts in headless** → `claude -p` will stall waiting on a prompt that no human is there to answer. Either add the rule to `settings.json` `allow`, pass `--permission-mode acceptEdits` (or, fully unattended, `--dangerously-skip-permissions`), or scope `--allowedTools` to exactly what the run needs.
