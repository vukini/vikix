#!/usr/bin/env bash
# 45-editors — Emacs and Neovim, configured from their git repositories.
#
# The configs are not Vikix's: each is its own repository, cloned into
# the place the editor reads it from, and pulled by `vikix update`.
#
#   ~/.emacs.d       VIKIX_EMACS_REPO  (default: vukini/emacs-void)
#   ~/.config/nvim   VIKIX_NVIM_REPO   (default: vukini/nvim-void-linux)
#
# Only for the editors you chose (the features emacs and neovim: vikix add
# emacs). Anything already at those paths that is not a git clone is left alone.
# Set the two variables in the environment to use other repositories.
#
# Then the pieces the configs assume are on the machine:
#   - language servers: Void's come with each language's list (ccls in
#     lang-c, gopls in lang-go, ...; efm-langserver with Neovim), and the npm ones, put in
#     ~/.local so no sudo is needed: typescript-language-server, pyright,
#     bash-language-server
#   - Neovim's plugins, installed now to the versions in lazy-lock.json,
#     so the first real start is instant
# Emacs installs its own packages the first time it starts; the daemon
# that vikix-session launches at login does that in the background.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/features.sh
. "$(dirname "$0")/../lib/features.sh"

: "${VIKIX_EMACS_REPO:=https://github.com/vukini/emacs-void}"
: "${VIKIX_NVIM_REPO:=https://github.com/vukini/nvim-void-linux}"

# clone_or_pull URL DIR — a clone gets pulled; anything else is left alone.
clone_or_pull() {
  local url=$1 dir=$2
  if [ -d "$dir/.git" ]; then
    say "$dir is a clone; pulling"
    # Over HTTPS even when the clone's remote is SSH (see git_pull).
    git_pull "$dir" || warn "could not update $dir (local changes?)"
  elif [ -e "$dir" ]; then
    warn "$dir exists and is not a git clone; leaving it alone"
  else
    say "cloning $url into $dir"
    run mkdir -p "$(dirname "$dir")"
    run git clone "$url" "$dir"
  fi
}

emacs=0 nvim=0
is_chosen emacs  && emacs=1
is_chosen neovim && nvim=1
if [ "$emacs$nvim" = 00 ]; then
  say "no editor chosen; nothing to do (vikix add emacs, or vikix add neovim)"
  exit 0
fi
[ "$emacs" = 1 ] && clone_or_pull "$VIKIX_EMACS_REPO" "$HOME/.emacs.d"
[ "$nvim" = 1 ]  && clone_or_pull "$VIKIX_NVIM_REPO"  "$HOME/.config/nvim"

# --- npm language servers, into ~/.local/bin ------------------------------
if command -v npm >/dev/null; then
  npm_missing=()
  command -v typescript-language-server >/dev/null || npm_missing+=(typescript-language-server typescript)
  command -v pyright-langserver         >/dev/null || npm_missing+=(pyright)
  command -v bash-language-server       >/dev/null || npm_missing+=(bash-language-server)
  if [ "${#npm_missing[@]}" -eq 0 ]; then
    say "npm language servers already installed"
  else
    say "installing with npm into ~/.local: ${npm_missing[*]}"
    run npm install -g --prefix "$HOME/.local" "${npm_missing[@]}"
  fi
else
  warn "npm not found (nodejs package); skipping the npm language servers"
fi

# --- Neovim plugins, now rather than at first start -----------------------
if [ "$nvim" = 1 ] && command -v nvim >/dev/null && [ -f "$HOME/.config/nvim/lazy-lock.json" ]; then
  say "installing Neovim plugins to lazy-lock.json (a minute or two)"
  # Lazy! = no UI; restore = the locked versions; the treesitter build runs too.
  run nvim --headless "+Lazy! restore" +qa
fi

ready=()
[ "$emacs" = 1 ] && ready+=("e (Emacs frame)")
[ "$nvim" = 1 ]  && ready+=("v (Neovim)")
say "editors ready: ${ready[*]}"
