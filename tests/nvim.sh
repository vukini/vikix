#!/usr/bin/env bash
# tests/nvim.sh — 45-editors and Neovim's config, without the network.
#
#   a new machine gets the starter (yours), a link to Vikix's part and the
#   lock Vikix tested, with the plugins restored; an update with nothing new
#   restores nothing; a new lock from Vikix moves an untouched one on, and
#   leaves one you changed (said once); an unchanged clone of the old sister
#   repo (nvim-void-linux) is set aside for the starter, and one with your
#   changes stays and is pulled; VIKIX_NVIM_REPO, a clone of your own and a
#   folder of your own are left to you; a dry run changes nothing; and the
#   Lua in config/nvim compiles.
#
# nvim is a stand-in that records what it was asked; the whole config,
# with its plugins, is tests/editors.sh's (--all, network).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME VIKIX_NVIM_REPO VIKIX_STATE
here=$(cd "$(dirname "$0")/.." && pwd)
real_nvim=$(command -v nvim || true)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
lacks() { ! grep -q -- "$1" <<<"$2"; }

# Stand-ins: nvim records its arguments (and makes lazy.nvim's folder, as a
# restore would); the npm language servers are "installed" already.
mkdir -p "$t/bin"
cat > "$t/bin/nvim" <<'EOF'
#!/bin/sh
echo "nvim $*" >> "$HOME/nvim.calls"
mkdir -p "$HOME/.local/share/nvim/lazy/lazy.nvim"
EOF
for c in typescript-language-server pyright-langserver bash-language-server; do printf '#!/bin/sh\n' > "$t/bin/$c"; done
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
export GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# A copy of the checkout, so a test can ship a new lock without touching the real one.
mkdir -p "$t/vikix/config"
cp -R "$here/lib" "$here/install" "$here/bin" "$here/packages" "$here/features.list" "$here/bundles.list" "$here/VERSION" "$t/vikix/"
cp -R "$here/config/nvim" "$here/config/yours.list" "$t/vikix/config/"

fresh() {   # fresh NAME — an empty HOME that chose Neovim
  export HOME="$t/$1"
  mkdir -p "$HOME/.config/vikix"
  echo neovim > "$HOME/.config/vikix/features"
}
stage() { bash "$t/vikix/install/45-editors.sh" 2>&1; }
calls() { cat "$HOME/nvim.calls" 2>/dev/null || true; }

# --- a new machine --------------------------------------------------------
fresh new
out=$(stage)
check "the starter should be copied: $out" test -f "$HOME/.config/nvim/init.lua"
check "the starter should load Vikix's part" grep -qF 'require, "vikix"' "$HOME/.config/nvim/init.lua"
check "the example for your own plugins should be there" test -f "$HOME/.config/nvim/lua/plugins/example.lua"
check "Vikix's part should be a link into the checkout: $(readlink "$HOME/.local/share/vikix/nvim")" \
  test "$(readlink "$HOME/.local/share/vikix/nvim")" = "$t/vikix/config/nvim"
check "the lock should be Vikix's" cmp -s "$HOME/.config/nvim/lazy-lock.json" "$t/vikix/config/nvim/lazy-lock.json"
check "the plugins should be restored (and the unused cleaned): $(calls)" has 'Lazy! restore.*Lazy! clean' "$(calls)"
check "the lock's state should be recorded" test -s "$HOME/.local/state/vikix/nvim-lock"

# An update with nothing new: no restore.
: > "$HOME/nvim.calls"
out=$(stage)
check "an update with nothing new shouldn't restore: $(calls)" test -z "$(calls)"
check "the starter shouldn't be copied again: $out" lacks 'starter' "$out"

# Your own plugin file stays through updates, and is in the snapshot history.
echo 'return {}' > "$HOME/.config/nvim/lua/plugins/mine.lua"
stage >/dev/null
check "your plugin file should stay" test -f "$HOME/.config/nvim/lua/plugins/mine.lua"
out=$(bash "$t/vikix/bin/vikix" snapshot test 2>&1 || true)
recorded=$(git --git-dir="$HOME/.local/state/vikix/yours.git" ls-files 2>/dev/null || true)
check "your Neovim files should be in the snapshot history: $out" has '.config/nvim/lua/plugins/mine.lua' "$recorded"

# Vikix ships a new lock: an untouched one moves on.
python3 - "$t/vikix/config/nvim/lazy-lock.json" <<'EOF'
import sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace('"lazy.nvim": { "branch": "main", "commit": "', '"lazy.nvim": { "branch": "main", "commit": "0', 1))
EOF
: > "$HOME/nvim.calls"
out=$(stage)
check "an untouched lock should move on to Vikix's new one: $out" cmp -s "$HOME/.config/nvim/lazy-lock.json" "$t/vikix/config/nvim/lazy-lock.json"
check "and the plugins be restored: $(calls)" has 'Lazy! restore' "$(calls)"

# A lock of your own stays, and is mentioned once for each new one Vikix ships.
echo '{ "mine": { "branch": "main", "commit": "1" } }' > "$HOME/.config/nvim/lazy-lock.json"
sed -i 's/"commit": "0/"commit": "00/' "$t/vikix/config/nvim/lazy-lock.json"
: > "$HOME/nvim.calls"
out=$(stage)
check "a lock of your own should stay" grep -q '"mine"' "$HOME/.config/nvim/lazy-lock.json"
check "it should say how to take Vikix's: $out" has 'plugin versions of your own' "$out"
check "and not restore: $(calls)" test -z "$(calls)"
out=$(stage)
check "it should say so only once: $out" lacks 'of your own' "$out"
sed -i 's/"commit": "00/"commit": "000/' "$t/vikix/config/nvim/lazy-lock.json"
out=$(stage)
check "a lock of yours should stay when Vikix ships yet another" grep -q '"mine"' "$HOME/.config/nvim/lazy-lock.json"
cp "$here/config/nvim/lazy-lock.json" "$t/vikix/config/nvim/lazy-lock.json"

