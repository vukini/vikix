# lib/common.sh — helpers shared by every Vikix script.
#
# Sourced, never run. Each helper does one small job:
#   say / warn / die        print progress, a warning, or stop
#   problem MSG             stop, or in a dry run only warn (so a dry run reads to the end)
#   run                     run a command (or only print it when DRY_RUN=1)
#   read_list FILE          print the entries of a list file (no comments, no blanks)
#   pkg_installed PKG       is this xbps package already installed?
#   enable_service SV       switch on the runit service SV
#   ensure_group GROUP [WHY]   add the user to GROUP
#   link_managed SRC DEST   point DEST at a Vikix-owned file (backs up anything in the way)
#   copy_user SRC DEST      give the user a starter file, once; never overwrite
#   ensure_block FILE NAME TEXT [top]   keep one marked block in a file, replaced on re-run
#   sudo_keepalive          ask for the password once, keep sudo valid until the script ends
#   use_mirror URL          point every xbps repository at the mirror URL
#   current_mirror          the mirror /etc/xbps.d points at (empty if none)
#   git_pull DIR            pull a clone, never asking for a password or passphrase

# Where the Vikix checkout lives (the folder that holds install.sh).
: "${VIKIX_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Where Vikix remembers what it has done (migrations already applied).
: "${VIKIX_STATE:=${XDG_STATE_HOME:-$HOME/.local/state}/vikix}"
: "${DRY_RUN:=0}"
# runit's folders: the services there are, and the ones switched on. Only
# tests point these elsewhere.
: "${VIKIX_SV_DIR:=/etc/sv}" "${VIKIX_SERVICE_DIR:=/var/service}"
export VIKIX_DIR VIKIX_STATE DRY_RUN
# An install runs unattended, so nothing may stop to ask a question: git
# fails at once instead of prompting for a username on a missing repo.
export GIT_TERMINAL_PROMPT=0

# Colour only when writing to a terminal. Piped into less or a log file,
# the escape codes would show up as literal "ESC[1;36m" noise.
if [ -t 1 ] && [ -t 2 ]; then
  c_say=$'\033[1;36m' c_warn=$'\033[1;33m' c_die=$'\033[1;31m' c_off=$'\033[0m'
else
  c_say='' c_warn='' c_die='' c_off=''
fi
say()  { printf '%s::%s %s\n' "$c_say"  "$c_off" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%sxx%s %s\n' "$c_die"  "$c_off" "$*" >&2; exit 1; }
problem() { if [ "$DRY_RUN" = 1 ]; then warn "$*"; else die "$*"; fi; }

# run CMD ARGS... — the only way scripts change the system.
# With DRY_RUN=1 it prints the command instead, so a whole install can be
# read before it is done.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '   would run: %s\n' "$*"
  else
    "$@"
  fi
}

# read_list FILE — one entry per line; '#' starts a comment.
read_list() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

pkg_installed() {
  command -v xbps-query >/dev/null 2>&1 && xbps-query "$1" >/dev/null 2>&1
}

# enable_service SV
# Void uses runit, not systemd: a service is switched on by linking its
# folder in /etc/sv into /var/service, and runit then starts it.
enable_service() {
  if [ -e "$VIKIX_SERVICE_DIR/$1" ]; then
    say "service $1 already enabled"
  else
    say "enabling service $1"
    run sudo ln -s "$VIKIX_SV_DIR/$1" "$VIKIX_SERVICE_DIR/"
  fi
}

# ensure_group GROUP [WHY]
# Adds the user to GROUP. Like any group change, it takes effect at the
# next login.
ensure_group() {
  local group=$1 why=${2:+ ($2)}
  # Ask the group database (id -nG USER), not this session's groups, which
  # only change at the next login: a second run in the same session would
  # otherwise add the user again.
  if id -nG "$(id -un)" | tr ' ' '\n' | grep -qx "$group"; then
    say "already in the $group group"
  else
    say "adding $(id -un) to the $group group$why; takes effect at next login"
    run sudo usermod -aG "$group" "$(id -un)"
  fi
}

timestamp() { date +%Y%m%d-%H%M%S; }

