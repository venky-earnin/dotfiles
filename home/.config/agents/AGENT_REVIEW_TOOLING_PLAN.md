# AGENT_REVIEW_TOOLING_PLAN.md - implementation plan

**Status:** DRAFT for cross-agent review
**Owner:** Codex
**Date:** 2026-07-01
**Scope:** Build the local collaboration harness so Claude Code and Codex follow
the agreed implement -> review -> address -> re-review workflow with minimal
manual ceremony and without repeated worktree/artifact copying.

This document is the review artifact for the tooling implementation. It should
be reviewed the same way as `COLLABORATION.md`: immutable local snapshot,
review note in `~/.config/agents/reviews/...`, source untouched by reviewers.

---

## 1. User decisions already made

These are treated as fixed inputs:

- Tooling lives under `~/.config/agents/bin/`, with user-facing commands
  symlinked into `~/bin`.
- Existing helpers may keep their current `~/bin` entrypoints, but new shared
  implementation code should live under `~/.config/agents/bin/` or
  `~/.config/agents/hooks/` and be symlinked outward. Do not move the existing
  helpers as part of Phase 1 unless needed for a specific fix.
- Main helper name: `agent-review`.
- Main helper interface:
  `agent-review init|resolve|snapshot|request|post|addressed|status|path|migrate`.
- The helper does **not** auto-commit tracked code. A tracked-code review target
  is an existing commit SHA. Dirty tracked files block review by default.
- Dirty/uncommitted tracked-code review is disallowed by default. It requires an
  explicit emergency mode such as `--dirty-copy`.
- Ignored/untracked artifacts are copied only when explicitly passed, and the
  copy path must be fast and deduped by checksum.
- Stable rules should be promoted into `~/.config/agents/AGENTS.md`, which Codex
  reads via `~/.codex/AGENTS.md` and Claude reads via `~/.claude/CLAUDE.md`.
- Once `agent-review` exists, Claude and Codex must use it. Manual ledger writes
  are fallback only.
- Status/dashboard should be shared. Start with `agent-review status --all`,
  then integrate a compact view into `agent-worktrees --status`.

---

## 2. Official-doc constraints

The implementation should stay inside documented extension points:

- Codex reads `AGENTS.md` at startup and layers global plus project instructions.
  The current symlink `~/.codex/AGENTS.md -> ~/.config/agents/AGENTS.md` is the
  correct global guidance path.
  Source: https://developers.openai.com/codex/guides/agents-md
- Codex supports lifecycle hooks from `~/.codex/hooks.json`, `~/.codex/config.toml`,
  and trusted project `.codex/` layers. Hooks require trust review when changed.
  Source: https://developers.openai.com/codex/hooks
- Codex app worktrees are Git worktrees and only exist for Git repositories.
  Non-git roots require direct-directory or artifact-ledger handling.
  Source: https://developers.openai.com/codex/app/worktrees
- Claude Code `CLAUDE.md` and memory are context, not hard enforcement. Use
  hooks for deterministic guardrails.
  Source: https://code.claude.com/docs/en/memory
- Claude Code hooks are deterministic lifecycle commands configured in
  `~/.claude/settings.json` or project settings.
  Sources: https://code.claude.com/docs/en/hooks and
  https://code.claude.com/docs/en/hooks-guide

Current local state:

- `~/.claude/CLAUDE.md` imports `@~/.config/agents/AGENTS.md`.
- `~/.codex/AGENTS.md` is a symlink to `~/.config/agents/AGENTS.md`.
- Claude already has hooks for `SessionStart`, `PreToolUse`, `PostToolUse(Bash)`,
  `Stop`, and `Notification`.
- Codex currently has `notify` configured but no visible `~/.codex/hooks.json`
  or inline `[hooks]` table in `~/.codex/config.toml`.

---

## 3. Core invariant: no repeated copying

The harness must make the cheap path the default:

```text
Tracked repo work:
  snapshot = commit SHA + metadata
  durable copied files = none
  optional review checkout = disposable Git worktree only when requested

Ignored/untracked artifact:
  snapshot = artifact checksum + provenance
  durable copied files = explicit artifact only, content-addressed and deduped

Non-git config/doc root:
  snapshot = explicit artifact checksum + provenance
  durable copied files = explicit source artifact only
```

