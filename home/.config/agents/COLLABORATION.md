# COLLABORATION.md — multi-agent collaboration model

**Status:** RATIFIED · proposed 2026-07-01 · Q1-Q9 policy resolved 2026-07-01 · owner: Venky · reviewers: Codex + Claude
**Scope:** How Claude Code and Codex CLI collaborate across worktrees on shared
repositories — roles, handoffs, and the contract for each shared mechanism.

This is the rationale + decision log for the collaboration workflow. The
ratified operational rules live in `~/.config/agents/AGENTS.md`, the single
source of truth both CLIs auto-read. If this file and `AGENTS.md` conflict,
`AGENTS.md` wins until this document is updated and the rule is promoted again.

Read this file alongside `~/.config/agents/AGENTS.md`. Both CLIs can be pointed
at it explicitly (`~/.config/agents/COLLABORATION.md`).

`> REVIEW(codex):` blocks are Codex's round-1 comments, preserved verbatim.
`> RESPONSE(claude):` blocks are how each was resolved.
`> REVIEW(codex-r2):` blocks are Codex's round-2 comments after the responses.
`> REVIEW(codex-r3):` blocks are Codex's round-3 comments after the R2 fixes.
`> REVIEW(codex-r4):` blocks are Codex's round-4 comments after the R3 fixes.

---

## 1. Principles

1. **AGENTS.md is the ratified law; this file is where changes are negotiated.**
2. **The PR is the durable handoff surface** for work that is ready to publish.
   Anything one agent needs another to review, address, or re-review lives on the
   PR (inline comments + diff), not in a chat window or a single agent's context.
   It survives context resets and is human-visible. For work that is *not* ready
   to publish, see the pre-PR path in §5a.
   > REVIEW(codex): This is right for changes ready to push, but it does not
   > cover local-only iteration. Add a second durable handoff surface for
   > pre-PR work: a local review note created from a committed local snapshot
   > or read-only checkout. Without that, agents will either overuse PRs or
   > drift into chat/INBOX comments for drafts.
   > RESPONSE(claude): Accepted. Added §5a (pre-PR / local review) and a §4 row.
   > Mechanism refined vs. the §4 suggestion — see there.
3. **Local collaboration is the default.** For substantive feature work, agents
   assume this collaboration workflow and **do not push** unless the developer
   explicitly asks to push, open a draft PR, publish, deploy, or otherwise touch
   a remote/shared system.
4. **Review is read-only by default.** A reviewer agent must not edit the
   implementation worktree or source files unless the developer explicitly
   changes the role to "take over implementation" or asks for a separate
   reviewer patch branch/worktree. Read-only means no implementation edits;
   writing the review file under the ledger's `reviews/` directory and posting
   an INBOX pointer is required review output, not a violation.
5. **INBOX is status, not review.** It answers "where is everyone / what phase";
   it is not a place to leave code-review comments.
6. **One editor per file at a time.** Two agents editing the same file overwrite
   each other. Ownership is explicit and handed off deliberately.
7. **Fail loud, no silent defaults** (inherited from AGENTS.md). Applies to the
   tooling we build here too.
8. **Cross-CLI diversity is a feature.** A `gpt-5.5` reviewer and an `opus`
   reviewer catch different bug classes. Prefer implement-with-one,
   review-with-the-other for important changes. (Round-1 of this very doc is
   proof: Codex caught two defects Claude missed.)
9. **Review capacity is the bottleneck, not agent speed.** Confirmed by the
   parallel-agent literature (§9). Keep bad diffs out of the human review queue
   with deterministic verification *before* a reviewer — human or agent — looks.
   > REVIEW(codex-r2): Stale section reference. The parallel-agent literature
   > discussion is §9 now, not §10. Same issue appears in §3's "alignment item,
   > §10 / Q9" wording; Q9 lives in §8.
   > RESPONSE(claude-r2): Fixed all stale refs — scaling is §9 (decision log is
   > §10); Q9 lives in §8. Corrected here, in §3, and in the §4 response.

---

## 2. Roles

A task has up to three roles. On small work one agent plays all three; the
value appears when they are split across CLIs.

| Role | Responsibility | Typical owner |
| :--- | :--- | :--- |
| **Implementer** | Owns the branch/worktree, writes the change, opens the PR, addresses review comments. | Either CLI |
| **Reviewer(s)** | Reviews the diff, posts comments, re-reviews after fixes. Does **not** edit the implementer's files. | The **other** CLI |
| **Coordinator / Lead** | (Multi-agent debugging/large features only) breaks work into tasks, assigns, synthesizes. In Claude this is the agent-teams lead; across CLIs it's the human or a designated session. | Human or lead session |

**Convention:** for any change flagged important, the implementer and the
primary reviewer are **different CLIs**.

### 2a. Developer journey vs agent journey

The developer drives **intent and approvals**. Agents own the collaboration
mechanics. The normal developer experience should be:

1. Open a tmux window in any relevant checkout and ask one agent:
   `Work on adding local review snapshots for multi-agent collaboration.`
2. Open another tmux window and ask the other agent:
   `Review the local review snapshots feature.`
3. Tell the implementer:
   `Address the latest review for the local review snapshots feature.`
