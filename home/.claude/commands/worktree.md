---
description: Create a new git worktree for the current task
argument-hint: <type/task-slug> [base-ref]
---

Use the `~/bin/agent-worktree` helper to create a dedicated worktree for the
current task. The argument should be `<type>/<slug>` where type is one of:
feat, fix, test, refactor, docs, chore, ci, perf, exp.

Run:

```bash
~/bin/agent-worktree --cli claude $ARGUMENTS
```

The helper prints the new worktree path on stdout and metadata
(branch, base ref, cli) on stderr. After creation:

1. Report the worktree path, branch name, and base ref to the user.
2. Suggest the next step: `cd <worktree-path>` from the user's tmux window,
   then start `claude --dangerously-skip-permissions` there if a separate
   agent session is needed.
3. Do not start editing until the user confirms.

If the user says just "make a worktree" without a type, default to `chore/`
and pick a slug from recent conversation context.
