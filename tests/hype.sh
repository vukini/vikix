#!/usr/bin/env bash
# tests/hype.sh — vikix hype: Hype, Markdown slides.
#
#   setup fetches Hype at the pinned commit and refuses another, builds it
#   with Void's qmake6, records the feature, asks for no sudo when the
#   packages are there; writes the hype command (OMARCHY_PATH pointing at
#   Vikix's themes, and yours if set), the launcher entry, and the portal's
#   settings (never over yours), moves aside a hype that isn't its own,
#   installs the agent's skill; vikix theme then writes the current theme
#   where Hype's window looks and every theme for the slides (and nothing
#   without Hype); a second setup builds nothing; a failed build says where
#   its log is; uninstall removes only what setup made; a dry run changes
#   nothing.
#
# git, qmake6 and make are stand-ins; the "hype" make builds logs its calls.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY OMARCHY_PATH
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$t/bin" "$VIKIX_STATE"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
hy() { bash "$here/bin/vikix-hype" "$@"; }
pinned=$(sed -n 's/^HYPE_COMMIT=\([0-9a-f]*\).*/\1/p' "$here/bin/vikix-hype")
echo "$pinned" > "$t/commit"
opt="$HOME/.local/opt/hype"
cmd="$HOME/.local/bin/hype"
portals="$HOME/.config/xdg-desktop-portal/portals.conf"
current="$HOME/.local/state/omarchy/current/theme/colors.toml"
themes="$HOME/.local/share/vikix/omarchy/themes"

# git: init makes .git, checkout the sources; HEAD is whatever $t/commit says.
cat > "$t/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >> "$calls"
case "\$*" in
  *" init"*) mkdir -p "$opt/.git" ;;
  *checkout*) mkdir -p "$opt/pkgbuild"; : > "$opt/hype.pro"; echo '<svg/>' > "$opt/pkgbuild/hype.svg" ;;
  *rev-parse*) cat "$t/commit" ;;
esac
EOF
printf '#!/bin/sh\necho "qmake6 (in $(pwd)) $*" >> %s\n' "$calls" > "$t/bin/qmake6"
# make writes ./hype, which logs what it's asked and what OMARCHY_PATH is;
# $t/break makes the build fail.
cat > "$t/bin/make" <<EOF
#!/bin/sh
echo "make (in \$(pwd)) \$*" >> "$calls"
[ -e "$t/break" ] && { echo "a compile error"; exit 1; }
cat > hype <<'IN'
#!/bin/sh
echo "hype \$* OMARCHY_PATH=\$OMARCHY_PATH" >> "$calls"
case "\$*" in "skill install") mkdir -p "\$HOME/.agents/skills/hype" "\$HOME/.claude/skills"; ln -sfn ../../.agents/skills/hype "\$HOME/.claude/skills/hype" ;; esac
IN
chmod +x hype
EOF
printf '#!/bin/sh\nexit 0\n' > "$t/bin/xbps-query"
printf '#!/bin/sh\necho "sudo $*" >> %s\n' "$calls" > "$t/bin/sudo"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_GIT="$t/bin/git" VIKIX_QMAKE="$t/bin/qmake6" VIKIX_MAKE="$t/bin/make"

# --- A dry run changes nothing ------------------------------------------------
DRY_RUN=1 hy setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run should build nothing" test ! -e "$opt"
check "a dry run should call no make" test -z "$(grep '^make' "$calls" || true)"
check "a dry run shouldn't write the command" test ! -e "$cmd"
check "a dry run shouldn't record the feature" test ! -e "$HOME/.config/vikix/features"
check "a dry run should say it would build Hype" grep -q "would build Hype" "$t/out"

# --- Not the pinned commit: refused ---------------------------------------------
echo 0000000000000000000000000000000000000000 > "$t/commit"
if hy setup > "$t/out" 2>&1; then echo "FAIL: another commit should be refused"; fail=1; fi
check "Hype should be fetched by its commit" grep -q "fetch -q --depth 1 origin $pinned" "$calls"
check "another commit shouldn't be built" test -z "$(grep '^make' "$calls" || true)"
check "no command after a refusal" test ! -e "$cmd"
echo "$pinned" > "$t/commit"; : > "$calls"

