# lib/common.sh — helpers shared by every Vikix script.
#
# Sourced, never run. Each helper does one small job:
#   say / warn / die        print progress, a warning, or stop
#   run                     run a command (or only print it when DRY_RUN=1)
#   read_list FILE          print the entries of a list file (no comments, no blanks)
#   pkg_installed PKG       is this xbps package already installed?
#   link_managed SRC DEST   point DEST at a Vikix-owned file (backs up anything in the way)
#   copy_user SRC DEST      give the user a starter file, once; never overwrite
#   ensure_block FILE NAME TEXT   keep one marked block in a file, replaced on re-run
#   sudo_keepalive          ask for the password once, keep sudo valid until the script ends

# Where the Vikix checkout lives (the folder that holds install.sh).
: "${VIKIX_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Where Vikix remembers what it has done (migrations already applied).
: "${VIKIX_STATE:=${XDG_STATE_HOME:-$HOME/.local/state}/vikix}"
: "${DRY_RUN:=0}"
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

timestamp() { date +%Y%m%d-%H%M%S; }

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
# '# <<< vikix NAME <<<', in FILE. Re-running replaces the block, so
# there are never duplicates and nothing outside the fence is touched.
ensure_block() {
  local file=$1 name=$2 text=$3
  local start="# >>> vikix $name >>>" end="# <<< vikix $name <<<"
  if [ "$DRY_RUN" = 1 ]; then
    printf '   would write block "%s" into %s\n' "$name" "$file"
    return 0
  fi
  touch "$file"
  local tmp
  tmp=$(mktemp)
  awk -v s="$start" -v e="$end" '
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$file" > "$tmp"
  printf '%s\n%s\n%s\n' "$start" "$text" "$end" >> "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# sudo_keepalive
# Asks for the password once, now, then refreshes sudo's timer every
# minute in the background for as long as this script runs. Without it,
# sudo forgets the password after five minutes and a long install stops
# half way to ask again, with nobody there to answer.
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
