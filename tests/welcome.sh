#!/usr/bin/env bash
# tests/welcome.sh — the welcome (`vikix welcome`) and its software picker:
#
#   - the picker lists bundles and features, marks the ones you have, and
#     adds only what you pick that you don't have yet
#   - its preview says what a feature is and which packages it brings
#   - the keyboard step offers the layouts X knows, and sets yours in
#     ~/.config/vikix/keyboard without touching the rest (a link stays one)
#   - each step is ticked off once done; opening it marks it as shown
#   - StumpWM opens it at the first login only; Super+m has it
#   - the migration marks it as shown on a desktop already in use
#
# fzf is a stand-in that "picks" the lines matching $PICK (none: Esc).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
lacks() { ! grep -q -- "$1" <<<"$2"; }

export HOME="$t/home" VIKIX_STATE="$t/state" VIKIX_DIR="$here"
mkdir -p "$HOME/.config/vikix" "$t/bin"
cat > "$t/bin/fzf" <<'EOF'
#!/bin/sh
# Picks the lines matching $PICK; none picked is Esc (130), as fzf does.
out=$(tee "${FZF_IN:-/dev/null}" | grep -E -- "${PICK:-^$^}") || exit 130
printf '%s\n' "$out"
EOF
printf '#!/bin/sh\necho "setxkbmap $*" >> %q\n' "$t/calls" > "$t/bin/setxkbmap"
printf '#!/bin/sh\nexit 0\n' > "$t/bin/notify-send"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
state="$t/state/welcome"
w() { bash "$here/bin/vikix-welcome" "$@" </dev/null 2>&1; }

# --- the picker ------------------------------------------------------------------------
printf 'python\n' > "$HOME/.config/vikix/features"
out=$(PICK='^(add|have) +(rust|python|forth) ' DRY_RUN=1 w add)
check "the picker should add rust and forth: $(grep 'adding:' <<<"$out" | head -1)" has ':: adding: forth rust' "$out"
check "the picker added python again, which is here" lacks 'adding: .*python' "$out"
check "vikix add should run for them" has 'stage 10-packages' "$out"
out=$(PICK='^have +python ' DRY_RUN=1 w add)
check "picking only what's here should add nothing: $out" lacks 'adding' "$out"
out=$(DRY_RUN=1 w add) || true
check "Esc in the picker should add nothing" lacks 'adding' "$out"
check "opening the picker marks the welcome as shown" test -e "$state"
out=$(w preview python)
check "the preview should say what python is and its packages: $out" has 'Packages (lang-python)' "$out"
check "the preview should list uv" has '  uv' "$out"
out=$(w preview essentials)
check "a bundle's preview should list its features: $out" has '  emacs' "$out"
out=$(w preview windows)
check "windows' preview should name its setup: $out" has 'Set up by: vikix windows setup' "$out"

# --- the keyboard ------------------------------------------------------------------------
cat > "$t/evdev.lst" <<'EOF'
! model
  pc105           Generic 105-key PC
! layout
  us              English (US)
  de              German
  fr              French
! variant
  intl            us: English (US, intl., with dead keys)
EOF
export VIKIX_XKB_RULES="$t/evdev.lst"
printf '# mine\nVIKIX_KB_LAYOUT=""\nVIKIX_KB_OPTIONS="ctrl:nocaps"\n' > "$t/keyboard"
ln -s "$t/keyboard" "$HOME/.config/vikix/keyboard"
: > "$t/calls"
out=$(PICK='^de ' bash -c "set -- seen; . '$here/bin/vikix-welcome'; layouts" 2>&1)
check "the layouts should be X's, and only layouts: $out" test "$(awk '{print $1}' <<<"$out" | tr '\n' ' ')" = "us de fr "
out=$(PICK='^de ' bash -c "set -- seen; . '$here/bin/vikix-welcome'; cmd_keyboard" </dev/null 2>&1)
check "the layout should be set in the keyboard file: $(cat "$t/keyboard")" grep -qx 'VIKIX_KB_LAYOUT="de"' "$t/keyboard"
check "the rest of the keyboard file changed" grep -qx 'VIKIX_KB_OPTIONS="ctrl:nocaps"' "$t/keyboard"
check "your comment in the keyboard file went" grep -qx '# mine' "$t/keyboard"
check "the linked keyboard file was replaced" test -L "$HOME/.config/vikix/keyboard"
check "the layout should be applied at once: $(cat "$t/calls")" grep -q 'setxkbmap -layout de' "$t/calls"
check "the keyboard step should be ticked" grep -qx keyboard "$state"

# --- the steps ------------------------------------------------------------------------------
out=$(PICK='keys that matter' bash -c "set -- seen; . '$here/bin/vikix-welcome'; cmd_keys" </dev/null 2>&1)
check "the keys card should name Super+m: $out" has 'Super+m' "$out"
check "the keys step should be ticked" grep -qx keys "$state"
# No themes of your own (no ~/.config/vikix/themes): the list still opens.
out=$(FZF_IN="$t/themes" bash -c "set -- seen; . '$here/bin/vikix-welcome'; cmd_theme; echo back" </dev/null 2>&1 || true)
check "the theme step should come back after Esc: $out" has '^back$' "$out"
check "the theme step should offer Vikix's themes: $(tr '\n' ' ' < "$t/themes" 2>/dev/null)" \
  bash -c "grep -qx void '$t/themes' && grep -qx paper '$t/themes'"
out=$(PICK='Close' w)
check "Close should end the welcome: $out" test -z "$(grep -v '^$' <<<"$out" || true)"
rm "$state"
w seen >/dev/null
check "vikix welcome seen should mark it shown" test -e "$state"

# --- StumpWM and the migration -------------------------------------------------------------------
lisp="$here/config/stumpwm/vikix/commands.lisp"
check "StumpWM should open the welcome only when it hasn't been shown" \
  grep -q 'probe-file (merge-pathnames ".local/state/vikix/welcome"' "$lisp"
check "Super+m should have Welcome and Add software" \
  bash -c "grep -q '(\"Welcome: first steps\" vikix-welcome)' '$lisp' && grep -q 'vikix-add-software)' '$lisp'"
mig=$(grep -l 'opens the welcome (vikix welcome)' "$here"/migrations/*.sh)
rm -f "$state"
bash "$mig" >/dev/null 2>&1
check "the migration should mark the welcome shown" test -e "$state"
echo keys > "$state"
bash "$mig" >/dev/null 2>&1
check "a second run of the migration emptied what was ticked" grep -qx keys "$state"

[ "$fail" = 0 ] && echo "welcome: the picker adds only what's new, previews, the keyboard layout, ticks, first login only, the migration"
exit "$fail"
