# AGENTS.md — global rules for coding agents

This file is the single source of truth for how any coding agent (Codex, Claude
Code, Claude SDK sub-agents, etc.) should behave in this developer's
environment. It lives at `~/.config/agents/AGENTS.md` and is reached by:

- **Codex** — natively, via the symlink `~/.codex/AGENTS.md`.
- **Claude Code** — via `@~/.config/agents/AGENTS.md` from `~/.claude/CLAUDE.md`.

Per-repo behavior lives in each repo's `AGENTS.md` (with `CLAUDE.md` doing
`@AGENTS.md` so both CLIs read the same file). Repo files take precedence over
this global file when they conflict.

## Command-output discipline

Use RTK (Codex run-tool-kit) or equivalent capture-to-file streaming for
commands expected to produce noisy output: tests, training logs, torchrun,
kubectl logs, docker logs, large diffs. Use raw commands when exact output
matters or for simple inspection commands such as `sed`, `rg`, `ls`, `git
status`. Claude users: prefer Read/Edit over `cat`/`sed`; pipe noisy commands
to a file and grep the file instead of dumping into context.

## SSM / remote-job polling — never loop SSM sessions

SSM Session Manager sessions are flaky and hang. **Never run a polling loop
that opens a fresh SSM session per iteration** (e.g. repeatedly calling
`run_hyperpod_controller_command.sh` in a `for`/`while` to watch a Slurm job or
file). It hangs and wastes turns. Instead:

- **Single-shot checks**, spaced by the agent's own turn cadence — fire one
  command, end the turn, check again next turn (or after a `ScheduleWakeup`).
- **Make the remote job self-report**: have the sbatch/job write a result file
  + a `DONE`/sentinel marker, then do ONE check later rather than polling.
- **Server-side wait in a single session** when a wait is unavoidable: one SSM
  command that runs the whole `until cond; do sleep; done; cat result`
  server-side (one session, not N), or use the `hyperpod-access`
  `hyperpod_watch.sh` helper (server-side tmux holds scrollback; each read
  pulls <750 bytes).

Applies to HyperPod controllers and any SSM-reached host. The failure mode is
recurring; treat looped SSM polling as a hard "don't."

## Worktree-per-task discipline

For any substantive repository code edits, use a dedicated git worktree unless
the user explicitly asks to work in the current checkout. This applies to
single-agent and multi-agent work.

Prefer the helper `~/bin/agent-worktree <type/task-slug> [base-ref]` (also
accessible as `~/.codex/bin/codex-worktree` for back-compat). It creates a
short semantic branch and a worktree with traceable metadata in
`.agent-session.json`. If only `<task-slug>` is provided, the helper defaults
the branch type to `chore`.

Keep branch names reviewer-facing and concise, such as
`fix/data-empty-validation-shards`. The helper keeps timestamp/id traceability
in `.agent-session.json` inside the worktree, and only appends a short id to
the branch if the concise branch name already exists.

Keep worktrees inside the active repository at
`<repo-root>/.worktrees/<type>-<slug>/`. The hidden directory is gitignored
per repo. Directory names mirror the branch (`<type>-<slug>`), so worktrees
are discoverable with `ls .worktrees` from inside the repo; historical
timestamp + short id stay in `.agent-session.json`, not the path. Avoid
creating new worktrees under `/tmp` except for disposable read-only
experiments.

## Parallel task workflow

For parallel task work, keep the operating model simple: one task maps to one
tmux window or session, one agent instance, and one dedicated git worktree.

The user's normal flow is manual: enter a repo with `z <repo>`, open or choose a
tmux window, then start the agent directly:

    claude --dangerously-skip-permissions
    codex --sandbox danger-full-access --dangerously-bypass-approvals-and-sandbox

Use the low-level helpers when they are useful, but do not assume shell launcher
shortcuts exist:

- `agent-worktree <type/slug> [base-ref]` — create the dedicated worktree
- `agent-worktrees --status` — inspect worktrees and active tmux owners
- `agent-attach --cli {codex|claude}` — attach an agent to an existing worktree

Do not introduce extra task launcher abstractions unless the user explicitly
asks for one. If the user starts in a general session and then chooses a task,
create or choose the dedicated worktree, report the worktree path and branch,
and continue there unless the user asks for a manual handoff.

