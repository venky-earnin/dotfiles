#!/usr/bin/env bash
# session-start-orient.sh — emit a short orient summary as additionalContext.
# Read-only: never creates worktrees, never writes INBOX, never mutates state.
# Skipped silently outside git repos.

set -euo pipefail

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
wt_basename="$(basename "$repo_root")"

context="$(
  printf 'Session orientation (auto):\n'
  printf '  cwd: %s\n' "$repo_root"
  printf '  branch: %s\n' "$branch"
  printf '  worktree: %s\n\n' "$wt_basename"
  printf 'Worktrees for this repo:\n'
  agent-worktrees --status 2>/dev/null | sed 's/^/  /' | head -40 || true
  printf '\nRecent INBOX (last 10):\n'
  agent-inbox --tail 10 2>/dev/null | sed 's/^/  /' || true
)"

python3 -c '
import json, sys
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": sys.stdin.read()
  }
}))
' <<<"$context"
