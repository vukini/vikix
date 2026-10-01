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
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
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
# xdotool: the focused window is $t/window's; typing is written down.
echo 42 > "$t/window"
cat > "$t/bin/xdotool" <<EOF
#!/bin/sh
case "\$1" in
  getactivewindow) cat "$t/window" ;;
  type) for a; do last=\$a; done; printf '%s' "\$last" > "$t/typed" ;;
esac
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
# A press, as after a pause (presses within 0.7 s of the last are one).
press() { rm -f "$t/run/vikix-dictation.last"; d toggle >/dev/null 2>&1; }

# Before setup, status says so, cleanly.
out=$(d status 2>&1)
check "status before setup should be clean: $out" test "$out" = "not set up (vikix dictate setup)"
out=$(d models 2>&1)
check "models before setup should be clean (no bash errors): $out" test -z "$(grep -i 'subscript\|line [0-9]' <<<"$out" || true)"

# Not set up: it says so, and doesn't listen.
press || true
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
check "setup should clone the pinned tag: $(grep 'git clone' "$calls")" grep -q 'git -c advice.detachedHead=false clone -q --depth 1 --branch v[0-9.]* https://github.com/ggml-org/whisper.cpp' "$calls"
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
press
check "toggle should listen: $(notes)" grep -q 'Listening' <<<"$(notes)"
check "it should record 16 kHz mono: $(grep pw-record "$calls")" grep -q -- '--rate 16000 --channels 1' "$calls"
check "the bar's file should name the recorder" test -s "$VIKIX_STATE/dictating"
check "the recording should be yours alone, is $(stat -c %a "$t/run/vikix-dictation.wav" 2>/dev/null)" \
  test "$(stat -c %a "$t/run/vikix-dictation.wav" 2>/dev/null)" = 600
sleep 0.8
press
check "it should type what was said, without sounds, a space after: [$(cat "$t/typed" 2>/dev/null)]" test "$(cat "$t/typed" 2>/dev/null)" = "Hello there. "
check "it should put it on the clipboard too" test "$(cat "$t/clipboard" 2>/dev/null)" = "Hello there. "
check "whisper should use voice detection: $(grep '^whisper' "$calls" | tail -1)" grep -q -- '--vad -vm .*ggml-silero' "$calls"
check "whisper should be told English: $(grep '^whisper' "$calls" | tail -1)" grep -q -- '-l en ' "$calls"
check "the recording should be gone" test ! -e "$t/run/vikix-dictation.wav"
check "the bar's file should be gone" test ! -e "$VIKIX_STATE/dictating"

# A press right after another (a held key's repeat, a double tap) is one press.
: > "$calls"; rm -f "$t/typed"
press; d toggle >/dev/null 2>&1
check "a second press within 0.7 s shouldn't stop it" test -s "$VIKIX_STATE/dictating"
sleep 0.8; d toggle >/dev/null 2>&1
check "the press after should type it" test "$(cat "$t/typed" 2>/dev/null)" = "Hello there. "

# The window changed while it was written down: only the clipboard.
rm -f "$t/typed" "$t/clipboard"; : > "$t/notes"
cat > "$t/bin/switcher" <<EOF
#!/bin/sh
echo 99 > "$t/window"; cat "$t/said"
EOF
chmod +x "$t/bin/switcher"
press; sleep 0.8
rm -f "$t/run/vikix-dictation.last"; VIKIX_WHISPER="$t/bin/switcher" d toggle >/dev/null 2>&1
check "moved to another window, it shouldn't type" test ! -e "$t/typed"
check "moved to another window, it should be on the clipboard: $(notes)" grep -q 'On the clipboard' <<<"$(notes)"
echo 42 > "$t/window"

# The 5-minute limit stopped it: the next press types it, not a new recording.
sleep 0.8
printf 'RIFF left' > "$t/run/vikix-dictation.wav"; chmod 600 "$t/run/vikix-dictation.wav"; rm -f "$VIKIX_STATE/dictating" "$t/typed"
press
check "a recording left by the limit should be typed by the next press" test "$(cat "$t/typed" 2>/dev/null)" = "Hello there. "
check "it shouldn't start a new recording instead" test ! -e "$VIKIX_STATE/dictating"

# A second dictation while the first is written down keeps its own file.
sleep 0.8
press; sleep 0.8
cat > "$t/bin/slow" <<EOF
#!/bin/sh
sleep 1.5; cat "$t/said"
EOF
chmod +x "$t/bin/slow"
rm -f "$t/run/vikix-dictation.last"; VIKIX_WHISPER="$t/bin/slow" d toggle >/dev/null 2>&1 &
sleep 0.9; press          # starts listening again, meanwhile
wait
check "a new recording during the writing down should still be there" test -e "$t/run/vikix-dictation.wav"
sleep 0.8; d cancel >/dev/null 2>&1

# Nothing heard: nothing typed.
rm -f "$t/typed"; echo '(silence)' > "$t/said"; : > "$t/notes"
press; sleep 0.8; press
check "nothing heard, it should say so: $(notes)" grep -q 'Heard nothing' <<<"$(notes)"
check "nothing heard, nothing should be typed" test ! -e "$t/typed"

# Cancel: nothing typed.
echo 'do not type me' > "$t/said"
press; sleep 0.8; d cancel >/dev/null 2>&1
check "cancel shouldn't type" test ! -e "$t/typed"
check "cancel should drop the recording" test ! -e "$t/run/vikix-dictation.wav"
check "cancel should stop the recorder" test ! -e "$VIKIX_STATE/dictating"

# A file that isn't speech: said, and a failure.
echo '' > "$t/said"; echo "not audio" > "$t/junk.wav"
out=$(d file "$t/junk.wav" 2>&1) && { echo "FAIL: file on no speech succeeded"; fail=1; }
check "file on no speech should say so: $out" grep -q 'no speech found' <<<"$out"

# The multilingual model.
: > "$calls"
d models small >/dev/null 2>&1
check "models small should download it" grep -q 'ggml-small.bin' "$calls"
check "models small should be the choice" grep -qx 'model=small' "$HOME/.config/vikix/dictation"
echo 'Bonjour.' > "$t/said"
press; sleep 0.8; press
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
