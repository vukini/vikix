#!/usr/bin/env bash
# tests/editors.sh — the Emacs and Neovim configs work on a machine that has
# never seen them: cloned into an empty HOME, every package installs, and
# they start without errors.
#
# This is where fresh installs broke before: an Emacs config loading
# hand-made clones (paredit, the Haskell input method), a MELPA package
# that broke every later install (SLIME's xterm-color), and nvim-treesitter's
# archived branch on Neovim 0.12. Those failures come from the configs'
# own repositories and from upstream packages, not from this repo, so the
# workflow also runs this every week.
#
# Needs emacs, nvim, git, a C compiler, tree-sitter (tree-sitter-cli) and
# the network. Takes several minutes: it installs every package.
#
#   tests/editors.sh            both
#   tests/editors.sh emacs      one of them

set -euo pipefail
: "${VIKIX_EMACS_REPO:=https://github.com/vukini/emacs-void}"
: "${VIKIX_NVIM_REPO:=https://github.com/vukini/nvim-void-linux}"
which=${1:-both}
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_DATA_HOME="$t/home/.local/share" \
       XDG_STATE_HOME="$t/home/.local/state" XDG_CACHE_HOME="$t/home/.cache"
mkdir -p "$HOME"
fail=0

# The lines that mean something went wrong, in either editor's output.
bad='^Error|Failed to install|Cannot open load file|Overwrite previous checkout|attempt to call|stack traceback|E[0-9]+: '

if [ "$which" = both ] || [ "$which" = emacs ]; then
  git clone -q --depth 1 "$VIKIX_EMACS_REPO" "$HOME/.emacs.d"
  echo "emacs: first start, installing every package (minutes)"
  emacs --batch -l "$HOME/.emacs.d/init.el" </dev/null >"$t/emacs1.log" 2>&1 || { echo "FAIL emacs: first start exited $?"; fail=1; }
  if grep -Eq "$bad" "$t/emacs1.log"; then
    echo "FAIL emacs: errors on the first start:"; grep -E "$bad" "$t/emacs1.log" | head -10; fail=1
  fi
  # Packages installed half way show up only on the next start.
  emacs --batch -l "$HOME/.emacs.d/init.el" </dev/null >"$t/emacs2.log" 2>&1 || { echo "FAIL emacs: second start exited $?"; fail=1; }
  if grep -Eq "$bad|Contacting host" "$t/emacs2.log"; then
    echo "FAIL emacs: the second start still had errors or downloads:"; grep -E "$bad|Contacting host" "$t/emacs2.log" | head -10; fail=1
  fi
  [ "$fail" = 0 ] && echo "emacs: installs from scratch and starts clean"
fi

if [ "$which" = both ] || [ "$which" = nvim ]; then
  git clone -q --depth 1 "$VIKIX_NVIM_REPO" "$HOME/.config/nvim"
  echo "nvim: installing the plugins in lazy-lock.json"
  nvim --headless "+Lazy! restore" +qa >"$t/nvim1.log" 2>&1 || { echo "FAIL nvim: Lazy restore exited $?"; fail=1; }
  # Open files of a few languages; the Markdown one is where 0.12 broke.
  printf '# Title\n\nSome `code` and a list:\n\n- one\n\n```lua\nprint(1)\n```\n' > "$t/test.md"
  printf 'local x = { 1, 2 }\nprint(#x)\n' > "$t/test.lua"
  printf 'def f(x):\n    return x + 1\n' > "$t/test.py"
  for f in test.md test.lua test.py; do
    # Parsers are fetched and built on first use, so give it time.
    nvim --headless "$t/$f" -c 'sleep 30' \
      -c "lua local ok, p = pcall(vim.treesitter.get_parser, 0); local hl = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil; if ok then p:parse(true) end; io.stderr:write(string.format('RESULT parser=%s highlight=%s\\n', ok and p:lang() or 'none', tostring(hl)))" \
      -c 'redir! >> '"$t"'/nvim-msgs | silent messages | redir END' -c 'qa!' >"$t/nvim-$f.log" 2>&1 || true
    res=$(grep -o 'RESULT.*' "$t/nvim-$f.log" || echo "RESULT none")
    if grep -Eq "$bad" "$t/nvim-$f.log" "$t/nvim-msgs" 2>/dev/null; then
      echo "FAIL nvim $f: errors:"; grep -Eh "$bad" "$t/nvim-$f.log" "$t/nvim-msgs" | head -10; fail=1
    elif ! grep -q 'highlight=true' <<<"$res"; then
      echo "FAIL nvim $f: no treesitter highlighting ($res)"; fail=1
    else
      echo "nvim $f: ${res#RESULT }"
    fi
  done
fi

exit "$fail"
