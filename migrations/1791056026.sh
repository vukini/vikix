#!/usr/bin/env bash
# Why: from 0.71.116 keys keep one rule (keys.lisp): what opens something
# beyond the six main apps is on Super+Alt, and a web app is that. The
# first mail web app had Super+Shift+m (s-M), and any web app could be
# given a key on plain Super or Super+Ctrl; those keys are no longer read.
# This moves each to Super+Alt with the same letter (s-M to s-M-m), and
# leaves a web app without a key, saying so, where that one is taken.
# rule-for-keys-webapps
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

list="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/webapps"
# Vikix's own keys: each command's :key in registry.lisp (since the registry;
# keys.lisp's list before that).
keys="$VIKIX_DIR/config/stumpwm/vikix/registry.lisp"
vikix_has() {
  grep -v '^ *;' "$keys" | grep -qF ":key \"$1\"" ||
    grep -qF "(\"$1\"" "$VIKIX_DIR/config/stumpwm/vikix/keys.lisp"
}
[ -f "$list" ] || { say "no web apps"; exit 0; }

new=$(mktemp)
trap 'rm -f "$new"' EXIT
changed=0
while IFS= read -r line || [ -n "$line" ]; do
  case $line in ''|'#'*|' '*'#'*) printf '%s\n' "$line" >> "$new"; continue ;; esac
  read -r name url key _ <<<"$line"
  if [ -z "${key:-}" ] || [[ $key =~ ^s-M-([A-Za-z0-9]|F[0-9]{1,2})$ ]]; then
    printf '%s\n' "$line" >> "$new"; continue
  fi
  case $key in
    s-M)   to=s-M-m ;;
    s-C-?) to=s-M-${key#s-C-} ;;
    s-?)   k=${key#s-}; to=s-M-${k,,} ;;
    s-F[0-9]|s-F[0-9][0-9]) to=s-M-${key#s-} ;;
    *)     to='' ;;
  esac
  # Taken by Vikix, or by a web app (above in the new list, or further down in the old).
  if [ -n "$to" ] && { vikix_has "$to" || awk -v k="$to" '$3 == k { f = 1 } END { exit !f }' "$new" "$list"; }; then
    to=''
  fi
  changed=1
  if [ -n "$to" ]; then
    printf '%s %s %s\n' "$name" "$url" "$to" >> "$new"
    say "$name: its key $key is now $to (Super+Alt and the same key)"
  else
    printf '%s %s\n' "$name" "$url" >> "$new"
    warn "$name: its key $key isn't read any more, and the same key on Super+Alt is taken. Give it one: vikix webapp key $name s-M-X"
  fi
done < "$list"

if [ "$changed" = 1 ]; then
  run cp "$new" "$list"
else
  say "web apps' keys are on Super+Alt already"
fi
