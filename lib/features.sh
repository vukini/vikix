# lib/features.sh — the features you chose, and the package lists they mean.
# Sourced after lib/common.sh (it uses VIKIX_DIR and read_list).
#
# features.list names each feature and its package lists; bundles.list
# groups features. Your choices are the lines of ~/.config/vikix/features.
# Any list in packages/ that no feature names is the base: always wanted.
#
# Before 0.46 there was no choices file: every list was installed, plus the
# optional ones named in ~/.config/vikix/optional. A machine without the
# file is treated the same way (a migration writes the file for it).

FEATURES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/features"
OLD_OPTIONAL_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/optional"
# Packages Vikix's lists name that you dropped (vikix pkg drop): 10-packages
# leaves them out.
SKIP_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/packages-skip"

# features_rows — features.list as NAME|LISTS|NEEDS|ADD|REMOVE|ABOUT, trimmed.
# Read once a shell, then kept: the functions below ask for every name,
# and parsing the file each time took seconds of every update.
features_rows() {
  if [ -z "${_VIKIX_FEATURE_ROWS:-}" ]; then
    _VIKIX_FEATURE_ROWS=$(read_list "$VIKIX_DIR/features.list" |
      awk -F'|' '{ for (i = 1; i <= NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
                   print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 }')
  fi
  printf '%s\n' "$_VIKIX_FEATURE_ROWS"
}

# bundles_rows — bundles.list as NAME|FEATURES|ABOUT, trimmed.
bundles_rows() {
  if [ -z "${_VIKIX_BUNDLE_ROWS:-}" ]; then
    _VIKIX_BUNDLE_ROWS=$(read_list "$VIKIX_DIR/bundles.list" |
      awk -F'|' '{ for (i = 1; i <= NF; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
                   print $1 "|" $2 "|" $3 }')
  fi
  printf '%s\n' "$_VIKIX_BUNDLE_ROWS"
}

# These read features.list to the end. Stopping at the first match (grep
# -q, awk's exit) leaves the writer writing to a closed pipe: SIGPIPE, which
# pipefail turns into "no such feature", now and then, as the list grows.

# feature_field NAME N — field N (1 name, 2 lists, 3 needs, 4 add, 5 remove, 6 about).
feature_field() {
  features_rows | awk -F'|' -v n="$1" -v f="$2" '$1 == n && !done { print $f; done = 1 }'
}

is_feature() { features_rows | cut -d'|' -f1 | grep -x -- "$1" >/dev/null; }
is_bundle()  { bundles_rows  | cut -d'|' -f1 | grep -x -- "$1" >/dev/null; }

# bundle_features BUNDLE — the names a bundle holds, bundles in it opened,
# without the features they need.
bundle_features() {
  local n
  for n in $(bundles_rows | awk -F'|' -v n="$1" '$1 == n { print $2 }'); do
    if is_bundle "$n"; then bundle_features "$n"; else printf '%s\n' "$n"; fi
  done
}

# expand_features NAME... — the features these names mean, one a line, in
# features.list's order: bundles opened (bundles may hold bundles), and the
# features each one needs added. An unknown name is an error on stderr.
expand_features() {
  local todo=("$@") seen=" " name bad=0
  while [ "${#todo[@]}" -gt 0 ]; do
    name=${todo[0]}; todo=("${todo[@]:1}")
    case $seen in *" $name "*) continue ;; esac
    seen="$seen$name "
    if is_bundle "$name"; then
      # shellcheck disable=SC2207  # word-splitting a list of names is the point
      todo+=($(bundles_rows | awk -F'|' -v n="$name" '$1 == n { print $2 }'))
    elif is_feature "$name"; then
      # shellcheck disable=SC2207
      todo+=($(feature_field "$name" 3))
    else
      warn "no feature or bundle called '$name' (see: vikix features)"
      bad=1
    fi
  done
  features_rows | cut -d'|' -f1 | while IFS= read -r name; do
    case $seen in *" $name "*) printf '%s\n' "$name" ;; esac
  done
  return "$bad"
}

# chosen_names — the names in your choices file, as written (bundles too).
# No file yet: everything, as before 0.46, and the optional features named
# in the old ~/.config/vikix/optional.
#
# A dry run writes nothing, so what it would have written is kept in
# VIKIX_DRY_CHOICES (exported, so the stages it starts see it too).
chosen_names() {
  if [ "${DRY_RUN:-0}" = 1 ] && [ -n "${VIKIX_DRY_CHOICES+set}" ]; then
    printf '%s\n' $VIKIX_DRY_CHOICES
  elif [ -f "$FEATURES_FILE" ]; then
    read_list "$FEATURES_FILE"
  else
    echo everything
    [ -f "$OLD_OPTIONAL_FILE" ] && read_list "$OLD_OPTIONAL_FILE"
  fi
  return 0
}

# chosen_features — the features you chose, bundles opened, needs added.
# A name features.list no longer has is skipped with a warning.
chosen_features() {
  local names
  mapfile -t names < <(chosen_names)
  [ "${#names[@]}" -gt 0 ] || return 0
  expand_features "${names[@]}" || true
}

is_chosen() { chosen_features 2>/dev/null | grep -x -- "$1" >/dev/null; }

