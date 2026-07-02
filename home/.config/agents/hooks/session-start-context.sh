#!/usr/bin/env bash
# Emit compact cross-agent context for Claude/Codex SessionStart hooks.
# Read-only: never creates worktrees, never writes INBOX, never mutates ledgers.

set -uo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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

context="$(
  repo_name="$(main_repo_name 2>/dev/null || true)"
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -z "$repo_name" && -z "$git_root" ]]; then
    exit 0
  fi

  printf 'Agent session context (auto):\n'
  printf '  cwd: %s\n' "$PWD"
  [[ -n "$repo_name" ]] && printf '  repo: %s\n' "$repo_name"
  [[ -n "$git_root" ]] && printf '  git_root: %s\n' "$git_root"
  [[ -n "$branch" ]] && printf '  branch: %s\n' "$branch"

  if [[ -n "$git_root" ]]; then
    printf '\nWorktrees (fast list):\n'
    git worktree list --porcelain 2>/dev/null | awk '
      /^worktree / {
        path=$2
        name=path
        sub(/^.*\//, "", name)
        printf "  %s\n", name
      }
      /^branch / { printf "    %s\n", $0 }
    ' | head -30 || true
  fi

  if command_exists agent-review; then
    printf '\nReview ledgers:\n'
    if [[ "$repo_name" == "agents-config" ]]; then
      agent-review status --repo agents-config --compact 2>/dev/null | sed 's/^/  /' || true
    elif [[ -n "$git_root" ]]; then
      agent-review status --current --compact 2>/dev/null | sed 's/^/  /' || true
    else
      printf '  (no current repo namespace)\n'
    fi
  fi

  if [[ -n "$repo_name" ]] && command_exists agent-inbox; then
    printf '\nRecent INBOX (last 10):\n'
    agent-inbox --repo "$repo_name" --tail 10 2>/dev/null | sed 's/^/  /' || true
  fi
)"

[[ -n "${context//[[:space:]]/}" ]] || exit 0

python3 -c '
import json
import sys

print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": sys.stdin.read()[:6000],
  },
  "suppressOutput": True,
}))
' <<<"$context"
