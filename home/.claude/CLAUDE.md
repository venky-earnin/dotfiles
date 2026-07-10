# Claude global config

Shared agent rules — same for Codex and any other agent — live at the neutral
location below. Import them first; Claude-specific addendum follows.

@~/.config/agents/AGENTS.md

## Claude-specific addendum

The rules above are CLI-agnostic. The rules below apply only to Claude Code
(this CLI, including sub-agents spawned via the Agent tool and Skills).

### Tool selection

- Prefer dedicated tools over Bash when one fits: `Read` over `cat`, `Edit`
  over `sed`/`awk`, `Write` over `echo >` for new files. Bash is for shell-only
  operations.
- Use the Agent tool with specialized sub-agents for:
  - Open-ended codebase exploration spanning many files (`Explore` agent).
  - Independent parallel queries that don't depend on each other.
  - Protecting the main context window from huge tool results (logs, dumps).
- Do NOT delegate to a sub-agent when a direct grep/read would answer the
  question — it adds latency and indirection.
- When delegating, brief the sub-agent like a colleague who just walked in:
  state the goal, list what to check, cap response length. Never write "based
  on your findings, do X" — that pushes synthesis onto the sub-agent.

### Parallel tool calls

When multiple tool calls have no dependency between them, batch them in a
single message. Example: reading three files in parallel, or running
`git status` + `git diff` + `git log` together. Sequential only when the next
call needs output from the previous one.

### Plan mode

Use plan mode (`/plan`) for substantive implementation work the user hasn't
explicitly approved yet. Exit with `ExitPlanMode` after presenting the plan.
Do NOT use `AskUserQuestion` to ask "is the plan ready?" — that's what
`ExitPlanMode` is for. Use `AskUserQuestion` for substantive clarifications
the user needs to answer before the plan is finalized.

### Memory rules

Use the file-based memory system at
`~/.claude/projects/<project>/memory/` for per-project context:

- **user** memories — role, preferences, knowledge level.
- **feedback** memories — corrections and validated patterns. Save both
  corrections ("don't do X") and confirmations ("X was the right call").
  Include the *why*.
- **project** memories — ongoing initiatives, decisions, deadlines. Convert
  relative dates to absolute.
- **reference** memories — pointers to external systems (Linear, Slack,
  Grafana).

Do NOT save: code patterns derivable by reading the code, git history,
debugging recipes, anything in CLAUDE.md, ephemeral task state.

For cross-project reusable patterns, append to
`~/.config/agents/LEARNINGS.md` instead — see global AGENTS.md.

### Slash commands

Common workflow commands live in `~/.claude/commands/`:

- `/worktree <type/slug>` — create a dedicated worktree for the current repo.
  Wraps `agent-worktree`; start any separate tmux/agent session manually.
- `/pr <title>` — open a PR from the current worktree branch using the global
  PR-style rules.
- `/recall <keyword|error>` — search `~/.config/agents/LEARNINGS.md` for
  relevant prior fixes. Treat hits as direction to try, not gospel.
- `/learn <title>` — append a terse durable learning entry. Use after
  spending meaningful time solving a non-obvious problem.
- `/inbox` — read and append to `.agents/INBOX.md` for cross-agent status.
- `/dashboard` — open the multi-agent visibility tmux session.

### Hook behavior

The following hooks are configured in `~/.claude/settings.json`:

- `Stop` → `~/.claude/hooks/notify-stop.sh` — desktop notification when a
  turn ends.
- `PreToolUse` → `~/.claude/hooks/audit-log.sh` — append-only audit log of
  tool invocations at `~/.claude/audit.log`. Useful for "what did the agent do
  at 3am" forensics.
- `PostToolUse(Bash)` → `~/.config/agents/hooks/recall-on-error.sh` — when a command
  fails with a real error signature, search durable learnings and inject
  matching hints back into context.
- `SessionStart` → `~/.config/agents/hooks/session-start-context.sh` — inject
  compact worktree, INBOX, and review-ledger context when a session starts in a
  supported repo or the shared agent config namespace.
- `Notification` → `~/.claude/hooks/notify.sh` — parity with Codex's notify
  config for waiting-for-input events.

### End-of-turn etiquette

- One- or two-sentence summary at end of turn. State what changed and what's
  next. No headers, no recap.
- Reference code locations as `file_path:line_number`.
- Do not narrate internal deliberation. State results and decisions directly.

### Memory promotion targets

When a piece of memory turns out to apply across all projects (not just this
one), promote it to `~/.config/agents/AGENTS.md`. When it becomes a recurring
workflow, promote it to a `skills/*/SKILL.md` file. The memory file should
note its promotion target in its body.