# emacs_ai — the running Emacs and Vikix's AI setup (vikix-ai.el): prints
# the checksum of the file it loaded, "old" when it runs without it, or
# nothing when no Emacs is running (or it doesn't answer in 5 seconds).
# Tests point EMACS_SOCKET_NAME nowhere, so they never reach yours.
emacs_ai() {
  command -v emacsclient >/dev/null || return 0
  local r
  r=$(timeout 5 emacsclient -a false -e \
      "(if (featurep 'vikix-ai) (or (bound-and-true-p vikix-ai--sum) \"unknown\") \"old\")" 2>/dev/null) || return 0
  r=${r#\"}; echo "${r%\"}"
}

# link_managed SRC DEST
# Vikix owns SRC. DEST becomes a symlink to it, so `vikix update`
# changes it in place. Anything already at DEST that is not our link is
# moved aside to DEST.vikix-bak.<time>, never deleted.
link_managed() {
  local src=$1 dest=$2
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return 0                                   # already correct
  fi
  run mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local bak
    bak="$dest.vikix-bak.$(timestamp)"
    warn "moving existing $dest to $bak"
    run mv "$dest" "$bak"
  fi
  run ln -s "$src" "$dest"
}

# copy_user SRC DEST
# The user owns DEST. It is created once from SRC and then left alone for
# good — this is where personal changes live.
copy_user() {
  local src=$1 dest=$2
  [ -e "$dest" ] && return 0
  run mkdir -p "$(dirname "$dest")"
  run cp "$src" "$dest"
}

# ensure_block FILE NAME TEXT
# Keeps exactly one block, fenced by '# >>> vikix NAME >>>' and
# '# <<< vikix NAME <<<', in FILE. Re-running replaces the block where it
# is, so there are never duplicates, the blocks keep their order, and
# nothing outside the fence is touched. A new block goes at the end of
# FILE, or with 'top' at the start: there, anything the user wrote below
# it runs later and so wins.
ensure_block() {
  local file=$1 name=$2 text=$3 where=${4:-end}
  local start="# >>> vikix $name >>>" end="# <<< vikix $name <<<"
  if [ "$DRY_RUN" = 1 ]; then
    printf '   would write block "%s" into %s\n' "$name" "$file"
    return 0
  fi
  touch "$file"
  local block tmp
  block=$(printf '%s\n%s\n%s' "$start" "$text" "$end")
  tmp=$(mktemp)
  if grep -qxF "$start" "$file"; then
    # awk -v would turn the backslashes in the text into escapes; ENVIRON doesn't.
    BLOCK=$block awk -v s="$start" -v e="$end" '
      $0 == s { skip = 1; print ENVIRON["BLOCK"]; next }
      $0 == e { skip = 0; next }
      !skip   { print }
    ' "$file" > "$tmp"
  elif [ "$where" = top ]; then
    { printf '%s\n' "$block"; cat "$file"; } > "$tmp"
  else
    { cat "$file"; printf '%s\n' "$block"; } > "$tmp"
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# sudo_keepalive
# Asks for the password once, now, then refreshes sudo's timer every
# minute in the background for as long as this script runs. Without it,
# sudo forgets the password after five minutes and a long install stops
# half way to ask again, with nobody there to answer.
# Drop the API keys (vikix ai key) from this process and what it starts:
# an install or an update runs other people's code (npm, uv, Quicklisp,
# build scripts), and none of it needs them.
drop_keys() {
  local v
  for v in $(compgen -e); do
    case $v in *_API_KEY|*_KEY|*_TOKEN|*_SECRET) unset "$v" ;; esac
  done
}

sudo_keepalive() {
  [ "$DRY_RUN" = 1 ] && return 0
  [ -n "${VIKIX_SUDO_KEPT:-}" ] && return 0     # a parent script already did it
  say "your password, once; after that everything runs by itself"
  sudo -v || die "sudo needs your password to install packages and services"
  local script=$$
  ( while kill -0 "$script" 2>/dev/null; do sudo -n -v 2>/dev/null; sleep 60; done ) \
    >/dev/null 2>&1 &
  VIKIX_SUDO_KEPT=1
  export VIKIX_SUDO_KEPT
}

# use_mirror URL
# Points every xbps repository at URL (a mirror's base, without /current).
# Void's own repository files live in /usr/share/xbps.d; a file of the
# same name in /etc/xbps.d replaces one there, as the Void handbook
# describes. Repositories added later (void-repo-nonfree) bring new files,
# so this is run again after them and copies only what isn't there yet.
use_mirror() {
  local url=${1%/} f base
  run sudo mkdir -p /etc/xbps.d
  for f in /usr/share/xbps.d/*-repository-*.conf; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    [ -e "/etc/xbps.d/$base" ] || run sudo cp "$f" "/etc/xbps.d/$base"
  done
  for f in /etc/xbps.d/*-repository-*.conf; do
    [ -e "$f" ] || continue
    grep -q "^repository=$url/current" "$f" && continue
    say "$(basename "$f"): now $url"
    run sudo sed -i -E "s|^repository=.*/current|repository=$url/current|" "$f"
  done
}

# current_mirror — the mirror /etc/xbps.d points the main repository at.
current_mirror() {
  sed -n 's|^repository=\(.*\)/current$|\1|p' /etc/xbps.d/*-repository-main.conf 2>/dev/null | head -1 || true
}

# git_pull DIR — pull a clone without ever asking for a password or a
# passphrase: `vikix update` may ask for nothing but sudo's password.
# GitHub is read over HTTPS, which needs no login for a public repo, even
# when the clone's remote is SSH (git@github.com:, as in a clone its owner
# pushes from); the remote itself stays as it is. If that fails (a private
# repo, another host), the pull as the clone is set up, with SSH told not to
# ask: a key already loaded in ssh-agent still works.
GIT_HTTPS_GITHUB=(-c 'url.https://github.com/.insteadOf=git@github.com:'
                  -c 'url.https://github.com/.insteadOf=ssh://git@github.com/')
git_pull() {
  run git -C "$1" "${GIT_HTTPS_GITHUB[@]}" pull --ff-only 2>/dev/null ||
    run env GIT_SSH_COMMAND='ssh -o BatchMode=yes' git -C "$1" pull --ff-only
}
