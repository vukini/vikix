#!/usr/bin/env bash
# 45-editors — Emacs and Neovim, with their configs, for the editors you
# chose (the features emacs and neovim: vikix add neovim).
#
# Neovim's config is Vikix's own, split like StumpWM's:
#   ~/.local/share/vikix/nvim   Vikix's part (a link to config/nvim):
#                               AstroNvim and Vikix's plugins, kept current
#   ~/.config/nvim              yours: the starter, copied once (init.lua,
#                               lua/plugins/ for your own specs, which win)
# Set VIKIX_NVIM_REPO to a repository of yours to use that instead; a clone
# (of anything) at ~/.config/nvim is pulled, and anything else left alone.
#
# Emacs's config is a sister repository, cloned and then pulled:
#   ~/.emacs.d       VIKIX_EMACS_REPO  (default: vukini/emacs-void)
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
VIKIX_NVIM_REPO=${VIKIX_NVIM_REPO:-}
# Neovim's config before 0.55: a clone of this, switched to Vikix's below.
OLD_NVIM_REPO=vukini/nvim-void-linux
NV="$VIKIX_DIR/config/nvim"
NVIM_DIR="$HOME/.config/nvim"
NVIM_LAYER="${XDG_DATA_HOME:-$HOME/.local/share}/vikix/nvim"
NVIM_LAZY="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
# "VIKIX-LOCK YOUR-LOCK": the checksums of the lock Vikix last shipped and
# of the one it left in ~/.config/nvim ("-" when that one was yours).
NVIM_LOCK_STATE="$VIKIX_STATE/nvim-lock"

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

sha() { local s; s=$(sha256sum < "$1"); echo "${s%% *}"; }

# The starter Vikix copied: its init.lua loads Vikix's part.
is_vikix_starter() { grep -qsF 'require, "vikix"' "$1/init.lua"; }

old_clone() {
  local url
  [ -d "$1/.git" ] && url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 1
  [[ $url == *"$OLD_NVIM_REPO"* ]]
}

# Nothing of yours in it: no edits (the lock aside, which :Lazy update
# writes), no new files, no commits that aren't on GitHub.
old_clone_unchanged() {
  local edits ahead
  edits=$(git -C "$1" status --porcelain -- . ':!lazy-lock.json' 2>/dev/null) || return 1
  ahead=$(git -C "$1" log --oneline '@{u}..' 2>/dev/null || true)
  [ -z "$edits" ] && [ -z "$ahead" ]
}

# nvim_restore [clean] — the plugins, to the versions in the lock.
nvim_restore() {
  command -v nvim >/dev/null || { warn "nvim not found; Neovim's plugins come at its first start"; return 1; }
  say "installing Neovim's plugins to lazy-lock.json (a minute or two the first time)"
  # Lazy! = no UI; restore = the locked versions; the treesitter build runs
  # too. clean drops plugins nothing asks for (presence.nvim, after 0.55).
  if [ "${1:-}" = clean ]; then run nvim --headless "+Lazy! restore" "+Lazy! clean" +qa
  else run nvim --headless "+Lazy! restore" +qa; fi
}

