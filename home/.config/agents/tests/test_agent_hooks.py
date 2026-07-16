#!/usr/bin/env python3
"""Smoke tests for shared agent hook wiring."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REAL_HOME = Path.home()
HOOK_DIR = REAL_HOME / ".config" / "agents" / "hooks"
SESSION_HOOK = HOOK_DIR / "session-start-context.sh"
RECALL_HOOK = HOOK_DIR / "recall-on-error.sh"
REMINDER_HOOK = HOOK_DIR / "review-state-reminder.sh"
SAFE_RM = REAL_HOME / ".local" / "bin" / "rm"


class AgentHookTests(unittest.TestCase):
    def run_hook(
        self,
        hook: Path,
        *,
        cwd: Path,
        env: dict[str, str],
        stdin: str = "",
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(hook)],
            input=stdin,
            cwd=cwd,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_codex_and_claude_hook_config_are_valid_json(self) -> None:
        codex = json.loads((REAL_HOME / ".codex" / "hooks.json").read_text(encoding="utf-8"))
        claude = json.loads((REAL_HOME / ".claude" / "settings.json").read_text(encoding="utf-8"))
        codex_rules = (REAL_HOME / ".codex" / "rules" / "default.rules").read_text(encoding="utf-8")

        self.assertEqual(
            codex["hooks"]["SessionStart"][0]["hooks"][0]["command"],
            "$HOME/.config/agents/hooks/session-start-context.sh",
        )
        self.assertEqual(
            claude["hooks"]["SessionStart"][0]["hooks"][0]["command"],
            "$HOME/.config/agents/hooks/session-start-context.sh",
        )
        self.assertEqual(len(claude["hooks"]["PreToolUse"]), 1)
        self.assertNotIn("ask", claude["permissions"])
        self.assertNotIn("publish-guard.py", json.dumps(claude))
        self.assertNotIn("Bash(rm -rf", json.dumps(claude["permissions"]["allow"]))
        self.assertIn("Bash(/bin/rm *)", claude["permissions"]["deny"])
        self.assertIn('prefix_rule(pattern=["/bin/rm"], decision="forbidden")', codex_rules)
        self.assertEqual(
            codex["hooks"]["PostToolUse"][0]["hooks"][0]["command"],
            "$HOME/.config/agents/hooks/recall-on-error.sh",
        )
        self.assertEqual(
            claude["hooks"]["PostToolUse"][0]["hooks"][0]["command"],
            "$HOME/.config/agents/hooks/recall-on-error.sh",
        )

    def test_safe_rm_accepts_force_recursive_for_a_missing_target(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing"
            proc = subprocess.run(
                [str(SAFE_RM), "-rf", str(missing)],
                cwd=tmp,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_safe_rm_refuses_the_current_working_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [str(SAFE_RM), "-rf", "."],
                cwd=tmp,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(proc.returncode, 2)
            self.assertIn("refusing protected path", proc.stderr)
            self.assertTrue(Path(tmp).exists())

    def test_session_context_emits_valid_json_for_agents_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            config_home = tmp_root / "home" / ".config" / "agents"
            config_home.mkdir(parents=True)
            env = os.environ.copy()
            env["AGENTS_CONFIG_HOME"] = str(config_home)
            env["CLAUDE_PROJECT_DIR"] = str(config_home)
            env["PATH"] = f"{REAL_HOME / 'bin'}:{env.get('PATH', '')}"

            proc = self.run_hook(SESSION_HOOK, cwd=config_home, env=env)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            payload = json.loads(proc.stdout)
            context = payload["hookSpecificOutput"]["additionalContext"]
            self.assertEqual(payload["hookSpecificOutput"]["hookEventName"], "SessionStart")
            self.assertIn("repo: agents-config", context)

    def test_session_context_is_silent_for_codex_startup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            config_home = tmp_root / "home" / ".config" / "agents"
            config_home.mkdir(parents=True)
            env = os.environ.copy()
            env["AGENTS_CONFIG_HOME"] = str(config_home)
            env.pop("CLAUDE_PROJECT_DIR", None)
            env["PATH"] = f"{REAL_HOME / 'bin'}:{env.get('PATH', '')}"

            proc = self.run_hook(SESSION_HOOK, cwd=config_home, env=env)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(proc.stdout, "")

    def test_session_context_is_silent_outside_repo_or_config_namespace(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            config_home = tmp_root / "home" / ".config" / "agents"
            config_home.mkdir(parents=True)
            outside = tmp_root / "outside"
            outside.mkdir()
            env = os.environ.copy()
            env["AGENTS_CONFIG_HOME"] = str(config_home)

            proc = self.run_hook(SESSION_HOOK, cwd=outside, env=env)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(proc.stdout, "")

    def test_recall_hook_is_silent_on_successful_bash_payload(self) -> None:
        payload = json.dumps({"tool_name": "Bash", "tool_response": {"exitCode": 0, "output": "ok"}})
        proc = self.run_hook(RECALL_HOOK, cwd=REAL_HOME, env=os.environ.copy(), stdin=payload)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "")

    def test_recall_hook_is_silent_without_tool_identity(self) -> None:
        payload = json.dumps({"result": {"exit_code": 1, "stderr": "ModuleNotFoundError: No module named missing_pkg"}})
        proc = self.run_hook(RECALL_HOOK, cwd=REAL_HOME, env=os.environ.copy(), stdin=payload)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "")

    def test_recall_hook_handles_codex_shaped_error_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            home = tmp_root / "home"
            bin_dir = home / "bin"
            bin_dir.mkdir(parents=True)
            recall = bin_dir / "agent-recall"
            recall.write_text(
                "#!/usr/bin/env bash\n"
                "printf '### 2026-07-01 -- module import fix\\nFix: install the missing module.\\n'\n",
                encoding="utf-8",
            )
            recall.chmod(0o755)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"
            payload = json.dumps(
                {
                    "toolName": "exec_command",
                    "result": {
                        "exit_code": 1,
                        "stderr": "ModuleNotFoundError: No module named 'missing_pkg'",
                    },
                }
            )

            proc = self.run_hook(RECALL_HOOK, cwd=tmp_root, env=env, stdin=payload)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            output = json.loads(proc.stdout)
            context = output["hookSpecificOutput"]["additionalContext"]
            self.assertIn("Prior LEARNINGS.md entries may apply", context)
            self.assertIn("module import fix", context)

    def test_review_reminder_is_silent_when_no_pending_ledgers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            config_home = tmp_root / "home" / ".config" / "agents"
            config_home.mkdir(parents=True)
            env = os.environ.copy()
            env["AGENTS_CONFIG_HOME"] = str(config_home)
            env["AGENT_REVIEWS_ROOT"] = str(config_home / "reviews")
            env["PATH"] = f"{REAL_HOME / 'bin'}:{env.get('PATH', '')}"

            proc = self.run_hook(REMINDER_HOOK, cwd=config_home, env=env)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(proc.stdout, "")

    def test_review_reminder_pending_gate_and_claude_system_message(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            home = tmp_root / "home"
            config_home = home / ".config" / "agents"
            bin_dir = home / "bin"
            config_home.mkdir(parents=True)
            bin_dir.mkdir(parents=True)
            agent_review = bin_dir / "agent-review"
            agent_review.write_text(
                "#!/usr/bin/env bash\n"
                "printf 'review_requested blockers=1 snapshot=001-local agents-config/chore-example\\n'\n",
                encoding="utf-8",
            )
            agent_review.chmod(0o755)
            env = os.environ.copy()
            env["HOME"] = str(home)
            env["AGENTS_CONFIG_HOME"] = str(config_home)
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"

            codex_proc = self.run_hook(REMINDER_HOOK, cwd=config_home, env=env)
            self.assertEqual(codex_proc.returncode, 0, codex_proc.stderr)
            self.assertEqual(codex_proc.stdout, "")

            claude_env = env.copy()
            claude_env["CLAUDE_PROJECT_DIR"] = str(config_home)
            claude_proc = self.run_hook(
                REMINDER_HOOK,
                cwd=config_home,
                env=claude_env,
                stdin=json.dumps({"stop_hook_active": False}),
            )
            self.assertEqual(claude_proc.returncode, 0, claude_proc.stderr)
            output = json.loads(claude_proc.stdout)
            self.assertIn("systemMessage", output)
            self.assertNotIn("hookSpecificOutput", output)
            self.assertIn("review_requested", output["systemMessage"])

            active_proc = self.run_hook(
                REMINDER_HOOK,
                cwd=config_home,
                env=claude_env,
                stdin=json.dumps({"stop_hook_active": True}),
            )
            self.assertEqual(active_proc.returncode, 0, active_proc.stderr)
            self.assertEqual(active_proc.stdout, "")

if __name__ == "__main__":
    unittest.main()