Rules:

- Never copy a whole worktree to create a review snapshot.
- Never copy tracked files for normal code review. Store commit SHA, base ref,
  `git status`, and optional `diff.patch`.
- Do not create a detached review worktree unless a reviewer explicitly needs a
  filesystem checkout. Prefer `git show`, `git diff <base>..<sha>`, and direct
  file extraction for review.
- For artifacts, require explicit `--artifact <path>` or explicit
  `--artifact-dir <path>`. No implicit directory sweep.
- Artifact storage is content-addressed:

```text
~/.config/agents/reviews/<repo>/<task-key>/
  artifacts/
    by-sha256/
      <sha256>/
        <safe-original-basename>
  snapshots/
    001-<timestamp>-<shortsha-or-local>/
      snapshot.json
      git-status.txt
      diff.patch
      artifacts.json
```

- If the same artifact checksum appears in a later cycle, do not copy it again.
  Reuse the existing content-addressed artifact and point the new snapshot at it.
- For large explicit artifact directories, hash files first, copy only new
  checksums, and record `truncated=true` if size/file caps are hit.

Compatibility with current ledgers:

- Existing review ledgers already on disk use the older layout:
  `snapshots/<snapshot-id>/artifacts/<file>` plus `checksums.sha256`.
- Phase 1 must read both layouts. `status`, `resolve`, `post`, and `addressed`
  cannot assume every historical snapshot has `artifacts.json` or
  `artifacts/by-sha256/`.
- New snapshots must use the content-addressed layout.
- Add `agent-review migrate --dry-run` and `agent-review migrate --apply` for
  existing ledgers. Migration hashes legacy artifact files, moves them into
  `artifacts/by-sha256/<sha256>/` when safe, otherwise copies only when required
  for compatibility, writes `artifacts.json`, and leaves a backward-compatible
  `checksums.sha256`. Dry-run is the default behavior when no flag is passed.

---

## 4. Ledger data model

Canonical path:

```text
~/.config/agents/reviews/<repo>/<task-key>/
  task.json
  snapshots/
  reviews/
  resolutions/
  artifacts/by-sha256/
  checkouts/
  .lock
```

`task.json` fields:

```json
{
  "schema_version": 1,
  "repo": "example-repo",
  "repo_root": "/abs/path/to/repo",
  "title": "natural language title",
  "type_slug": "feat/example",
  "task_key": "feat-example",
  "owner_cli": "codex",
  "owner_worktree": "/abs/path/to/repo/.worktrees/feat-example",
  "owner_branch": "feat/example",
  "base_ref": "main",
  "source_paths": [],
  "latest_snapshot_id": "001-20260701T000000Z-abc1234",
  "latest_snapshot_sha": "abc1234...",
  "latest_artifact_revision": null,
  "latest_review_path": null,
  "latest_resolution_path": null,
  "review_state": "initialized",
  "current_blocker_count": null,
  "verification": {
    "required": true,
    "last_command": null,
    "last_status": null,
    "last_ran_at_utc": null
  },
  "last_updated_utc": "2026-07-01T00:00:00Z",
  "notes": ""
}
```

Review states:

- `initialized`
- `implementation_in_progress`
- `review_requested`
- `review_posted`
- `addressed_needs_rereview`
- `reviewed_no_blockers`
- `blocked`
- `published`
- `closed`

Locking:

- Every write command takes an exclusive lock on `.lock`.
- Writes are atomic: write temp file in same directory, then `rename`.
- If a manual edit is detected while the lock is held, fail loud.

---

## 5. `agent-review` command contract

Implementation language: Python 3 stdlib in a single executable script at
`~/.config/agents/bin/agent-review`, symlinked to `~/bin/agent-review`.

Python is preferred over shell here because the helper owns JSON, checksums,
locking, atomic writes, and cross-platform-ish path handling. Keep the script
dependency-free.

### `agent-review init`

