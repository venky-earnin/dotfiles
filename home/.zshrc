# Interactive zsh setup.

[[ -o interactive ]] || return

# Fast, deterministic PATH setup for Apple Silicon macOS.
typeset -U path fpath
path=(
  "$HOME/.codex/bin"
  "$HOME/.local/bin"
  "$HOME/bin"
  /opt/homebrew/bin
  /opt/homebrew/sbin
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  /usr/local/bin
  /System/Cryptexes/App/usr/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
  /Library/TeX/texbin
  $path
)
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
export PATH

# Editors and pagers.
export EDITOR="cursor --wait"
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PAGER="less"
export LESS="-FRX"

# History.
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=200000
export SAVEHIST=200000
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS

# Local-only secrets, work-specific exports, auth helpers, and certificate
# overrides live here. This file is chmod 600 and should not be committed.
[[ -r "$HOME/.config/zsh/private.zsh" ]] && source "$HOME/.config/zsh/private.zsh"

# Lightweight native completion. Oh My Zsh is installed, but not sourced.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' group-name ''
autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${_zcompdump:h}"
if [[ -r "$_zcompdump" ]]; then
  compinit -C -d "$_zcompdump"
else
  compinit -d "$_zcompdump"
fi
unset _zcompdump

# Modern CLI integrations.
if [[ "$TERM" != "dumb" && -t 0 ]]; then
  [[ -r /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh
  [[ -r /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  # fzf-tab must load after compinit, before zsh-syntax-highlighting.
  [[ -r "$HOME/.config/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] && source "$HOME/.config/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
  [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
if [[ "$TERM" != "dumb" && -t 0 ]] && command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
  bindkey '^X^R' history-incremental-search-backward
fi
if [[ "$TERM" != "dumb" && -t 0 ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Syntax highlighting must be sourced near the end.
if [[ "$TERM" != "dumb" && -t 0 && -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# fzf defaults.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude .venv --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude .venv --exclude node_modules'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || true'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {} 2>/dev/null | head -200'"

# Safer aliases: keep base commands like cat/grep exact, add faster shortcuts.
alias ..='cd ..'
alias ...='cd ../..'
alias ll='eza -lah --group-directories-first --git'
alias la='eza -la --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
alias bcat='bat --paging=never'
alias lg='lazygit'
alias g='git'
alias gs='git status --short --branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --decorate --graph --max-count=30'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gco='git checkout'
alias gb='git branch --sort=-committerdate'
alias c='cursor .'
alias reload-zsh='source ~/.zshrc'
alias rebuild-completions='rm -f ~/.cache/zsh/zcompdump* && autoload -Uz compinit && compinit -d ~/.cache/zsh/zcompdump'
alias ports='lsof -nP -iTCP -sTCP:LISTEN'
alias rewrite='rtk rewrite'
alias tl='tmux list-sessions'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'
alias ccu='ccusage'                       # claude-code token spend (try: ccu daily / ccu monthly)
alias prs='gh dash'                       # PR dashboard TUI
alias md='glow'                           # render markdown in-terminal

# 2026-05-16 power-user tools (geeky-tier installs).
# Keeping aliases narrow on purpose — most tools have short names already (btop,
# tldr, dust, duf, procs, tokei, gum, hyperfine). Don't shadow builtins.
alias dt='difft'                          # structural diff on arbitrary files (`dt a.py b.py`)
alias gdt='git dt'                        # `git dt` = diff via difftastic (gitconfig alias)
alias gdts='git dts'                      # `git dts` = diff --staged via difftastic
alias bench='hyperfine'                   # benchmark commands statistically

# 2026-05-16 git iteration helpers.
# gabs = absorb review fixups into the right historical commits, then auto-squash.
gabs() {
  emulate -L zsh
  local upstream="${1:-@{u}}"
  git absorb --base "$upstream" && git rebase -i --autosquash "$upstream"
}
alias gst='agent-worktrees --status'      # `gst` = unified status across all worktrees

mkcd() {
  mkdir -p "$1" && cd "$1"
}

cwt() {
  agent-worktree "$@"
}

agent-task() {
  emulate -L zsh
  setopt pipefail null_glob

  local cli="${AGENT_CLI:-codex}"
  local auto_yes=false
  local skip_derive=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cli) cli="$2"; shift 2 ;;
      --cli=*) cli="${1#--cli=}"; shift ;;
      -y|--yes) auto_yes=true; shift ;;
      --no-derive) skip_derive=true; shift ;;
      -h|--help)
        echo "Usage: agent-task [--cli codex|claude] [-y|--yes] [--no-derive] <type/task-slug|description> [base-ref]"
        echo "Example: agent-task --cli claude perf/improve-dataloader"
        echo "Example: cx improve-dataloader     # codex shorthand"
        echo "Example: cl improve-dataloader     # claude shorthand"
        echo "Example: cl 'add more decoder metrics and clean up spammy mlflow logs'"
        echo "  (free-form description -> claude haiku derives type/slug;"
        echo "   add -y to skip the y/N confirmation, --no-derive to disable)"
        echo "Example: codex-task / claude-task  # long-form symmetric names"
        return 0
        ;;
      *) break ;;
    esac
  done

  case "$cli" in
    codex|claude) ;;
    *) echo "--cli must be one of: codex, claude" >&2; return 2 ;;
  esac

  if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: agent-task [--cli codex|claude] [-y|--yes] <type/task-slug|description> [base-ref]" >&2
    return 2
  fi

  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed or not on PATH." >&2
    return 1
  fi

  local task="$1"
  local base_ref="${2:-HEAD}"
  local normalized_task branch_type branch_slug repo_root current_repo_root repo_name repo_parent
  local repo_slug worktree_root candidate worktree session session_prefix legacy_session_prefix
  local existing_session launch_cmd cli_prefix
  local lower_task derived reply

  # If the first positional arg isn't already a clean "type/slug" or "slug"
  # (e.g. cl "add more decoder metrics and cleanup spammy mlflow logs"), treat
  # it as a free-form description and ask Claude Haiku to derive a branch
  # name. Confirmation prompt unless -y/--yes was passed.
  lower_task="$(printf '%s' "$task" | tr '[:upper:]' '[:lower:]')"
  if ! $skip_derive && ! [[ "$lower_task" =~ ^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)?$ ]]; then
    if [[ ! -x "$HOME/bin/agent-derive-slug" ]]; then
      echo "agent-task: '$task' isn't a valid slug, and ~/bin/agent-derive-slug isn't installed." >&2
      echo "  install the helper, pass an explicit type/slug, or use --no-derive." >&2
      return 2
    fi
    echo "deriving branch name from description via claude haiku (~5-15s)..." >&2
    derived="$("$HOME/bin/agent-derive-slug" "$task")" || {
      echo "agent-task: failed to derive a branch name; pass an explicit type/slug." >&2
      return 1
    }
    echo "derived: $derived" >&2
    if ! $auto_yes; then
      printf 'proceed with %s? [y/N] ' "$derived" >&2
      read -r reply
      case "$reply" in
        y|Y|yes|YES) ;;
        *) echo "cancelled." >&2; return 1 ;;
      esac
    fi
    task="$derived"
  fi

  normalized_task="$(printf '%s' "$task" | tr '[:upper:]' '[:lower:]')"
  if [[ "$normalized_task" == */* ]]; then
    branch_type="${normalized_task%%/*}"
    branch_slug="${normalized_task#*/}"
  else
    branch_type="chore"
    branch_slug="$normalized_task"
  fi

  case "$branch_type" in
    feat|fix|test|refactor|docs|chore|ci|perf|exp) ;;
    *)
      echo "branch type must be one of: feat, fix, test, refactor, docs, chore, ci, perf, exp" >&2
      return 2
      ;;
  esac

  if [[ "$branch_slug" == */* || ! "$branch_slug" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
    echo "task-slug must contain only letters, numbers, dot, underscore, and dash, and must start with a letter or number" >&2
    return 2
  fi

  current_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "agent-task must be run inside a git repository." >&2
    return 1
  }

  repo_root="$current_repo_root"
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      worktree\ *)
        repo_root="${line#worktree }"
        break
        ;;
    esac
  done < <(git -C "$current_repo_root" worktree list --porcelain)

  repo_name="$(basename "$repo_root")"
  repo_slug="$(printf '%s' "$repo_name" |
    tr '[:upper:]' '[:lower:]' |
    tr -cs 'a-z0-9._-' '-' |
    sed 's/^-//; s/-$//; s/--*/-/g')"
  worktree_root="${repo_root}/.worktrees"
  case "$cli" in
    codex)  cli_prefix="cx" ;;
    claude) cli_prefix="cl" ;;
  esac
  session="${cli_prefix}-${repo_slug}-${branch_type}-${branch_slug}"
  legacy_session_prefix="${cli_prefix}-${branch_slug}-"

  existing_session="$(tmux list-sessions -F '#{session_created} #{session_name}' 2>/dev/null |
    awk -v session="$session" -v legacy="$legacy_session_prefix" '
      $2 == session || index($2, legacy) == 1 {
        if ($1 > newest) {
          newest = $1
          name = $2
        }
      }
      END {
        if (name != "") print name
      }
    ')"

  if [[ -n "$existing_session" ]]; then
    echo "tmux session: $existing_session"
    echo "reusing existing session"
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t "$existing_session"
    else
      tmux attach-session -t "$existing_session"
    fi
    return $?
  fi

  for candidate in "$worktree_root/${branch_type}-${branch_slug}" "$worktree_root/${branch_type}-${branch_slug}-"*; do
    [[ -d "$candidate" ]] || continue
    if [[ -f "$candidate/.agent-session.json" || -f "$candidate/.codex-session.json" ]]; then
      worktree="$candidate"
    fi
  done

  if [[ -n "$worktree" ]]; then
    echo "reusing worktree: $worktree"
  else
    worktree="$("$HOME/bin/agent-worktree" --cli "$cli" "$task" "$base_ref")" || return $?
  fi

  case "$cli" in
    codex)
      launch_cmd="codex --sandbox danger-full-access --dangerously-bypass-approvals-and-sandbox"
      ;;
    claude)
      launch_cmd="claude --dangerously-skip-permissions"
      ;;
  esac

  tmux new-session -d -s "$session" -c "$worktree" || return $?
  tmux send-keys -t "$session:" "$launch_cmd" C-m || return $?

  echo "tmux session: $session"
  echo "worktree: $worktree"
  echo "cli: $cli"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session"
  else
    tmux attach-session -t "$session"
  fi
}