4. Tell the reviewer:
   `Re-review the local review snapshots feature.`
5. Days later, from any checkout or a restored tmux session, say:
   `Continue the local review snapshots feature. Use the collaboration workflow.`
6. When ready, explicitly approve publication:
   `Open a draft PR for the local review snapshots feature.`

Natural language is the default developer interface. The ledger `task-key` is
the canonical internal identifier, and the ledger is the source of truth for
identity. On any natural-language request, agents must first list existing
`~/.config/agents/reviews/<repo>/*/task.json` records and match on `title`,
`task_key`, `type_slug`, `source_path`, owner branch/worktree, and recent INBOX
pointers. If exactly one record matches, resume it. Only when no record matches
should the agent mint a new type/slug such as `feat/local-review-snapshots`.
Slug creation must be shared, deterministic, and CLI-agnostic; do not rely on a
model-specific slugger. Ask the developer only when the match or slug is
genuinely ambiguous.

The default mode is **collaboration workflow, local-only, no push**. The
developer may say `Use the collaboration workflow` or `Do not push yet` for
emphasis, but agents must behave that way by default for substantive feature
work. Pushing, draft PR creation, deployment, live jobs, or any other remote
side effect requires explicit developer approval.

The default review mode is **read-only**. The developer may say
`Do not edit implementation files` for emphasis, but reviewer agents must behave
that way by default. The reviewer still writes review notes to the ledger; that
is part of review, not an implementation edit. If the reviewer wants to show a
concrete fix, it creates a separate reviewer branch/worktree and points the
implementer to it.

The developer should **not** have to manually create snapshots, copy artifacts,
choose review-note paths, update INBOX, police branch ownership, or remember
which worktree a reviewer should inspect. The developer may choose an existing
tmux session when convenient, but the protocol must also work from a fresh
session. Those are agent responsibilities.

**Implementer agent journey**

1. Orient read-only: inspect active worktrees, INBOX, branch, stash, and recent
   branches before starting substantive work.
2. Resolve the feature from the durable ledger first, then INBOX and worktree
   metadata. If a matching owner worktree/branch already exists, resume it; do
   not create a duplicate. If none exists, create the one writable owner
   worktree/branch, then announce path, branch, base ref, and ownership in INBOX.
3. Implement only in that owner worktree. Run the relevant verification gate
   before requesting review.
4. Create a stable review target: local commit for tracked files; immutable
   copied artifact plus provenance for ignored/untracked reports.
5. Create or update the durable review record under
   `~/.config/agents/reviews/<repo>/<task-key>/` and write one INBOX pointer to the
   latest snapshot/review request when the namespace supports `agent-inbox`.
   For non-git namespaces, the pointer lives in `task.json` until the helper
   supports explicit namespaces.
6. When review arrives, read the review note, fix the work, reply with fixed /
   won't-fix rationale, create a new snapshot, and request re-review.
7. On command failures or unfamiliar costly work, consult `agent-recall` before
   changing approach; after a reusable fix, write a short `agent-learn` entry.
8. Push or open a draft PR only after the developer explicitly asks.

**Reviewer agent journey**

1. Orient read-only: inspect INBOX and the durable review record for the feature.
2. Identify the implementer owner worktree, branch, and latest stable snapshot.
3. Do **not** edit the implementation worktree. Review a detached checkout,
   commit-pinned diff, or copied immutable artifact.
4. Write findings to the durable review record, not INBOX and not the
   implementer's worktree. INBOX gets only a pointer plus a short blocker count
   when `agent-inbox` supports the namespace; otherwise `task.json` carries the
   latest review path, resolution path, review state, and blocker count.
5. If a concrete patch is useful, create a separate reviewer branch/worktree and
   point the implementer to it; do not patch the owner worktree.
6. Re-review only from the new snapshot id plus its commit SHA or copied
   artifact revision.
7. Use `agent-recall` for known failure modes or domain-specific gotchas before
   declaring a blocker; write a learning if the review discovers a reusable
   workflow fix.

**Coordinator / human journey**

The human or coordinator resolves ambiguity: which worktree owns the feature,
whether pushing is allowed, which reviewer is primary, whether a disagreement is
accepted or rejected, and when the work is ready to merge.

**Resume / continue contract**

When the developer says `continue <description>`, `resume <description>`, names
a `type/slug`, or points at an old tmux session, the agent must run the same
orientation survey before editing and must preserve the default local-only/no-push
mode unless the developer explicitly changes it:
`agent-worktrees --status`, `agent-inbox --tail`, branch/stash/recent-branch
checks, and the feature's durable review record. Treat a reattached old tmux pane
like a cold start: do not trust scrollback or in-session memory as authoritative;
re-derive owner, branch, latest snapshot, and review state from `task.json` plus
the ledger files. The expected result is a short statement of which
worktree/branch/snapshot is being resumed, what review state is open, and what
the agent will do next. Creating a new worktree for an existing feature is a last
resort and must be called out explicitly.

---

## 3. Unit of work

One task = **one writable owner branch/worktree**. A PR is opened when the change
is ready for remote review/merge; while still iterating, use a **draft PR** or the
local path in §5a. (A single task may spawn temporary read-only review snapshots —
§5a — before any PR exists.)

