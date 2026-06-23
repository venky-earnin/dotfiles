#!/usr/bin/env bash
set -euo pipefail

dry_run=false
tools_mode=prompt
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run | -n)
      dry_run=true
      shift
      ;;
    --install-tools)
      tools_mode=always
      shift
      ;;
    --skip-tools)
      tools_mode=never
      shift
      ;;
    -h | --help)
      echo "usage: scripts/bootstrap.sh [--dry-run] [--install-tools|--skip-tools]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_root="${repo_root}/home"

run() {
  if "$dry_run"; then
    printf '+ %q' "$1"
    shift
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf '\n'
  else
    "$@"
  fi
}

backup_existing() {
  local target="$1"
  if [[ -L "$target" ]]; then
    return 0
  fi
  if [[ -e "$target" ]]; then
    local backup
    backup="${target}.backup.$(date -u +%Y%m%dT%H%M%SZ)"
    echo "backup: $target -> $backup"
    run mv "$target" "$backup"
  fi
}

link_file() {
  local rel="$1"
  local src="${home_root}/${rel}"
  local target="${HOME}/${rel}"
  [[ -e "$src" ]] || {
    echo "missing source: $src" >&2
    exit 1
  }
  run mkdir -p "$(dirname "$target")"
  backup_existing "$target"
  run ln -sfn "$src" "$target"
}

link_tree_files() {
  local base="$1"
  while IFS= read -r src; do
    local rel="${src#"${home_root}"/}"
    link_file "$rel"
  done < <(find "${home_root}/${base}" -type f | sort)
}

install_brew_tools() {
  local brewfile="${repo_root}/Brewfile"
  [[ -f "$brewfile" ]] || {
    echo "missing Brewfile: $brewfile" >&2
    exit 1
  }

  if "$dry_run"; then
    run brew bundle --file "$brewfile"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install tools from Brewfile." >&2
    echo "Install Homebrew from https://brew.sh, then rerun:" >&2
    echo "  ${repo_root}/scripts/bootstrap.sh --install-tools" >&2
    exit 1
  fi

  run brew bundle --file "$brewfile"
}

maybe_install_brew_tools() {
  case "$tools_mode" in
    never)
      return 0
      ;;
    always)
      install_brew_tools
      return 0
      ;;
    prompt)
      if "$dry_run"; then
        echo "dry-run: would prompt to install tools from Brewfile"
        return 0
      fi
      if [[ ! -t 0 || ! -t 1 ]]; then
        echo "tool install skipped: rerun with --install-tools or run: brew bundle --file ${repo_root}/Brewfile"
        return 0
      fi

      local answer
      printf 'Install command-line tools from Brewfile now? [y/N] '
      read -r answer
      case "$answer" in
        [Yy] | [Yy][Ee][Ss]) install_brew_tools ;;
        *) echo "tool install skipped" ;;
      esac
      ;;
    *)
      echo "unknown tools mode: $tools_mode" >&2
      exit 2
      ;;
  esac
}

top_level_files=(
  ".zshrc"
  ".zprofile"
  ".zshenv"
  ".gitconfig"
  ".tmux.conf.local"
  ".wezterm.lua"
)

for rel in "${top_level_files[@]}"; do
  link_file "$rel"
done

link_tree_files ".config"
link_tree_files ".claude"
link_tree_files "bin"

run chmod 700 "${HOME}/.config" "${HOME}/.claude" "${HOME}/bin"
run chmod 755 "${HOME}"/bin/agent-* "${HOME}"/.claude/hooks/*.sh

# Codex compatibility symlinks.
run mkdir -p "${HOME}/.codex/bin"
backup_existing "${HOME}/.codex/AGENTS.md"
run ln -sfn "${HOME}/.config/agents/AGENTS.md" "${HOME}/.codex/AGENTS.md"
run ln -sfn "${HOME}/bin/agent-worktree" "${HOME}/.codex/bin/codex-worktree"
run ln -sfn "${HOME}/bin/agent-worktrees" "${HOME}/.codex/bin/codex-worktrees"
run ln -sfn "${HOME}/bin/agent-tmp" "${HOME}/.codex/bin/codex-tmp"

# tmux framework: use upstream checkout, keep local overrides in this repo.
if [[ ! -d "${HOME}/.config/oh-my-tmux/.git" ]]; then
  run git clone --depth=1 https://github.com/gpakosz/.tmux.git "${HOME}/.config/oh-my-tmux"
fi
backup_existing "${HOME}/.tmux.conf"
run ln -sfn "${HOME}/.config/oh-my-tmux/.tmux.conf" "${HOME}/.tmux.conf"

# zsh plugin clone, not vendored into this repo.
if [[ ! -d "${HOME}/.config/zsh/plugins/fzf-tab/.git" ]]; then
  run git clone --depth=1 https://github.com/Aloxaf/fzf-tab "${HOME}/.config/zsh/plugins/fzf-tab"
fi

if [[ ! -e "${HOME}/.config/zsh/private.zsh" ]]; then
  run mkdir -p "${HOME}/.config/zsh"
  run cp "${repo_root}/examples/private.zsh.example" "${HOME}/.config/zsh/private.zsh"
  run chmod 600 "${HOME}/.config/zsh/private.zsh"
fi

maybe_install_brew_tools

echo "done"
