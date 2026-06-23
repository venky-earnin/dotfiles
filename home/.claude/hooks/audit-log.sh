#!/bin/bash
# Claude Code PreToolUse hook: append-only audit log of tool invocations.
# Useful for "what did the agent do at 3am" forensics. Reads JSON from stdin.

set -u

LOG_FILE="${HOME}/.claude/audit.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Best-effort parse; jq is preferred but we fall back to a regex if missing.
if command -v jq >/dev/null 2>&1; then
  payload="$(cat)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // "?"' 2>/dev/null)"
  session="$(printf '%s' "$payload" | jq -r '.session_id // "?"' 2>/dev/null | cut -c1-8)"
  project="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
  # Compact tool input — first 200 chars of JSON, single line.
  input="$(printf '%s' "$payload" | jq -c '.tool_input // {}' 2>/dev/null | head -c 200)"
  printf '%s session=%s project=%s tool=%s input=%s\n' \
    "$ts" "$session" "$project" "$tool" "$input" >>"$LOG_FILE"
else
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  project="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
  printf '%s project=%s (jq not installed; tool/input omitted)\n' \
    "$ts" "$project" >>"$LOG_FILE"
fi

# Rotate at 5 MiB (keep one prior generation).
if [[ -f "$LOG_FILE" ]]; then
  size="$(stat -f %z "$LOG_FILE" 2>/dev/null || echo 0)"
  if [[ "$size" -gt 5242880 ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
  fi
fi

exit 0
