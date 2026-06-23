#!/bin/bash
# Claude Code Notification hook: desktop notification for permission prompts
# and waiting-for-input events. Parity with Codex's notify config.

set -u

payload="$(cat 2>/dev/null || true)"
project="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"

# Skip if a terminal app is frontmost (you're watching).
if command -v osascript >/dev/null 2>&1; then
  frontmost="$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
  case "$frontmost" in
    WezTerm | Alacritty | Terminal | iTerm2 | Ghostty) exit 0 ;;
  esac
fi

message="needs input"
if command -v jq >/dev/null 2>&1; then
  reason="$(printf '%s' "$payload" | jq -r '.message // .reason // ""' 2>/dev/null)"
  [[ -n "$reason" ]] && message="$reason"
fi

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "Claude · $project" \
    -message "$message" \
    -sound Tink \
    -group "claude-notify-$project" \
    -activate com.github.wez.wezterm >/dev/null 2>&1 || true
fi

exit 0