# Back-compat: codex-task name still works.
codex-task() { agent-task --cli codex "$@" }

# Symmetric long form for Claude.
claude-task() { agent-task --cli claude "$@" }

# Shortcuts. cx and cl are chosen to avoid collisions with /usr/bin/cc (C
# compiler) and /usr/bin/at (Unix at scheduler).
cx() { agent-task --cli codex "$@" }
cl() { agent-task --cli claude "$@" }

# cxa/cla — ATTACH a CLI into an EXISTING worktree (no creation).
# Useful when: a tmux session died but the worktree is still there; or
# you want a second CLI on the same worktree without manual cd.
#   no args  → fzf picker over all worktrees of this repo
#   <query>  → exact basename match, then substring (slashes auto-normalized)
cxa() { agent-attach --cli codex  "$@" }
cla() { agent-attach --cli claude "$@" }

# Override EDITOR for AI agents so cursor --wait can't block git commit hooks
# inside an agent shell. The agent inherits these env vars at exec time.
claude() {
  EDITOR=vim VISUAL=vim GIT_EDITOR=vim command claude "$@"
}
codex() {
  EDITOR=vim VISUAL=vim GIT_EDITOR=vim command codex "$@"
}

# cxw: same as `cx` but spawn the worktree+agent in a new WezTerm OS window so
# parallel agents are glanceable across windows instead of buried in tmux.
agent-w() {
  # Generic WezTerm-window-per-task: spawns a new WezTerm window running
  # agent-task with the requested CLI. Falls back to in-pane agent-task if
  # WezTerm CLI is unavailable.
  emulate -L zsh
  local cli="${AGENT_CLI:-codex}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cli)    cli="$2"; shift 2 ;;
      --cli=*)  cli="${1#--cli=}"; shift ;;
      *) break ;;
    esac
  done

  if [[ -z "${WEZTERM_PANE:-}" ]] || ! command -v wezterm >/dev/null 2>&1; then
    echo "agent-w needs WezTerm CLI. Falling back to agent-task in current pane."
    agent-task --cli "$cli" "$@"
    return $?
  fi

  local cmd_str
  cmd_str="$(printf 'agent-task --cli %q' "$cli")"
  local arg
  for arg in "$@"; do
    cmd_str+=" $(printf '%q' "$arg")"
  done
  wezterm cli spawn --new-window --cwd "$PWD" -- zsh -lic "$cmd_str"
}

# Codex / Claude shortcuts for new-WezTerm-window launches.
cxw() { agent-w --cli codex  "$@" }
clw() { agent-w --cli claude "$@" }
