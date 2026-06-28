# xtty zsh shell-integration bootstrap.
#
# xtty launches your shell with ZDOTDIR pointed at this directory, so zsh sources
# THIS .zshenv first. We capture that, restore your real ZDOTDIR, source your own
# startup files, then (for interactive shells) install xtty's OSC 133/7 hooks.
# Your ~/.zprofile / ~/.zshrc / ~/.zlogin still load normally — only .zshenv is
# intercepted. If anything here fails, your shell still starts; you just lose
# semantic capture.

# 1. Capture xtty's integration directory (this is where this file lives).
XTTY_INTEGRATION_DIR="$ZDOTDIR"

# 2. Restore the user's real ZDOTDIR (forwarded by xtty), so the rest of zsh
#    startup reads the user's own files.
if [[ -n "$XTTY_ORIG_ZDOTDIR" ]]; then
  export ZDOTDIR="$XTTY_ORIG_ZDOTDIR"
else
  unset ZDOTDIR
fi
unset XTTY_ORIG_ZDOTDIR

# 3. Source the user's real .zshenv from the restored location.
if [[ -f "${ZDOTDIR:-$HOME}/.zshenv" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshenv"
fi

# 4. Install xtty's integration for interactive shells only.
if [[ -o interactive && -r "$XTTY_INTEGRATION_DIR/xtty-integration" ]]; then
  source "$XTTY_INTEGRATION_DIR/xtty-integration"
fi
unset XTTY_INTEGRATION_DIR
