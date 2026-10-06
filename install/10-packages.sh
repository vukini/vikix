#!/usr/bin/env bash
# 10-packages — install the package lists in packages/ that are wanted here.
#
# Wanted: the base (every list no feature names) and the lists of the
# features you chose (features.list; your choices in ~/.config/vikix/features,
# which vikix add and vikix remove keep; lib/features.sh reads them).
# packages/optional/*.list are only ever there through a feature (windows,
# webapps).
#
# VIKIX_LISTS names the lists to install instead (vikix add sets it to the
# new feature's lists). A name is a list in packages/ or packages/optional/.
#
# Packages on your skip list (~/.config/vikix/packages-skip, from vikix pkg
# drop) are left out.
#
# Only packages that are not installed yet are passed to xbps-install,
# so the output shows exactly what is new. Add a package by adding a line
# to the right list; `vikix update` runs this stage again.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"
# shellcheck source=../lib/features.sh
. "$(dirname "$0")/../lib/features.sh"

# The lists this run installs, as paths.
lists=()
if [ -n "${VIKIX_LISTS:-}" ]; then
  for name in $VIKIX_LISTS; do
    if [ -f "$VIKIX_DIR/packages/$name.list" ]; then lists+=("$VIKIX_DIR/packages/$name.list")
    elif [ -f "$VIKIX_DIR/packages/optional/$name.list" ]; then lists+=("$VIKIX_DIR/packages/optional/$name.list")
    else warn "no package list called '$name'"; fi
  done
else
  while IFS= read -r name; do
    [ -f "$VIKIX_DIR/packages/$name.list" ] && lists+=("$VIKIX_DIR/packages/$name.list")
  done < <(wanted_lists)
fi
wanted_list() {   # is this list (by name, without .list) in this run?
  case " ${lists[*]##*/} " in *" $1.list "*) return 0 ;; esac
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

# Your skip list (vikix pkg drop): packages you uninstalled, left out.
skipped=" "
[ -f "$SKIP_FILE" ] && skipped=" $(read_list "$SKIP_FILE" | tr '\n' ' ')"
wanted=() left_out=()
for list in "${lists[@]}"; do
  [ "$(basename "$list" .list)" = repos ] && continue
  while IFS= read -r pkg; do
    case $skipped in *" $pkg "*) left_out+=("$pkg"); continue ;; esac
    wanted+=("$pkg")
  done < <(read_list "$list")
done
[ "${#left_out[@]}" -eq 0 ] || say "left out, on your skip list (vikix pkg list): ${left_out[*]}"

# What isn't installed yet, from one listing of what is (pkg_installed).
missing=()
for pkg in "${wanted[@]}"; do
  pkg_installed "$pkg" || missing+=("$pkg")
done
if [ "${#missing[@]}" -eq 0 ]; then
  say "all ${#wanted[@]} packages already installed"
  exit 0
fi

# Sync the repository index, only now that something is to be installed
# (it's a download, every time: an update with nothing new skips it), and
# twice in all when repositories were just added: they bring new indexes.
# The sync lets unknown names be spotted before the install, where one bad
# line would fail the whole batch.
run sudo xbps-install -Sy >/dev/null </dev/null ||
  warn "could not sync the package index; installing from the last one"
known=()
for pkg in "${missing[@]}"; do
  if [ "$DRY_RUN" != 1 ] && command -v xbps-query >/dev/null && ! xbps-query -R "$pkg" >/dev/null 2>&1; then
    warn "no package called '$pkg' in the repositories; skipping it (check the spelling in packages/)"
    continue
  fi
  known+=("$pkg")
done
missing=("${known[@]}")
if [ "${#missing[@]}" -eq 0 ]; then
  say "nothing to install: the new names aren't in the repositories"
  exit 0
fi

# A package that took another's place on a list (i3lock-color for i3lock,
# the same files): xbps refuses the new one while the old is installed, so
# the old one goes first.
for pkg in "${missing[@]}"; do
  case $pkg in i3lock-color) old=i3lock ;; *) continue ;; esac
  pkg_installed "$old" || continue
  say "removing $old: $pkg takes its place"
  run sudo xbps-remove -y "$old"
done

# A fresh Void install refuses every other package until xbps itself is
# current ("The 'xbps' package must be updated"). A no-op when it is.
run sudo xbps-install -yu xbps
say "installing ${#missing[@]} of ${#wanted[@]} packages: ${missing[*]}"
run sudo xbps-install -y "${missing[@]}"
