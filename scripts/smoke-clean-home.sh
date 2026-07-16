#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-home.XXXXXX")"

cleanup() {
  rm -rf "$tmp_home"
}
trap cleanup EXIT

# Avoid network during the smoke test while still exercising the bootstrap path
# that expects these upstream checkouts to exist after a real install.
mkdir -p "$tmp_home/.config/oh-my-tmux/.git"
mkdir -p "$tmp_home/.config/zsh/plugins/fzf-tab/.git"
touch "$tmp_home/.config/oh-my-tmux/.tmux.conf"

echo "==> bootstrap into temporary HOME"
HOME="$tmp_home" "$repo_root/scripts/bootstrap.sh" --skip-tools >/dev/null

require_link() {
  local rel="$1"
  if [[ ! -L "$tmp_home/$rel" ]]; then
    echo "expected symlink: ~/$rel" >&2
    exit 1
  fi
}

require_file() {
  local rel="$1"
  if [[ ! -f "$tmp_home/$rel" ]]; then
    echo "expected file: ~/$rel" >&2
    exit 1
  fi
}

require_link ".zshrc"
require_link ".profile"
require_link ".gitconfig"
require_link ".tmux.conf"
require_link ".tmux.conf.local"
require_link ".wezterm.lua"
require_link ".config/agents/AGENTS.md"
require_link ".config/agents/bin/agent-review"
require_link ".config/atuin/config.toml"
require_link ".config/starship.toml"
require_link ".claude/CLAUDE.md"
require_link ".codex/AGENTS.md"
require_link ".codex/hooks.json"
require_link ".codex/rules/default.rules"
require_link ".local/bin/rm"
require_link "bin/agent-review"
require_link "bin/agent-worktree"
require_link "bin/agent-inbox"
require_file ".config/zsh/private.zsh"

echo "==> linked shell syntax"
HOME="$tmp_home" zsh -n "$tmp_home/.zshrc"

echo "==> recoverable rm precedence"
HOME="$tmp_home" zsh -lc '[[ "$(command -v rm)" == "$HOME/.local/bin/rm" ]]'
HOME="$tmp_home" bash -lc '[[ "$(command -v rm)" == "$HOME/.local/bin/rm" ]]'

echo "clean-home smoke test passed"
