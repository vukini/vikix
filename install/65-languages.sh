#!/usr/bin/env bash
# 65-languages — the languages Void does not package, built from source.
#
# The packaged languages are plain lines in packages/lang-*.list, one file
# per language, installed by 10-packages. This stage is for the rest:
#
#   PicoLisp   the current release, software-lab.de/pil21.tgz, built with
#              clang into ~/.local/opt/picolisp, `pil` linked into ~/.local/bin.
#              (Not the git server, git.software-lab.de: it is often
#              unreachable. The tarball is the official release channel.)
#
# Not automated (see README, "Languages"): Cuis Smalltalk (a VM download
# that changes shape between releases) and Odin (prebuilt binaries).
# Everything here is skipped when already present; VIKIX_REBUILD_LANGS=1
# rebuilds.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

OPT="$HOME/.local/opt"
BIN="$HOME/.local/bin"
run mkdir -p "$OPT" "$BIN"

# --- PicoLisp ---------------------------------------------------------------
pil_dir="$OPT/picolisp"
if [ -x "$pil_dir/bin/picolisp" ] && [ "${VIKIX_REBUILD_LANGS:-0}" != 1 ]; then
  say "PicoLisp already built in $pil_dir"
elif missing=$(for t in clang llvm-config opt llc llvm-link pkg-config; do
                  command -v "$t" >/dev/null || printf '%s ' "$t"; done) &&
     [ -n "$missing" ] && [ "$DRY_RUN" != 1 ]; then
  warn "PicoLisp can't be built yet: missing $missing"
  warn "they come from packages/lang-lisp.list and lang-c.list; run: ./install.sh --only 10-packages, then this stage again"
else
  say "downloading PicoLisp (software-lab.de/pil21.tgz)"
  tmp=$(mktemp -d)
  run curl -fL --retry 3 -o "$tmp/pil21.tgz" https://software-lab.de/pil21.tgz
  run tar -xzf "$tmp/pil21.tgz" -C "$tmp"          # unpacks to $tmp/pil21
  # A rebuild replaces the old tree (including an old git checkout).
  [ -e "$pil_dir" ] && run rm -rf "$pil_dir"
  run mv "$tmp/pil21" "$pil_dir"
  rm -rf "$tmp"
  say "building PicoLisp (about a minute)"
  run make -C "$pil_dir/src"
fi

# ~/.local/bin/pil: a two-line script, not a symlink. PicoLisp's own `pil`
# finds its files next to itself (${0%/*}), so a symlink to it would look
# for them in ~/.local/bin instead.
if [ -x "$pil_dir/bin/picolisp" ] || [ "$DRY_RUN" = 1 ]; then
  if [ -L "$BIN/pil" ] || [ ! -e "$BIN/pil" ]; then
    say "adding the pil command to $BIN"
    run rm -f "$BIN/pil"
    [ "$DRY_RUN" = 1 ] || printf '#!/bin/sh\nexec "%s/pil" "$@"\n' "$pil_dir" > "$BIN/pil"
    run chmod +x "$BIN/pil"
  fi
fi

say "languages ready; try: pil +   (PicoLisp)   racket   gforth   ghci   tcc -run x.c"
