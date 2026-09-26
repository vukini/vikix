#!/usr/bin/env bash
# install.sh — turn a fresh (or existing) Void Linux install into Vikix.
#
# The install comes in two parts, so the slow part never stands between
# you and a working desktop:
#
#   ./install-1.sh   the desktop: base system, network, StumpWM, config,
#                    login. Then reboot and log in; StumpWM starts.
#   ./install-2.sh   everything else, run from a terminal on the new
#                    desktop: editors, languages, apps, audio, laptop
#                    hardware. The long part.
#
# Each part asks for your password once, at the start, and then runs by
# itself; you can walk away. Everything is also written to a log in
# ~/.local/state/vikix/logs/.
#
#   ./install.sh                  both parts, one after the other
#   ./install.sh --phase 1        the same as ./install-1.sh (or 2)
#   ./install.sh --dry-run        print what would be done, change nothing
#   ./install.sh --only 30-lisp   run a single stage
#   ./install.sh --list           list the stages and their part
#
# Part one stops at the first stage that fails, because each of its
# stages needs the one before. Part two's stages don't depend on each
# other, so a failure is noted and the rest still run; the summary at
# the end names what to re-run.
#
# Safe to re-run: every stage checks before it changes anything.

set -euo pipefail

VIKIX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export VIKIX_DIR

# The stages of each part. 10-packages and 20-services are in both: part
# one installs the core package lists, part two the rest, and services
# whose packages arrive in part two are switched on then.
PHASE1=(00-preflight 10-packages 20-services 25-network 30-lisp 40-config 60-login 70-vm 90-finish)
PHASE2=(10-packages 20-services 45-editors 50-audio 55-hardware 65-languages 90-finish)
# The package lists part one installs: enough for a working desktop.
CORE_LISTS="base desktop network lisp cli"

phase=all only="" dry=0
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --phase)   phase=${2:?--phase needs 1 or 2}; shift ;;
    --only)    only=${2:?--only needs a stage name}; shift ;;
    --list)
      echo "part 1: ${PHASE1[*]}"
      echo "part 2: ${PHASE2[*]}"
      exit 0 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done
case $phase in 1|2|all) ;; *) echo "--phase is 1 or 2" >&2; exit 1 ;; esac

# --- A log of everything --------------------------------------------------
# Set up before anything prints, so the log has the whole run.
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/vikix/logs"
mkdir -p "$log_dir"
log="$log_dir/install-$phase-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$log") 2>&1

DRY_RUN=$dry
export DRY_RUN
# shellcheck source=lib/common.sh
. "$VIKIX_DIR/lib/common.sh"

say "Vikix $(cat "$VIKIX_DIR/VERSION"), part $phase; log: $log"
[ "$DRY_RUN" = 1 ] && say "dry run: nothing will be changed"

# --- The password, once ---------------------------------------------------
sudo_keepalive

# --- Running the stages ---------------------------------------------------
ran=0 failed=()

# run_stage NAME STOP_ON_FAILURE
run_stage() {
  local name=$1 stop=$2 stage="$VIKIX_DIR/install/$1.sh"
  [ -f "$stage" ] || die "no stage called '$name' (see ./install.sh --list)"
  say "stage $name"
  ran=$((ran + 1))
  # Each stage runs in its own bash, so one stage's variables never
  # leak into the next.
  if bash "$stage"; then return 0; fi
  if [ "$stop" = stop ]; then
    die "stage $name failed. Fix it, then: ./install.sh --only $name, and ./install-$VIKIX_PHASE.sh again"
  fi
  warn "stage $name failed; carrying on with the rest"
  failed+=("$name")
}

run_phase() {
  VIKIX_PHASE=$1
  export VIKIX_PHASE
  local stages stop
  if [ "$1" = 1 ]; then
    stages=("${PHASE1[@]}") stop=stop
    VIKIX_LISTS=$CORE_LISTS
  else
    stages=("${PHASE2[@]}") stop=go-on
    VIKIX_LISTS=""                       # every list
  fi
  export VIKIX_LISTS
  local name
  for name in "${stages[@]}"; do run_stage "$name" "$stop"; done
}

if [ -n "$only" ]; then
  VIKIX_PHASE=${phase/all/2} VIKIX_LISTS=""
  export VIKIX_PHASE VIKIX_LISTS
  run_stage "$only" stop
elif [ "$phase" = all ]; then
  run_phase 1
  run_phase 2
else
  run_phase "$phase"
fi

# --- Summary --------------------------------------------------------------
if [ "${#failed[@]}" -gt 0 ]; then
  warn "finished, but ${#failed[@]} stage(s) failed: ${failed[*]}"
  warn "the log says why: $log"
  warn "after fixing, re-run just those: ./install.sh --only NAME"
  result="finished with ${#failed[@]} failed stage(s): ${failed[*]}"
else
  say "done ($ran stage(s))"
  result="finished"
fi

# On the desktop, say so where it will be seen after walking away.
if [ -n "${DISPLAY:-}" ] && command -v notify-send >/dev/null; then
  notify-send -a Vikix "Vikix install, part $phase: $result" "Log: $log" || true
fi
[ "${#failed[@]}" -eq 0 ]
