#!/usr/bin/env bash
# tests/editors.sh — the Emacs and Neovim configs work on a machine that has
# never seen them: in an empty HOME (Emacs's cloned, Neovim's from this
# checkout, set up as 45-editors does), every package installs, and they
# start without errors.
#
# This is where fresh installs broke before: an Emacs config loading
# hand-made clones (paredit, the Haskell input method), a MELPA package
# that broke every later install (SLIME's xterm-color), and nvim-treesitter's
# archived branch on Neovim 0.12. Those failures come from upstream
# packages (and Emacs's config repository), not only from this repo, so the
# workflow also runs this every week.
#
# Needs emacs, nvim, git, a C compiler, tree-sitter (tree-sitter-cli) and
# the network. Takes several minutes: it installs every package.
#
#   tests/editors.sh            both
#   tests/editors.sh emacs      one of them

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
: "${VIKIX_EMACS_REPO:=https://github.com/vukini/emacs-void}"
# Neovim: this checkout's config/nvim, or a repository of yours if set.
VIKIX_NVIM_REPO=${VIKIX_NVIM_REPO:-}
here=$(cd "$(dirname "$0")/.." && pwd)
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
  # Vikix's part, as 45-editors links it: the config loads it when it's there.
  mkdir -p "$HOME/.local/share/vikix"
  ln -s "$here/config/emacs" "$HOME/.local/share/vikix/emacs"
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
  if [ -n "$VIKIX_NVIM_REPO" ]; then
    git clone -q --depth 1 "$VIKIX_NVIM_REPO" "$HOME/.config/nvim"
  else
    # As 45-editors does: Vikix's part linked, the starter and the lock copied.
    mkdir -p "$XDG_DATA_HOME/vikix" "$HOME/.config/nvim"
    ln -s "$here/config/nvim" "$XDG_DATA_HOME/vikix/nvim"
    cp -R "$here/config/nvim/starter/." "$HOME/.config/nvim/"
    cp "$here/config/nvim/lazy-lock.json" "$HOME/.config/nvim/"
  fi
  echo "nvim: installing the plugins in lazy-lock.json"
  nvim --headless "+Lazy! restore" +qa >"$t/nvim1.log" 2>&1 || { echo "FAIL nvim: Lazy restore exited $?"; fail=1; }
  if [ -z "$VIKIX_NVIM_REPO" ]; then
    out=$(nvim --headless -c 'lua local p = require("lazy.core.config").plugins; io.stderr:write("VIKIX=" .. tostring(p.vikix ~= nil) .. " TYPST=" .. tostring(p["typst-preview.nvim"] ~= nil) .. "\n")' -c 'qa!' 2>&1 || true)
    grep -q 'VIKIX=true TYPST=true' <<<"$out" || { echo "FAIL nvim: Vikix's part didn't load: $(grep -o 'VIKIX.*' <<<"$out" || tail -3 <<<"$out")"; fail=1; }
    # AI, with no key and no agent: the keys say what's missing, and start
    # nothing; the agents would start through vikix agent --acp.
    mkdir -p "$HOME/.config/vikix"; echo use=claude > "$HOME/.config/vikix/ai"
    cat > "$t/ai.lua" <<'EOF'
local said = {}
vim.notify = function(m) table.insert(said, m) end
require("lazy").load { plugins = { "codecompanion.nvim" } }
for _, k in ipairs { " Ac", " Ag" } do vim.fn.maparg(k, "n", false, true).callback() end
local cmd = require("codecompanion.adapters.acp").resolve("claude_code").commands
io.stderr:write("AI said=" .. table.concat(said, " | "):gsub("\n", " ") .. " cmd=" .. table.concat(cmd.default, " ")
  .. " others=" .. tostring(vim.tbl_count(cmd) - 2) .. "\n")
EOF
    out=$(env -u ANTHROPIC_API_KEY PATH="$here/bin:$PATH" nvim --headless -c "luafile $t/ai.lua" -c 'qa!' 2>&1 || true)
    for want in 'vikix ai key set anthropic' 'vikix agent --install claude' 'cmd=vikix agent --acp claude ' 'others=0'; do
      grep -q -- "$want" <<<"$out" || { echo "FAIL nvim: AI should have said '$want': $(grep -o 'AI said.*' <<<"$out" || tail -3 <<<"$out")"; fail=1; }
    done
    rm "$HOME/.config/vikix/ai"
  fi
  # Open files of a few languages; the Markdown one is where 0.12 broke.
  printf '# Title\n\nSome `code` and a list:\n\n- one\n\n```lua\nprint(1)\n```\n' > "$t/test.md"
  printf 'local x = { 1, 2 }\nprint(#x)\n' > "$t/test.lua"
  printf 'def f(x):\n    return x + 1\n' > "$t/test.py"
  printf '= Title\n\nSome *strong* text and $x^2$.\n' > "$t/test.typ"   # Vikix's Typst pack
  for f in test.md test.lua test.py test.typ; do
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
