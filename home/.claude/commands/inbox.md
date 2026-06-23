---
description: Read or append to the shared agent INBOX for cross-agent status visibility
argument-hint: [message to append, or --tail to read]
---

Cross-agent status board. Each running agent appends one-line snapshots at
phase boundaries (entering edit phase, kicking off long-running command,
finishing, blocking). Other agents (and the human) can read it without
context-switching tmux.

Behavior:

- If `$ARGUMENTS` starts with `--tail`, run `~/bin/agent-inbox --tail 20` and
  show the output to the user.
- If `$ARGUMENTS` is empty, default to showing the last 20 lines.
- Otherwise treat `$ARGUMENTS` as the status message and append it with
  `~/bin/agent-inbox "$ARGUMENTS"`.

The helper auto-formats lines as `[timestamp session branch wt:<worktree>] message`.
Storage lives under `~/.config/agents/inbox/<repo>/INBOX.md`, shared across a
repo's base checkout and worktrees.
