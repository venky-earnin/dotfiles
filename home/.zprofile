# Login-shell setup. Interactive behavior belongs in ~/.zshrc.

typeset -U path
path=(
  "$HOME/.codex/bin"
  "$HOME/.local/bin"
  "$HOME/bin"
  /opt/homebrew/bin
  /opt/homebrew/sbin
  "$HOME/.cargo/bin"
  /usr/local/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
  /Library/TeX/texbin
  $path
)
export PATH
