# learn/c/lib.sh — what the C course's checks share. Each lesson's
# check.sh sources it and runs in your copy of the lesson (~/learn/c/NN-*),
# so the file it checks is yours, and the checks are Vikix's: a fix to a
# check reaches you with vikix update.
#
# A check is a list of steps; the first that fails is the only thing
# shown, with what to do about it, and check.sh stops there.

CFLAGS_LEARN="-std=c17 -Wall -Wextra -pedantic -g"
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer"
# The sanitizers need gcc's libsanitizer (libsanitizer-devel, in the base
# since 0.71.18): without it, the checks run without them and say so once.
_san_ok() {
  [ -n "${_LEARN_SAN+x}" ] && { [ "$_LEARN_SAN" = 1 ]; return; }
  if printf 'int main(void){return 0;}\n' | cc $SAN -x c -o /dev/null - 2>/dev/null; then _LEARN_SAN=1
  else _LEARN_SAN=0; echo "(the sanitizers aren't installed: vikix update brings libsanitizer-devel; checking without them)"; fi
  [ "$_LEARN_SAN" = 1 ]
}

step=0
_san_ok || true   # says so, once a check, when they're missing
# pass MESSAGE — a step went well.
pass() { step=$((step + 1)); printf '  ok %s\n' "$1"; }
# fail MESSAGE [DETAIL...] — the first step that failed: say it, and stop.
fail() {
  step=$((step + 1))
  printf '  NOT YET, step %s: %s\n' "$step" "$1"
  shift
  [ "$#" -gt 0 ] && printf '%s\n' "$@" | sed 's/^/    /'
  exit 1
}

# build SRC OUT [MORE FLAGS] — compile with every warning as an error, so
# a warning is something to fix, as it would be in real work.
build() {
  local src=$1 out=$2; shift 2
  local flags="$CFLAGS_LEARN -Werror"
  _san_ok >/dev/null && flags="$flags $SAN"
  # shellcheck disable=SC2086  # the flags are words
  cc $flags "$@" -o "$out" "$src" 2>&1
}

# runs OUT — run it; the sanitizers' reports count as failing.
runs() {
  ASAN_OPTIONS=detect_leaks=1:abort_on_error=0 UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 "$@" 2>&1
}

# brief REPORT — a sanitizer's report, cut to what you need: what went
# wrong, the kind of access, and where in your file. The summary,
# the shadow-byte map and the C library's frames are left out.
brief() {
  printf '%s\n' "$1" |
    grep -E 'ERROR: |runtime error|^(READ|WRITE) of|#[0-9]+ .*exercise\.c:[0-9]+' |
    sed -E -e 's/^ *#[0-9]+ 0x[0-9a-f]+ in ([^ ]+) .*\/([^/]+:[0-9]+).*/  in \1, \2/' \
           -e 's/^=+[0-9]+=+ERROR: //' -e 's/ on address 0x[0-9a-f]+ at pc .*//' \
           -e 's/ at 0x[0-9a-f]+ thread T0//' -e 's/^[^:]*exercise\.c:([0-9]+):[0-9]+: runtime error/exercise.c:\1: runtime error/' |
    head -n 8
}
