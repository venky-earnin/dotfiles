# Agent Harness Hardening Design

Status: the July 2 hardening implementation was cross-CLI reviewed clean. Its
Git/GitHub approval gates were intentionally removed by developer direction on
July 10, 2026.

This note documents the July 2026 hardening pass for the local Claude Code +
Codex collaboration harness. It explains what changed, what the setup looked
like before, and why the enforcement model is different for Codex and Claude.

## July 10 Policy Update

Git and GitHub commands no longer require a separate client approval prompt
when they are within the scope of the developer's request. The Claude
`publish-guard.py` hook and `permissions.ask` entries were removed, and the
corresponding Codex execpolicy rules now return `allow`. The historical sections
below remain as a record of the earlier hardening design; this update supersedes
their publish-gating policy.

## July 16 Local Delete Safety Update

Local `rm` now resolves through `~/.local/bin/rm`, which accepts common removal
flags but moves targets with macOS `/usr/bin/trash`. The wrapper rejects unknown
or interactive options, refuses `/`, the home directory, and the current
working directory, and fails if Trash is unavailable. Shared agent instructions
forbid permanent-delete bypasses; Claude deny rules and Codex execpolicy rules
also forbid direct `/bin/rm` and `/usr/bin/rm` commands.

## Current State

- The hardening ledger is `reviewed_no_blockers`.
- Codex hook trust was verified by the developer through `/hooks` after the
  hardening pass.
- Git/GitHub writes are not permission-gated in either client.
- Local shell deletion is recoverable by default in both clients.

## Decision Summary

Before this hardening pass, the harness relied too much on instruction files and
some permissive client rules. Now the split is deliberate:

- Instruction files (`AGENTS.md`, `CLAUDE.md`) describe defaults and workflow.
- `agent-review` owns local review state, snapshots, stale checks, and event
  logging.
- Codex Git/GitHub rules explicitly allow in-scope commands.
- Claude has no Git/GitHub `permissions.ask` rules or publish guard hook.
- Cross-agent adherence is audited from `agent-review-events.jsonl`, not inferred
  from chat history.

## Problem

The collaboration workflow depended on the right idea but had one weak layer:
important rules were written as instructions, while some client permission files
still allowed the very actions those instructions said should require explicit
human approval.

The intended policy was:

- Local implementation and local review are the default.
- Agents should use `agent-review` before pushing or opening a PR.
- Agents should not push, create PRs, mutate PRs, or merge unless the developer
  explicitly approves the exact action.
- Both Claude and Codex should load the same workflow contract from
  `~/.config/agents/AGENTS.md`.

The gap was that `AGENTS.md` is guidance, not enforcement. Both vendors document
that durable instruction files shape model behavior but do not guarantee it.
Hard guarantees must be implemented through client permissions, rules, hooks,
or the local helper tools themselves.

## Before

The old setup had useful coordination primitives:

- `~/.config/agents/AGENTS.md` was shared by both CLIs.
- Claude loaded it through `~/.claude/CLAUDE.md`.
- Codex loaded it through `~/.codex/AGENTS.md`.
- `agent-review` provided durable local review ledgers under
  `~/.config/agents/reviews/<repo>/<task-key>/`.
- Shared hooks injected session context and recall reminders.
- `COLLABORATION.md` documented the broader developer and agent journeys.

But enforcement and measurement were incomplete:

- Claude settings had a broad allow rule for `Bash(gh pr *)`.
- Codex rules had `allow` entries for `git push`, `git merge`,
  `gh pr create`, and some PR-editing `gh api` commands.
- There was no clean adherence log for `agent-review`; the Claude audit log
  could miss wrapped commands and Codex activity was not directly countable.
- Codex hook trust was not proven. Codex command hooks require explicit trust
  through `/hooks`; untrusted or changed hooks can be skipped.

This meant the model was instructed not to publish by default, but the client
layer could still silently allow publish-sensitive commands.

## Design

The hardened design splits responsibilities by enforcement strength.

| Layer | Purpose | Enforced by |
| --- | --- | --- |
| `AGENTS.md` | Shared workflow contract and defaults | Context loaded by both CLIs |
| `agent-review` | Durable local review state and stale/dirty snapshot checks | Local tool logic |
| `agent-review-events.jsonl` | Measurement of real workflow usage | Local tool self-logging |
| Claude publish guard | Prompt before publish/PR mutations | Claude PreToolUse hook plus permission rules |
| Codex rules | Prompt before publish/PR mutations | Codex execpolicy |
| Hooks | Context injection, recall, reminders, selected blocking | CLI hook systems |
| Human approval | Final authority for push, PR, merge, deploy | Developer |