Purpose: create or resume a ledger.

Shape:

```bash
agent-review init \
  --title "Add local review snapshots" \
  --type-slug feat/local-review-snapshots \
  --owner-cli codex \
  [--repo <namespace>] \
  [--source <path>] \
  [--base-ref HEAD]
```

Behavior:

- Resolve `<repo>`:
  - Git repo: git top-level basename.
  - Non-git root: require `--repo`; do not guess from basename if ambiguous.
- Resolve `task-key` from existing ledgers first:
  - Search `~/.config/agents/reviews/<repo>/*/task.json`.
  - Match on `title`, `task_key`, `type_slug`, source path, owner branch, and
    owner worktree.
  - If exactly one match exists, print it and resume.
  - If multiple matches exist, fail and list candidates.
  - If none exists, create `task-key` from `type_slug` by replacing `/` with `-`.
- Write `task.json` and set state to `initialized`.

### `agent-review resolve`

Purpose: natural-language entry point for fresh sessions.

```bash
agent-review resolve "local review snapshots feature"
agent-review resolve feat/local-review-snapshots
```

Behavior:

- Searches all repo namespaces unless `--repo` is passed.
- Prints exactly one resolved ledger path or fails loud with candidates.
- Does not write state.

### `agent-review snapshot`

Purpose: create immutable review target.

```bash
agent-review snapshot [--task-key <key>] [--verify "<cmd>"] \
  [--artifact <path> ...] [--artifact-dir <path>]
```

Git behavior:

- If inside a Git repo, detect tracked dirty state.
- If tracked files are dirty, exit non-zero with:
  "dirty tracked files; commit or amend before review".
- Do **not** commit automatically.
- Use `HEAD` as the snapshot commit.
- Snapshot id shape:
  `NNN-YYYYMMDDTHHMMSSZ-<shortsha>`.
- Store:
  - `snapshot.json`
  - `git-status.txt`
  - `diff.patch` from the configured base to `HEAD` when base is known
  - no copied tracked files

Artifact behavior:

- Copy only paths explicitly passed with `--artifact` or `--artifact-dir`.
- Hash before copy.
- Store new content under `artifacts/by-sha256/<sha256>/`.
- If checksum already exists, skip copy and reference existing path.
- `--artifact-dir` must be explicit and should have conservative defaults:
  max 500 files, max 250 MB, deterministic sorted traversal, skip hidden cache
  directories unless explicitly included.
- `--dirty-copy` is an emergency escape hatch and must record dirty status,
  dirty diff, and command provenance. It is never default.

Non-git behavior:

- Require at least one explicit `--artifact`.
- Snapshot id shape:
  `NNN-YYYYMMDDTHHMMSSZ-local`.
- Store checksum/provenance and update `task.json`.

Verification:

- If `--verify` is passed, run command with captured output path.
- Store command, exit code, duration, and output file path in `snapshot.json`.
- A failing verification does not disappear; it sets
  `verification.last_status = "failed"` and `review_state` remains
  `implementation_in_progress` unless `--request-anyway` is explicit.

### `agent-review request`

Purpose: mark latest snapshot ready for review.

```bash
agent-review request [--reviewer claude|codex] [--message "..."]
```

Behavior:

- Requires a latest snapshot.
- Requires clean verification if the task has verification required, unless
  `--request-anyway --reason "..."` is passed.
- Refuses when `current_blocker_count > 0` unless a newer snapshot and
  resolution file exist.
- Sets `review_state=review_requested`.
- Posts INBOX pointer if `agent-inbox` supports the namespace.
- For non-git namespaces, writes the pointer fields into `task.json` and records
  that INBOX was skipped; never hand-edits INBOX.

### `agent-review post`

Purpose: reviewer records findings without editing implementation files.

```bash
agent-review post \
  --reviewer claude \
  --snapshot latest \
  --blockers 2 \
  --file /path/to/review.md
```

Behavior:

- Assigns `rNNN` monotonically per ledger by scanning existing `reviews/r*.md`,
  taking the highest numeric prefix, adding one, and zero-padding to three
  digits. Never reuse a number after deletion.
