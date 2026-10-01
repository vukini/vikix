#!/usr/bin/env bash
# install.sh — turn a fresh (or existing) Void Linux install into Vikix.
#
# It installs the base: a complete desktop (StumpWM, the bar, a terminal,
# Firefox, files, sound, Wi-Fi, Bluetooth, the laptop's hardware, the AI
# agent on Super+a). Then you reboot and log in. Everything else is a
# feature you add when you want it: a language, an editor, LibreOffice,
# Windows ... (vikix features lists them; vikix add NAME installs one).
#
#   ./install.sh                         the base
#   ./install.sh --with essentials,windows   the base, then these features
#                                        or bundles (the same as vikix add)
#   ./install.sh --dry-run               print what would be done, change nothing
#   ./install.sh --only 30-lisp          run a single stage
#   ./install.sh --list                  list the stages
#
# It asks for your password once, at the start, and then runs by itself;
# you can walk away. Everything is also written to a log in
# ~/.local/state/vikix/logs/.
#
# The stages up to the login stop at the first one that fails, because
# each needs the one before. The rest (sound, laptop hardware, a VM's
# guest tools, the features) carry on past a failure, and the summary at
# the end names what to re-run.
#
# Safe to re-run: every stage checks before it changes anything.
#
# Before 0.47 the install came in two parts; install-1.sh is now the same
# as this, and install-2.sh adds what part two had (vikix add everything).

set -euo pipefail

VIKIX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export VIKIX_DIR

# The stages, in order. The ones in GO_ON carry on past a failure.
STAGES=(00-preflight 05-mirror 10-packages 20-services 25-network 30-lisp 40-config
        50-audio 55-hardware 60-login 70-vm 90-finish)
GO_ON=" 50-audio 55-hardware 70-vm "

with="" only="" dry=0
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --with)    with=${2:?--with needs features, such as essentials,windows}; shift ;;
    --with=*)  with=${1#--with=} ;;
    --only)    only=${2:?--only needs a stage name}; shift ;;
    --phase)   # before 0.47: part 1 is the base; part 2 is everything
      case ${2:-} in
        1) ;;
        2) with=${with:+$with,}everything ;;
        *) echo "--phase is 1 or 2" >&2; exit 1 ;;
      esac
      shift ;;
    --list)    printf '%s\n' "${STAGES[@]}"; exit 0 ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done

# --- A log of everything --------------------------------------------------
# Set up before anything prints, so the log has the whole run.
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/vikix/logs"
mkdir -p "$log_dir"
log="$log_dir/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$log") 2>&1

DRY_RUN=$dry
export DRY_RUN
# shellcheck source=lib/common.sh
. "$VIKIX_DIR/lib/common.sh"
# shellcheck source=lib/features.sh
. "$VIKIX_DIR/lib/features.sh"
drop_keys    # the stages run others' code (npm, uv, Quicklisp); none needs your API keys

# The features asked for, checked before anything changes.
features=()
if [ -n "$with" ]; then
  IFS=', ' read -r -a features <<<"$with"
  expand_features "${features[@]}" >/dev/null || die "nothing was changed; ./bin/vikix features lists the names"
fi

say "Vikix $(cat "$VIKIX_DIR/VERSION"): the base${features[*]:+, then ${features[*]}}; log: $log"
[ "$DRY_RUN" = 1 ] && say "dry run: nothing will be changed"

# --- The password, once ---------------------------------------------------
sudo_keepalive

# --- Running the stages ---------------------------------------------------
ran=0 failed=()

# run_stage NAME — stops the install when a stage outside GO_ON fails.
run_stage() {
  local name=$1 stage="$VIKIX_DIR/install/$1.sh"
  [ -f "$stage" ] || die "no stage called '$name' (see ./install.sh --list)"
  say "stage $name"
  ran=$((ran + 1))
  # Each stage runs in its own bash, so one stage's variables never
  # leak into the next.
  if bash "$stage"; then return 0; fi
  case $GO_ON in
    *" $name "*) warn "stage $name failed; carrying on with the rest"; failed+=("$name") ;;
    *) die "stage $name failed. Fix it, then: ./install.sh --only $name, and ./install.sh again" ;;
  esac
}

if [ -n "$only" ]; then
  run_stage "$only"
else
  # Your choices file, before 10-packages reads it. A fresh machine starts
  # with the base alone; one that already has Vikix (it has a record of
  # migrations) keeps what it had, since before 0.46 that was everything.
  if [ ! -f "$FEATURES_FILE" ]; then
    if [ -d "$VIKIX_STATE/migrations" ]; then
      record_features
    elif [ "$DRY_RUN" = 1 ]; then
      printf '   would write %s: the base alone\n' "$FEATURES_FILE"
      VIKIX_DRY_CHOICES=""       # what the stages see in this dry run
      export VIKIX_DRY_CHOICES
    else
      mkdir -p "$(dirname "$FEATURES_FILE")"
      printf '%s\n' "# The Vikix features you chose: vikix add NAME, vikix remove NAME." \
        "# vikix update keeps their packages. See: vikix features" > "$FEATURES_FILE"
    fi
  fi
  # A fresh machine's wallpaper cycles through Vid's collection, so it
  # comes with the base (vikix remove wallpapers takes it away). Not one
  # of the features you asked for: 90-finish names only those.
  adding=("${features[@]}")
  if [ ! -d "$VIKIX_STATE/migrations" ] && [[ " ${features[*]} " != *" wallpapers "* ]]; then
    adding+=(wallpapers)
  fi
  for name in "${STAGES[@]}"; do
    [ "$name" = 90-finish ] && continue
    run_stage "$name"
  done
  if [ "${#adding[@]}" -gt 0 ]; then
    say "adding: ${adding[*]}"
    bash "$VIKIX_DIR/bin/vikix-features" add "${adding[@]}" || failed+=("vikix add ${adding[*]}")
  fi
  VIKIX_ADDED="${features[*]}"
  export VIKIX_ADDED            # 90-finish says what was added
  run_stage 90-finish
fi

# --- Summary --------------------------------------------------------------
if [ "${#failed[@]}" -gt 0 ]; then
  warn "finished, but these failed: ${failed[*]}"
  warn "the log says why: $log"
  warn "after fixing, re-run a stage with ./install.sh --only NAME, or the features with vikix add"
  result="finished with ${#failed[@]} failure(s): ${failed[*]}"
else
  say "done ($ran stage(s))"
  result="finished"
fi

# On a desktop (re-running it there), say so where it will be seen.
# Not in a dry run: nothing was installed, and the tests run dry runs.
if [ "$DRY_RUN" != 1 ] && [ -n "${DISPLAY:-}" ] && command -v notify-send >/dev/null; then
  notify-send -a Vikix "Vikix install: $result" "Log: $log" || true
fi
[ "${#failed[@]}" -eq 0 ]