# --- A failed build -------------------------------------------------------------------
touch "$t/break"
if hy setup > "$t/out" 2>&1; then echo "FAIL: a failed build should fail setup"; fail=1; fi
check "a failed build should name its log" grep -q "hype-build.log" "$t/out"
check "no command after a failed build" test ! -e "$cmd"
rm "$t/break"; : > "$calls"

# --- setup -----------------------------------------------------------------------------
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\necho someone else\n' > "$cmd"
hy setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup should work"; fail=1; }
check "qmake6 should run in build/, on hype.pro" grep -q "qmake6 (in $opt/build) ../hype.pro" "$calls"
check "no sudo when the packages are there" test -z "$(grep '^sudo' "$calls" || true)"
check "the feature should be recorded" grep -qx hype "$HOME/.config/vikix/features"
bak=("$HOME"/.local/bin/hype.vikix-bak.*)
check "another hype should be moved aside" test -e "${bak[0]}"
check "the command should be Vikix's" grep -q 'Written by vikix hype setup' "$cmd"
check "the launcher entry should open with the command" grep -qx "Exec=$cmd open %f" "$HOME/.local/share/applications/vikix-hype.desktop"
check "the icon should be there" test -f "$HOME/.local/share/icons/hicolor/scalable/apps/hype.svg"
check "the portal should use gtk" grep -qx 'default=gtk' "$portals"
check "the agent's skill should be installed" test -L "$HOME/.claude/skills/hype"
check "the command should point OMARCHY_PATH at Vikix's themes" grep -q "skill install OMARCHY_PATH=$HOME/.local/share/vikix/omarchy" "$calls"
: > "$calls"
OMARCHY_PATH=/mine "$cmd" themes
check "an OMARCHY_PATH of yours should win" grep -qx 'hype themes OMARCHY_PATH=/mine' "$calls"

# --- The themes -----------------------------------------------------------------------
check "setup should write the current theme for Hype's window" grep -qx 'background = "#1e1e2e"' "$current"
check "and every built-in theme for the slides" test -f "$themes/gruvbox/colors.toml" -a -f "$themes/contrast/colors.toml"
bash "$here/bin/vikix" theme nord >/dev/null
check "vikix theme should move Hype's window to nord" grep -qx 'background = "#2e3440"' "$current"
check "the slide themes should stay their own" grep -qx 'background = "#282828"' "$themes/gruvbox/colors.toml"
check "with all 16 colours" test "$(grep -c '^color[0-9]* = "#' "$themes/nord/colors.toml")" = 16

# --- Again -----------------------------------------------------------------------------
echo mine > "$portals"; : > "$calls"
hy setup > "$t/out" 2>&1
check "a second setup should build nothing" test -z "$(grep '^make' "$calls" || true)"
check "your portal settings should be left alone" grep -qx mine "$portals"
out=$(hy status); check "status should say it's built: $out" grep -q "0\.[0-9.]*, built" <<<"$out"

# --- uninstall -------------------------------------------------------------------------
hy uninstall > "$t/out" 2>&1
check "uninstall should remove Hype" test ! -e "$opt"
check "and the command" test ! -e "$cmd"
check "and the launcher entry" test ! -e "$HOME/.local/share/applications/vikix-hype.desktop"
check "and the skill" test ! -e "$HOME/.claude/skills/hype" -a ! -e "$HOME/.agents/skills/hype"
check "and the themes" test ! -e "$themes" -a ! -e "$current"
check "but not your portal settings" grep -qx mine "$portals"
check "and forget the feature" test -z "$(grep -x hype "$HOME/.config/vikix/features" || true)"
bash "$here/bin/vikix" theme void >/dev/null
check "without Hype, vikix theme writes nothing for it" test ! -e "$current"

[ "$fail" = 0 ] && echo "hype: built from the pinned release, in your theme's colours, with file dialogs and the agent's skill; uninstall leaves only yours"
exit "$fail"
