#!/usr/bin/env bash
# tests/dictate.sh — vikix dictate: speak, and it types what you said.
#
#   setup clones whisper.cpp at the pinned tag and refuses another commit,
#   builds it for this CPU, downloads the model and the voice detector and
#   refuses a wrong checksum (keeping nothing), writes the choice, records
#   the feature, installs no packages that are there; toggle listens (16 kHz
#   mono, 600, the bar's file), then stops, writes it down with voice
#   detection and types it (and puts it on the clipboard), without whisper's
#   descriptions of sounds; nothing heard, nothing typed; cancel types
#   nothing; not set up, it says so; models small switches (any language);
#   uninstall keeps the models unless asked
#
# git, cmake, curl, the recorder, whisper, xdotool and xclip are stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/bin/pw-record" 2>/dev/null || true; rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/home/.local/state/vikix" XDG_RUNTIME_DIR="$t/run"
mkdir -p "$HOME" "$t/bin" "$t/run" "$VIKIX_STATE"; chmod 700 "$t/run"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
calls="$t/calls"; : > "$calls"
d() { bash "$here/bin/vikix-dictate" "$@"; }
pinned=$(sed -n 's/^WHISPER_COMMIT=//p' "$here/bin/vikix-dictate")
echo "$pinned" > "$t/commit"

# git: a clone is a folder with .git; HEAD is whatever $t/commit says.
cat > "$t/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >> "$calls"
case "\$*" in
  clone*) for a; do last=\$a; done; mkdir -p "\$last/.git" ;;
  *rev-parse*) cat "$t/commit" ;;
esac
EOF
# cmake: "builds" a whisper-cli that answers with $t/said and logs its args.
cat > "$t/bin/cmake" <<EOF
#!/bin/sh
echo "cmake \$*" >> "$calls"
case "\$*" in
  --build*) mkdir -p "$HOME/.local/opt/whisper.cpp/build/bin"
    cat > "$HOME/.local/opt/whisper.cpp/build/bin/whisper-cli" <<'W'
#!/bin/sh
echo "whisper \$*" >> "$calls"
cat "$t/said" 2>/dev/null
W
    chmod +x "$HOME/.local/opt/whisper.cpp/build/bin/whisper-cli" ;;
esac
EOF
# curl: every download is the same bytes (the test's checksum is theirs).
cat > "$t/bin/curl" <<EOF
#!/bin/sh
echo "curl \$*" >> "$calls"
prev=; for a; do [ "\$prev" = -o ] && out=\$a; prev=\$a; done
printf 'model bytes' > "\$out"
EOF
# The recorder writes its file, and stops (exit 0) on INT, as pw-record does.
cat > "$t/bin/pw-record" <<EOF
#!/bin/sh
echo "pw-record \$*" >> "$calls"
for a; do last=\$a; done
printf 'RIFF' > "\$last"
trap 'exit 0' INT TERM
while :; do sleep 0.1; done
EOF
cat > "$t/bin/xdotool" <<EOF
#!/bin/sh
for a; do last=\$a; done
printf '%s' "\$last" > "$t/typed"
EOF
cat > "$t/bin/xclip" <<EOF
#!/bin/sh
cat > "$t/clipboard"
EOF
cat > "$t/bin/notify-send" <<EOF
#!/bin/sh
echo "\$*" >> "$t/notes"
case "\$*" in *-p*) echo 5 ;; esac
EOF
cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
exit 0
EOF
cat > "$t/bin/sudo" <<EOF
#!/bin/sh
echo "sudo \$*" >> "$calls"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH" VIKIX_GIT="$t/bin/git" VIKIX_CMAKE="$t/bin/cmake" VIKIX_CURL="$t/bin/curl"
VIKIX_TEST_SHA=$(printf 'model bytes' | sha256sum | cut -d' ' -f1)
export VIKIX_TEST_SHA
notes() { cat "$t/notes" 2>/dev/null; }

# Not set up: it says so, and doesn't listen.
d toggle >/dev/null 2>&1 || true
check "not set up, it should say so: $(notes)" grep -q "isn't set up" <<<"$(notes)"
check "not set up, it shouldn't listen" test -z "$(grep pw-record "$calls" || true)"

