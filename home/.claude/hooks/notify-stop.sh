#!/bin/bash
# Claude Code Stop hook: notify when an agent finishes responding.
# Reads the hook payload from stdin (JSON); we only need cwd, which Claude
# Code also exposes via $CLAUDE_PROJECT_DIR / $PWD at exec time.
#
# Notifications are grouped per-project so repeated stops in the same repo
# replace the previous bubble instead of stacking.

set -u

project="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"

# Skip notifying if the focused window already belongs to the terminal — the
# user is watching, no need to bing. Best-effort; falls through on errors.
if command -v osascript >/dev/null 2>&1; then
  frontmost="$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
  case "$frontmost" in
    WezTerm | Alacritty | Terminal | iTerm2 | Ghostty) exit 0 ;;
  esac
fi

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "Claude · $project" \
    -message "session idle" \
    -sound Glass \
    -group "claude-$project" \
    -activate com.github.wez.wezterm >/dev/null 2>&1 || true
fi

exit 0
