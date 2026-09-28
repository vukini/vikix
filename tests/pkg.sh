#!/usr/bin/env bash
# tests/pkg.sh — single programs (`vikix pkg`):
#
#   - add NAME installs it, straight away when it's a package's name; other
#     words open the search, which leaves out what's installed
#   - drop NAME uninstalls it (asking, unless --yes); one that a wanted list
#     names goes on the skip list, and the feature's own way is named
#   - 10-packages leaves the skip list out; adding one again takes it off
#     (your comments stay, and a linked skip list stays a link)
#
# xbps-query, sudo and fzf are stand-ins: nothing is installed.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
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
# The repository: gimp, gnome-mines; installed: gimp? no; firefox, htop, gforth yes.
printf 'gimp-3.0.4_1\tGNU image manipulation program\ngnome-mines-48.1_1\tMinesweeper\nfirefox-143.0_1\tWeb browser\nhtop-3.4.1_1\tProcess viewer\ngforth-0.7.3_1\tGNU Forth\n' > "$t/repo"
printf 'firefox\nhtop\ngforth\n' > "$t/installed"
cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
case "\$1" in
  -Rs) while IFS="\$(printf '\t')" read -r pv d; do n=\${pv%-*}
         if grep -qx "\$n" "$t/installed"; then m='[*]'; else m='[-]'; fi
         printf '%s %s %s\n' "\$m" "\$pv" "\$d"; done < "$t/repo" ;;
  -m)  while read -r n; do grep "^\$n-" "$t/repo" | cut -f1; done < "$t/installed" ;;
  -R)  grep -q "^\$2-[^-]*_[0-9]*\$(printf '\t')" "$t/repo" ;;
  -X)  exit 0 ;;
  *)   grep -qx "\$1" "$t/installed" ;;
esac
EOF
cat > "$t/bin/fzf" <<'EOF'
#!/bin/sh
out=$(grep -E -- "${PICK:-^$^}") || exit 130
printf '%s\n' "$out"
EOF
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$t/calls" > "$t/bin/sudo"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_SUDO_KEPT=1
skip="$HOME/.config/vikix/packages-skip"
p() { bash "$here/bin/vikix-pkg" "$@" </dev/null 2>&1; }
printf 'emacs\n' > "$HOME/.config/vikix/features"     # the base, emacs; not forth

# --- add ----------------------------------------------------------------------
: > "$t/calls"
out=$(p add gimp)
check "add gimp should install it: $(cat "$t/calls")" grep -qx 'sudo xbps-install -Sy gimp' "$t/calls"
: > "$t/calls"
out=$(PICK='^(gnome-mines|htop) ' p add mine)
check "words should open the search and install what's picked: $(cat "$t/calls")" grep -qx 'sudo xbps-install -Sy gnome-mines' "$t/calls"
check "the search installed htop, which is installed" bash -c "! grep -q htop '$t/calls'"
: > "$t/calls"
out=$(p add)
check "Esc in the search should install nothing" test ! -s "$t/calls"
out=$(p preview firefox)
check "the preview should say which list names firefox: $out" has "In Vikix's lists: apps" "$out"

# --- drop -----------------------------------------------------------------------
: > "$t/calls"
out=$(p drop htop) && { echo "FAIL: drop without --yes went ahead"; fail=1; }
check "drop without --yes and no terminal should ask for it: $out" has -- '--yes' "$out"
check "drop without --yes uninstalled" test ! -s "$t/calls"
out=$(p drop htop --yes)
check "drop htop should uninstall it: $(cat "$t/calls")" grep -qx 'sudo xbps-remove -Ry htop' "$t/calls"
check "htop, in the base's cli list, should go on the skip list" grep -qx htop "$skip"
check "the skip list should say what it is" grep -q '^# Packages Vikix' "$skip"
out=$(p drop gforth --yes)
check "gforth, in no list wanted here (forth isn't chosen), went on the skip list" bash -c "! grep -qx gforth '$skip'"
printf 'emacs\nforth\n' > "$HOME/.config/vikix/features"
out=$(p drop gforth --yes)
check "gforth, with forth chosen, should name vikix remove forth: $out" has 'vikix remove forth' "$out"
out=$(p list)
check "vikix pkg list should show the skip list: $out" has '  htop' "$out"

# --- 10-packages leaves them out ------------------------------------------------------
out=$(DRY_RUN=1 VIKIX_LISTS="cli lang-forth" bash "$here/install/10-packages.sh" 2>&1)
check "10-packages should say what it leaves out: $(grep 'left out' <<<"$out")" has 'left out, on your skip list (vikix pkg list): htop gforth' "$out"
check "10-packages would install htop anyway" lacks 'xbps-install -y .*htop' "$out"

# --- adding again takes it off, in place ----------------------------------------------------
mv "$skip" "$t/skip-real"; ln -s "$t/skip-real" "$skip"
echo "# mine" >> "$t/skip-real"
out=$(p add htop)
check "add htop should take it off the skip list: $(grep -v '^#' "$t/skip-real" | tr '\n' ' ')" bash -c "! grep -qx htop '$t/skip-real'"
check "gforth should stay on the skip list" grep -qx gforth "$t/skip-real"
check "your comment on the skip list went" grep -qx '# mine' "$t/skip-real"
check "the linked skip list was replaced by a plain file" test -L "$skip"

[ "$fail" = 0 ] && echo "pkg: add by name or search, drop with a skip list that update leaves out, and add takes one off"
exit "$fail"