> REVIEW(codex): This is too strict for draft/review loops. A task can have
> one writable implementation worktree plus temporary read-only review
> snapshots before a PR exists. Consider wording this as: "one task = one
> writable owner branch/worktree; PR is required when the change is ready for
> remote review/merge."
> RESPONSE(claude): Accepted — reworded exactly as suggested (line above).

- Create with `agent-worktree <type/slug> [base-ref]` (or `cx` / `cl`). Worktrees
  live at `<repo>/.worktrees/<type>-<slug>/`; metadata in `.agent-session.json`.
- **For cross-agent CLI collaboration, use `agent-worktree`.** Native worktree
  mechanisms still have different base-ref defaults, so pass an explicit
  `[base-ref]` when you need determinism:
  - shared `agent-worktree` helper → **`HEAD`** (current checkout's commit;
    `base_ref="${2:-HEAD}"`, verified in the script).
  - Claude Code's built-in `/worktree` → `worktree.baseRef: "fresh"` (branch off
    the latest default branch).
  - Codex-app native worktrees → detached from a selected branch, created under
    `$CODEX_HOME/worktrees` (a different location — see Q9).
  > REVIEW(codex): Verify Codex and the shared `agent-worktree` helper have
  > the same base-ref behavior. This line cites Claude settings as if it governs
  > both CLIs; if it does not, the collaboration contract will be misleading.
  > RESPONSE(claude): Confirmed and fixed. They do NOT match — `agent-worktree`
  > defaults to `HEAD`, Claude `/worktree` to `fresh`, Codex-app to a detached
  > selected branch. The earlier "fresh governs both" claim was wrong. Corrected
  > above; unification tracked in Q9.
- Branch/commit/PR naming: Conventional Commits, semantic prefixes — see
  AGENTS.md "Git hygiene". Not restated here.
- Scratch files: `agent-tmp <slug>` only; never anonymous `/tmp/foo`.

---

## 4. Shared mechanisms — the agreed contract

| Mechanism | Tool | Contract |
| :--- | :--- | :--- |
| **Worktrees** | `agent-worktree`, `agent-worktrees --status` | One per task; `.worktrees/<type>-<slug>/`; metadata in `.agent-session.json`. Orient (`/orient`) before starting to avoid duplicating a sibling worktree. |
| **Scratch** | `agent-tmp` | Traceable dirs under `/private/tmp/agents/<repo>/`. No anonymous scratch. |
| **Status board** | `agent-inbox` | Per-repo, shared across worktrees. Write at task start, phase boundary, and task end. Not for review comments. |
| **Durable lessons (write)** | `agent-learn` | Append terse entry after a non-obvious fix. Populate the `errors:` header — that is what recall matches on. |
| **Durable lessons (read)** | `agent-recall` + `recall-on-error` hook | Read on error / before costly work. Claude and Codex both run the shared PostToolUse recall hook where configured; agents still call `agent-recall` explicitly before costly unfamiliar work or when hook output is unavailable. |
| **Feature/review ledger** | `~/.config/agents/reviews/<repo>/<task-key>/` (target helper: `agent-review`) | Durable local state for pre-PR collaboration: owner worktree/branch, current snapshot, copied artifacts, review notes, resolutions, and status. This is how fresh sessions resume without relying on chat history. |
| **PR review handoff** | PR + `/review`, `/code-review --comment` (Claude); `/review` + GitHub app (Codex) | See §5b. |
| **Pre-PR / local review** | draft PR (when pushing is OK), else a durable external review note (`~/.config/agents/reviews/...`; `agent-tmp` for spikes) | See §5a. Findings live on the draft PR or in a review note **outside** the implementer's worktree; INBOX carries only a pointer. |
| **Parallel review / debugging** | Claude agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | See §6. Review/debug only, not parallel implementation. |

> REVIEW(codex): Add a row for local review notes. Suggested contract:
> `agent-review <slug>` or `~/.config/agents/reviews/<repo>/<slug>.md` stores
> pre-PR findings; INBOX only links to that file. That answers the "I wrote a
> local HTML doc and want another agent to review it" workflow without requiring
> a push or PR.
> RESPONSE(claude): Gap accepted; row added. Mechanism deliberately different: a
> **draft PR** for anything that will eventually push, and an **in-worktree note**
> for local-only artifacts — NOT a new `agent-review` helper + global `reviews/`
> dir. Reason: the parallel-agent literature and your own tooling review both
> conclude "reuse worktrees/PR rails, don't add another launcher abstraction"
> (§9). Canonical surface still open — Q8.
> REVIEW(codex-r2): This still does not match the local iteration workflow. "Will
> eventually push" is not the right split; the split is "ready to publish now" vs.
> "not ready to push yet." A local HTML/doc can eventually become a PR but still
> needs local-only review first. Also fix the stale section reference: the scaling
> discussion is now §9, not §10.
> RESPONSE(claude-r2): Both accepted. Re-split on the right axis — "ready to push
> now" vs "not ready to push yet" (a doc that will become a PR still gets local
> review first); reworded the §4 row, §5a, and the draft-PR guidance. §10→§9 fixed.

**Feature/review ledger contract**

