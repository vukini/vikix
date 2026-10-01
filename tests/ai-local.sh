#!/usr/bin/env bash
# tests/ai-local.sh — local models (`vikix ai setup | models | stop`), with
# a stand-in Ollama release and stand-ins for curl and rofi.
#
#   setup    downloads (checked against its checksum; a wrong one is
#            deleted and nothing installed), unpacks only what this machine
#            uses (no NVIDIA libraries; the CPU's and Vulkan's kept), puts
#            ollama on PATH, deletes the 1.4 GB download, and keeps models
#            out of backups; a second setup downloads nothing
#   models   offers what fits: 7-8B "slowly" on 16 GB, not at all on 8 GB;
#            marks what you have; from Super+m before setup, a notification
#   serve    notes the loaded model for the bar, and takes the note away
#   stop     unloads each loaded model
#
# The unpacking needs Python's zstd (3.14); without it that part is skipped.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/" 2>/dev/null || true; rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME/.config/vikix" "$t/bin"
calls="$t/calls"; : > "$calls"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
ai() { bash "$here/bin/vikix-local-ai" "$@"; }

if ! python3 -c 'from compression import zstd' 2>/dev/null; then
  echo "ai-local: needs Python 3.14's zstd; skipped"; exit 0
fi

# A stand-in release: bin/ollama (a script noting what it's asked), CPU and
# Vulkan libraries, and NVIDIA's, which must stay out.
mkdir -p "$t/rel/bin" "$t/rel/lib/ollama/cuda_v12" "$t/rel/lib/ollama/vulkan"
cat > "$t/rel/bin/ollama" <<EOF
#!/bin/sh
echo "ollama \$*" >> "$calls"
case \$1 in
  serve) sleep 2 ;;
  run) : ;;
  list) printf 'NAME ID SIZE MODIFIED\nllama3.2:3b abc 2.0GB now\n' ;;
esac
EOF
chmod +x "$t/rel/bin/ollama"
echo cpu > "$t/rel/lib/ollama/libggml-cpu-haswell.so"
echo vk > "$t/rel/lib/ollama/vulkan/libggml-vulkan.so"
head -c 100000 /dev/urandom > "$t/rel/lib/ollama/cuda_v12/libggml-cuda.so"
python3 - "$t/rel" "$t/release.tar.zst" <<'PY'
import sys, tarfile
from compression import zstd
src, out = sys.argv[1:]
with zstd.open(out, "wb") as f, tarfile.open(fileobj=f, mode="w|") as tf:
    tf.add(src, arcname=".")
PY
sum=$(sha256sum "$t/release.tar.zst" | cut -d' ' -f1)

# curl: a download copies the stand-in release; the API answers from files.
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
out=; for a; do [ "\$prev" = -o ] && out=\$a; prev=\$a; done
case "\$*" in
  *api/version*) [ -e "$t/running" ] ;;
  *api/ps*) cat "$t/ps" 2>/dev/null || echo '{"models": []}' ;;
  *api/tags*) echo '{"models": [{"name": "llama3.2:3b"}]}' ;;
  *api/generate*) rm -f "$t/ps" ;;
  *) cp "$t/release.tar.zst" "\$out" ;;
esac
EOF
printf '#!/bin/sh\necho "setsid $*" >> %q\n' "$calls" > "$t/bin/setsid"
printf '#!/bin/sh\necho "notify-send $*" >> %q\n' "$calls" > "$t/bin/notify-send"
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_OLLAMA_SHA256=$sum
opt="$HOME/.local/opt/ollama"

# --- setup -------------------------------------------------------------------------
out=$(VIKIX_OLLAMA_SHA256=0000 ai setup 2>&1) && { echo "FAIL: setup took a download with the wrong checksum"; fail=1; }
check "a wrong checksum should be said: $out" grep -q "checksum doesn't match" <<<"$out"
check "a wrong download was installed" test ! -e "$opt"
check "a wrong download was kept" bash -c "! ls '$HOME/.cache/vikix/' 2>/dev/null | grep -q ollama"

