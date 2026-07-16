# Login-shell PATH setup for Bash and POSIX shells.

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
