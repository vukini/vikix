#!/usr/bin/env bash
# 10-packages — install everything named in packages/*.list.
#
# VIKIX_LISTS narrows it to some lists (install.sh's part one sets it to
# the core ones: base desktop network lisp cli); empty means every list.
#
# Only packages that are not installed yet are passed to xbps-install,
# so the output shows exactly what is new. Add a package by adding a line
# to the right list; `vikix update` runs this stage again.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

wanted_list() {   # is this list (by name, without .list) wanted this time?
  [ -z "${VIKIX_LISTS:-}" ] && return 0
  case " $VIKIX_LISTS " in *" $1 "*) return 0 ;; esac
  return 1
}

# Extra repositories first, on their own, then a sync: only after that can
# the other lists name packages from them (intel-ucode is in nonfree).
repos=()
wanted_list repos && while IFS= read -r pkg; do pkg_installed "$pkg" || repos+=("$pkg"); done \
  < <(read_list "$VIKIX_DIR/packages/repos.list")
if [ "${#repos[@]}" -gt 0 ]; then
  say "enabling repositories: ${repos[*]}"
  run sudo xbps-install -Syu xbps
  run sudo xbps-install -y "${repos[@]}"
  # The new repositories come pointed at Void's default mirror; move them
  # to the one 05-mirror chose, so nonfree downloads are fast too.
  mirror=$(current_mirror)
  if [ -n "$mirror" ]; then use_mirror "$mirror"; fi
fi

wanted=()
for list in "$VIKIX_DIR"/packages/*.list; do
  name=$(basename "$list" .list)
  [ "$name" = repos ] && continue
  wanted_list "$name" || continue
  while IFS= read -r pkg; do wanted+=("$pkg"); done < <(read_list "$list")
done

# Sync the repository index, once from here on (twice in all when
# repositories were just added: they bring new indexes). The sync lets
# unknown names be spotted before the install, where one bad line would
# fail the whole batch.
run sudo xbps-install -Sy >/dev/null </dev/null ||
  warn "could not sync the package index; installing from the last one"

missing=()
for pkg in "${wanted[@]}"; do
  pkg_installed "$pkg" && continue
  if [ "$DRY_RUN" != 1 ] && command -v xbps-query >/dev/null && ! xbps-query -R "$pkg" >/dev/null 2>&1; then
    warn "no package called '$pkg' in the repositories; skipping it (check the spelling in packages/)"
    continue
  fi
  missing+=("$pkg")
done

if [ "${#missing[@]}" -eq 0 ]; then
  say "all ${#wanted[@]} packages already installed"
  exit 0
fi

# A fresh Void install refuses every other package until xbps itself is
# current ("The 'xbps' package must be updated"). A no-op when it is.
run sudo xbps-install -yu xbps
say "installing ${#missing[@]} of ${#wanted[@]} packages: ${missing[*]}"
run sudo xbps-install -y "${missing[@]}"