- Refuses stale snapshot unless `--stale-ok` is explicit. A review is stale when
  the reviewed `snapshot_id` differs from `task.json.latest_snapshot_id`.
- Copies or moves the review file into `reviews/` using the canonical name:
  `rNNN-<snapshot-id>-<reviewer>-<timestamp>.md`.
- Updates `task.json`:
  - `latest_review_path`
  - `current_blocker_count`
  - `review_state=blocked` when `blockers > 0`
  - `review_state=reviewed_no_blockers` when `blockers == 0`
- Posts INBOX pointer where supported; otherwise task.json is the pointer.

### `agent-review addressed`

Purpose: implementer records resolution and requests re-review.

```bash
agent-review addressed \
  --review rNNN \
  --file /path/to/resolution.md
```

Behavior:

- Stores canonical resolution:
  `rNNN-<reviewed-snapshot-id>-addressed-<implementer>-<timestamp>.md`.
- Requires a newer snapshot than the reviewed snapshot before setting
  `addressed_needs_rereview`. The reviewed snapshot is parsed from the review
  filename/header; the newer snapshot must equal `task.json.latest_snapshot_id`
  and differ from the reviewed snapshot.
- Updates `latest_resolution_path`, state, and notes.
- Refuses to mark addressed if `current_blocker_count > 0` and no resolution
  file is provided.

### Published and closed states

- `published` is set only by a future publish/PR helper after an explicit
  developer-approved push or PR creation.
- `closed` is set only by an explicit close/archive command.
- Phase 1 may define these states but does not need to implement the publish or
  close commands.

### `agent-review status`

Purpose: shared dashboard.

```bash
agent-review status --all
agent-review status --repo <repo>
agent-review status --current
agent-review status --json
```

Output columns:

```text
STATE                  BLOCKERS  SNAPSHOT                  OWNER  TASK                 PATH
review_requested       ?         004-...-abc1234           codex  feat-example         ...
reviewed_no_blockers   0         003-...-local             codex  docs-agent-tooling   ...
```

The compact form should be cheap enough for SessionStart hooks.

### `agent-review path`

Purpose: print the ledger path for scripts and agents.

```bash
agent-review path <description|type-slug|task-key>
```

No writes.

---

## 6. Hook and instruction wiring

### Shared `AGENTS.md`

Add a concise ratified section to `~/.config/agents/AGENTS.md` after the
existing INBOX section:

- Use `agent-review` for pre-PR local review.
- Normal tracked-code snapshots are SHA-only; do not copy worktrees.
- Dirty tracked files block review until commit/amend.
- Explicit artifacts only; dedupe by checksum.
- Reviewer is read-only for implementation files but writes ledger reviews.
- `task.json` is authoritative for resume/state.
- Manual ledger edits are fallback only when `agent-review` is unavailable.

This works for both CLIs because local config already wires:

- Codex: `~/.codex/AGENTS.md -> ~/.config/agents/AGENTS.md`
- Claude: `~/.claude/CLAUDE.md` imports `@~/.config/agents/AGENTS.md`

### Claude Code hooks

Keep current hooks, but route new collaboration context through shared scripts:

- `SessionStart`:
  - Current: `~/.claude/hooks/session-start-orient.sh`
  - Update it to include `agent-review status --current --compact` when in a
    Git repo and `agent-review status --repo agents-config --compact` for
    `~/.config/agents`.
- `PostToolUse(Bash)`:
  - Current recall-on-error remains.
  - Later: replace with shared `~/.config/agents/hooks/recall-on-error.sh`
    if the shared script handles both Claude and Codex payload shapes.
- Optional future `PreToolUse(Edit|Write)`:
  - Do not build first. It is easy to over-block legitimate implementation.
  - Add only after `agent-review` has an explicit session role marker.

### Codex hooks