# Setup refuses another commit behind the tag, and a wrong checksum.
: > "$calls"
echo 0000000000000000000000000000000000000000 > "$t/commit"
d setup >/dev/null 2>&1 && { echo "FAIL: setup built a commit that isn't the pinned one"; fail=1; }
check "a moved tag shouldn't be built" test -z "$(grep 'cmake --build' "$calls" || true)"
echo "$pinned" > "$t/commit"
VIKIX_TEST_SHA=0000 d setup >/dev/null 2>&1 && { echo "FAIL: setup took a model with the wrong checksum"; fail=1; }
kept=$(find "$HOME/.local/share/vikix/whisper" -type f 2>/dev/null || true)
check "a model with the wrong checksum shouldn't be kept: $kept" test -z "$kept"
d setup >/dev/null 2>&1 || { echo "FAIL: setup failed"; fail=1; }
check "setup should clone the pinned tag: $(grep 'git clone' "$calls")" grep -q 'git clone -q --depth 1 --branch v[0-9.]* https://github.com/ggml-org/whisper.cpp' "$calls"
check "setup should build for this CPU: $(grep -m1 cmake "$calls")" grep -q 'GGML_NATIVE=ON' "$calls"
check "setup should fetch the English model" grep -q 'ggml-base.en.bin' "$calls"
check "setup should fetch the voice detector" grep -q 'ggml-silero' "$calls"
check "setup should write the choice" grep -qx 'model=base.en' "$HOME/.config/vikix/dictation"
check "setup should record the feature" grep -qx dictation "$HOME/.config/vikix/features"
check "setup shouldn't ask for sudo when the build tools are there: $(grep sudo "$calls")" test -z "$(grep '^sudo' "$calls" || true)"
: > "$calls"
d setup >/dev/null 2>&1
check "a second setup shouldn't build or download again: $(cat "$calls")" test -z "$(grep -E 'cmake --build|curl' "$calls" || true)"

# Listening, then typing.
echo 'Hello there. (crickets chirping) [BLANK_AUDIO]' > "$t/said"
: > "$t/notes"
d toggle >/dev/null 2>&1
check "toggle should listen: $(notes)" grep -q 'Listening' <<<"$(notes)"
check "it should record 16 kHz mono: $(grep pw-record "$calls")" grep -q -- '--rate 16000 --channels 1' "$calls"
check "the bar's file should name the recorder" test -s "$VIKIX_STATE/dictating"
check "the recording should be yours alone, is $(stat -c %a "$t/run/vikix-dictation.wav" 2>/dev/null)" \
  test "$(stat -c %a "$t/run/vikix-dictation.wav" 2>/dev/null)" = 600
sleep 0.3
d toggle >/dev/null 2>&1
check "it should type what was said, without sounds: [$(cat "$t/typed" 2>/dev/null)]" test "$(cat "$t/typed" 2>/dev/null)" = "Hello there."
check "it should put it on the clipboard too" test "$(cat "$t/clipboard" 2>/dev/null)" = "Hello there."
check "whisper should use voice detection: $(grep '^whisper' "$calls" | tail -1)" grep -q -- '--vad -vm .*ggml-silero' "$calls"
check "whisper should be told English: $(grep '^whisper' "$calls" | tail -1)" grep -q -- '-l en ' "$calls"
check "the recording should be gone" test ! -e "$t/run/vikix-dictation.wav"
check "the bar's file should be gone" test ! -e "$VIKIX_STATE/dictating"

# Nothing heard: nothing typed.
rm -f "$t/typed"; echo '(silence)' > "$t/said"; : > "$t/notes"
d toggle >/dev/null 2>&1; sleep 0.2; d toggle >/dev/null 2>&1
check "nothing heard, it should say so: $(notes)" grep -q 'Heard nothing' <<<"$(notes)"
check "nothing heard, nothing should be typed" test ! -e "$t/typed"

# Cancel: nothing typed.
echo 'do not type me' > "$t/said"
d toggle >/dev/null 2>&1; sleep 0.2; d cancel >/dev/null 2>&1
check "cancel shouldn't type" test ! -e "$t/typed"
check "cancel should drop the recording" test ! -e "$t/run/vikix-dictation.wav"
check "cancel should stop the recorder" test ! -e "$VIKIX_STATE/dictating"

# The multilingual model.
: > "$calls"
d models small >/dev/null 2>&1
check "models small should download it" grep -q 'ggml-small.bin' "$calls"
check "models small should be the choice" grep -qx 'model=small' "$HOME/.config/vikix/dictation"
echo 'Bonjour.' > "$t/said"
d toggle >/dev/null 2>&1; sleep 0.2; d toggle >/dev/null 2>&1
check "small should let whisper find the language: $(grep '^whisper' "$calls" | tail -1)" grep -q -- '-l auto ' "$calls"

# Uninstall: the program goes, the models stay unless asked.
d uninstall >/dev/null 2>&1
check "uninstall should remove whisper.cpp" test ! -e "$HOME/.local/opt/whisper.cpp"
check "uninstall should keep the models" test -s "$HOME/.local/share/vikix/whisper/ggml-small.bin"
check "uninstall should forget the feature" test -z "$(grep -x dictation "$HOME/.config/vikix/features" || true)"
d uninstall --models >/dev/null 2>&1
check "uninstall --models should remove them" test ! -e "$HOME/.local/share/vikix/whisper"

[ "$fail" = 0 ] && echo "dictate: pinned and checked, listens 16 kHz, types what was said (sounds and silence left out), cancel, models, uninstall"
exit "$fail"
