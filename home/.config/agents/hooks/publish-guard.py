#!/usr/bin/env python3
"""Claude PreToolUse hook: require approval for publish-sensitive Bash commands."""

from __future__ import annotations

import json
import os
import re
import shlex
import sys
from pathlib import PurePath
from typing import Any


PR_MUTATING_COMMANDS = {"create", "edit", "merge", "ready", "close", "comment"}
WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}
SHELLS = {"bash", "sh", "zsh"}
GIT_GLOBAL_OPTIONS_WITH_VALUE = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--super-prefix",
}
GH_API_FIELD_FLAGS = {"-f", "-F", "--field", "--raw-field", "--input"}


def tool_name(payload: dict[str, Any]) -> str:
    return str(
        payload.get("tool_name")
        or payload.get("toolName")
        or payload.get("tool")
        or payload.get("name")
        or ""
    )


def bash_command(payload: dict[str, Any]) -> str:
    tool_input = payload.get("tool_input") or payload.get("toolInput") or payload.get("input") or {}
    if not isinstance(tool_input, dict):
        return ""
    return str(tool_input.get("command") or tool_input.get("cmd") or tool_input.get("script") or "")


def split_segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return [[command]]
    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in {";", "&&", "||", "|", "&", "\n"}:
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def command_basename(token: str) -> str:
    return PurePath(token).name


def strip_env(tokens: list[str]) -> list[str]:
    out = list(tokens)
    while out and "=" in out[0] and not out[0].startswith("-"):
        key = out[0].split("=", 1)[0]
        if key and key.replace("_", "").isalnum() and not key[0].isdigit():
            out.pop(0)
            continue
        break
    if out and command_basename(out[0]) == "env":
        out.pop(0)
        while out and "=" in out[0] and not out[0].startswith("-"):
            out.pop(0)
    return out


def nested_shell_script(tokens: list[str]) -> str | None:
    if not tokens or command_basename(tokens[0]) not in SHELLS:
        return None
    i = 1
    while i < len(tokens):
        token = tokens[i]
        if token in {"-c", "-lc"}:
            return tokens[i + 1] if i + 1 < len(tokens) else None
        if "c" in token[1:] and token.startswith("-") and not token.startswith("--"):
            return tokens[i + 1] if i + 1 < len(tokens) else None
        i += 1
    return None


def git_subcommand(tokens: list[str]) -> str | None:
    if not tokens or command_basename(tokens[0]) != "git":
        return None
    i = 1
    while i < len(tokens):
        token = tokens[i]
        if token in GIT_GLOBAL_OPTIONS_WITH_VALUE:
            i += 2
            continue
        if any(token.startswith(opt + "=") for opt in GIT_GLOBAL_OPTIONS_WITH_VALUE if opt.startswith("--")):
            i += 1
            continue
        if token.startswith("-"):
            i += 1
            continue
        return token
    return None


def gh_method(tokens: list[str]) -> str | None:
    for i, token in enumerate(tokens):
        if token in {"-X", "--method"} and i + 1 < len(tokens):
            return tokens[i + 1].upper()
        if token.startswith("-X") and len(token) > 2:
            return token[2:].upper()
        if token.startswith("--method="):
            return token.split("=", 1)[1].upper()
    return None


def gh_api_mutates(tokens: list[str]) -> bool:
    method = gh_method(tokens)
    if method in WRITE_METHODS:
        return True
    return any(token in GH_API_FIELD_FLAGS or any(token.startswith(flag + "=") for flag in GH_API_FIELD_FLAGS) for token in tokens)


def segment_reason(tokens: list[str]) -> str | None:
    tokens = strip_env(tokens)
    if not tokens:
        return None

    script = nested_shell_script(tokens)
    if script is not None:
        return command_reason(script)

    subcmd = git_subcommand(tokens)
    if subcmd in {"push", "merge"}:
        return f"git {subcmd}"

    if len(tokens) >= 3 and command_basename(tokens[0]) == "gh" and tokens[1] == "pr" and tokens[2] in PR_MUTATING_COMMANDS:
        return f"gh pr {tokens[2]}"

    if len(tokens) >= 2 and command_basename(tokens[0]) == "gh" and tokens[1] == "api" and gh_api_mutates(tokens[2:]):
        method = gh_method(tokens[2:]) or "write"
        return f"gh api {method}"

    return None


def command_reason(command: str) -> str | None:
    for segment in split_segments(command):
        reason = segment_reason(segment)
        if reason:
            return reason
    return raw_command_reason(command)


def raw_command_reason(command: str) -> str | None:
    git_match = re.search(
        r"(?<![\w./-])git(?:\s+(?:-[Cc]\s+\S+|-c\s+\S+|--(?:git-dir|work-tree|namespace)(?:=\S+|\s+\S+)|-[A-Za-z]+))*\s+(push|merge)\b",
        command,
    )
    if git_match:
        return f"git {git_match.group(1)}"

    pr_match = re.search(r"(?<![\w./-])gh\s+pr\s+(create|edit|merge|ready|close|comment)\b", command)
    if pr_match:
        return f"gh pr {pr_match.group(1)}"

    method_match = re.search(
        r"(?<![\w./-])gh\s+api\b[^\n;&|]*(?:-X\s*(POST|PUT|PATCH|DELETE)|--method(?:=|\s+)(POST|PUT|PATCH|DELETE))\b",
        command,
        flags=re.IGNORECASE,
    )
    if method_match:
        method = next(group for group in method_match.groups() if group)
        return f"gh api {method.upper()}"

    if re.search(r"(?<![\w./-])gh\s+api\b[^\n;&|]*(?:\s-[fF]\s|\s--(?:field|raw-field|input)(?:=|\s+))", command):
        return "gh api write"

    return None


def ask(reason: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": (
                        f"{reason} may publish, mutate a PR, or merge code. "
                        "Explicit developer approval is required for this exact action."
                    ),
                },
                "suppressOutput": True,
            }
        )
    )


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    if tool_name(payload) != "Bash":
        return 0
    command = bash_command(payload)
    if not command:
        return 0
    reason = command_reason(command)
    if reason:
        ask(reason)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