# installed_features — features you have but never chose: installed by
# hand (xi dropbox) or before Vikix had features for them. One counts when
# every package on its lists is installed; one with a setup command
# (vikix ai setup, say) or no lists can't be told this way, so never does.
installed_features() {
  local chosen name lists setup l p all
  chosen=" $(chosen_features 2>/dev/null | tr '\n' ' ') "
  while IFS='|' read -r name lists _ setup _ _; do
    case $chosen in *" $name "*) continue ;; esac
    [ -n "$lists" ] && [ -z "$setup" ] || continue
    all=1
    for l in $lists; do
      [ -f "$VIKIX_DIR/packages/$l.list" ] || { all=0; break; }
      for p in $(read_list "$VIKIX_DIR/packages/$l.list"); do
        pkg_installed "$p" || { all=0; break 2; }
      done
    done
    [ "$all" = 1 ] && printf '%s\n' "$name"
  done < <(features_rows)
  return 0
}

# lists_of FEATURE... — the package lists of these features, one a line.
lists_of() {
  local f
  for f in "$@"; do
    # shellcheck disable=SC2046  # the lists field is space-separated names
    printf '%s\n' $(feature_field "$f" 2)
  done | awk '!seen[$0]++'
}

# base_lists — every packages/*.list no feature names.
base_lists() {
  local featured list name
  featured=" $(features_rows | cut -d'|' -f2 | tr '\n' ' ') "
  for list in "$VIKIX_DIR"/packages/*.list; do
    name=$(basename "$list" .list)
    case $featured in *" $name "*) ;; *) printf '%s\n' "$name" ;; esac
  done
}

# wanted_lists — the base and your features' lists: what 10-packages installs
# and every update keeps. Names relative to packages/ (optional/windows).
wanted_lists() {
  local chosen
  mapfile -t chosen < <(chosen_features)
  { base_lists; [ "${#chosen[@]}" -eq 0 ] || lists_of "${chosen[@]}"; } | awk '!seen[$0]++'
}

# record_features NAME... — add these names to your choices file, once each.
# The first time, the file starts with what was chosen without it (see
# chosen_names), so nothing that was kept stops being kept.
record_features() {
  local name seed
  if [ ! -f "$FEATURES_FILE" ]; then
    seed=$(chosen_names)       # before the file exists: that decides what it says
    run mkdir -p "$(dirname "$FEATURES_FILE")"
    if [ "$DRY_RUN" = 1 ]; then
      printf '   would write %s: %s\n' "$FEATURES_FILE" "$(echo $seed)"
    else
      {
        echo "# The Vikix features you chose: vikix add NAME, vikix remove NAME."
        echo "# vikix update keeps their packages. See: vikix features"
        printf '%s\n' "$seed"
      } > "$FEATURES_FILE"
    fi
  fi
  if [ "$DRY_RUN" = 1 ]; then
    VIKIX_DRY_CHOICES="$(chosen_names | tr '\n' ' ')$*"
    export VIKIX_DRY_CHOICES
  fi
  for name in "$@"; do
    [ "$DRY_RUN" = 1 ] && { printf '   would add %s to %s\n' "$name" "$FEATURES_FILE"; continue; }
    read_list "$FEATURES_FILE" | grep -x -- "$name" >/dev/null || printf '%s\n' "$name" >> "$FEATURES_FILE"
  done
}

# forget_features NAME... — take these names out of your choices file; your
# comments and other lines stay. Written back in place (not sed -i), so a
# choices file that is a link into your dotfiles stays a link.
forget_features() {
  local name kept
  [ -f "$FEATURES_FILE" ] || return 0
  for name in "$@"; do
    if [ "$DRY_RUN" = 1 ]; then
      printf '   would take %s out of %s\n' "$name" "$FEATURES_FILE"
      continue
    fi
    kept=$(awk -v n="$name" '{ line = $0; sub(/#.*/, "", line); gsub(/[ \t]/, "", line) } line != n' "$FEATURES_FILE")
    printf '%s\n' "$kept" > "$FEATURES_FILE"
  done
}

# open_bundles — in your choices file, put each bundle's features in place
# of the bundle's name, so one of them can be removed on its own.
open_bundles() {
  local names name out=() kept
  [ -f "$FEATURES_FILE" ] || return 0
  mapfile -t names < <(read_list "$FEATURES_FILE")
  for name in "${names[@]}"; do
    is_bundle "$name" || continue
    mapfile -t out < <(bundle_features "$name")
    if [ "$DRY_RUN" = 1 ]; then
      printf '   would write %s in place of %s in %s\n' "${out[*]}" "$name" "$FEATURES_FILE"
      continue
    fi
    kept=$(awk -v n="$name" '{ line = $0; sub(/#.*/, "", line); gsub(/[ \t]/, "", line) } line != n' "$FEATURES_FILE")
    printf '%s\n' "$kept" > "$FEATURES_FILE"
    for name in "${out[@]}"; do
      read_list "$FEATURES_FILE" | grep -x -- "$name" >/dev/null || printf '%s\n' "$name" >> "$FEATURES_FILE"
    done
  done
}

# Parsed here, in the shell that loads this file: the functions run in
# pipelines and $( ), which are subshells, and only inherit what's
# already set.
features_rows >/dev/null
bundles_rows >/dev/null
