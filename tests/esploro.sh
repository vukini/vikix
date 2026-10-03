#!/usr/bin/env bash
# tests/esploro.sh — vikix esploro: Vid's file explorer (its window in Emacs,
# its core in Common Lisp).
#
#   setup fetches Esploro at the pinned commit and refuses another, builds
#   its command with build.lisp in its folder (SBCL alone), links esploro into
#   ~/.local/bin and puts it in the launcher; records the feature; asks for
#   no sudo when the packages are there; a second setup builds nothing,
#   --rebuild builds again; a failed build says where its log is and links
#   nothing; status says what's built; uninstall removes only what setup
#   made and forgets the feature; a dry run changes nothing. The key and
#   the Apps menu name the command and the program.
#
# git and sbcl are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix"
mkdir -p "$t/bin" "$VIKIX_STATE"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
es() { bash "$here/bin/vikix-esploro" "$@"; }
pinned=$(sed -n 's/^ESPLORO_COMMIT=\([0-9a-f]*\).*/\1/p' "$here/bin/vikix-esploro")
echo "$pinned" > "$t/commit"
opt="$HOME/.local/opt/esploro"
apps="$HOME/.local/share/applications"

# git: init makes .git; HEAD is whatever $t/commit says.
cat > "$t/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >> "$calls"
case "\$*" in
  *" init"*) mkdir -p "$opt/.git" ;;
  *rev-parse*) cat "$t/commit" ;;
esac
EOF
# sbcl: build.lisp writes ./esploro.new; $t/break makes the build fail.
cat > "$t/bin/sbcl" <<EOF
#!/bin/sh
echo "sbcl (in \$(pwd)) \$*" >> "$calls"
case "\$*" in
  *build.lisp*) [ -e "$t/break" ] && { echo "a compile error"; exit 1; }
    printf '#!/bin/sh\n' > esploro.new; chmod +x esploro.new
    mkdir -p doc; echo "the manual" > doc/esploro.info ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$t/bin/xbps-query"
printf '#!/bin/sh\necho "install-info $*" >> %q\n' "$calls" > "$t/bin/install-info"
printf '#!/bin/sh\necho "sudo $*" >> %q\n' "$calls" > "$t/bin/sudo"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_GIT="$t/bin/git" VIKIX_SBCL="$t/bin/sbcl"

# --- A dry run changes nothing ------------------------------------------------
DRY_RUN=1 es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a dry run should work"; fail=1; }
check "a dry run should build nothing" test ! -e "$opt"
check "a dry run should call no sbcl: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
check "a dry run shouldn't record the feature" test ! -e "$HOME/.config/vikix/features"
check "a dry run should say it would build Esploro" grep -q "would build Esploro" "$t/out"
check "a dry run should say it would reload Esploro in a running Emacs" grep -q "would reload Esploro" "$t/out"
check "the reload should unbind Esploro's keymaps first, so new keys take" \
  grep -q "makunbound" "$here/bin/vikix-esploro"

# --- Not the pinned commit: refused ---------------------------------------------
echo 0000000000000000000000000000000000000000 > "$t/commit"
if es setup > "$t/out" 2>&1; then echo "FAIL: another commit should be refused"; fail=1; fi
check "Esploro should be fetched by its commit: $(grep fetch "$calls")" grep -q "fetch -q --depth 1 origin $pinned" "$calls"
check "another commit shouldn't be built" test -z "$(grep sbcl "$calls" || true)"
check "nothing should be linked after a refusal" test ! -e "$HOME/.local/bin/esploro"
echo "$pinned" > "$t/commit"; : > "$calls"

# --- Setup ------------------------------------------------------------------------
mkdir -p "$HOME/.config"
printf '[Default Applications]\ninode/directory=pcmanfm.desktop\n' > "$HOME/.config/mimeapps.list"
es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: setup should work"; fail=1; }
dbus_service="$HOME/.local/share/dbus-1/services/org.freedesktop.FileManager1.service"
check "folders should open in Esploro (over PCManFM, Vikix's own earlier choice)" \
  grep -qx 'inode/directory=vikix-esploro.desktop' "$HOME/.config/mimeapps.list"
