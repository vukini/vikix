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
#   Lazarus    Void packages it (lang-pascal.list); this builds the docked
#              IDE from it, in ~/.lazarus: menu, editor, object inspector
#              and form designer in one window, which StumpWM tiles (the
#              rules are in windows.lisp). Rebuilt when Void's Lazarus is
#              newer than the build. vikix-lazarus starts it.
#   Julia      Void packages juliaup (lang-julia.list), which downloads
#              Julia itself; this gets the current release now, not at the
#              first `julia`.
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

# --- Lazarus, docked ----------------------------------------------------------
LAZ=/usr/lib/lazarus
IDE="$HOME/.lazarus/bin/lazarus"
if ! command -v lazbuild >/dev/null || [ ! -d "$LAZ/lcl" ]; then
  say "no Lazarus (packages/lang-pascal.list); skipping its docked IDE"
elif [ -x "$IDE" ] && [ "$IDE" -nt "$LAZ/lazarus" ] && [ "${VIKIX_REBUILD_LANGS:-0}" != 1 ]; then
  say "Lazarus: the docked IDE is already built in ~/.lazarus"
else
  # The widget set Void built the LCL for (Qt5 now; GTK2 in older builds).
  ws=
  for w in qt5 gtk2 qt6 gtk3; do
    compgen -G "$LAZ/lcl/units/*-linux/$w" >/dev/null && { ws=$w; break; }
  done
  log="$VIKIX_STATE/logs/lazarus-build.log"
  say "building the docked Lazarus IDE ($ws) into ~/.lazarus (a minute or two; log: $log)"
  # /usr/lib/lazarus isn't writable, so lazbuild puts the IDE and the
  # packages it compiles under ~/.lazarus instead.
  cmd=(lazbuild --lazarusdir="$LAZ/" ${ws:+--ws=$ws}
       --add-package "$LAZ/components/anchordocking/design/anchordockingdsgn.lpk"
                     "$LAZ/components/dockedformeditor/dockedformeditor.lpk"
       --build-ide=)
  if [ "$DRY_RUN" = 1 ]; then
    printf '   would run: %s > %s\n' "${cmd[*]}" "$log"
  else
    mkdir -p "$(dirname "$log")"
    if "${cmd[@]}" > "$log" 2>&1 && [ -x "$IDE" ]; then
      touch "$IDE"          # newer than Void's, so the next run skips this
    else
      warn "the docked Lazarus IDE didn't build; see $log. vikix-lazarus starts the plain one."
    fi
  fi
fi

# lazbuild's config names the Lazarus folder and the compiler but no
# version, so the IDE would open by offering to "upgrade" it. Add the
# version and the rest the IDE's first-start checks look at. Only what is
# missing: the IDE rewrites this file, and your settings stay.
env_opts="$HOME/.lazarus/environmentoptions.xml"
if [ -f "$env_opts" ] && [ "$DRY_RUN" != 1 ]; then
  add_opt() {   # add_opt NAME XML — the element, unless the file has one
    grep -q "<$1[ >]" "$env_opts" ||
      sed -i "s|^  <EnvironmentOptions>\$|  <EnvironmentOptions>\n    $2|" "$env_opts"
  }
  add_opt Version "<Version Value=\"110\" Lazarus=\"$(lazbuild --version 2>/dev/null | head -n 1)\"/>"
  [ -d /usr/lib/fpc/src ] && add_opt FPCSourceDirectory '<FPCSourceDirectory Value="/usr/lib/fpc/src/"/>'
  add_opt MakeFilename '<MakeFilename Value="/usr/bin/make"/>'
  add_opt DebuggerFilename '<DebuggerFilename Value="/usr/bin/gdb"/>'
fi

# --- Julia -----------------------------------------------------------------------
if ! command -v juliaup >/dev/null; then
  say "no juliaup (packages/lang-julia.list); skipping Julia"
elif juliaup status 2>/dev/null | grep -qw release; then
  say "Julia: the release channel is already installed (juliaup update brings new ones)"
else
  say "downloading the current Julia release (juliaup add release)"
  run juliaup add release || warn "juliaup couldn't download Julia; the first \`julia\` will try again"
fi

say "languages ready; try: pil +   (PicoLisp)   racket   gforth   ghci   tcc -run x.c   julia   vikix-lazarus"
