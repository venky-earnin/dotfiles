#!/usr/bin/env bash
# Stop hook: remind the agent about pending local-review handoff state.
# Read-only and quiet unless a ledger is blocked, requested, or needs re-review.

set -uo pipefail

command -v agent-review >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"

if command -v jq >/dev/null 2>&1 && [[ -n "$payload" ]]; then
  stop_hook_active="$(printf '%s' "$payload" | jq -r '.stop_hook_active // .stopHookActive // false' 2>/dev/null || printf 'false')"
  [[ "$stop_hook_active" == "true" ]] && exit 0
fi

main_repo_name() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local common_dir
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common_dir" ]]; then
      basename "$(dirname "$common_dir")"
      return 0
    fi
    basename "$(git rev-parse --show-toplevel 2>/dev/null)"
    return 0
  fi

  local config_home="${AGENTS_CONFIG_HOME:-$HOME/.config/agents}"
  local pwd_physical
  pwd_physical="$(pwd -P 2>/dev/null || printf '%s' "$PWD")"
  if [[ -d "$config_home" ]]; then
    config_home="$(cd "$config_home" 2>/dev/null && pwd -P || printf '%s' "$config_home")"
  fi
  case "$pwd_physical" in
    "$config_home" | "$config_home"/*)
      printf 'agents-config\n'
      return 0
      ;;
  esac
  return 1
}

repo_name="$(main_repo_name 2>/dev/null || true)"
[[ -n "$repo_name" ]] || exit 0

status="$(agent-review status --repo "$repo_name" --compact 2>/dev/null || true)"
[[ -n "$status" ]] || exit 0

pending="$(printf '%s\n' "$status" | grep -E '^(blocked|review_requested|addressed_needs_rereview)' || true)"
[[ -n "$pending" ]] || exit 0

# Codex currently accepts SessionStart context output but marks Stop hook output
# as failed. Until Codex documents a Stop output contract, keep this hook silent
# for Codex. Claude gets a passive systemMessage rather than additionalContext,
# so the reminder does not continue the conversation.
if [[ -z "${CLAUDE_PROJECT_DIR:-}" && "${AGENT_HOOK_ALLOW_STOP_CONTEXT:-}" != "1" ]]; then
  exit 0
fi

ctx="Local review handoff reminder (auto):
$(printf '%s\n' "$pending" | head -20)

Use agent-review for the next handoff. Reviewers should post findings with agent-review post; implementers should snapshot, mark addressed, and request re-review."

python3 -c '
import json
import sys

print(json.dumps({
  "systemMessage": sys.stdin.read()[:4000],
  "suppressOutput": True,
}))
' <<<"$ctx"
