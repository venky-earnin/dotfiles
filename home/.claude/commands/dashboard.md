---
description: Open the multi-agent visibility dashboard (worktrees + inbox + tmux sessions)
---

Run `~/bin/agent-dashboard`. This opens (or attaches to) a tmux session named
`agents-dashboard` with three live panes:

- top-left:  `agent-worktrees --status` refreshing every 15s
- top-right: `tail -F` of shared INBOX files under `~/.config/agents/inbox`
- bottom:    `tmux list-sessions` refreshing every 5s

After launching, report the tmux session name to the user.