For local CLI collaboration, use the shared `<repo>/.worktrees/` layout and
`agent-worktree` helper so `agent-worktrees --status`, INBOX, review ledgers,
and the dashboard see the same work. Codex-app native worktrees are acceptable
for Codex-app-only experiments, but before cross-agent review the work must be
available in the shared worktree layout or explicitly registered in the review
ledger. `agent-worktree` defaults its base ref to the current `HEAD`; pass an
explicit base ref when deterministic ancestry matters.

## Session orientation — survey before starting work

Before taking on substantive repo work in a freshly started session, run a
short orientation survey so you don't duplicate work already in flight in a
sibling worktree, miss a relevant stash, or restart a task another agent
already finished. The user has a `/orient` slash command (Claude) and the
equivalent commands work in any shell:

    agent-worktrees --status     # what worktrees exist, their state, tmux owner
    agent-inbox --tail 30        # recent cross-agent activity (shared per-repo)
    git stash list               # pocketed work
    git branch -a --sort=-committerdate --format='%(committerdate:short) %(refname:short) — %(subject)' | head -15

The orientation is **read-only** — it must not create worktrees, run cleanup,
or write to INBOX. After the survey, deliver a one-paragraph summary and a
recommendation: reuse an existing worktree, create a new one (with proposed
type/slug), or work in the current checkout (only for trivial / read-only
work). Trivial reads and single-file inspections don't need orientation.

Skip the survey when:

- The task is trivial (reading one file, answering a question about the code).
- The user has already pointed you at a specific worktree or branch.
- You are mid-session and have already oriented earlier in the same session.

## Visible orientation when leaving the original checkout

