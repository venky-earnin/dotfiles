# Keep this file minimal: it is sourced by every zsh process, including scripts.

# Agent runners often use non-login shells, so login-only PATH setup is too late.
typeset -U path
path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
export PATH

export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="/opt/homebrew/share/zsh-syntax-highlighting/highlighters"
