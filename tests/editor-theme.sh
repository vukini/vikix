#!/usr/bin/env bash
# tests/editor-theme.sh — the editors follow `vikix theme`, without the network.
#
#   vikix theme writes the palette the editors read; in Emacs
#   (config/emacs/vikix-theme.el) contrast is Modus Vivendi, a theme of
#   yours is `vikix-palette' in its own colours, a built-in one whose
#   package can't be installed falls back to its colours too, and a second
#   apply of the same theme does nothing; in Neovim (lua/vikix/theme.lua)
#   each built-in theme has its scheme and the rest are "vikix", the palette
#   is read, the "vikix" scheme is the palette's colours (when mini.base16
#   is here: Vikix's Neovim installed it), and `vikix theme` reaches a
#   running Neovim through its socket.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
base16=$(find "$HOME/.local/share/nvim/lazy" -maxdepth 1 -name mini.base16 2>/dev/null | head -1)
t=$(mktemp -d)
trap 'kill "${nvim_pid:-}" 2>/dev/null || true; rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
export HOME="$t/home" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME/.config/vikix/themes" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
theme() { DISPLAY='' bash "$here/bin/vikix" theme "$@" >/dev/null; }
pal="$HOME/.config/vikix/theme/palette"

# --- the palette -------------------------------------------------------------------
theme gruvbox
check "vikix theme should write the palette" grep -qx 'bg=#282828' "$pal"
check "with every colour, sel too" test "$(grep -c '^[a-z0-9]*=#' "$pal")" = 23
sed 's/^bg=.*/bg=#102030/; s/^fg=.*/fg=#f0e0d0/' "$here/themes/void.theme" > "$HOME/.config/vikix/themes/mine.theme"
theme mine
check "a theme of yours gets its palette too" grep -qx 'bg=#102030' "$pal"

# --- Emacs ---------------------------------------------------------------------------
if command -v emacs >/dev/null; then
  el="$here/config/emacs/vikix-theme"
  # No archives and an empty package folder: nothing can be installed.
  # Only the last line: package.el talks on stderr and stdout as it starts.
  em() {
    emacs --batch -Q --eval "(setq package-user-dir \"$t/elpa\" package-archives nil)" \
      --eval "(fset 'package-refresh-contents (lambda (&rest _) (error \"offline\")))" \
      -l "$el" --eval "$1" 2>/dev/null | tail -1 || true
  }
  out=$(em '(princ (format "%s %s" (cdr vikix-theme--applied) (face-attribute (quote default) :background)))')
  check "Emacs: a theme of yours should be vikix-palette in its colours: $out" test "$out" = "vikix-palette #102030"
  theme contrast
  out=$(em '(princ (cdr vikix-theme--applied))')
  check "Emacs: contrast should be Modus Vivendi: $out" test "$out" = modus-vivendi
  theme void
  out=$(em '(princ (format "%s %s" (cdr vikix-theme--applied) (face-attribute (quote default) :background)))')
  check "Emacs: void without its package should fall back to its own colours: $out" test "$out" = "vikix-palette #1e1e2e"
  out=$(em '(princ (vikix-theme-apply))')
  check "Emacs: applying the same theme again should do nothing: $out" test "$out" = nil
  out=$(em '(progn (princ (length custom-enabled-themes)))')
  check "Emacs: one theme at a time: $out" test "$out" = 1
  # A second theme of yours in the same Emacs: the palette theme must take
  # the new colours, not keep the first's (its old settings outlived the
  # disabling, and won; the Office and Esploro, Emacs frames, stayed in
  # the first imported theme's colours through every switch).
  sed 's/^bg=.*/bg=#304050/' "$here/themes/void.theme" > "$HOME/.config/vikix/themes/mine2.theme"
  theme mine
  out=$(em "(progn (let ((process-environment (cons \"DISPLAY=\" process-environment))) (call-process \"bash\" nil nil nil \"$here/bin/vikix\" \"theme\" \"mine2\")) (vikix-theme-apply) (princ (format \"%s %s %s\" (car vikix-theme--applied) (face-attribute (quote default) :background) (length custom-enabled-themes))))")
  check "Emacs: a second theme of yours should bring its own colours: $out" test "$out" = "mine2 #304050 1"
  theme void
else
  echo "(the Emacs part needs Emacs; skipped here)"
fi

# --- Neovim ------------------------------------------------------------------------------
if command -v nvim >/dev/null; then
  rtp="$here/config/nvim"
  nv() { nvim --headless --clean --cmd "set rtp^=$rtp${base16:+,$base16}" -c "lua $1" -c q 2>&1; }
  out=$(nv 'io.write(require("vikix.theme").colorscheme())')
  check "Neovim: void should be Catppuccin Mocha: $out" test "$out" = catppuccin-mocha
  theme tokyo-night
  out=$(nv 'io.write(require("vikix.theme").colorscheme())')
  check "Neovim: tokyo-night should be tokyonight-night: $out" test "$out" = tokyonight-night
  theme contrast
  out=$(nv 'local t = require("vikix.theme"); io.write(t.colorscheme(), " ", t.palette().accent)')
  check "Neovim: contrast should be vikix, from its palette: $out" test "$out" = "vikix #ffd700"
  if [ -n "$base16" ]; then
    out=$(nv 'vim.cmd.colorscheme "vikix"; io.write(string.format("%s #%06x", vim.g.colors_name, vim.api.nvim_get_hl(0, { name = "Normal" }).bg))')
    check "Neovim: the vikix scheme should be the palette's colours: $out" test "$out" = "vikix #000000"
  else
    echo "(Neovim's vikix scheme needs mini.base16, which Vikix's Neovim installs; skipped here)"
  fi
  # A running Neovim: vikix theme calls apply() in it, through its socket.
  sock="$XDG_RUNTIME_DIR/nvim.4242.0"
  nvim --headless --clean --listen "$sock" --cmd "set rtp^=$rtp" \
    -c 'lua package.loaded["vikix.theme"] = { apply = function() vim.g.vikix_applied = (vim.g.vikix_applied or 0) + 1 end }' >/dev/null 2>&1 &
  nvim_pid=$!
  for _ in $(seq 1 50); do [ -S "$sock" ] && break; sleep 0.1; done
  DISPLAY=:99 bash "$here/bin/vikix" theme nord >/dev/null 2>&1 || true
  out=$(timeout 3 nvim --server "$sock" --remote-expr 'g:vikix_applied' 2>&1 || true)
  check "vikix theme should reach a running Neovim: $out" test "$out" = 1
fi

[ "$fail" = 0 ] && echo "editor-theme: Emacs and Neovim follow vikix theme, built-in or yours, and a running Neovim changes at once"
exit "$fail"