Create user-level `~/.codex/hooks.json` rather than inline hooks in
`config.toml`, so lifecycle behavior is separate from model/provider config:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/agents/hooks/session-start-context.sh",
            "timeout": 10,
            "statusMessage": "Loading agent review status"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/agents/hooks/recall-on-error.sh",
            "timeout": 10,
            "statusMessage": "Checking durable learnings"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/agents/hooks/review-state-reminder.sh",
            "timeout": 10,
            "statusMessage": "Checking review handoff state"
          }
        ]
      }
    ]
  }
}
```

Important Codex-specific implementation note:

- The Codex hook **configuration** schema above is intentionally similar to
  Claude's nested event/matcher/hooks shape and has been checked against the
  official Codex hooks documentation.
- The hook **stdin payload** schema is not assumed to be the same as Claude's.
  Shared scripts must detect and parse each payload shape explicitly.
- Codex requires non-managed command hooks to be reviewed/trusted after changes.
  After installing `~/.codex/hooks.json`, run `/hooks` in Codex and trust the
  hook definitions. Until trusted, hooks may be skipped.

### Shared hook scripts

Create:

```text
~/.config/agents/hooks/session-start-context.sh
~/.config/agents/hooks/recall-on-error.sh
~/.config/agents/hooks/review-state-reminder.sh
```

Rules:

- Hook scripts must be read-only except for intended append-only logs/learnings.
- They must degrade silently when outside a repo or when `agent-review` is not
  installed.
- They must never dump large diffs or full logs into context.
- They must handle Claude and Codex hook payload differences explicitly. Do not
  assume Claude's `tool_response.exitCode` shape works for Codex PostToolUse
  payloads.

---

## 7. Implementation phases

### Phase 0 - Review this plan

Deliverables:

- This plan document.
- Snapshot in the collaboration ledger.
- Claude review, Codex resolution, re-review loop as needed.

Exit criteria:

- No blockers on plan.

### Phase 1 - Build `agent-review`

Deliverables:

- `~/.config/agents/bin/agent-review`
- `~/bin/agent-review` symlink
- `agent-inbox --repo <namespace>` / `--namespace <name>` support for non-git
  review ledgers, preserving current git-derived behavior as the default
- Unit/integration smoke tests under `~/.config/agents/tests/`
- `agent-review status --all`
- Legacy-ledger read compatibility and `agent-review migrate --dry-run|--apply`

Minimum tests:

- Git clean repo snapshot stores commit SHA only and copies no tracked files.
- Dirty tracked repo snapshot fails with a clear message.
- Explicit artifact snapshot stores content-addressed artifact.
- Repeated artifact snapshot with same checksum does not copy again.
- Non-git namespace requires `--repo` and explicit artifact.
- Existing legacy snapshot layout is readable; migration writes
  `artifacts/by-sha256/` and `artifacts.json` without losing checksum evidence.
- `resolve` resumes exactly one match and fails loud with candidate list on
  multiple matches.
- `.lock` prevents concurrent writer corruption and atomic rename leaves valid
  JSON after interrupted writes.
- `--artifact-dir` cap records `truncated=true`.
- Verification failure keeps the task in `implementation_in_progress` unless
  `--request-anyway --reason` is explicit.
- Non-git INBOX fallback writes latest review/resolution/state/blocker pointers
  to `task.json`; `agent-inbox --repo` posts to the named inbox when requested.
- Reviewer `post` leaves source and implementation files byte-identical.
- `post` refuses stale snapshot by default.
- `addressed` requires a newer snapshot.
- `status --all --json` returns valid JSON.

### Phase 2 - Ratify stable rules in `AGENTS.md`

Deliverables:

- Concise local-review section in `~/.config/agents/AGENTS.md`.
- This ratifies the mechanical local-review workflow only. It does not settle
  the separate human policy questions Q1-Q9 in `COLLABORATION.md` unless those
  questions are explicitly resolved later.
- Verify Codex instruction loading:
  `codex --ask-for-approval never "Summarize the active local review workflow instructions."`
- Verify Claude instruction loading:
  start Claude and run `/memory` or ask it to summarize the imported shared
  local-review rules.

### Phase 3 - Hook wiring

Deliverables:

- Shared hook scripts under `~/.config/agents/hooks/`.
- Updated `~/.claude/settings.json` to include compact ledger status at session
  start.
- New `~/.codex/hooks.json` with SessionStart, PostToolUse(Bash) recall, and
  Stop reminder.
- Run `/hooks` in both CLIs where applicable and trust/review new Codex hooks.

Verification:

- Claude new session receives compact worktree + review-ledger context.
- Codex new session receives compact review-ledger context after hook trust.
- Codex failed Bash command can surface matching `agent-recall` guidance.
- Hook failures do not block normal work unless the hook is explicitly a guard.

### Phase 4 - Dashboard/status integration

Deliverables:

- `agent-review status --all --compact`
- `agent-worktrees --status` appends review state for matching repo/task keys.
- `agent-dashboard` includes active review states and blocker counts.

### Phase 5 - Optional guardrails

Only after the basic helper proves stable:

- Reviewer-role marker in ledger/session metadata.
- PreToolUse guard that blocks implementation-file edits when a session is
  explicitly marked as reviewer-only.
- Stop hook that warns if an implementer says review is requested but no
  `agent-review snapshot/request` exists.

Do not build edit-blocking guards first; they are risky without explicit session
role state.

---

## 8. Developer journeys after tooling

### Start implementation

Developer says:

```text
Work on adding X. Use the collaboration workflow.
```

Agent does:

1. `agent-review resolve "adding X"` to avoid duplicate ledger/worktree.
2. `agent-worktree feat/x` if no existing owner worktree.
3. `agent-review init ...`
4. Implement in owner worktree.
5. Commit or amend tracked code.
6. `agent-review snapshot --verify "<project gate>"`
7. `agent-review request --reviewer <other-cli>`

No tracked files are copied.

### Start review

Developer says:

```text
Review adding X.
```

Reviewer does:

1. `agent-review resolve "adding X"`.
2. Read `task.json` and latest `snapshot.json`.
3. For tracked code, review commit SHA/diff. Create a detached checkout only if
   needed.
4. Write review note.
5. `agent-review post --reviewer <cli> --blockers N --file <review.md>`.

Reviewer does not edit implementation files.

### Address and re-review

Implementer:

1. Reads latest review from `task.json`.
2. Fixes in owner worktree.
3. Commits/amends.
4. `agent-review snapshot`.
5. `agent-review addressed --review rNNN --file <resolution.md>`.
6. `agent-review request --reviewer <same-or-other-reviewer>`.

Reviewer:

1. Resolves same ledger.
2. Verifies latest snapshot id.
3. Reviews only the new snapshot.
4. Posts new review.

Again, tracked code is SHA-only.

### Continue days later

Agent does:

1. Run existing orientation.
2. `agent-review resolve "<description>"`.
3. Report task path, owner worktree, latest snapshot, review state, blockers.
4. Continue based on `task.json`, not chat history or tmux scrollback.

---

## 9. Resolved design decisions from review

These are implementation decisions resolved during review, not policy Q1-Q9 from
`COLLABORATION.md`:

1. `agent-review snapshot --verify` is mandatory only when the repo/task
   declares a gate through `verification.required`; fail loud when a required
   gate is missing.
2. `agent-review request` refuses when `current_blocker_count > 0` unless a
   newer snapshot and resolution file exist.
3. Artifact dedupe stores references in `snapshot.json`/`artifacts.json`, not
   symlinks. Symlinks are brittle under backup/restore and cross-machine moves.
4. `agent-worktrees --status` shells out to
   `agent-review status --repo <repo> --json`; ledger parsing has one source of
   truth.
5. `agent-inbox --repo <namespace>` is Phase 1, because non-git config reviews
   already depend on it.

---

## 10. Reviewer checklist

Review this plan for:

- Does it preserve the no-repeated-copying invariant?
- Is the `agent-review` interface small enough for agents to use reliably?
- Are the Claude and Codex hook plans grounded in documented extension points?
- Does the plan avoid overbuilding edit-blocking guards before role state exists?
- Are the tests sufficient to catch stale snapshots, dirty tracked state, and
  artifact dedupe failures?
- Is the AGENTS.md ratification scoped enough to keep both CLIs aligned without
  bloating startup context?