check "the browsers' Show in folder should reach Esploro" grep -qx "Exec=$HOME/.local/bin/esploro --dbus" "$dbus_service"
check "the build should run build.lisp in Esploro's folder: $(grep sbcl "$calls")" \
  grep -q "sbcl (in $opt) .*--no-userinit --load build.lisp" "$calls"
check "the build shouldn't need Quicklisp (the window is Emacs)" test -z "$(grep -i quicklisp "$calls" || true)"
check "the program should be in place" test -x "$opt/esploro"
check "no half-written program should be left" test ! -e "$opt/esploro.new"
check "Esploro should record the commit it was built from" test "$(cat "$opt/.vikix-built" 2>/dev/null)" = "$pinned"
check "esploro should be linked" test "$(readlink "$HOME/.local/bin/esploro")" = "$opt/esploro"
check "Esploro should be in the launcher" grep -q "^Exec=$HOME/.local/bin/esploro %F" "$apps/vikix-esploro.desktop"
check "the launcher entry should offer it for folders" grep -q "^MimeType=inode/directory;" "$apps/vikix-esploro.desktop"
check "setup should record the feature" grep -qx esploro "$HOME/.config/vikix/features"
check "setup shouldn't ask for sudo when the packages are there: $(grep sudo "$calls")" test -z "$(grep '^sudo' "$calls" || true)"
check "setup should say how long the build takes" grep -q "a few seconds" "$t/out"
check "the build log should be kept" test -e "$VIKIX_STATE/logs/esploro-build.log"
check "the manual should be where Info looks" test "$(readlink "$HOME/.local/share/info/esploro.info")" = "$opt/doc/esploro.info"
check "the manual should be in Info's list: $(grep install-info "$calls")" grep -q "install-info --info-dir=$HOME/.local/share/info $HOME/.local/share/info/esploro.info" "$calls"

# --- The doctor ----------------------------------------------------------------------
printf '#!/bin/sh\necho vikix-esploro.desktop\n' > "$t/bin/xdg-mime"; chmod +x "$t/bin/xdg-mime"
es doctor > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: the doctor should pass after setup"; fail=1; }
check "the doctor should say it's built at the pin" grep -q "built at Vikix's pin" "$t/out"
check "the doctor should say Show in folder reaches it" grep -q "Show in folder reaches Esploro" "$t/out"
check "the doctor should say folders open in it" grep -q "folders open in Esploro" "$t/out"
printf '#!/bin/sh\necho thunar.desktop\n' > "$t/bin/xdg-mime"
es doctor > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a folder program of your own isn't a problem"; fail=1; }
check "a folder program of yours should be said, not counted" grep -q "folders open in thunar.desktop" "$t/out"
echo other > "$opt/.vikix-built"
if es doctor > "$t/out" 2>&1; then echo "FAIL: built from another commit should count"; fail=1; fi
check "the doctor should say how to build the pinned one" grep -q "built from another commit: vikix esploro setup" "$t/out"
echo "$pinned" > "$opt/.vikix-built"

# --- Again: nothing to build; --rebuild builds ----------------------------------
: > "$calls"
es setup > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: a second setup should work"; fail=1; }
check "a second setup should build nothing: $(cat "$calls")" test -z "$(grep sbcl "$calls" || true)"
es setup --rebuild > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: --rebuild should work"; fail=1; }
check "--rebuild should build again" grep -q build.lisp "$calls"
if es setup --nonsense > /dev/null 2>&1; then echo "FAIL: an unknown option should be refused"; fail=1; fi

# --- Status ----------------------------------------------------------------------
es status > "$t/out" 2>&1
check "status should show the commit: $(cat "$t/out")" grep -q "built, commit ${pinned:0:7}" "$t/out"
echo other > "$opt/.vikix-built"
es status > "$t/out" 2>&1
check "status should say it's from another commit" grep -q "another commit" "$t/out"
echo "$pinned" > "$opt/.vikix-built"