# The plugins' versions. The lock is yours (Lazy rewrites it, :Lazy update
# moves it), so it's copied, not linked. When Vikix ships a newer one,
# yours moves with it only if it's still the one Vikix left there.
nvim_lock() {
  local lock="$NVIM_DIR/lazy-lock.json" ship="$NV/lazy-lock.json"
  local now_ship now_user="" last_ship="" last_user=""
  now_ship=$(sha "$ship")
  [ -f "$lock" ] && now_user=$(sha "$lock")
  [ -f "$NVIM_LOCK_STATE" ] && read -r last_ship last_user < "$NVIM_LOCK_STATE" || true
  if [ ! -f "$lock" ]; then
    say "Neovim's plugins: the versions Vikix tested"
    run cp "$ship" "$lock"
  elif [ "$now_user" = "$last_user" ]; then
    if [ "$now_ship" = "$last_ship" ]; then
      [ -d "$NVIM_LAZY" ] && return 0     # nothing new, and the plugins are there
    else
      say "Neovim's plugins move on to the versions Vikix tested last"
      run cp "$ship" "$lock"
    fi
  elif [ "$now_user" != "$now_ship" ]; then
    # Yours: said once for each lock Vikix ships.
    if [ "$now_ship" != "$last_ship" ]; then
      say "your ~/.config/nvim/lazy-lock.json has plugin versions of your own, so it stays."
      echo "   For the ones Vikix tested: cp $ship $lock; vikix update"
      [ "$DRY_RUN" = 1 ] || { mkdir -p "$VIKIX_STATE"; echo "$now_ship -" > "$NVIM_LOCK_STATE"; }
    fi
    return 0
  fi
  nvim_restore clean || return 0
  [ "$DRY_RUN" = 1 ] || { mkdir -p "$VIKIX_STATE"; echo "$now_ship $(sha "$lock")" > "$NVIM_LOCK_STATE"; }
}

nvim_config() {
  local moved=0
  if [ -n "$VIKIX_NVIM_REPO" ]; then
    clone_or_pull "$VIKIX_NVIM_REPO" "$NVIM_DIR"
    [ -f "$NVIM_DIR/lazy-lock.json" ] && nvim_restore
    return 0
  fi
  if old_clone "$NVIM_DIR"; then
    if old_clone_unchanged "$NVIM_DIR"; then
      local bak
      bak="$NVIM_DIR.vikix-bak.$(timestamp)"
      say "Neovim's config is now Vikix's own; your clone of nvim-void-linux, unchanged, goes to $bak"
      run mv "$NVIM_DIR" "$bak"
      moved=1
    else
      clone_or_pull "" "$NVIM_DIR"
      say "your ~/.config/nvim (nvim-void-linux) has changes of yours, so it stays."
      echo "   Neovim's config is now Vikix's own. To switch: move ~/.config/nvim away, vikix update,"
      echo "   then put your changes in ~/.config/nvim/lua/plugins/."
      [ -f "$NVIM_DIR/lazy-lock.json" ] && nvim_restore
      return 0
    fi
  elif [ -d "$NVIM_DIR/.git" ]; then
    clone_or_pull "" "$NVIM_DIR"            # a config of your own
    [ -f "$NVIM_DIR/lazy-lock.json" ] && nvim_restore
    return 0
  elif [ -e "$NVIM_DIR" ] && ! is_vikix_starter "$NVIM_DIR"; then
    warn "$NVIM_DIR is neither Vikix's starter nor a git clone; leaving it alone"
    return 0
  fi
  link_managed "$NV" "$NVIM_LAYER"
  if [ ! -e "$NVIM_DIR" ] || [ "$moved" = 1 ]; then
    say "copying Vikix's Neovim starter to $NVIM_DIR (yours from now on)"
    run mkdir -p "$NVIM_DIR"
    run cp -R "$NV/starter/." "$NVIM_DIR/"
  fi
  # A dry run has moved nothing: the lock it would find is the old clone's.
  [ "$DRY_RUN" = 1 ] && [ "$moved" = 1 ] && return 0
  nvim_lock
}

emacs=0 nvim=0
is_chosen emacs  && emacs=1
is_chosen neovim && nvim=1
if [ "$emacs$nvim" = 00 ]; then
  say "no editor chosen; nothing to do (vikix add emacs, or vikix add neovim)"
  exit 0
fi
[ "$emacs" = 1 ] && clone_or_pull "$VIKIX_EMACS_REPO" "$HOME/.emacs.d"

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

# --- Neovim: its config, and its plugins now rather than at first start ---
[ "$nvim" = 1 ] && nvim_config

ready=()
[ "$emacs" = 1 ] && ready+=("e (Emacs frame)")
[ "$nvim" = 1 ]  && ready+=("v (Neovim)")
say "editors ready: ${ready[*]}"
