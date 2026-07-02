#!/usr/bin/env python3
"""Smoke tests for the local agent-review harness."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REAL_HOME = Path.home()
AGENT_REVIEW = REAL_HOME / ".config" / "agents" / "bin" / "agent-review"
AGENT_INBOX = REAL_HOME / "bin" / "agent-inbox"
AGENT_WORKTREE = REAL_HOME / "bin" / "agent-worktree"
AGENT_WORKTREES = REAL_HOME / "bin" / "agent-worktrees"


class Harness:
    def __init__(self, test: unittest.TestCase):
        self.test = test
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.config = self.home / ".config" / "agents"
        self.home.mkdir(parents=True)
        self.config.mkdir(parents=True)
        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        self.env["AGENTS_CONFIG_HOME"] = str(self.config)
        self.env["AGENT_REVIEWS_ROOT"] = str(self.config / "reviews")
        self.env["PATH"] = f"{REAL_HOME / 'bin'}:{self.env.get('PATH', '')}"

    def close(self) -> None:
        self.tmp.cleanup()

    def run(self, args: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        proc = subprocess.run(args, cwd=cwd, env=self.env, text=True, capture_output=True)
        if check and proc.returncode != 0:
            self.test.fail(f"{args} failed\nstdout={proc.stdout}\nstderr={proc.stderr}")
        return proc

    def agent_review(self, *args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        return self.run([str(AGENT_REVIEW), *args], cwd=cwd, check=check)

    def agent_review_with_env(
        self,
        *args: str,
        cwd: Path | None = None,
        env_updates: dict[str, str],
        check: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        env = self.env.copy()
        env.update(env_updates)
        proc = subprocess.run([str(AGENT_REVIEW), *args], cwd=cwd, env=env, text=True, capture_output=True)
        if check and proc.returncode != 0:
            self.test.fail(f"{args} failed\nstdout={proc.stdout}\nstderr={proc.stderr}")
        return proc

    def git(self, repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return self.run(["git", *args], cwd=repo)

    def make_repo(self) -> Path:
        repo = self.root / "repo"
        repo.mkdir()
        self.git(repo, "init")
        self.git(repo, "config", "user.email", "agent-review@example.test")
        self.git(repo, "config", "user.name", "Agent Review Test")
        (repo / "README.md").write_text("hello\n", encoding="utf-8")
        self.git(repo, "add", "README.md")
        self.git(repo, "commit", "-m", "init")
        return repo


class AgentReviewTests(unittest.TestCase):
    def setUp(self) -> None:
        self.h = Harness(self)

    def tearDown(self) -> None:
        self.h.close()

    def test_git_snapshot_is_sha_only_and_blocks_dirty_tracked_files(self) -> None:
        repo = self.h.make_repo()
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Add review harness",
            "--type-slug",
            "feat/review-harness",
            "--repo",
            "repo",
            cwd=repo,
        ).stdout.strip()

        dirty = repo / "README.md"
        dirty.write_text("dirty\n", encoding="utf-8")
        proc = self.h.agent_review("snapshot", "--ledger", ledger, cwd=repo, check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("dirty tracked files", proc.stderr)

        self.h.git(repo, "add", "README.md")
        self.h.git(repo, "commit", "-m", "change")
        snap = self.h.agent_review("snapshot", "--ledger", ledger, cwd=repo).stdout.strip()
        task = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(task["latest_snapshot_id"], snap)
        self.assertIsNotNone(task["latest_snapshot_sha"])
        self.assertFalse((Path(ledger) / "snapshots" / snap / "artifacts").exists())

    def test_explicit_artifact_is_content_addressed_and_deduped(self) -> None:
        artifact = self.h.root / "report.html"
        artifact.write_text("<h1>same</h1>\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Review report",
            "--type-slug",
            "docs/report-review",
            "--repo",
            "agents-config",
            "--source",
            str(artifact),
            cwd=self.h.root,
        ).stdout.strip()
        snap1 = self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root).stdout.strip()
        snap2 = self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root).stdout.strip()
        root = Path(ledger) / "artifacts" / "by-sha256"
        artifact_files = [p for p in root.rglob("*") if p.is_file()]
        self.assertEqual(len(artifact_files), 1)
        first = json.loads((Path(ledger) / "snapshots" / snap1 / "artifacts.json").read_text(encoding="utf-8"))
        second = json.loads((Path(ledger) / "snapshots" / snap2 / "artifacts.json").read_text(encoding="utf-8"))
        self.assertTrue(first["artifacts"][0]["copied"])
        self.assertFalse(second["artifacts"][0]["copied"])

    def test_multi_artifact_revision_is_stable_across_dedup(self) -> None:
        a = self.h.root / "a.txt"
        b = self.h.root / "b.txt"
        a.write_text("a\n", encoding="utf-8")
        b.write_text("b\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Stable multi artifact",
            "--type-slug",
            "docs/stable-multi-artifact",
            "--repo",
            "agents-config",
            cwd=self.h.root,
        ).stdout.strip()
        self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(a), "--artifact", str(b), cwd=self.h.root)
        first = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))["latest_artifact_revision"]
        self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(a), "--artifact", str(b), cwd=self.h.root)
        second = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))["latest_artifact_revision"]
        self.assertEqual(first, second)

    def test_post_stale_refusal_and_addressed_requires_newer_snapshot(self) -> None:
        artifact = self.h.root / "doc.md"
        artifact.write_text("v1\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Review doc",
            "--type-slug",
            "docs/review-doc",
            "--repo",
            "agents-config",
            "--source",
            str(artifact),
            cwd=self.h.root,
        ).stdout.strip()
        snap1 = self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root).stdout.strip()
        review = self.h.root / "review.md"
        review.write_text(f"**Reviewed snapshot:** `{snap1}`\n\n0 blockers\n", encoding="utf-8")
        posted = self.h.agent_review(
            "post",
            "--ledger",
            ledger,
            "--reviewer",
            "claude",
            "--snapshot",
            snap1,
            "--blockers",
            "0",
            "--file",
            str(review),
            cwd=self.h.root,
        ).stdout.strip()
        resolution = self.h.root / "resolution.md"
        resolution.write_text("fixed\n", encoding="utf-8")
        proc = self.h.agent_review("addressed", "--ledger", ledger, "--review", posted, "--file", str(resolution), cwd=self.h.root, check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("newer latest snapshot", proc.stderr)

        artifact.write_text("v2\n", encoding="utf-8")
        self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root)
        before = artifact.read_bytes()
        self.h.agent_review("addressed", "--ledger", ledger, "--review", posted, "--file", str(resolution), cwd=self.h.root)

        stale = self.h.agent_review(
            "post",
            "--ledger",
            ledger,
            "--reviewer",
            "claude",
            "--snapshot",
            snap1,
            "--blockers",
            "0",
            "--file",
            str(review),
            cwd=self.h.root,
            check=False,
        )
        self.assertNotEqual(stale.returncode, 0)
        self.assertIn("stale review", stale.stderr)
        self.assertEqual(artifact.read_bytes(), before)

    def test_post_adopts_existing_ledger_review_without_duplicate(self) -> None:
        artifact = self.h.root / "doc.md"
        artifact.write_text("v1\n", encoding="utf-8")
        ledger = Path(
            self.h.agent_review(
                "init",
                "--title",
                "Adopt review",
                "--type-slug",
                "docs/adopt-review",
                "--repo",
                "agents-config",
                cwd=self.h.root,
            ).stdout.strip()
        )
        snap = self.h.agent_review("snapshot", "--ledger", str(ledger), "--artifact", str(artifact), cwd=self.h.root).stdout.strip()
        review = ledger / "reviews" / f"r001-{snap}-claude-20260701T000000Z.md"
        review.write_text(f"**Reviewed snapshot:** `{snap}`\n\n0 blockers\n", encoding="utf-8")

        posted = self.h.agent_review(
            "post",
            "--ledger",
            str(ledger),
            "--reviewer",
            "claude",
            "--snapshot",
            "latest",
            "--blockers",
            "0",
            "--file",
            str(review),
            cwd=self.h.root,
        ).stdout.strip()

        task = json.loads((ledger / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(Path(posted).resolve(), review.resolve())
        self.assertEqual(Path(task["latest_review_path"]).resolve(), review.resolve())
        self.assertEqual(task["review_state"], "reviewed_no_blockers")
        self.assertEqual(len(list((ledger / "reviews").glob("*.md"))), 1)

    def test_legacy_migrate_and_agent_inbox_repo(self) -> None:
        ledger = Path(
            self.h.agent_review(
                "init",
                "--title",
                "Legacy review",
                "--type-slug",
                "docs/legacy-review",
                "--repo",
                "agents-config",
                cwd=self.h.root,
            ).stdout.strip()
        )
        legacy_dir = ledger / "snapshots" / "001-20260701T000000Z-local" / "artifacts"
        legacy_dir.mkdir(parents=True)
        (legacy_dir / "old.txt").write_text("legacy\n", encoding="utf-8")
        dry = json.loads(self.h.agent_review("migrate", "--ledger", str(ledger), cwd=self.h.root).stdout)
        self.assertFalse(dry["apply"])
        self.assertEqual(len(dry["migrations"]), 1)
        self.h.agent_review("migrate", "--ledger", str(ledger), "--apply", cwd=self.h.root)
        self.assertTrue((ledger / "snapshots" / "001-20260701T000000Z-local" / "artifacts.json").exists())
        self.assertEqual(len([p for p in (ledger / "artifacts" / "by-sha256").rglob("*") if p.is_file()]), 1)
        self.assertFalse((ledger / "snapshots" / "001-20260701T000000Z-local" / "artifacts").exists())
        again = json.loads(self.h.agent_review("migrate", "--ledger", str(ledger), "--apply", cwd=self.h.root).stdout)
        self.assertEqual(again["migrations"], [])

        self.h.run([str(AGENT_INBOX), "--repo", "agents-config", "hello from non-git"], cwd=self.h.root)
        inbox = self.h.config / "inbox" / "agents-config" / "INBOX.md"
        self.assertIn("hello from non-git", inbox.read_text(encoding="utf-8"))

    def test_resolve_ambiguity_fails_loud(self) -> None:
        for slug in ("one-thing", "two-thing"):
            self.h.agent_review(
                "init",
                "--title",
                "Shared thing",
                "--type-slug",
                f"docs/{slug}",
                "--repo",
                "agents-config",
                cwd=self.h.root,
            )
        proc = self.h.agent_review("resolve", "Shared thing", "--repo", "agents-config", cwd=self.h.root, check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("multiple ledgers match", proc.stderr)

    def test_init_infers_owner_cli_from_claude_env_and_rejects_invalid_owner(self) -> None:
        ledger = Path(
            self.h.agent_review_with_env(
                "init",
                "--title",
                "Claude owned",
                "--type-slug",
                "docs/claude-owned",
                "--repo",
                "agents-config",
                cwd=self.h.root,
                env_updates={"CLAUDE_PROJECT_DIR": str(self.h.root)},
            ).stdout.strip()
        )
        task = json.loads((ledger / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(task["owner_cli"], "claude")

        invalid = self.h.agent_review(
            "init",
            "--title",
            "Invalid owner",
            "--type-slug",
            "docs/invalid-owner",
            "--repo",
            "agents-config",
            "--owner-cli",
            "not-a-cli",
            cwd=self.h.root,
            check=False,
        )
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("owner-cli must be one of", invalid.stderr)

    def test_worktree_repo_derivation_uses_main_repo_namespace(self) -> None:
        repo = self.h.make_repo()
        worktree = self.h.root / "repo-linked-worktree"
        self.h.git(repo, "worktree", "add", "-b", "feat/worktree-task", str(worktree))
        ledger = Path(
            self.h.agent_review(
                "init",
                "--title",
                "Worktree task",
                "--type-slug",
                "feat/worktree-task",
                cwd=worktree,
            ).stdout.strip()
        )
        self.assertEqual(ledger.parent.name, "repo")
        task = json.loads((ledger / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(task["repo"], "repo")
        self.h.agent_review("snapshot", "--ledger", str(ledger), cwd=worktree)
        self.h.agent_review("request", "--ledger", str(ledger), cwd=worktree)
        inbox = self.h.config / "inbox" / "repo" / "INBOX.md"
        self.assertIn("feat-worktree-task", inbox.read_text(encoding="utf-8"))

    def test_status_json_exposes_owner_fields_for_dashboard(self) -> None:
        repo = self.h.make_repo()
        branch = self.h.git(repo, "branch", "--show-current").stdout.strip()
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Dashboard visibility",
            "--type-slug",
            "feat/dashboard-visibility",
            "--repo",
            "repo",
            cwd=repo,
        ).stdout.strip()
        rows = json.loads(self.h.agent_review("status", "--all", "--json", cwd=repo).stdout)
        row = next(r for r in rows if r["path"] == ledger)
        self.assertEqual(row["owner_worktree"], str(repo.resolve()))
        self.assertEqual(row["owner_worktree_realpath"], str(repo.resolve()))
        self.assertEqual(row["owner_branch"], branch)
        self.assertEqual(row["type_slug"], "feat/dashboard-visibility")

    def test_agent_worktrees_status_includes_matching_review_state(self) -> None:
        repo = self.h.make_repo()
        worktree = self.h.root / "repo-linked-worktree"
        self.h.git(repo, "worktree", "add", "-b", "feat/dashboard-visibility", str(worktree))
        self.h.agent_review(
            "init",
            "--title",
            "Dashboard visibility",
            "--type-slug",
            "feat/dashboard-visibility",
            cwd=worktree,
        )

        status = self.h.run([str(AGENT_WORKTREES), "--status"], cwd=worktree).stdout
        self.assertIn("● repo-linked-worktree", status)
        self.assertIn("review  initialized blockers=? snapshot=- task=feat-dashboard-visibility", status)

    def test_agent_worktrees_status_matches_owner_worktree_by_realpath(self) -> None:
        repo = self.h.make_repo()
        worktree = self.h.root / "repo-linked-worktree"
        symlink = self.h.root / "repo-worktree-link"
        self.h.git(repo, "worktree", "add", "-b", "feat/realpath-match", str(worktree))
        ledger = Path(
            self.h.agent_review(
                "init",
                "--title",
                "Realpath match",
                "--type-slug",
                "feat/realpath-match",
                cwd=worktree,
            ).stdout.strip()
        )
        symlink.symlink_to(worktree, target_is_directory=True)
        task_path = ledger / "task.json"
        task = json.loads(task_path.read_text(encoding="utf-8"))
        task["owner_worktree"] = str(symlink)
        task_path.write_text(json.dumps(task, indent=2) + "\n", encoding="utf-8")

        status = self.h.run([str(AGENT_WORKTREES), "--status"], cwd=worktree).stdout
        self.assertIn("review  initialized blockers=? snapshot=- task=feat-realpath-match", status)

    def test_agent_worktrees_status_reports_ambiguous_branch_matches(self) -> None:
        repo = self.h.make_repo()
        branch = self.h.git(repo, "branch", "--show-current").stdout.strip()
        ledgers = []
        for slug in ("ambiguous-one", "ambiguous-two"):
            ledger = Path(
                self.h.agent_review(
                    "init",
                    "--title",
                    "Ambiguous branch",
                    "--type-slug",
                    f"docs/{slug}",
                    "--repo",
                    "repo",
                    cwd=repo,
                ).stdout.strip()
            )
            task_path = ledger / "task.json"
            task = json.loads(task_path.read_text(encoding="utf-8"))
            task["owner_worktree"] = str(self.h.root / f"elsewhere-{slug}")
            task["owner_branch"] = branch
            task_path.write_text(json.dumps(task, indent=2) + "\n", encoding="utf-8")
            ledgers.append(ledger)

        status = self.h.run([str(AGENT_WORKTREES), "--status"], cwd=repo).stdout
        self.assertIn("review  2 ledgers: docs-ambiguous-one,docs-ambiguous-two", status)

    def test_agent_worktree_writes_only_canonical_session_metadata(self) -> None:
        repo = self.h.make_repo()
        worktree = Path(
            self.h.run(
                [str(AGENT_WORKTREE), "--cli", "codex", "docs/metadata-policy"],
                cwd=repo,
            ).stdout.strip()
        )
        self.assertTrue((worktree / ".agent-session.json").is_file())
        self.assertFalse((worktree / ".codex-session.json").exists())

    def test_artifact_dir_cap_and_verify_failure_state(self) -> None:
        artifact_dir = self.h.root / "artifacts"
        artifact_dir.mkdir()
        (artifact_dir / "a.txt").write_text("a\n", encoding="utf-8")
        (artifact_dir / "b.txt").write_text("b\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Verify failure",
            "--type-slug",
            "docs/verify-failure",
            "--repo",
            "agents-config",
            "--verification-required",
            cwd=self.h.root,
        ).stdout.strip()
        snap = self.h.agent_review(
            "snapshot",
            "--ledger",
            ledger,
            "--artifact-dir",
            str(artifact_dir),
            "--max-files",
            "1",
            "--verify",
            "false",
            cwd=self.h.root,
        ).stdout.strip()
        snapshot = json.loads((Path(ledger) / "snapshots" / snap / "snapshot.json").read_text(encoding="utf-8"))
        task = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))
        self.assertTrue(snapshot["artifact_dir_truncated"])
        self.assertEqual(snapshot["verification"]["status"], "failed")
        self.assertEqual(task["review_state"], "implementation_in_progress")
        failed = self.h.agent_review("request", "--ledger", ledger, cwd=self.h.root, check=False)
        self.assertNotEqual(failed.returncode, 0)
        self.h.agent_review("request", "--ledger", ledger, "--request-anyway", "--reason", "testing override", cwd=self.h.root)

    def test_post_blockers_sets_blocked_and_request_refuses_without_resolution(self) -> None:
        artifact = self.h.root / "blocked.md"
        artifact.write_text("v1\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Blocked flow",
            "--type-slug",
            "docs/blocked-flow",
            "--repo",
            "agents-config",
            cwd=self.h.root,
        ).stdout.strip()
        snap = self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root).stdout.strip()
        review = self.h.root / "blocked-review.md"
        review.write_text(f"**Reviewed snapshot:** `{snap}`\n\n2 blockers\n", encoding="utf-8")
        self.h.agent_review(
            "post",
            "--ledger",
            ledger,
            "--reviewer",
            "claude",
            "--snapshot",
            snap,
            "--blockers",
            "2",
            "--file",
            str(review),
            cwd=self.h.root,
        )
        task = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(task["review_state"], "blocked")
        refused = self.h.agent_review("request", "--ledger", ledger, cwd=self.h.root, check=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("open blockers", refused.stderr)

    def test_git_snapshot_base_ref_diff_path(self) -> None:
        repo = self.h.make_repo()
        base = self.h.run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Base diff",
            "--type-slug",
            "docs/base-diff",
            "--repo",
            "repo",
            "--base-ref",
            base,
            cwd=repo,
        ).stdout.strip()
        (repo / "README.md").write_text("changed\n", encoding="utf-8")
        self.h.git(repo, "add", "README.md")
        self.h.git(repo, "commit", "-m", "change readme")
        snap = self.h.agent_review("snapshot", "--ledger", ledger, cwd=repo).stdout.strip()
        diff = (Path(ledger) / "snapshots" / snap / "diff.patch").read_text(encoding="utf-8")
        self.assertIn("+changed", diff)

    def test_concurrent_snapshots_leave_valid_json(self) -> None:
        a = self.h.root / "a.txt"
        b = self.h.root / "b.txt"
        a.write_text("a\n", encoding="utf-8")
        b.write_text("b\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Concurrent snapshots",
            "--type-slug",
            "docs/concurrent-snapshots",
            "--repo",
            "agents-config",
            cwd=self.h.root,
        ).stdout.strip()
        commands = [
            [str(AGENT_REVIEW), "snapshot", "--ledger", ledger, "--artifact", str(a)],
            [str(AGENT_REVIEW), "snapshot", "--ledger", ledger, "--artifact", str(b)],
        ]
        procs = [subprocess.Popen(cmd, cwd=self.h.root, env=self.h.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for cmd in commands]
        outputs = [p.communicate(timeout=10) for p in procs]
        for proc, (stdout, stderr) in zip(procs, outputs, strict=True):
            self.assertEqual(proc.returncode, 0, f"stdout={stdout}\nstderr={stderr}")
        json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))
        snapshots = [p for p in (Path(ledger) / "snapshots").iterdir() if p.is_dir()]
        self.assertEqual(len(snapshots), 2)

    def test_request_records_note_when_inbox_helper_missing(self) -> None:
        artifact = self.h.root / "doc.md"
        artifact.write_text("v1\n", encoding="utf-8")
        ledger = self.h.agent_review(
            "init",
            "--title",
            "Missing inbox",
            "--type-slug",
            "docs/missing-inbox",
            "--repo",
            "agents-config",
            "--source",
            str(artifact),
            cwd=self.h.root,
        ).stdout.strip()
        self.h.agent_review("snapshot", "--ledger", ledger, "--artifact", str(artifact), cwd=self.h.root)
        self.h.agent_review_with_env("request", "--ledger", ledger, cwd=self.h.root, env_updates={"PATH": "/usr/bin:/bin"})
        task = json.loads((Path(ledger) / "task.json").read_text(encoding="utf-8"))
        self.assertEqual(task["review_state"], "review_requested")
        self.assertIn("INBOX pointer skipped", task["notes"])

    def test_mutating_commands_append_event_log_and_status_is_quiet(self) -> None:
        log = self.h.root / "agent-review-events.jsonl"
        artifact = self.h.root / "doc.md"
        artifact.write_text("v1\n", encoding="utf-8")
        env = {"AGENT_REVIEW_EVENT_LOG": str(log), "AGENT_CLI": "claude"}

        ledger = self.h.agent_review_with_env(
            "init",
            "--title",
            "Logged task",
            "--type-slug",
            "docs/logged-task",
            "--repo",
            "agents-config",
            "--source",
            str(artifact),
            cwd=self.h.root,
            env_updates=env,
        ).stdout.strip()
        snap = self.h.agent_review_with_env(
            "snapshot",
            "--ledger",
            ledger,
            "--artifact",
            str(artifact),
            cwd=self.h.root,
            env_updates=env,
        ).stdout.strip()
        self.h.agent_review_with_env("request", "--ledger", ledger, "--reviewer", "codex", cwd=self.h.root, env_updates=env)
        before_status = log.read_text(encoding="utf-8")
        self.h.agent_review_with_env("status", "--repo", "agents-config", cwd=self.h.root, env_updates=env)
        self.assertEqual(log.read_text(encoding="utf-8"), before_status)

        events = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]
        self.assertEqual([event["command"] for event in events], ["init", "snapshot", "request"])
        self.assertTrue(all(event["outcome"] == "completed" for event in events))
        self.assertTrue(all(event["cli"] == "claude" for event in events))
        self.assertEqual(events[-1]["snapshot_id"], snap)
        self.assertEqual(events[-1]["review_state"], "review_requested")
        self.assertEqual(events[-1]["requested_reviewer"], "codex")

    def test_failed_mutating_command_is_event_logged(self) -> None:
        repo = self.h.make_repo()
        log = self.h.root / "agent-review-events.jsonl"
        ledger = self.h.agent_review_with_env(
            "init",
            "--title",
            "Dirty tracked file",
            "--type-slug",
            "fix/dirty-tracked-file",
            "--repo",
            "repo",
            cwd=repo,
            env_updates={"AGENT_REVIEW_EVENT_LOG": str(log)},
        ).stdout.strip()

        (repo / "README.md").write_text("dirty\n", encoding="utf-8")
        proc = self.h.agent_review_with_env(
            "snapshot",
            "--ledger",
            ledger,
            cwd=repo,
            env_updates={"AGENT_REVIEW_EVENT_LOG": str(log)},
            check=False,
        )
        self.assertNotEqual(proc.returncode, 0)

        events = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(events[-1]["command"], "snapshot")
        self.assertEqual(events[-1]["outcome"], "failed")
        self.assertEqual(events[-1]["exit_code"], 2)


if __name__ == "__main__":
    unittest.main()