The key principle: rules that must hold move out of prose and into a tool,
permission rule, hook, or policy check. Prose remains useful for defaults,
judgment, and workflows that cannot be mechanically decided.

## What Changed

### 1. Codex publish actions now prompt

File: `~/.codex/rules/default.rules`

Changed from silent `allow` to `prompt` for:

- `git push`
- `git merge`
- `gh pr create`
- `gh pr edit`
- `gh pr merge`
- `gh pr ready`
- `gh pr close`
- `gh pr comment`
- `gh api -X POST`
- `gh api -X PUT`
- `gh api -X PATCH`
- `gh api -X DELETE`

Read-only PR inspection remains allowed, for example `gh pr view`.

Why: Codex rules are the right Codex-side enforcement layer for shell command
approval. This makes publish-sensitive commands visible to the developer instead
of relying on the model to remember "do not push yet."

### 2. Claude publish actions now ask through PreToolUse

Files:

- `~/.config/agents/hooks/publish-guard.py`
- `~/.claude/settings.json`

Removed:

```json
"Bash(gh pr *)"
```

Added `permissions.ask` rules for:

- `Bash(git push:*)`
- `Bash(git merge:*)`
- `Bash(gh pr create:*)`
- `Bash(gh pr merge:*)`
- `Bash(gh pr ready:*)`
- `Bash(gh pr close:*)`
- `Bash(gh pr edit:*)`
- `Bash(gh pr comment:*)`
- `Bash(gh api -X POST:*)`
- `Bash(gh api -X PUT:*)`
- `Bash(gh api -X PATCH:*)`
- `Bash(gh api -X DELETE:*)`

Added a Claude `PreToolUse(Bash)` hook:

```text
~/.config/agents/hooks/publish-guard.py
```

The hook returns `permissionDecision: "ask"` for publish-sensitive Bash
commands, including:

- `git push`
- `git -C <repo> push`
- `git merge`
- `gh pr create/edit/merge/ready/close/comment`
- `gh api -X POST|PUT|PATCH|DELETE`
- `gh api --method POST|PUT|PATCH|DELETE`
- write-style `gh api` calls that use `-f`, `-F`, `--field`, `--raw-field`, or
  `--input`
- shell-wrapped forms such as `body=$(cat file); gh api ... -f title=x`

Why: Claude Code supports client-level permission rules, but the live config
also uses `defaultMode: "auto"` and `skipAutoPermissionPrompt: true`. The
PreToolUse hook is a stronger, mode-independent enforcement point for this
policy. The `permissions.ask` entries stay as defense in depth and as readable
policy in the Claude settings file.

### 3. `agent-review` now self-logs mutating workflow events

File: `~/.config/agents/bin/agent-review`

New log:

```text
~/.config/agents/logs/agent-review-events.jsonl
```

Logged commands:

- `init`
- `resolve`
- `snapshot`
- `request`
- `post`
- `addressed`
- `migrate`

Each event records timestamp, CLI, command, cwd, argv, outcome, exit code, and
ledger context when available. `status` is intentionally not logged to avoid
dashboard/read-only noise.

Why: adherence should be measured by tool usage, not inferred from chat history
or a truncated shell audit log. The log lets us ask, "did this feature actually
go through the local review workflow?"

### 4. `AGENTS.md` documents the enforceable layer

File: `~/.config/agents/AGENTS.md`

Added:

- the event log location,
- the expectation that adherence should be audited from the log,
- the Codex `/hooks` trust requirement,
- and the fact that publish actions are permission-gated.

Why: future agents need to understand that the workflow is not only a prose
rule. The source of truth for coordination is still `agent-review`, while the
publish boundary is enforced by Codex rules and the Claude PreToolUse guard.

## Codex-Specific Notes

Codex has three relevant surfaces:

- `AGENTS.md` for durable guidance,
- `hooks.json` for lifecycle hook scripts,
- `rules/default.rules` plus sandbox/approval policy for command approval.

Important behavior:

- User-level `~/.codex/AGENTS.md` loads the shared instructions.
- Codex command hooks must be trusted in `/hooks`; changed hooks need renewed
  trust.
