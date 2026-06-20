#!/usr/bin/env bash
# no-api-key-guard.sh — keep this agent on your signed-in Claude Code session.
#
# This agent is designed to run with NO Anthropic API key: headless `claude -p`
# draws from your existing subscription, nothing billed per run. If an Anthropic
# API key / auth token is present (or a cloud-provider backend is selected),
# headless runs bill as API usage instead — silently — which is exactly the
# failure this guard prevents (see anthropics/claude-code issues #43333, #37686).
#
# Source it at the TOP of every unattended runner — run.sh, evals/run-evals.sh,
# any trigger/scheduled script — AFTER the `cd` into my-agent/ and BEFORE the
# first `claude` call. It prints a message and STOPS the run if it finds a key.
# Safe under `set -euo pipefail` (uses ${VAR:-}). Designed to be sourced.

_lya_guard_fail() {
  echo "🛑 launch-your-agent: refusing to run — Anthropic API credential detected." >&2
  echo "   $1" >&2
  echo >&2
  echo "   This agent runs on your signed-in Claude Code session with NO API key —"  >&2
  echo "   nothing billed per run. A key/token in the environment makes headless"     >&2
  echo "   'claude -p' bill as API usage instead (anthropics/claude-code #43333,"     >&2
  echo "   #37686). This fork never creates or installs an Anthropic key for you."     >&2
  echo >&2
  echo "   Fix: remove it, then re-run. To unset it for one run only:"                >&2
  echo "     env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN ./run.sh"               >&2
  echo "   Then confirm the run shows up on your subscription, NOT the API"           >&2
  echo "   dashboard at platform.claude.com."                                          >&2
  exit 1
}

# 1. Environment variables that divert off your subscription.
[ -n "${ANTHROPIC_API_KEY:-}" ]       && _lya_guard_fail "ANTHROPIC_API_KEY is set in the environment."
[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]    && _lya_guard_fail "ANTHROPIC_AUTH_TOKEN is set in the environment."
[ -n "${CLAUDE_CODE_USE_BEDROCK:-}" ] && _lya_guard_fail "CLAUDE_CODE_USE_BEDROCK is set (routes to AWS Bedrock, not your subscription)."
[ -n "${CLAUDE_CODE_USE_VERTEX:-}" ]  && _lya_guard_fail "CLAUDE_CODE_USE_VERTEX is set (routes to Google Vertex, not your subscription)."

# 2. A key 'installed' into the folder even if it was never exported.
#    (.env is for THIRD-PARTY connector tokens only — never an Anthropic key.)
for _lya_f in .env .claude/settings.json .claude/settings.local.json; do
  [ -f "$_lya_f" ] || continue
  if grep -qiE '^[[:space:]]*"?(ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN)"?[[:space:]]*[:=]' "$_lya_f"; then
    _lya_guard_fail "An Anthropic key/token is written into $_lya_f — remove it (this folder is key-free by design)."
  fi
done

unset -f _lya_guard_fail
unset _lya_f