printf '# mine\n$HOME/.cache\n' > "$HOME/.config/vikix/backup-exclude"
out=$(ai setup 2>&1) || { echo "FAIL: setup failed: $out"; fail=1; }
check "no ollama installed" test -x "$opt/bin/ollama"
check "the CPU libraries weren't kept" test -e "$opt/lib/ollama/libggml-cpu-haswell.so"
check "Vulkan's library wasn't kept (it's for Intel graphics, later)" test -e "$opt/lib/ollama/vulkan/libggml-vulkan.so"
check "NVIDIA's libraries were installed (2 GB this machine can't use)" test ! -e "$opt/lib/ollama/cuda_v12"
check "no VERSION noted" test -s "$opt/VERSION"
check "ollama isn't on PATH (~/.local/bin/ollama)" test "$(readlink "$HOME/.local/bin/ollama")" = "$opt/bin/ollama"
check "the 1.4 GB download was kept after installing" bash -c "! ls '$HOME/.cache/vikix/' 2>/dev/null | grep -q ollama"
check "models aren't kept out of backups" grep -qF '$HOME/.ollama/models' "$HOME/.config/vikix/backup-exclude"
check "setup should start Ollama" grep -q 'setsid .*vikix-local-ai serve' "$calls"
: > "$calls"
out=$(ai setup 2>&1)
check "a second setup downloaded again: $(grep -c 'curl -fL' "$calls")" bash -c "! grep -q 'curl -fL' '$calls'"
check "a second setup should say it's installed: $out" grep -q 'is installed' <<<"$out"
check "a second setup doubled the backup lines" test "$(grep -c '.ollama/models' "$HOME/.config/vikix/backup-exclude")" = 1

# --- models ------------------------------------------------------------------------
printf 'MemTotal:       16134020 kB\n' > "$t/mem16"
printf 'MemTotal:        8000000 kB\n' > "$t/mem8"
touch "$t/running"
out=$(VIKIX_MEMINFO="$t/mem16" ai models --print)
check "16 GB should offer qwen3:8b, running slowly: $out" grep -qE 'qwen3:8b .*runs slowly' <<<"$out"
check "a 1B model should run fast: $out" grep -qE 'gemma3:1b .*runs fast' <<<"$out"
check "a model you have should be marked ✓: $out" grep -qE '^✓ llama3.2:3b ' <<<"$out"
out=$(VIKIX_MEMINFO="$t/mem8" ai models --print)
check "8 GB offered an 8B model that won't fit: $out" bash -c "! grep -q 'qwen3:8b' <<<'$out'"
check "8 GB should still offer a 3B model" grep -q 'llama3.2:3b' <<<"$out"

# Choosing: by number in a terminal, or in rofi; with or without the ✓.
: > "$calls"
printf '4\n' | VIKIX_MEMINFO="$t/mem16" ai models >/dev/null 2>&1 || true
want=$(VIKIX_MEMINFO="$t/mem16" ai models --print | sed -n 4p | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /:/) { print $i; exit } }')
check "choosing number 4 should download $want: $(grep 'ollama pull' "$calls")" grep -qx "ollama pull $want" "$calls"
: > "$calls"
printf '2\n' | VIKIX_MEMINFO="$t/mem16" ai models >/dev/null 2>&1 || true
check "choosing a model you have (✓) should name it, not the ✓: $(grep 'ollama pull' "$calls")" grep -qE '^ollama pull [a-z0-9.-]+:[a-z0-9.]+$' "$calls"
printf '#!/bin/sh\necho "✓ llama3.2:3b           2.02 GB  runs well    all-rounder"\n' > "$t/bin/rofi"; chmod +x "$t/bin/rofi"
printf '#!/bin/sh\necho "terminal $*" >> %q\n' "$calls" > "$t/bin/alacritty"; chmod +x "$t/bin/alacritty"
: > "$calls"
VIKIX_MEMINFO="$t/mem16" ai models --rofi >/dev/null 2>&1 || true
check "a model picked in rofi should download in a terminal, by its name: $(cat "$calls")" grep -q "terminal .*pull 'llama3.2:3b'" "$calls"