- Rules apply to command argument lists. Codex can split simple shell wrappers,
  but complex shell scripts may be evaluated as the wrapper command itself.
- `codex execpolicy check` is the verification tool for rule decisions.

Hook trust status:

```text
/hooks
```

The developer verified/trusted the shared hooks through `/hooks` after this
hardening pass. Re-run `/hooks` after future Codex hook command changes because
trust is tied to the current hook definition.

## Claude-Specific Notes

Claude has three relevant surfaces:

- `CLAUDE.md` imports the shared `AGENTS.md`,
- `settings.json` contains client permissions and hooks,
- hooks can inject context or block selected actions depending on hook event and
  exit/response contract.

Important behavior:

- Claude reads `CLAUDE.md` / imported `AGENTS.md` as context.
- `publish-guard.py` is the primary publish-sensitive enforcement point. It
  emits `permissionDecision: "ask"` for commands that may push, merge, create a
  PR, mutate a PR, or write through `gh api`.
- `permissions.ask` is defense in depth and readable policy for the same class
  of actions.
- Broad `Bash(gh pr *)` allow rules are too permissive for this workflow.

## Validation

The hardening pass was validated with:

```text
python3 ~/.config/agents/tests/test_agent_review.py
python3 ~/.config/agents/tests/test_agent_hooks.py
python3 -m py_compile ~/.config/agents/bin/agent-review ~/.config/agents/hooks/publish-guard.py ~/.config/agents/tests/test_agent_review.py ~/.config/agents/tests/test_agent_hooks.py
jq empty ~/.claude/settings.json ~/.codex/hooks.json
bash -n ~/.config/agents/hooks/*.sh ~/bin/agent-worktree ~/bin/agent-worktrees ~/bin/agent-tmp ~/bin/agent-dashboard
codex execpolicy check --rules ~/.codex/rules/default.rules -- git push origin HEAD
codex execpolicy check --rules ~/.codex/rules/default.rules -- gh pr create --draft
codex execpolicy check --rules ~/.codex/rules/default.rules -- gh pr view 123
codex execpolicy check --rules ~/.codex/rules/default.rules -- gh api -X PATCH repos/example-org/example-repo/pulls/1 -f title=x
```

Expected policy results:

- `git push` -> `prompt`
- `git merge` -> `prompt`
- `gh pr create` -> `prompt`
- `gh pr merge` -> `prompt`
- `gh pr edit` -> `prompt`
- write-style `gh api` -> `prompt`
- `gh pr view` -> `allow`

Expected Claude hook results:

- `git push origin HEAD` -> `permissionDecision: ask`
- `git -C /tmp/repo push origin HEAD` -> `permissionDecision: ask`
- `gh pr create --draft` -> `permissionDecision: ask`
- `gh pr merge 123 --squash` -> `permissionDecision: ask`
- `gh api -X PATCH ... -f title=x` -> `permissionDecision: ask`
- `gh api --method DELETE ...` -> `permissionDecision: ask`
- `body=$(cat file); gh api ... -f title=x` -> `permissionDecision: ask`
- `gh pr view 123 --json title` -> silent
- `git status --short` -> silent

## Remaining Gaps

This hardening pass does not claim perfect enforcement of every collaboration
judgment step. The following are still intentionally handled by workflow and
tool behavior:

- choosing the right feature slug,
- deciding when a change is substantive enough for a worktree,
- deciding the right reviewer,
- selecting the right project verification gate,
- and resolving ambiguous ledgers.

Where these become recurring failure modes, the next step should be another
tool or policy change, not more prose.

Known follow-up:

- Consider adding a small audit command that compares recent branches/worktrees
  against `agent-review-events.jsonl` and reports features without ledgers.
- Optionally perform one Claude live sanity check with `git push --dry-run`,
  then deny/abort at the prompt.

## References

- OpenAI Codex `AGENTS.md`: https://developers.openai.com/codex/guides/agents-md
- OpenAI Codex hooks: https://developers.openai.com/codex/hooks
- OpenAI Codex rules: https://developers.openai.com/codex/rules
- OpenAI Codex approvals/security: https://developers.openai.com/codex/agent-approvals-security
- Anthropic Claude Code memory: https://docs.anthropic.com/en/docs/claude-code/memory
- Anthropic Claude Code hooks: https://docs.anthropic.com/en/docs/claude-code/hooks
