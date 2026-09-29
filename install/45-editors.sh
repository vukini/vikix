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
# The lock Vikix last left in ~/.config/nvim, to tell its plugins' versions
# from yours; and the last lock of Vikix's that yours was said to differ from.
NVIM_SAVED="$VIKIX_STATE/nvim-lock.json"
NVIM_TOLD="$VIKIX_STATE/nvim-lock.told"
NVIM_OLD_STATE="$VIKIX_STATE/nvim-lock"        # 0.55.0's: two checksums
NVIM_LOG="$VIKIX_STATE/logs/nvim-plugins.log"
NVIM_NOTE=''       # said again last, so it isn't lost in the update's output
NVIM_CHANGED=0     # Neovim's files changed: a snapshot after, so they aren't "yours"

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

# nvim_restore [clean] — the plugins, to the versions in the lock. Lazy's
# progress (hundreds of lines) goes to a log of its own, not the update's.
nvim_restore() {
  command -v nvim >/dev/null || { warn "nvim not found; Neovim's plugins come at its first start"; return 1; }
  say "installing Neovim's plugins to lazy-lock.json (a minute or two the first time; log: $NVIM_LOG)"
  # Lazy! = no UI; restore = the locked versions; the treesitter build runs
  # too. clean drops plugins nothing asks for any more.
  local cmd=(nvim --headless "+Lazy! restore")
  [ "${1:-}" = clean ] && cmd+=("+Lazy! clean")
  cmd+=(+qa)
  if [ "$DRY_RUN" = 1 ]; then run "${cmd[@]}"; return 0; fi
  mkdir -p "$(dirname "$NVIM_LOG")"
  "${cmd[@]}" > "$NVIM_LOG" 2>&1 || { warn "Neovim's plugins didn't all install (log: $NVIM_LOG)"; return 1; }
}

save_state() {   # save_state FILE CONTENT-FROM
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$VIKIX_STATE"
  cp "$2" "$1"
}

# The plugins' versions. The lock is yours (Lazy rewrites it whenever a
# plugin comes or goes, :Lazy update moves it on), so it's copied, not
# linked. When Vikix tests newer versions, yours move with them only while
# Vikix's plugins are still at the versions it left: plugins you added
# don't count, and are kept (lib/nvim-lock.py).
nvim_lock() {
  local lock="$NVIM_DIR/lazy-lock.json" ship="$NV/lazy-lock.json" helper="$VIKIX_DIR/lib/nvim-lock.py"
  # 0.55.0 kept two checksums: its lock, if still the same, is the saved one.
  if [ ! -f "$NVIM_SAVED" ] && [ -f "$NVIM_OLD_STATE" ] && [ -f "$lock" ]; then
    local last_user=''
    read -r _ last_user < "$NVIM_OLD_STATE" || true    # "VIKIX-LOCK YOURS"
    [ "$(sha "$lock")" = "$last_user" ] && save_state "$NVIM_SAVED" "$lock"
  fi
  [ "$DRY_RUN" = 1 ] || rm -f "$NVIM_OLD_STATE"

  if [ ! -f "$lock" ]; then
    say "Neovim's plugins: the versions Vikix tested"
    run cp "$ship" "$lock"
  elif [ -f "$NVIM_SAVED" ] && cmp -s "$ship" "$NVIM_SAVED"; then
    [ -d "$NVIM_LAZY" ] && return 0     # nothing new from Vikix, and the plugins are there
    nvim_restore clean || true
    return 0
  elif [ -f "$NVIM_SAVED" ] && python3 "$helper" untouched "$NVIM_SAVED" "$lock"; then
    say "Neovim's plugins move on to the versions Vikix tested last (plugins you added keep theirs)"
    if [ "$DRY_RUN" = 1 ]; then printf '   would merge %s into %s\n' "$ship" "$lock"
    else
      local merged; merged=$(mktemp)
      python3 "$helper" merge "$ship" "$NVIM_SAVED" "$lock" > "$merged" && mv -f "$merged" "$lock" ||
        { rm -f "$merged"; warn "couldn't merge Neovim's lock; yours stays"; return 0; }
    fi
  elif ! cmp -s "$ship" "$lock"; then
    # Vikix's plugins at versions of yours (:Lazy update): said once for
    # each lock Vikix ships.
    if ! cmp -s "$ship" "$NVIM_TOLD" 2>/dev/null; then
      say "your Neovim plugins are at versions of your own (:Lazy update), so they stay."
      echo "   For the ones Vikix tested: cp $ship $lock; vikix update"
      save_state "$NVIM_TOLD" "$ship"
    fi
    return 0
  fi
  NVIM_CHANGED=1
  nvim_restore clean || return 0
  save_state "$NVIM_SAVED" "$ship"
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
      say "Neovim's config now comes with Vikix. Your old one (nvim-void-linux, with no changes of yours) is kept in $bak"
      run mv "$NVIM_DIR" "$bak"
      NVIM_NOTE="Neovim: your old config is kept in $bak; the new one is ~/.config/nvim (your plugins go in its lua/plugins/)"
      moved=1
    else
      clone_or_pull "" "$NVIM_DIR"
      say "your ~/.config/nvim (nvim-void-linux) has changes of yours, so it stays."
      echo "   Neovim's config now comes with Vikix. To switch: move ~/.config/nvim away, vikix update,"
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
    say "Neovim: your config is $NVIM_DIR, copied from Vikix's starter (yours to change); Vikix's part is $NVIM_LAYER"
    run mkdir -p "$NVIM_DIR"
    run cp -R "$NV/starter/." "$NVIM_DIR/"
    NVIM_CHANGED=1
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
# The update's snapshot (40-config) came before this: take one now, or
# vikix changes would show Vikix's starter and lock as changes of yours,
# and vikix undo would take them away.
if [ "$NVIM_CHANGED" = 1 ]; then
  "$VIKIX_DIR/bin/vikix" snapshot "Neovim, set up by Vikix $(cat "$VIKIX_DIR/VERSION")" ||
    warn "no snapshot after setting up Neovim (above)"
fi

ready=()
[ "$emacs" = 1 ] && ready+=("e (Emacs frame)")
[ "$nvim" = 1 ]  && ready+=("v (Neovim)")
say "editors ready: ${ready[*]}"
[ -z "$NVIM_NOTE" ] || say "$NVIM_NOTE"