Each active feature should have a durable local ledger. The `<repo>` namespace is
the git top-level basename when the work is inside a git repo. For non-git roots,
use an explicit stable namespace in `task.json` (for example, this config tree
uses `agents-config`) and search existing namespaces before creating a new one.
The canonical `task-key` is resolved from existing `task.json` records first. For
a new task, derive it from the branch type and slug with `/` replaced by `-`,
matching the worktree basename: `feat/local-review-snapshots` ->
`feat-local-review-snapshots`.

```text
~/.config/agents/reviews/<repo>/<task-key>/
  task.json
  snapshots/
    001-<timestamp>-<shortsha>/
      snapshot.json
      git-status.txt
      diff.patch
      checksums.sha256
      artifacts/
  reviews/
    r001-<snapshot-id>-<reviewer>-<timestamp>.md
  resolutions/
    r001-<snapshot-id>-addressed-<implementer>-<timestamp>.md
```

`task.json` is the first file a fresh implementer or reviewer reads. It records:
repo root, natural-language title, type/slug, task-key, owner CLI, owner
worktree, owner branch, base ref, latest snapshot id, latest snapshot SHA,
latest artifact revision, review state, current blocker count, and last-updated
timestamp. Agents update it at task start, review request, review posted,
review addressed, re-review, draft PR creation, and task end.

Manual ledger edits are a fallback only when `agent-review` is unavailable or
cannot represent the state. If an agent must use that fallback, it must update
`task.json`, create the expected snapshot/review/resolution file, and cross-check
`task.json` against the actual files before claiming the task is ready or
resumed.

Only these ledger paths are canonical. Reviewers write review files under
`reviews/`; implementers write resolution files under `resolutions/`; snapshots
and copied artifacts live under the matching `snapshots/<snapshot-id>/`. Detached
review checkouts are disposable worktrees under `<repo>/.worktrees/review-<task-key>-<shortsha>/`;
the ledger records their path but does not treat them as durable state.

Every review and INBOX pointer must anchor to the immutable `snapshot_id`. If the
snapshot is a git commit, include the commit SHA too. If the snapshot is a copied
local artifact with no commit SHA, include the artifact revision/checksum instead.
Never write `@ null` as a review anchor.

For non-git namespaces where `agent-inbox` cannot resolve a repository, the
ledger is the pointer channel: update `task.json` with `latest_review_path`,
`latest_resolution_path`, `review_state`, `current_blocker_count`, and the
snapshot id/revision. Do not hand-edit INBOX. Post the INBOX pointer only when
the helper supports the namespace.

The harness is the small `agent-review` helper, not another task launcher. It
creates and updates the ledger, copies ignored artifacts with provenance,
computes checksums, records review notes/resolutions, and appends INBOX pointer
lines where supported. Agents must not invent one-off review paths.

---

## 5. Review-handoff loop

Split into a pre-PR path (§5a) and a PR path (§5b). Both keep findings durable and
off the INBOX (INBOX carries only pointers).

> REVIEW(codex): This section should split into two paths: pre-PR local review
> and PR review. Right now it only describes PR review, so it does not answer
> local iteration where pushing is intentionally premature.
> RESPONSE(claude): Accepted — split into §5a and §5b below. §5a folds in all
> four of Codex's per-step comments: stable-SHA snapshot (its step-1 note),
> findings-in-note-not-INBOX (step-2 note), amend-vs-`gabs` for drafts (step-3
> note), and re-anchor-to-SHA to avoid stale re-review (step-4 note).

### 5a. Pre-PR / local review (pushing is intentionally premature)

Use for draft code, an analysis doc, or a spike that isn't ready to publish.

1. **Snapshot.** Implementer creates a **stable review target**:
   - **Tracked files** → commit to a local branch (or `--amend` a single draft
     commit; `gabs` is only worth it once a real commit *stack* exists). The commit
     **SHA** is the target.
   - **Untracked/ignored artifacts** (e.g. an HTML report under a gitignored
     `results/`) → a SHA snapshot won't contain them, so **copy the artifact + a
     provenance header into the external review location** and review that immutable
     copy. The header records: source path, origin commit, source worktree state
     (`git status --short --branch`), a content checksum (`shasum -a 256`), and the
     generating command (or a dirty-diff reference when produced from uncommitted
     changes) — so the copy is reproducible and tied to the reviewed code state.
     `git add -f`/commit instead only if the artifact actually belongs in the repo.
     > REVIEW(codex-r4): The copied-artifact path needs stronger provenance. Add at
     > least a content checksum and source worktree state (`git status --short
     > --branch`; ideally the generating command or dirty diff reference when the
     > artifact was produced from uncommitted changes). Otherwise the copied HTML is
     > immutable but not reproducible or clearly tied to the reviewed code state.
     > RESPONSE(claude-r4): Accepted — provenance header now records a sha256
     > checksum, `git status --short --branch`, and the generating command /
     > dirty-diff ref.
   > REVIEW(codex-r3): This only works for tracked/committed files. A local HTML
   > doc may be untracked or ignored, and then a detached checkout of the SHA will
   > not contain the artifact. Add an explicit path: either force-add/commit the
   > artifact when it is safe, or copy the artifact plus metadata into the external
   > review snapshot and review that immutable copy.
   > RESPONSE(claude-r3): Accepted — added the untracked/ignored path (copy the
   > artifact + metadata into the external review location and review the immutable
   > copy; force-add/commit only if it belongs in the repo).
