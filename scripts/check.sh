#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> git whitespace check"
git diff --check

echo "==> sensitive content scan"
./scripts/check-sensitive.sh

if command -v brew >/dev/null 2>&1; then
  echo "==> Brewfile syntax"
  brew bundle list --file Brewfile --all >/dev/null
else
  echo "==> Brewfile syntax skipped: brew not installed"
fi

echo "==> shell syntax"
for file in scripts/*.sh home/.local/bin/* home/bin/agent-* home/.claude/hooks/*.sh home/.config/agents/hooks/*.sh; do
  bash -n "$file"
done

echo "==> python syntax"
python3 -m py_compile \
  home/.config/agents/bin/agent-review \
  home/.config/agents/tests/test_agent_hooks.py \
  home/.config/agents/tests/test_agent_review.py

echo "==> zsh syntax"
for file in home/.zshrc home/.zprofile home/.zshenv; do
  zsh -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  shellcheck scripts/*.sh home/.local/bin/* home/bin/agent-* home/.claude/hooks/*.sh home/.config/agents/hooks/*.sh
else
  echo "==> shellcheck skipped: not installed"
fi

if command -v shfmt >/dev/null 2>&1; then
  echo "==> shfmt"
  shfmt -i 2 -ci -d scripts/*.sh home/.local/bin/* home/bin/agent-* home/.claude/hooks/*.sh home/.config/agents/hooks/*.sh
else
  echo "==> shfmt skipped: not installed"
fi

echo "==> bootstrap dry-run"
./scripts/bootstrap.sh --dry-run --skip-tools >/dev/null

echo "check passed"
