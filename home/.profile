# Login-shell PATH setup for Bash and POSIX shells.

case ":$PATH:" in
  *:/opt/homebrew/sbin:*) ;;
  *) PATH="/opt/homebrew/sbin:$PATH" ;;
esac
case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH" ;;
esac
export PATH

if [ -r "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi
if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

case "$PATH" in
  "$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