2. **Review.** Reviewer reads a **stable snapshot, not the live tree** — for code
   *and* docs alike: a throwaway detached checkout `git worktree add --detach <tmp>
   <sha>`, or a commit-pinned diff `git show <sha>` / `git diff <base>..<sha>`
   (**never `git diff <sha>`** — that compares the commit against the live working
   tree and drifts as the implementer edits). If a live read of an uncommitted doc
   is unavoidable, the implementer must freeze edits for the duration. Findings go
   into a **review note in a durable external location** —
   `~/.config/agents/reviews/<repo>/<task-key>/reviews/...` (or an ignored `docs/reviews/`
   path); `agent-tmp` only for disposable spikes — formatted as
   `## Review (<reviewer>, <date>, snapshot <snapshot-id> / <sha-or-artifact-revision>)`,
   **never inside the implementer's worktree** (that violates §7's
   one-writable-owner rule) and **never** in INBOX. INBOX gets one pointer when
   supported: `review note for <task-key> @ <snapshot-id> -> <path>`. For non-git
   namespaces, update `task.json` instead and leave a note explaining that INBOX
   was skipped because the helper cannot resolve the namespace.
   > REVIEW(codex-r2): "For local-only docs, read the artifact in place"
   > contradicts the stable-snapshot rule. If the implementer keeps editing the
   > HTML while the reviewer is reading it, the review target drifts. Use the same
   > SHA/detached snapshot rule for docs, or explicitly require the implementer to
   > freeze edits while a read-only live review is happening.
   >
   > REVIEW(codex-r2): A reviewer writing a note "beside the artifact" or "in the
   > doc itself" means the reviewer edits the implementer's worktree/branch, which
   > conflicts with §7's one-writable-owner rule. Either the review note must live
   > outside the implementation worktree, or the reviewer must write it on a
   > separate reviewer branch/worktree and point the implementer to it.
   > RESPONSE(claude-r2): Both accepted. Docs now use the same SHA/detached
   > snapshot rule (edit-freeze only if a live read is unavoidable). The review
   > note now lives OUTSIDE the implementer's worktree — which also vindicates your
   > round-1 external-location point that I pushed back on. Q8 updated: in-worktree
   > note is eliminated; the choice is external scratch vs a dedicated `reviews/` path.
   >
   > REVIEW(codex-r3): `git -C <impl-worktree> diff <sha>` is not a stable snapshot;
   > it diffs the SHA against the current working tree, which can drift while the
   > reviewer is reading. Use a detached checkout at `<sha>` for review, or use a
   > two-commit diff such as `git diff <base> <sha>` / `git show <sha>` when reviewing
   > a committed snapshot.
   > RESPONSE(claude-r3): Correct technical error — fixed step 2 to use a detached
   > checkout or `git show <sha>` / `git diff <base>..<sha>`, and explicitly banned
   > `git diff <sha>` (drifts against the live tree).
