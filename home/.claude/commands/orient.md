---
description: Orient at session start — survey worktrees, recent cross-agent activity, and pocketed work
argument-hint: (no arguments)
---

Before taking on substantive repo work, get a picture of what's in flight so
you don't duplicate work, lose track of a parallel worktree, or miss recent
activity from another agent.

Run these in parallel and report a synthesized summary to the user:

1. **Where am I right now**:

   ```bash
   pwd && git rev-parse --show-toplevel && git rev-parse --abbrev-ref HEAD
   ```

   If `show-toplevel` differs from the original repo path, call out that you
   are inside a worktree, not the main checkout.

2. **What worktrees exist for this repo, and what's their state**:

   ```bash
   agent-worktrees --status
   ```

   This shows per-worktree: time, ref, dirty/clean, ahead/behind, last commit,
   active tmux session, and CLI owner. Note any worktree whose branch or
   commit subject sounds related to the current task.

3. **Recent cross-agent activity (shared INBOX across all worktrees)**:

   ```bash
   agent-inbox --tail 30
   ```

   Lines are prefixed with `wt:<basename>` so you can see which checkout
   produced each status. Look for in-progress phases, blockers, or recent
   completions on related work.

4. **Stashed work that might be relevant**:

   ```bash
   git stash list
   ```

5. **Recently active branches across the whole repo**:

   ```bash
   git branch -a --sort=-committerdate --format='%(committerdate:short) %(refname:short) — %(subject)' | head -15
   ```

After running all five, deliver a synthesized one-paragraph summary to the
user covering:

- Where the agent currently sits (base repo vs. worktree, branch).
- How many worktrees exist; flag any whose branch name or last commit hints
  they overlap with the task the user is about to start.
- Anything notable from the INBOX (recent activity, in-flight phases, stale
  entries older than ~3 days).
- Stashes that look related, if any.

End the summary with a recommendation: **reuse an existing worktree**, **create
a new one** (and propose the type/slug), or **work in the current checkout**
(only if the user explicitly wants that or the work is trivial / read-only).

This command is read-only — it must not create worktrees, run cleanup, or
write to INBOX. The user invokes it when they want orientation; do not
auto-run it on every prompt.
