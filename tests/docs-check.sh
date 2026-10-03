#!/usr/bin/env bash
# tests/docs-check.sh — .claude/docs-check, the weekly guides check, on a
# made-up plugins repo and a made-up Vikix history:
#   - a plugin with no section in docs/plugins.md, a key or a setting the
#     guide doesn't mention: each found; a guide that mentions all: nothing
#   - Super+Alt+Shift+i is how s-M-I is written
#   - a commit that changed bin/ without the guides is found; one that
#     changed the guides too, or only tests, isn't; --reviewed starts afresh
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t" XDG_STATE_HOME="$t/state" VIKIX_PLUGINS_SRC="$t/plugins"
export GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
printf '[init]\n\tdefaultBranch = main\n' > "$t/gitconfig"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

# A Vikix with the check and a plugins guide, and a plugins repo.
v="$t/vikix"; mkdir -p "$v/.claude" "$v/docs" "$v/bin" "$v/tests"
cp "$here/.claude/docs-check" "$v/.claude/"
cat > "$v/docs/plugins.md" <<'MD'
# Plugins

## Adding

| Super+Alt+n | notes | A note |

## notes: notes

Super+Alt+Shift+i quotes. Set `file = x`.
MD
git -C "$v" init -q; git -C "$v" add -A; git -C "$v" commit -qm start
for p in notes other; do
  mkdir -p "$t/plugins/$p/settings"; echo "name: $p" > "$t/plugins/$p/manifest"
done
printf '(vikix-plugin-key "s-M-n" "a" "b")\n(vikix-plugin-key "s-M-I" "a" "b")\n(vikix-plugin-key "s-M-q" "a" "b")\n' > "$t/plugins/notes/plugin.lisp"
printf 'file = ~/x\n# folder = ~/y\n' > "$t/plugins/notes/settings/settings"
git -C "$t/plugins" init -q; git -C "$t/plugins" add -A; git -C "$t/plugins" commit -qm start
dc() { python3 "$v/.claude/docs-check" "$@"; }
python3 "$v/.claude/docs-check" --reviewed >/dev/null

out=$(dc || true)
check "a plugin with no section: $out" grep -q 'no section for the plugin other' <<<"$out"
check "a key not mentioned: $out" grep -q "doesn't mention notes's key Super+Alt+q" <<<"$out"
check "a commented setting not mentioned: $out" grep -q "doesn't mention notes's setting folder =" <<<"$out"
check "keys and settings mentioned aren't found: $out" bash -c '! grep -qE "Super\+Alt\+(n|Shift\+i)$|setting file =" <<<"$1"' _ "$out"

# Commits.
echo x > "$v/bin/vikix-new"; git -C "$v" add bin/vikix-new; git -C "$v" commit -qm "A new command, no guide"
echo y > "$v/bin/vikix-doc"; echo z >> "$v/docs/plugins.md"; git -C "$v" add -A; git -C "$v" commit -qm "A command with its guide"
echo t > "$v/tests/new.sh"; git -C "$v" add -A; git -C "$v" commit -qm "Only a test"
out=$(dc || true)
check "a change without the guides is found: $out" grep -q 'A new command, no guide' <<<"$out"
check "one with its guide isn't: $out" bash -c '! grep -q "with its guide" <<<"$1"' _ "$out"
check "only a test isn't: $out" bash -c '! grep -q "Only a test" <<<"$1"' _ "$out"
dc --reviewed >/dev/null
out=$(dc || true)
check "after --reviewed, the old commits are gone: $out" bash -c '! grep -q "A new command" <<<"$1"' _ "$out"

[ "$fail" = 0 ] && echo "docs-check: the plugins guide's sections, keys and settings, changes without the guides, and --reviewed"
exit "$fail"