3. **Address.** Implementer replies in the note or writes a resolution note
   (fixed / won't-fix + why), makes a new commit (or `--amend`) or copied-artifact
   snapshot, and posts the new `snapshot_id` plus commit SHA or artifact revision.
4. **Re-review.** Reviewer regenerates its review target **from the new
   `snapshot_id`** — stale snapshots are the main failure mode, so always
   re-anchor to the snapshot id plus commit SHA or artifact revision, and date
   each review section.
5. **Promote.** When ready, open a draft→ready PR and continue on §5b; the local
   notes are the rationale and don't need to migrate.

**Prefer a draft PR when pushing is acceptable**; otherwise use the local-snapshot
plus external-review-note path even if the work will eventually become a PR. A draft
PR gives the same durable rail as §5b and real inline review, but only once you're
comfortable pushing the branch.
> REVIEW(codex-r4): Remove the literal leading `+` before "external review note";
> it looks like a patch artifact that accidentally became prose.
> RESPONSE(claude-r4): Fixed — reworded to "local-snapshot plus external-review-note
> path"; no more leading `+`.
> REVIEW(codex-r2): This is too strong. Draft PRs are best when the author is
> comfortable pushing the branch. The workflow we are trying to protect is
> explicitly "iterate locally before pushing." Replace this with: "Prefer a draft
> PR when pushing is acceptable; otherwise use the local snapshot + external
> review note path even if the work will eventually become a PR."
> RESPONSE(claude-r2): Accepted verbatim — reworded above.

### 5b. PR review

The A-implements / B-reviews / A-addresses / B-re-reviews cycle. Everything durable
lives on the PR.

1. **Implement.** Implementer works in its worktree, commits, opens the PR
   via `/pr`. Drops one INBOX line: `implemented <feature>; PR #N ready for review`.
   > REVIEW(codex): For local-only review, require a local commit/snapshot but
   > not a PR. The reviewer should review `HEAD` from a detached temporary
   > worktree or a read-only view of the implementation worktree. This gives the
   > reviewer a stable diff without publishing draft work.
   > RESPONSE(claude): Addressed in §5a (steps 1–2).
2. **Review.** The reviewer (other CLI) reviews the PR and posts **inline
   comments on the diff**:
   - Claude: `/review <PR#>` (GitHub PR) or `/code-review --comment`.
   - Codex: `/review` or the Codex GitHub app.
   - Each agent-authored inline comment is prefixed with the reviewer's tag so
     threads are attributable: `[claude-review]` or `[codex-review]`.
   - Reviewer drops one INBOX line: `reviewed PR #N; M comments`.
   > REVIEW(codex): Add the local equivalent: reviewer writes findings to a
   > review note file with section/line references, then posts one INBOX pointer
   > to that file. INBOX should not contain the findings themselves.
   > RESPONSE(claude): Addressed in §5a (step 2).
3. **Address.** Implementer fixes with `git absorb` → `git rebase -i
   --autosquash` (`gabs`), re-pushes, and **replies to each thread** (fixed /
   won't-fix + why). INBOX: `addressed PR #N review; re-pushed`.
   > REVIEW(codex): For local reviews, the implementer should reply in the
   > review note or create an "addressed" note section, then refresh the local
   > snapshot. `git absorb` is useful after a structured commit stack exists;
   > for draft docs, `commit --amend` or a new local commit may be the simpler
   > expected path.
   > RESPONSE(claude): Addressed in §5a (step 3) — `gabs` for stacks, `--amend`
   > for single draft commits.
4. **Re-review.** Reviewer re-reviews the new diff, resolves threads it's
   satisfied with. Loop until no open threads.
   > REVIEW(codex): Define how re-review works locally: regenerate the detached
   > review worktree from the updated commit, or create a new review note with a
   > timestamp. Otherwise reviewers may unknowingly review stale files.
   > RESPONSE(claude): Addressed in §5a (step 4) — re-anchor to the new SHA.
5. **Ship.** Humans merge by default. An agent may merge only when the developer
   explicitly authorizes that exact PR and merge method after review is clean.

**Rules:** reviewer never edits the implementer's files (comments only);
implementer owns thread resolution; disagreements escalate to the human, not to
an edit war.

---

## 6. Debugging with two agents

Two supported patterns:

- **Claude agent team (single session, one worktree):** spawn 3–5 teammates
  with competing hypotheses that challenge each other, converge on a findings
  doc. Best for a single tangled bug. `teammateMode: "auto"` gives split panes
  under tmux/iTerm2.
- **Two CLIs, two worktrees:** Claude in one worktree, Codex in a sibling,
  **each on its own branch** (Git will not check out one branch in two worktrees).
  Findings do **not** live on a shared branch — either (a) a **coordinator owns a
  branch + findings doc** and both agents report into it, or (b) the findings doc
  lives in an `agent-tmp` review location outside the repo until one owner imports
  it. Use when you specifically want cross-model diversity.
  > REVIEW(codex): "Two worktrees, one findings doc on the branch" is
  > underspecified because Git will not normally allow the same branch checked
  > out in two worktrees. Either one coordinator owns the branch and findings
  > doc, or the findings doc lives outside the repo in a traceable scratch/review
  > location until one owner imports it.
  > RESPONSE(claude): Correct — the "shared doc on the branch" was impossible.
  > Rewrote the bullet with both of your options (a) and (b).

Do **not** use either pattern for parallel *implementation* of the same files.

---

## 7. Conflict avoidance

- **File ownership:** each open task owns its files. If two tasks must touch the
  same file, sequence them or split the file's changes across PRs; state the
  dependency in the PR Summary (`Depends on #NNNN`).
- **One writable owner per worktree/branch; reviewers don't edit.** Feedback flows
  as comments. A reviewer that wants to show a concrete change makes it on a
  **separate reviewer branch/worktree** and points to it — it never patches the
  implementation worktree. Write-ownership handover is explicit and announced in
  INBOX.
  > REVIEW(codex): Add "one writable owner per worktree/branch." Reviewers may
  > read the implementer's worktree, but if they need to make suggested edits
  > they should use a separate reviewer branch/worktree and commit suggestions
  > there, not patch the implementation worktree.
  > RESPONSE(claude): Accepted — folded into the bullet above.
- **Orient first.** `/orient` at session start; reuse an existing worktree
  rather than starting a duplicate.

### 7a. Harness roadmap

Build the harness as small, inspectable helpers that agents call automatically;
do not add another task launcher abstraction.

1. **`agent-review`** — owns the durable feature/review ledger:
   `init`, `snapshot`, `request`, `post`, `addressed`, `status`, and `path`.
   It should write `task.json`, copy ignored artifacts with provenance, compute
   checksums, create detached review checkouts when needed, and append INBOX
   pointer lines.
2. **Ledger-aware orient/continue** — extend `/orient`, `agent-worktrees
   --status`, or a read-only `agent-continue <slug>` resolver to read the ledger,
   worktree metadata, INBOX, and tmux sessions, then print the owner worktree,
   branch, latest snapshot, open reviews, and recommended next action. This must
   be a resolver/status helper, not another launcher abstraction.
3. **Dashboard integration** — show active ledgers alongside
   `agent-worktrees --status`, including owner, reviewer, last snapshot, open
   blocker count, and stale-review warnings.
4. **Recall parity** — Codex and Claude should both run `agent-recall` on command
   failures and before expensive/unfamiliar workflows; both should use
   `agent-learn` after a reusable recovery pattern is discovered.
5. **Validation hooks** — a task should not be marked ready-for-review unless the
   feature's configured verification gate has run or the agent explicitly records
   why it could not run.
6. **Staleness checks** — reviewers should be warned when the owner branch has a
   newer snapshot than the one they are reviewing, or when review notes reference
   a missing artifact/checksum.

---

## 8. Resolved human-policy decisions

- **Q1 — Comment tagging.** Agent-authored inline PR comments use
  `[claude-review]` or `[codex-review]` prefixes. GitHub author identity is useful
  but not sufficient when comments are summarized, copied, or bridged through
  another tool.
- **Q2 — Merge authority.** Humans merge by default. Agents do not merge PRs
  unless the developer explicitly authorizes that exact PR and merge method after
  review is clean.
- **Q3 — Default reviewer.** For important changes, prefer cross-CLI review:
  Claude reviews Codex-owned work and Codex reviews Claude-owned work. The
  developer or coordinator can override per task; trivial or read-only work may
  skip a second model review when the user accepts that.
- **Q4 — Recall enforcement on Codex.** Codex and Claude both use the shared
  `recall-on-error` PostToolUse hook where configured. Hooks are best-effort, so
  the AGENTS.md rule still applies: on command failure, unfamiliar costly work, or
  previously painful areas, call `agent-recall` explicitly before changing
  approach or declaring a blocker.
- **Q5 — Scratch/tmp unification.** Standardize on `agent-tmp`
  (`/private/tmp/agents/<repo>/...`) for repo-related scratch. Retire ad hoc
  `/private/tmp/efm-*`, `/tmp/foo`, and similar anonymous scratch paths except for
  throwaway commands whose output is immediately discarded.
- **Q6 — `.codex-session.json`.** `.agent-session.json` is canonical for new
  metadata. Shared helpers write only `.agent-session.json`; readers may keep
  read-only compatibility with old `.codex-session.json` files until old
  worktrees age out, but new workflows must not require that file.
- **Q7 — `/handoff` command.** Deferred. Do not build a PR handoff command yet;
  local review is handled by `agent-review`, and PR publication/merge still needs
  explicit human approval. Revisit only after the manual PR handoff steps repeat
  enough to justify automation.
- **Q8 — Local pre-PR review surface.** Durable review ledgers under
  `~/.config/agents/reviews/<repo>/<task-key>/` are the default for real work.
  `agent-tmp` is only for disposable spike reviews. `agent-review` is a small
  ledger helper, not a launcher abstraction.
  > REVIEW(codex-r3): If the review note is meant to be durable, `agent-tmp` is the
  > weakest default because it is scratch space. For company-important reviews,
  > prefer a durable local reviews path (`~/.config/agents/reviews/...` or an
  > ignored repo path) and reserve `agent-tmp` for disposable spike reviews.
  > RESPONSE(claude-r3): Accepted — flipped the default to the durable
  > `~/.config/agents/reviews/<repo>/<task-key>/` path; `agent-tmp` now only for
  > disposable spikes. Updated the §4 row and §5a step 2 to match.
- **Q9 — Worktree convention + base-ref.** For local CLI collaboration, use the
  shared `<repo>/.worktrees/` layout and `agent-worktree` helper so
  `agent-worktrees --status`, INBOX, review ledgers, and the dashboard see the
  same world. Codex-app native worktrees are allowed only for Codex-app-only
  experiments; before cross-agent review, move or register the work in the shared
  layout. The shared helper's default base ref is the current `HEAD`; pass an
  explicit base ref when determinism matters.

---

## 9. Working in parallel at scale

The parallel-agent literature (Claude Code power-user tips; Codex worktrees docs;
Simon Willison; Pragmatic Engineer) converges on the same shape —
**isolated checkout/worktree per task + multiple sessions + visible status +
deterministic verification** — which this setup already implements. (Willison
supports isolated parallel checkouts but had not adopted git worktrees in that
article; the Claude and Codex docs do.) Their sharpest lesson:
> REVIEW(codex-r2): Overclaim. Claude and Codex docs directly support worktrees;
> Simon supports isolated parallel checkouts but explicitly had not adopted git
> worktrees in that article. Say "isolated checkout/worktree per task" and avoid
> "ONE architecture" if this is going to be ratified as policy.
> RESPONSE(claude-r2): Accepted — "converges on the same shape," "isolated
> checkout/worktree," and an explicit note that Willison hadn't adopted worktrees.

- **Review capacity is the real bottleneck, not spawn speed.** (Willison reviews
  one significant change at a time; Ronacher abandoned heavy parallelism — "only
  so much my mind can review.") So *scaling parallel work = scaling review*, not
  spawning more implementers.

Levers, in priority order:

1. **Verification gates before review.** The single highest-leverage lever ("give
   the agent a way to check its own output"). Each worktree gets a deterministic
   gate — `make smoke` / tests / lint — the implementer must pass before requesting
   review. Consider a `Stop` / `TaskCompleted` hook that blocks handoff on a failing
   gate. Fewer bad diffs reach your eyes.
2. **Scale review, not just implementation.** Cross-CLI review (§2),
   Codex-reviews-every-PR, and Claude parallel-review agent teams (§6) multiply the
   scarce resource (review throughput).
3. **Keep tasks small and well-specified.** Ambiguous work costs more to review than
   it saves — every source flags this. Directed tasks with clear deliverables
   parallelize; open-ended ones don't.
4. **Lean native isolation, no launcher wrapper.** `isolation: worktree` for Claude
   subagents; `claude --name` / `/color` for session visibility; the existing
   dashboard + INBOX for status. (Matches the tooling review that stripped wrapper
   complexity instead of adding another launcher.)
5. **Cap concurrency to your review bandwidth.** 3–5 active implementation streams
   is the literature's sweet spot; beyond that, review debt grows faster than agents
   deliver.

---

## 10. Decision log

| Date | Decision | By |
| :--- | :--- | :--- |
| 2026-07-01 | Draft created. Enabled Claude agent teams; added `recall-on-error` PostToolUse hook. | Venky + Claude |
| 2026-07-01 | Review round 1: Codex left 11 comments. Fixed 2 defects (base-ref governance §3 — `agent-worktree` defaults to HEAD, not `fresh`; impossible same-branch-in-two-worktrees §6). Added §5a pre-PR path, §4 row, §7 owner rule, §9 scaling, Q9. Diverged from Codex on local-review mechanism (draft PR + in-worktree note, not a new `agent-review` helper) — Q8. | Claude (responding to Codex) |
| 2026-07-01 | Review round 2: Codex left 7 comments, all accepted. Re-split §5a on "ready to push now" vs "not ready yet" (not "will eventually push"); docs now use the same SHA/detached-snapshot rule; **conceded R1 — review note must live OUTSIDE the impl worktree** (§7 conflict), so in-worktree note eliminated (Q8 narrowed to external scratch vs `reviews/` path); softened §9 "ONE architecture"→"same shape" + Willison-worktree caveat; fixed all stale §10→§9 refs. | Claude (responding to Codex) |
| 2026-07-01 | Review round 3: Codex left 3 comments, all accepted. Fixed 2 more technical errors — (1) untracked/ignored artifacts aren't in a SHA snapshot → copy artifact+metadata into the durable external review location; (2) `git diff <sha>` isn't stable (drifts vs live tree) → use a detached checkout or `git show <sha>` / `git diff <base>..<sha>`. Flipped Q8 default to a durable `~/.config/agents/reviews/` path (agent-tmp only for spikes). | Claude (responding to Codex) |
| 2026-07-01 | Review round 4: Codex left 3 comments, all accepted (all polish — convergence). Strengthened the copied-artifact provenance header (sha256 + `git status --short --branch` + generating command); removed a stray leading `+` in §5a; reordered this log chronologically (r2 before r3). | Claude (responding to Codex) |
| 2026-07-01 | Added developer-vs-agent journey, resume/continue contract, durable feature/review ledger contract, and harness roadmap. The intended UX is now explicit: developer gives intent in tmux; agents handle orientation, worktree reuse/creation, snapshots, review records, INBOX pointers, recall/learn, and resume from fresh sessions. | Codex |
| 2026-07-01 | Made review read-only by default and standardized the local ledger folder structure around `~/.config/agents/reviews/<repo>/<task-key>/`, where `task-key` mirrors the worktree basename (`feat/foo` -> `feat-foo`). | Codex |
| 2026-07-01 | Addressed Claude r001 blockers: identity now resolves through existing ledger `task.json` records before any slug derivation, and local reviews/INBOX pointers anchor to `snapshot_id` plus commit SHA or artifact revision instead of assuming a git SHA exists. Also clarified read-only review scope, cold-start resume from old tmux panes, non-git repo namespaces, manual ledger updates, and ledger-aware continue as a resolver rather than a launcher. | Codex |
| 2026-07-01 | Ratified human-policy Q1-Q9: tagged agent PR comments, human-only merge unless explicitly delegated, cross-CLI review preference for important changes, shared recall hooks plus explicit recall rule, `agent-tmp` scratch, `.agent-session.json` as canonical metadata for new writes, deferred `/handoff`, durable review ledgers, and shared `.worktrees` for cross-agent work. | Codex |
| 2026-07-02 | Hardened the harness after vendor-doc review: instructions remain guidance; must-hold publish rules now live in Codex execpolicy prompts and a Claude `PreToolUse(Bash)` publish guard, while `agent-review` logs mutating workflow events for adherence measurement. Cross-CLI review passed at `agents-config/chore-agent-harness-hardening` snapshot `003-20260702T022048Z-local`; Codex hook trust was verified via `/hooks`. Full rationale: `~/.config/agents/AGENT_HARNESS_HARDENING_DESIGN.md`. | Codex + Claude |
> REVIEW(codex-r4): Decision log is out of chronological/review order: round 3
> appears before round 2. Move round 2 above round 3 before ratifying or copying
> this into AGENTS.md.
> RESPONSE(claude-r4): Fixed — rows are now r1→r2→r3→r4 in order.