# --- A failed build: its log is named ------------------------------------------
touch "$t/break"
if es setup --rebuild > "$t/out" 2>&1; then echo "FAIL: a failed build should fail"; fail=1; fi
check "a failed build should name its log: $(cat "$t/out")" grep -q "esploro-build.log" "$t/out"
check "a failed build should show its end" grep -q "a compile error" "$t/out"
rm -f "$t/break"

# --- Uninstall: only what setup made --------------------------------------------
es setup > /dev/null 2>&1 || true
es uninstall > "$t/out" 2>&1 || { cat "$t/out"; echo "FAIL: uninstall should work"; fail=1; }
check "esploro's link should be gone" test ! -e "$HOME/.local/bin/esploro"
check "Esploro's folder should be gone" test ! -e "$opt"
check "the launcher entry should be gone" test ! -e "$apps/vikix-esploro.desktop"
check "the manual should be gone from where Info looks" test ! -e "$HOME/.local/share/info/esploro.info"
check "folders should go back to PCManFM" grep -qx 'inode/directory=pcmanfm.desktop' "$HOME/.config/mimeapps.list"
check "Show in folder should be Esploro's no more" test ! -e "$dbus_service"
if es doctor > "$t/out" 2>&1; then echo "FAIL: the doctor should fail once Esploro is gone"; fail=1; fi
check "the doctor should say it isn't built" grep -q "Esploro isn't built" "$t/out"
check "and from Info's list" grep -q "install-info --delete" "$calls"
check "uninstall should forget the feature" test -z "$(grep -x esploro "$HOME/.config/vikix/features" || true)"
# A folder program of your own is never replaced.
printf '[Default Applications]\ninode/directory=thunar.desktop\n' > "$HOME/.config/mimeapps.list"
es setup > /dev/null 2>&1 || true
check "your own folder program should stay" grep -qx 'inode/directory=thunar.desktop' "$HOME/.config/mimeapps.list"
es uninstall > /dev/null 2>&1 || true
check "and stay after uninstall" grep -qx 'inode/directory=thunar.desktop' "$HOME/.config/mimeapps.list"
# Your own esploro (make install in your clone) is never touched.
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\n' > "$HOME/.local/bin/esploro"
es uninstall > /dev/null 2>&1 || true
check "an esploro that isn't setup's should stay" test -f "$HOME/.local/bin/esploro" -a ! -L "$HOME/.local/bin/esploro"

# --- The key and the menu -------------------------------------------------------
check "Super+e should run vikix-esploro" grep -q '("s-e" *"vikix-esploro"' "$here/config/stumpwm/vikix/keys.lisp"
check "Super+Alt+r should reveal the window's file" grep -q '("s-M-r" *"exec esploro reveal"' "$here/config/stumpwm/vikix/keys.lisp"
check "Super+Alt+e should be PCManFM" grep -q '("s-M-e" *"exec pcmanfm"' "$here/config/stumpwm/vikix/keys.lisp"
check "without Esploro, Super+e should still open files (PCManFM)" grep -q '(run-shell-command "pcmanfm")' "$here/config/stumpwm/vikix/commands.lisp"
check "vikix-esploro should go to the Esploro frame on this workspace only (by its title, an Emacs frame)" \
  grep -q '(find "Esploro" (group-windows (current-group))' "$here/config/stumpwm/vikix/commands.lisp"
check "the reload should reset the old one-buffer state, and make its buffer a view" \
  grep -q 'esploro--view t' "$here/bin/vikix-esploro"
check "the feature should bring Emacs, where the window is" grep -qE '^esploro +\| optional/esploro +\| emacs +\|' "$here/features.list"
check "the Apps menu should offer Esploro once it's here" \
  grep -q '(run-shell-command "esploro") "~/.local/bin/esploro")' "$here/config/stumpwm/vikix/commands.lisp"