Keep the user visibly oriented whenever work happens outside the original
checkout. Before creating or switching to a worktree, send a short update
naming the source repository, intended base ref, branch/task slug, and whether
the original checkout will be left untouched. Immediately after creating or
choosing a worktree, send another update with the exact worktree path, branch
name, and base ref or base commit. During substantial work, mention the active
worktree path or branch whenever changing phase, starting edits, launching
long-running commands, or handing work to another agent. Before the final
response, check and report the active worktree's `git status --short
--branch`, changed files or `git diff --stat`, validation commands run, and
whether changes are uncommitted, committed, pushed, or in a PR. If multiple
worktrees or agents are involved, keep a simple mapping of task to
worktree/branch so the user is never left guessing where changes live.

## Live infrastructure preflight

Before launching, cancelling, updating, or deploying any live Databricks,
SageMaker, HyperPod, AWS, or similar infrastructure job, run a short preflight
and show the important parts to the user. Include the active repository or
worktree path, branch, HEAD commit, `git status --short --branch`, the exact
config file or bundle resource being used, the target/profile/environment, and
whether the action will use a saved workflow or create a one-off run.

If multiple checkouts or worktrees exist for the same repository, inspect
`git worktree list` and choose the checkout that actually contains the intended
config/resource. Do not run from an older checkout merely because it is the
current shell directory. If the required config exists only in a different
worktree, switch to that worktree first and state the switch explicitly.

## Databricks bundle discipline

For Databricks Asset Bundle managed workflows, use `databricks bundle
validate`, `databricks bundle deploy`, and `databricks bundle run` from the
worktree that contains the intended bundle resource. Do not use
`databricks jobs submit` to compensate for a missing bundle resource,
incorrect parameters, or checkout confusion unless the user explicitly approves
a one-off run.

Do not assume `databricks bundle run --var ...` changes an already-defined job's
task parameters. For variant jobs such as 1pct vs 5pct, require a distinct DAB
resource or verify the actual job/run parameters with `databricks jobs get` or
`databricks jobs get-run` before treating the run as valid. If the user asks for
a non-user workflow, call out any target that is development/user-scoped before
running it, and use the appropriate non-user target only after verifying the
bundle summary.

## Traceable scratch directories

When using `/tmp` or `/private/tmp` for ad hoc work, prefer the helper
`~/bin/agent-tmp <task-slug>` (also `~/.codex/bin/codex-tmp`). It creates a
traceable directory named `/private/tmp/agents/<repo-name>/<task>--<timestamp>--<id>`
with `.agent-session.json` metadata. Do not leave anonymous scratch
directories like `/tmp/foo`, `/tmp/test`, or `/tmp/efm-run` when the work
relates to a repository task.

`.agent-session.json` is canonical for new worktree and scratch metadata.
Shared helpers write only `.agent-session.json`. They may read old
`.codex-session.json` files for compatibility with older worktrees, but new
workflows must not require that file.

## Cross-agent status (shared INBOX)

The INBOX is a single per-repo log shared across the base checkout and **all
its worktrees**. It lives at:

    ~/.config/agents/inbox/<main-repo-name>/INBOX.md

Use the `agent-inbox` helper — never edit the file directly:

    agent-inbox <message...>       # append a status line
    agent-inbox --tail 30          # show last 30 lines
    agent-inbox --tail-follow      # tail -F
    agent-inbox --path             # print resolved path

Format of each appended line:

    [YYYY-MM-DDTHH:MM:SSZ <session> <branch> wt:<wt-basename>] <message>

The `wt:` prefix tells readers which checkout produced the line, since one
INBOX is shared across all worktrees of the same repo.

**When to append.** Treat these as required write points so the log stays
informative:

- **Task start.** One line stating what you're about to do and where (which
  worktree/branch).
- **Phase boundary.** When switching from one substantial phase to another
  (e.g. design done → implementation; tests passing → starting deploy);
  before kicking off a long-running command; when blocking on user input or
  an external system.
- **Task end.** One line summarizing the outcome (landed, paused, blocked).

Skip INBOX writes for trivial reads, one-shot questions, or rapid iteration
within a single phase — the goal is informative, not noisy.

**Never write** secrets, tokens, raw sensitive command output, customer
data, or personal info. Treat the INBOX as if it could be read by anyone with
shell access.

## Local pre-PR review workflow

Use `agent-review` for local implement -> review -> address -> re-review cycles
before a branch is pushed or a PR exists. Manual ledger edits are a fallback
only when `agent-review` is unavailable or cannot represent the state.
Full rationale, journeys, and review-history details live in
`~/.config/agents/COLLABORATION.md`; this section is the executable cold-start
contract agents must follow.

The review ledger is the source of truth for cross-agent coordination:

    ~/.config/agents/reviews/<repo>/<task-key>/task.json

`agent-review` appends mutating workflow events to:

    ~/.config/agents/logs/agent-review-events.jsonl

Use that log to audit whether agents actually used the workflow; do not infer
adherence from chat history alone. Codex lifecycle hooks must also be trusted in
the interactive `/hooks` UI after any hook command changes, because untrusted
Codex hooks are skipped. The hardening rationale and before-vs-now design record
lives in `~/.config/agents/AGENT_HARNESS_HARDENING_DESIGN.md`.

For tracked repository code, normal snapshots are SHA-only: commit or amend the
implementation first, then snapshot `HEAD`. Do not copy a whole worktree or
tracked files for review. Dirty tracked files block review by default; use any
dirty-copy escape hatch only when explicitly requested and record why.

For ignored, untracked, or non-git artifacts, pass explicit `--artifact` or
`--artifact-dir` paths. The helper stores content by checksum and reuses
previously copied blobs, so repeated review cycles should not recopy identical
artifacts. For non-git roots, pass an explicit `--repo <namespace>` such as
`--repo agents-config`; do not rely on directory basename guessing.

Implementer default flow:

    agent-review resolve "<feature title or type/slug>" || true
    agent-worktree <type/slug> [base-ref]   # for substantive repo edits, if not already in the owner worktree
    agent-review init --title "<feature title>" --type-slug <type/slug>
    agent-review snapshot --verify "<project gate>"
    agent-review request --reviewer <other-cli>

Always try `agent-review resolve "<task>"` before `init`. If it returns exactly
one ledger, resume that ledger instead of creating a new one. If it returns
multiple ledgers, stop and ask the developer which one is authoritative. Only
run `init` when no existing ledger matches the feature. In Claude sessions,
pass `--owner-cli claude` if `AGENT_CLI` is not set; in Codex sessions, pass
`--owner-cli codex` or rely on the Codex default.

For repository edits, create or reuse the dedicated owner worktree before
initializing the review ledger. Non-git/config namespaces such as
`agents-config` may use an explicit `--repo <namespace>` ledger without a git
worktree.

The review request posts an INBOX pointer when a repo/namespace supports
`agent-inbox`; otherwise the request is discoverable through `task.json` and
`agent-review status`. The human normally opens or prompts the other CLI to
review; `request` records state but does not spawn a reviewer agent.

Reviewer default flow:

    agent-review resolve "<feature title or type/slug>"
    # If latest_review_path already reviews latest_snapshot_id, do not duplicate it.
    # Otherwise write findings under the ledger reviews/ dir, then record them:
    agent-review post --reviewer <cli> --snapshot latest --blockers <N> --file <review.md>

Reviewers are read-only for implementation files unless the user explicitly
asks them to edit. Reviewers write findings through `agent-review post`; they
do not hand-edit `task.json`.

Reviewers must review a stable target, not the live mutable tree:

- Git code snapshots: use `git show <snapshot-sha>`, `git diff <base>..<sha>`,
  or a detached read-only checkout at the snapshot SHA.
- Artifact snapshots: read the copied artifact recorded in the ledger's
  `artifacts.json` / `checksums.sha256`.
- Avoid `git diff <sha>` against a live working tree; it drifts as the
  implementer edits.

Before writing a review, inspect `task.json.latest_snapshot_id` and
`task.json.latest_review_path`. If the latest review file already covers the
latest snapshot id, report that no new review is needed instead of creating a
duplicate. Review files should live under:

    ~/.config/agents/reviews/<repo>/<task-key>/reviews/

Use the canonical filename shape when writing directly into the ledger:

    rNNN-<snapshot-id>-<reviewer>-<YYYYMMDDTHHMMSSZ>.md

Include this header near the top so `agent-review addressed` and staleness checks
can parse it:

    **Reviewed snapshot:** `<snapshot-id>`

If a reviewer already wrote the canonical review file under the ledger's
`reviews/` directory, the owner records it with the same `agent-review post
--file <path>` command; the helper adopts the file in place rather than creating
a duplicate review.

Address-and-rereview flow:

    agent-review snapshot --verify "<project gate>"
    agent-review addressed --review rNNN --file <resolution.md>
    agent-review request --reviewer <same-or-other-cli>

Resolve `rNNN` from `task.json.latest_review_path` or by listing the ledger's
`reviews/` directory. Do not guess a review number from chat history.

On resume or in a fresh session, start with `agent-review resolve "<task>"` or
`agent-review status --current --compact`, then report the ledger path, latest
snapshot, review state, blocker count, owner worktree, and next action.

Choose `--verify` from the repo's own `AGENTS.md`, README, Makefile, or test
docs. If no repo-specific gate exists, run the smallest relevant deterministic
test/lint/syntax check and record it. If verification cannot run, request review
only with an explicit `--request-anyway --reason <why>` and mention the gap.

## Human review and merge policy

Agent-authored inline PR review comments must be prefixed with
`[claude-review]` or `[codex-review]`. GitHub author identity is useful, but the
prefix keeps provenance intact when comments are summarized, copied, or bridged
through another tool.

Humans merge by default. Agents must not merge PRs unless the developer
explicitly authorizes that exact PR and merge method after review is clean.
Publishing actions (`git push`, `gh pr create`, `gh pr merge`, PR mutation via
`gh api`, and similar) are permission-gated in Claude/Codex config and should
prompt even if the model thinks the prose allows them. Claude uses a
`PreToolUse(Bash)` publish guard plus `permissions.ask`; Codex uses execpolicy
rules plus the normal approval flow.

For important changes, prefer cross-CLI review: Claude reviews Codex-owned work
and Codex reviews Claude-owned work. The developer or coordinator can override
per task; trivial or read-only work may skip a second model review when the user
accepts that.

Do not build or use a PR handoff automation command by default. Local review is
handled by `agent-review`, and publication/merge actions still require explicit
developer approval.

## Git hygiene — branches, commits, PRs

Use reviewer-facing Git hygiene for branches, commits, and pull requests.
Branch names should describe the work with semantic prefixes: `feat/`, `fix/`,
`test/`, `refactor/`, `docs/`, `chore/`, `ci/`, `perf/`, or `exp/`. Do not use
`codex/`, `claude/`, `agent/`, `tmp/`, or tool-name branch prefixes unless the
user explicitly requests them. Good examples:
`fix/data-empty-validation-shards`, `feat/hyperpod-job-submit`,
`test/distributed-allreduce-probe`.

Use Conventional Commit style for PR titles and commit subjects: `type(scope):
concise reviewer-facing summary`. Good examples: `fix(data): handle empty
validation shards`, `feat(hyperpod): add submit job workflow`,
`test(distributed): add allreduce smoke probe`.

PR descriptions follow their own rules — see **Pull request descriptions** below.

## Pull request descriptions

PR descriptions are read by distributed reviewers who only see what is on
`main` or the feature branch — not your local session, scratch notes, or
chat history. Write so a colleague in a different timezone can review
without asking you questions.

### Sections

Use only these sections, in this order. Omit empty ones.

1. **Summary** — 1-3 bullets on *what* changed and *why*. Reviewer-facing
   language, not commit history.
2. **Validation** — what was checked beyond the unit/integration tests CI
   will run anyway. See "What belongs in Validation" below.
3. **Notes** (optional) — follow-ups, intentional out-of-scope items,
   migration steps reviewers must take.
4. **Risk** (optional) — concrete blast radius: what breaks if this is
   wrong, what the rollback looks like, who/what is affected.

No "Test Plan", no "Checklist", no "Generated by", no emoji headers, no
collapsible `<details>` blocks.

### What belongs in Validation

**Mention briefly** (one line each, no command output):

- Unit / integration tests added or updated — CI runs them, so the diff is
  the proof. Do not paste pytest output.
- Type-check / lint passes if relevant to the change.

**Always include when applicable**:

- Live job runs: SageMaker training job ARN, HyperPod job ID, Databricks
  job/run URL, Airflow DAG run, GitHub Actions workflow URL.
- Experiment-tracker links: MLflow / W&B / TensorBoard run URLs with the
  key numbers (loss, eval metric, throughput, MFU) pasted in — paste the
  numbers, do not just link.
- Comparative metrics vs. a named baseline: `before → after` for the metric
  the change is supposed to move.
- Manual verification on a real environment: dataset slice checked, query
  executed, dashboard inspected. Name the environment (prod / staging /
  ephemeral / local).
- For schema, config, or infra changes: dry-run output (`bundle validate`,
  `terraform plan`, migration preview, `dbt compile`).

**Never include**:

- Local pytest output, `make smoke` traces, terminal session transcripts.
- "I tried X, then Y, then Z" debugging narratives — the diff and commits
  carry that history if needed.
- `/tmp` paths, worktree paths, session IDs, agent/tool attribution
  ("generated by Claude / Codex / Copilot") unless the tool itself is the
  subject of the change.
- Failed attempts or bugs encountered and fixed during the same PR — the
  final state is what reviewers review.
- Internal Slack threads, DM screenshots, or chat snippets.

### Scope and stacking

- One logical change per PR. If Validation requires explaining two
  unrelated changes, split the PR.
- If the PR depends on or is part of a stack, state the dependency in one
  line at the top of Summary: `Depends on #1234 (must land first).`