# --- serve: the bar's note ---------------------------------------------------------
rm -f "$t/running"
echo '{"models": [{"name": "llama3.2:3b"}]}' > "$t/ps"
ai serve >/dev/null 2>&1 &
for _ in $(seq 20); do [ -e "$VIKIX_STATE/ai-loaded" ] && break; sleep 0.1; done
check "serve didn't note the loaded model for the bar" grep -qx 'llama3.2:3b' "$VIKIX_STATE/ai-loaded"
wait
check "serve left the note behind when Ollama ended" test ! -e "$VIKIX_STATE/ai-loaded"

# --- status, stop, chat, remove ----------------------------------------------------
touch "$t/running"
echo '{"models": [{"name": "llama3.2:3b", "size": 2560000000, "expires_at": "2099-01-01T12:05:00+00:00"}]}' > "$t/ps"
out=$(ai status)
check "status should say how much memory the loaded model holds, and until when: $out" \
  grep -qE 'loaded: +llama3.2:3b, holding 2.6 GB of memory, until [0-9]{2}:[0-9]{2}' <<<"$out"
: > "$calls"
out=$(ai stop 2>&1)
check "stop should unload through the API (keep_alive 0): $(grep generate "$calls")" grep -q 'api/generate .*"keep_alive": 0' "$calls"
check "stop should say what it freed: $out" grep -q 'unloaded llama3.2:3b' <<<"$out"
: > "$calls"
ai stop --notify >/dev/null 2>&1
check "stop from Super+m should notify" grep -q 'notify-send .*Local AI' "$calls"
: > "$calls"
ai chat >/dev/null 2>&1 || true
check "chat with one model should run it: $(grep 'ollama run' "$calls")" grep -qx 'ollama run llama3.2:3b' "$calls"
out=$(ai remove 2>&1) && { echo "FAIL: remove with no model worked"; fail=1; }
check "remove with no model should say so plainly: $out" grep -q 'which model?' <<<"$out"
check "remove with no model showed a bash error: $out" bash -c "! grep -q 'line [0-9]' <<<'$out'"
out=$(ai remove nosuch:1b 2>&1) && { echo "FAIL: removing a model you don't have worked"; fail=1; }
check "removing a model you don't have should say so: $out" grep -q "you don't have nosuch:1b" <<<"$out"

# --- the log doesn't grow for ever -------------------------------------------------
rm -f "$t/running"; rm -f "$t/ps"
head -c 1100000 /dev/zero > "$VIKIX_STATE/ollama.log"
ai serve >/dev/null 2>&1 &
for _ in $(seq 20); do [ -e "$VIKIX_STATE/ollama.log.old" ] && break; sleep 0.1; done
check "a big ollama.log should be moved aside at the next start" test -e "$VIKIX_STATE/ollama.log.old"
wait

# --- uninstall, and before setup -------------------------------------------------------
mkdir -p "$HOME/.ollama/models"; touch "$HOME/.ollama/models/blob"
# A decoy: another "ollama serve", not this install's (as the real one on
# the machine running the tests is). uninstall must leave it alone.
mkdir -p "$t/decoy"; printf '#!/bin/sh\nexec sleep 30\n' > "$t/decoy/ollama"; chmod +x "$t/decoy/ollama"
"$t/decoy/ollama" serve & decoy=$!
ai uninstall >/dev/null 2>&1
check "uninstall killed another ollama, not its own (it once stopped the tester's real Ollama)" kill -0 "$decoy"
kill "$decoy" 2>/dev/null || true
check "uninstall left Ollama" test ! -e "$opt"
check "uninstall left the ollama link" test ! -e "$HOME/.local/bin/ollama"
check "uninstall without --models deleted the models" test -e "$HOME/.ollama/models/blob"
ai uninstall --models >/dev/null 2>&1
check "uninstall --models kept the models" test ! -e "$HOME/.ollama"
rm -rf "$opt"; : > "$calls"
ai models --rofi >/dev/null 2>&1 || true
check "the Super+m entry, before setup, should say how to set it up" grep -q 'notify-send .*vikix ai setup' "$calls"
: > "$calls"
ai chat --rofi >/dev/null 2>&1 || true
check "talk to a model from Super+m, before setup, should say how to set it up" grep -q 'notify-send .*vikix ai setup' "$calls"

[ "$fail" = 0 ] && echo "ai-local: setup installs only what this machine uses, checked; models fit the memory; the bar's note; stop"
exit "$fail"