check "vikix update should build a moved pin" grep -q 'is_chosen esploro' "$here/bin/vikix"

# --- The rofi door: Super+Alt+x -----------------------------------------------------
check "Super+Alt+x should open Esploro's commands in rofi" grep -q '("s-M-x" *"exec vikix-esploro menu"' "$here/config/stumpwm/vikix/keys.lisp"
check "the reload should load Esploro's loader (embark's , and J) even before Esploro is opened" grep -q 'esploro-loaddefs' "$here/bin/vikix-esploro"
check "a new keymap (closing a project) should be reset on reload" grep -q 'esploro-project-mode-map' "$here/bin/vikix-esploro"
cat > "$t/bin/esploro" <<EOF
#!/bin/sh
echo "esploro \$*" >> "$calls"
case "\$1" in
  reveal) cat "$t/revealed" 2>/dev/null ;;
  commands) printf 'copy-path\tCopy path: Copy its path\ncompress\tCompress: Into a .zip\n' ;;
  run) [ "\$2" = compress ] && echo '(:error "zip isn'"'"'t installed")'
       [ "\$2" = shrink ] && echo '(:done 1 :made ("$HOME/notes/a & b small.png"))' ;;
esac
EOF
# rofi: prints what $t/picked says was picked; nothing there is Escape (exit 1).
printf '#!/bin/sh\necho "rofi $*" >> %q\ncat > /dev/null\n[ -s %q ] || exit 1\ncat %q\n' "$calls" "$t/picked" "$t/picked" > "$t/bin/rofi"
printf '#!/bin/sh\necho "notify-send $*" >> %q\n' "$calls" > "$t/bin/notify-send"
chmod +x "$t/bin/esploro" "$t/bin/rofi" "$t/bin/notify-send"
: > "$calls"; : > "$t/revealed"
es menu
check "with no file behind the window, it should say so, and open no rofi" \
  sh -c "grep -q 'No file behind this window' '$calls' && ! grep -q '^rofi' '$calls'"
echo "$HOME/notes/today.md" > "$t/revealed"
printf 'copy-path\tCopy path: Copy its path\n' > "$t/picked"
: > "$calls"; es menu
check "it should run the command picked on the window's file: $(cat "$calls")" grep -qx "esploro run copy-path $HOME/notes/today.md" "$calls"
check "rofi should show the labels, not the names" grep -q -- "-display-columns 2" "$calls"
printf 'compress\tCompress: Into a .zip\n' > "$t/picked"
: > "$calls"; es menu
check "a command's error should be a notification" grep -q "notify-send Esploro zip isn't installed" "$calls"
printf 'shrink\tShrink: A copy at half the size\n' > "$t/picked"
: > "$calls"; es menu
check "what a command made should be a notification: $(grep notify "$calls")" grep -qF "notify-send Esploro Shrink: made ~/notes/a &amp; b small.png" "$calls"
: > "$t/picked"; : > "$calls"; es menu
check "Escape in rofi should run nothing" sh -c "! grep -q 'esploro run' '$calls'"
# rofi's message is markup: an & in the name would blank it.
echo "$HOME/notes/Tom & Jerry <1>.md" > "$t/revealed"
: > "$calls"; es menu
check "rofi's message should escape the file's name: $(grep '^rofi' "$calls")" grep -qF -- "-mesg ~/notes/Tom &amp; Jerry &lt;1&gt;.md" "$calls"
printf 'copy-path\tCopy path: Copy its path\n' > "$t/picked"
: > "$calls"; es menu
check "the command should still get the file as it is" grep -qxF "esploro run copy-path $HOME/notes/Tom & Jerry <1>.md" "$calls"

[ "$fail" = 0 ] && echo "esploro: fetched at its pin, its command built in its folder with SBCL alone, linked and in the launcher for folders, only what setup made goes, Emacs comes with it, Super+e"
exit "$fail"