- A "small follow-up" cleanup that also changes behavior is a separate PR.

## Coding practices — fail loud, no silent defaults

Apply broadly Google-style engineering hygiene. The unifying principle: a
program should be obviously correct or obviously wrong — never quietly
limping with the wrong behavior.

### No silent fallbacks

- A missing config value, missing file, missing env var, or unsupported
  branch must **raise** with a message that names what was missing and
  where it was expected. Do not substitute a default that hides the bug.
- `dict.get(key, default)` is fine when the default is the *intended*
  behavior. It is wrong when the default is "I dunno, hope nothing breaks
  downstream."
- No bare `except:`, no `except Exception: pass`. Catch specific exceptions
  whose recovery you can describe in one sentence. If you do not know what
  you are catching, you cannot recover from it — let it propagate.
- No "retry forever on error" or "return `None` on error" patterns unless
  that is the documented contract of the function.
- Swallowing an exception only to log it is the same antipattern. Either
  the failure matters (raise) or it does not (don't catch).

### Defaults are explicit

- Defaults live in one obvious place: the function signature, a `dataclass`
  default, or a config schema. Not buried six layers deep behind `or`.
- Document non-obvious defaults inline (`# 8 because tokenizer pad is 8`).
  Do not document obvious ones.
- Changing a default is a behavior change. Call it out in the PR Summary.

### Fail at the boundary

- Validate inputs once, at the system boundary: CLI entrypoint, HTTP
  handler, file loader, deserializer. Inside the program, trust internal
  invariants — do not re-validate in every helper.
- Validation failures should be loud and structured: which field, what was
  expected, what was received.

### No defensive cruft

- Do not wrap calls in `try/except` "just in case." Either the failure
  matters and the message belongs in the trace, or it does not matter and
  the wrapper is dead code.
- Do not add `isinstance` / `hasattr` checks for types your own code
  controls. Trust the type system; if the type is wrong, that is a bug.
- Backwards-compatibility shims, deprecated re-exports, and "for old
  callers" branches need an explicit user request. By default, change the
  code and update all call sites.
- Do not add features, abstractions, or configuration for hypothetical
  future use. Three similar lines is better than a premature abstraction.

### Naming and structure

- Names carry behavior. `load_config()` reads from a predictable place;
  `try_load_config()` may return `None`; `require_config()` raises. Pick a
  verb the caller can trust without reading the body.
- Helpers exist when used at least twice (or once with an obvious second
  use). Do not pre-factor.
- Comments explain *why*, not *what* — the code shows what. No
  multi-paragraph docstrings on internal functions.

### Logging

- Log at boundaries (job start/end, external call, state transition). Do
  not log inside tight loops.
- Logging an error and silently returning a default is the silent-fallback
  antipattern. If you log it, raise it; if you don't raise it, you don't
  need to log it.

## Iteration and stack hygiene

- **Fixup during review** — when addressing PR review comments, use `git
  absorb` to auto-fixup the right historical commit, then `git rebase -i
  --autosquash @{u}`. Alias: `gabs`.
- **Stacked PRs** — when one task depends on another's open PR, use `git
  spice` (`git-spice`) to manage the stack. Submit with `git spice stack
  submit`; restack after the base lands.
- **Recovery** — `jj` is installed in colocated mode for emergency recovery.
  If a rebase, merge, or branch delete went wrong, `jj op log` and `jj op
  restore <op>` undo it. Daily flow stays on `git`.

## Durable learnings — read and write

`~/.config/agents/LEARNINGS.md` (also at `~/.codex/learnings.md` via symlink)
is a shared, append-only knowledge base for both Codex and Claude. It is the
continuous-improvement loop: when an agent spends time fixing a problem, the
fix is captured so future agents that hit the same error can try it.

**Learnings are hints, not gospel.** They reflect what worked at a point in
time. Always verify before relying on them. Note the date.

### Reading — when to consult LEARNINGS.md

- **On error or retry**: when a command fails, pull a 5-12 word snippet from
  the error message and run `agent-recall -e '<snippet>'`. If a match exists,
  read its `Fix:` line first, try it, and verify. If you apply a learning,
  briefly tell the user "applying learning from <date>: <one-line gist>".
- **Before unfamiliar costly work**: `agent-recall -t <topic>` (e.g. `ssm`,
  `hyperpod`, `packed-pretrain`, `npm`, `tmux`). Factor any cautionary notes
  into the plan.
- **When the user references prior pain**: `agent-recall <keyword>`.
- If a learning fails to apply or is clearly outdated, note that in the
  next learning entry — staleness signal.
- Do **not** load the entire LEARNINGS.md into context proactively. It is
  searched, not pre-loaded. Stable rules belong in this AGENTS.md.

### Writing — when to append

Default to appending a learning when an agent:

- corrects its own approach after a failed attempt,
- discovers that an earlier assumption was wrong,
- identifies a flaky or misleading command behavior,
- finds a reusable repository/workflow convention,
- or needs more than ~3 attempts to land a reliable pattern.

If the learning is reusable and contains no secrets/credentials/raw sensitive
logs/personal data/large command output, append it without asking. If it may
be sensitive, customer-specific, one-off, or too noisy to summarize safely,
ask first.

Use the terse canonical format (see `LEARNINGS.md` top-of-file spec). Capture
fast with `agent-learn -t "<short title>"` (interactive) or with `--body` for
non-interactive writes. Keep entries ~10 lines. If an entry grows past that,
split it.

Before the final response, briefly state whether a durable learning was
saved. If no learning was saved after a correction or failed attempt, state
why not.

### Promoting stable patterns

If a learning has solidified into a recurring rule (you find yourself
recalling it repeatedly), promote it to one of:

- `~/.config/agents/AGENTS.md` for global cross-CLI rules
- a repo `AGENTS.md` for repo-specific behavior
- a `skills/*/SKILL.md` file for repeatable workflows

Set the entry's `Promote-to:` field. When promoted, remove the redundant
LEARNINGS.md entry — duplicating loaded rules in the searched log just bloats
the search space.

This file (and `LEARNINGS.md`) is shared between Codex and Claude.

## Memory vs learnings

- Claude's per-project memory at
  `~/.claude/projects/<project>/memory/` is for short-to-medium-term context
  about the current project: user role, project goals, recent decisions,
  active feedback. Lifetime: scoped to that project.
- `~/.config/agents/LEARNINGS.md` is for cross-session, cross-project reusable
  lessons. Lifetime: durable. Append-only log.

When in doubt: project-specific facts → memory; reusable patterns → learnings.
