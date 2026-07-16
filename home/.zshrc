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

# Keep orchestration explicit. Day to day, cd/z into a repo, start tmux windows
# manually, launch the agent CLI directly, and let the agent create a worktree
# with `agent-worktree` when the task needs edits.

# Override EDITOR for AI agents so cursor --wait can't block git commit hooks
# inside an agent shell. The agent inherits these env vars at exec time.
claude() {
  EDITOR=vim VISUAL=vim GIT_EDITOR=vim command claude "$@"
}
codex() {
  EDITOR=vim VISUAL=vim GIT_EDITOR=vim command codex "$@"
}