# --- a dry run changes nothing --------------------------------------------
fresh dry
out=$(DRY_RUN=1 stage)
check "a dry run should copy nothing: $(ls -A "$HOME/.config")" test ! -e "$HOME/.config/nvim"
check "a dry run should say what it would do: $out" has 'would' "$out"
check "a dry run should run no nvim: $(calls)" test -z "$(calls)"

# --- the old sister repo --------------------------------------------------
# A local stand-in for github.com/vukini/nvim-void-linux (the name is what counts).
mkdir -p "$t/remote/vukini"
git init -q --bare "$t/remote/vukini/nvim-void-linux.git"
git clone -q "$t/remote/vukini/nvim-void-linux.git" "$t/seed" 2>/dev/null
printf 'require "lazy_setup"\n' > "$t/seed/init.lua"
echo '{}' > "$t/seed/lazy-lock.json"
git -C "$t/seed" add -A && git -C "$t/seed" commit -qm seed && git -C "$t/seed" push -q origin HEAD 2>/dev/null

fresh oldclean
git clone -q "$t/remote/vukini/nvim-void-linux.git" "$HOME/.config/nvim"
echo '{ "changed": {} }' > "$HOME/.config/nvim/lazy-lock.json"    # :Lazy update did this: not a change of yours
out=$(stage)
check "an unchanged old clone should give way to the starter: $out" grep -qF 'require, "vikix"' "$HOME/.config/nvim/init.lua"
bak=$(ls -d "$HOME/.config/nvim.vikix-bak."* 2>/dev/null | head -1)
check "the old clone should be kept aside, not deleted" test -f "$bak/init.lua"
check "the lock should be Vikix's now" cmp -s "$HOME/.config/nvim/lazy-lock.json" "$here/config/nvim/lazy-lock.json"

fresh oldmine
git clone -q "$t/remote/vukini/nvim-void-linux.git" "$HOME/.config/nvim"
echo '-- mine' >> "$HOME/.config/nvim/init.lua"
out=$(stage)
check "an old clone with your changes should stay: $out" grep -q -- '-- mine' "$HOME/.config/nvim/init.lua"
check "it should say how to switch: $out" has 'move ~/.config/nvim away' "$out"
check "there should be no starter over it" test ! -e "$HOME/.local/share/vikix/nvim"

fresh oldcommit
git clone -q "$t/remote/vukini/nvim-void-linux.git" "$HOME/.config/nvim"
echo '-- mine' >> "$HOME/.config/nvim/init.lua"
git -C "$HOME/.config/nvim" commit -qam mine
out=$(stage)
check "an old clone with a commit of yours should stay: $out" grep -q -- '-- mine' "$HOME/.config/nvim/init.lua"

# --- configs of your own --------------------------------------------------
fresh ownrepo
out=$(VIKIX_NVIM_REPO="$t/remote/vukini/nvim-void-linux.git" stage)
check "VIKIX_NVIM_REPO should be cloned: $out" test -d "$HOME/.config/nvim/.git"
check "and have no starter: $out" lacks 'starter' "$out"

fresh ownclone
git init -q "$HOME/.config/nvim"
echo '-- mine' > "$HOME/.config/nvim/init.lua"
out=$(stage)
check "a clone of your own should be left to you: $out" test ! -e "$HOME/.config/nvim/lua/plugins/example.lua"
# A clone with no commit yet would make git refuse the whole snapshot.
out=$(bash "$t/vikix/bin/vikix" snapshot test 2>&1) || { echo "FAIL: a snapshot with a clone at ~/.config/nvim should work: $out"; fail=1; }
recorded=$(git --git-dir="$HOME/.local/state/vikix/yours.git" ls-tree -r --name-only HEAD 2>/dev/null || true)
check "a clone should be left out of the snapshot history (it has its own): $recorded" lacks '.config/nvim' "$recorded"

fresh ownfolder
mkdir -p "$HOME/.config/nvim" && echo '-- mine' > "$HOME/.config/nvim/init.lua"
out=$(stage)
check "a folder of your own should be left alone: $out" has 'leaving it alone' "$out"
check "and not changed" test "$(cat "$HOME/.config/nvim/init.lua")" = '-- mine'

# --- the Lua compiles -----------------------------------------------------
if [ -n "$real_nvim" ]; then
  mapfile -t lua < <(find "$here/config/nvim" -name '*.lua' | sort)
  out=$("$real_nvim" --clean --headless -c 'lua for _, f in ipairs(vim.fn.argv()) do local ok, err = loadfile(f); if not ok then io.stderr:write("BAD " .. err .. "\n") end end' -c 'qa!' -- "${lua[@]}" 2>&1 || true)
  check "every Lua file in config/nvim should compile: $out" lacks 'BAD' "$out"
else
  echo "nvim: no nvim here; the Lua wasn't compiled"
fi

[ "$fail" = 0 ] && echo "nvim: the starter, Vikix's part and lock on a new machine, locks that move on or stay, the old clone set aside or kept, your own configs left alone, dry run, the Lua compiles"
exit "$fail"
