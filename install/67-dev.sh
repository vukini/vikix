#!/usr/bin/env bash
# 67-dev — ~/dev: a folder per language, its offline docs, and Python with
# JupyterLab ready to use.
#
#   ~/dev/<language>/          your projects in that language
#   ~/dev/<language>/docs/     its documentation, offline
#   ~/dev/python/.venv/        Python for JupyterLab (jlab, or s-m → JupyterLab)
#   ~/dev/docsets              the Zeal docsets (a link into Zeal's folder)
#   ~/dev/index.html           every doc on one page (`docs` opens it)
#
# Only languages that are installed get a folder, so deleting a
# packages/lang-*.list file leaves that language out here too.
#
# The docs come in two forms:
#   - each language's own: HTML (Python, HyperSpec, Lua, Zig, SQLite),
#     the -doc packages (GHC, Racket, linked), or man/info/ri pages
#   - Zeal docsets, searchable in one app (Zeal), and readable from Emacs
#     too: ~/.docsets, dash-docs' default folder, links to the same place
#
# ~/dev is yours: nothing here is ever deleted or overwritten. Downloads
# already done are skipped, so `vikix update` (which runs this stage)
# only adds what is new. VIKIX_DEV_DIR moves the folder.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

DEV=${VIKIX_DEV_DIR:-$HOME/dev}
ZEAL="$HOME/.local/share/Zeal/Zeal/docsets"
have() { command -v "$1" >/dev/null 2>&1; }

# fetch URL FILE — download, retrying; a failure is a warning, not the end
# of the stage (one unreachable site shouldn't cost the other languages).
# A download crawling below 10 KB/s for a minute is given up too: from some
# places a site sends 5 KB/s, and a docs archive would then take an hour.
# The next `vikix update` tries again.
fetch() {
  # --continue-at -: a retry resumes the partial file instead of starting over.
  run curl -fL --retry 2 --continue-at - --connect-timeout 20 --speed-limit 10000 --speed-time 60 \
    -o "$2" "$1" && return 0
  warn "could not download $1"
  return 1
}

# docs_dir NAME — make ~/dev/NAME/docs and print its path.
docs_dir() {
  run mkdir -p "$DEV/$1/docs" >&2      # stdout is the path; keep dry-run lines off it
  printf '%s\n' "$DEV/$1/docs"
}

# note NAME TEXT — a README.md in NAME/docs for docs that live in a command
# (man, info, go doc) rather than in files. Written once; yours after that.
note() {
  local f="$DEV/$1/docs/README.md"
  [ -e "$f" ] && return 0
  if [ "$DRY_RUN" = 1 ]; then printf '   would write %s\n' "$f"; return 0; fi
  printf '%s\n' "$2" > "$f"
}

# link_doc NAME TARGET LINKNAME — docs a package installed, linked in.
link_doc() {
  local link="$DEV/$1/docs/$3"
  [ -e "$2" ] || return 0
  [ -e "$link" ] || [ -L "$link" ] || run ln -s "$2" "$link"
}

# The languages present, by the command each one brings.
langs=()
have cc                        && langs+=(c)
have python3                   && langs+=(python)
{ have sbcl || have ccl; }     && langs+=(lisp)
have racket                    && langs+=(racket)
have ghc                       && langs+=(haskell)
have lua5.4                    && langs+=(lua)
have go                        && langs+=(go)
have zig                       && langs+=(zig)
have gforth                    && langs+=(forth)
have ruby                      && langs+=(ruby)
have sqlite3                   && langs+=(sql)
have wat2wasm                  && langs+=(wasm)
say "~/dev for: ${langs[*]}"
has() { case " ${langs[*]} " in *" $1 "*) return 0 ;; esac; return 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- each language's own docs ---------------------------------------------

if has c; then
  docs_dir c >/dev/null
  note c '# C docs

- `man 3 printf` — the C library (man-pages-devel)
- `man 3p printf` — what POSIX says (man-pages-posix)
- `man gcc`, `man clang`
- Zeal: the C docset'
fi

if has python; then
  d=$(docs_dir python)
  pv=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
  if [ -d "$d/python-$pv-docs-html" ]; then
    say "Python $pv docs already there"
  else
    say "downloading the Python $pv docs"
    fetch "https://docs.python.org/$pv/archives/python-$pv-docs-html.zip" "$tmp/py.zip" &&
      run unzip -q "$tmp/py.zip" -d "$d"
  fi
fi

if has lisp; then
  d=$(docs_dir lisp)
  if [ -d "$d/HyperSpec" ]; then
    say "Common Lisp HyperSpec already there"
  else
    say "downloading the Common Lisp HyperSpec (LispWorks)"
    fetch http://ftp.lispworks.com/pub/software_tools/reference/HyperSpec-7-0.tar.gz "$tmp/clhs.tgz" &&
      run tar -xzf "$tmp/clhs.tgz" -C "$d"            # unpacks to HyperSpec/
  fi
fi

has racket  && docs_dir racket  >/dev/null && link_doc racket /usr/share/doc/racket racket
if has haskell; then
  docs_dir haskell >/dev/null
  for g in /usr/share/doc/ghc-*/html; do link_doc haskell "$g" ghc; done
fi

if has lua; then
  d=$(docs_dir lua)
  if [ -f "$d/manual.html" ]; then
    say "Lua 5.4 manual already there"
  else
    say "downloading the Lua 5.4 reference manual"
    for f in manual.html contents.html manual.css lua.css; do
      fetch "https://www.lua.org/manual/5.4/$f" "$d/$f" || break
    done
  fi
fi

if has go; then
  docs_dir go >/dev/null
  note go '# Go docs

- `go doc fmt.Println` — any package, type or function
- `go help` — the go command itself
- Zeal: the Go docset'
fi

if has zig; then
  d=$(docs_dir zig)
  zv=$(zig version)
  if [ -f "$d/langref-$zv.html" ]; then
    say "Zig $zv language reference already there"
  else
    say "downloading the Zig $zv language reference"
    fetch "https://ziglang.org/documentation/$zv/" "$d/langref-$zv.html" || true
  fi
  note zig '# Zig docs

- `langref-*.html` here — the language reference
- `zig std` — the standard library docs, served locally in the browser'
fi

if has forth; then
  docs_dir forth >/dev/null
  note forth '# Forth docs

- `info gforth` — the Gforth manual (or in Emacs: C-h i, then Gforth)'
fi

if has ruby; then
  docs_dir ruby >/dev/null
  note ruby '# Ruby docs

- `ri String#split` — the core and standard library (ruby-ri)
- Zeal: the Ruby docset'
fi

if has sql; then
  d=$(docs_dir sql)
  if compgen -G "$d/sqlite-doc-*" >/dev/null; then
    say "SQLite docs already there"
  else
    # The download page names the current archive, dated folder and all.
    rel=$(curl -fsL https://www.sqlite.org/download.html | grep -o '[0-9]*/sqlite-doc-[0-9]*\.zip' | head -1 || true)
    if [ -n "$rel" ]; then
      say "downloading the SQLite docs ($(basename "$rel"))"
      fetch "https://www.sqlite.org/$rel" "$tmp/sqlite.zip" && run unzip -q "$tmp/sqlite.zip" -d "$d"
    else
      warn "could not find the SQLite docs on sqlite.org/download.html"
    fi
  fi
fi

has wasm && docs_dir wasm >/dev/null

# --- Zeal docsets ------------------------------------------------------------
# Each docset's feed lists the same file on several mirrors. A mirror
# slower than 200 KB/s for 15 seconds is dropped for the next one.
declare -A docset=([c]=C [python]=Python [lisp]=Common_Lisp [racket]=Racket
                   [haskell]=Haskell [lua]=Lua [go]=Go [ruby]=Ruby [sql]=SQLite)
run mkdir -p "$ZEAL"
for lang in "${langs[@]}" bash; do
  if [ "$lang" = bash ]; then name=Bash; else name=${docset[$lang]:-}; fi
  [ -n "$name" ] || continue
  if [ -d "$ZEAL/$name.docset" ]; then
    say "Zeal docset $name already there"
    continue
  fi
  mapfile -t urls < <(curl -fsL "https://kapeli.com/feeds/$name.xml" | grep -o '<url>[^<]*' | sed 's/<url>//' || true)
  if [ "${#urls[@]}" -eq 0 ]; then warn "no feed for the $name docset"; continue; fi
  say "downloading the $name docset"
  got=0
  for u in "${urls[@]}"; do
    if run curl -fL --connect-timeout 20 --speed-limit 200000 --speed-time 15 -o "$tmp/$name.tgz" "$u"; then
      got=1; break
    fi
  done
  if [ "$got" = 0 ]; then warn "could not download the $name docset from any mirror"; continue; fi
  run tar -xzf "$tmp/$name.tgz" -C "$ZEAL"
  run rm -f "$tmp/$name.tgz"
done
[ -e "$DEV/docsets" ] || [ -L "$DEV/docsets" ] || run ln -s "$ZEAL" "$DEV/docsets"
# Emacs' dash-docs (and counsel-dash, consult-dash) read ~/.docsets.
[ -e "$HOME/.docsets" ] || [ -L "$HOME/.docsets" ] || run ln -s "$ZEAL" "$HOME/.docsets"

# --- Python for JupyterLab ---------------------------------------------------
# A uv environment of its own: Void's Python won't take pip installs, and
# this one is yours to add to (uv pip install --python ~/dev/python/.venv X).
PY_LIBS=(jupyterlab ipykernel numpy pandas matplotlib scipy sympy)
venv="$DEV/python/.venv"
if has python; then
  if ! have uv; then
    warn "uv is not installed (packages/lang-python.list); skipping the Python environment"
  else
    # A Void update to a new Python leaves the old environment unusable.
    if [ -e "$venv" ] && ! "$venv/bin/python" -c '' 2>/dev/null; then
      say "the Python environment was made for an older Python; making it again"
      run rm -rf "$venv"
    fi
    [ -e "$venv" ] || run uv venv --python /usr/bin/python3 "$venv"
    say "Python libraries for JupyterLab: ${PY_LIBS[*]}"
    run uv pip install --quiet --python "$venv/bin/python" "${PY_LIBS[@]}"
  fi
fi

# --- ~/dev/index.html ----------------------------------------------------------
# Regenerated each time, from what is on disk now. Vikix's file, not yours.
page() {
  local l d f
  cat <<'EOF'
<!doctype html><meta charset="utf-8"><title>~/dev — offline docs</title>
<style>body{font:15px/1.5 sans-serif;max-width:46em;margin:2em auto;padding:0 1em}
h2{margin-bottom:.2em}code{background:#eee;padding:0 .3em}li{margin:.15em 0}</style>
<h1>Offline docs</h1>
<p>Zeal searches every docset at once. In a shell: <code>docs</code> opens this page,
<code>jlab</code> starts JupyterLab here.</p>
EOF
  for l in "${langs[@]}"; do
    d="$DEV/$l/docs"
    printf '<h2>%s</h2><ul>\n' "$l"
    for f in "$d"/python-*-docs-html/index.html "$d"/HyperSpec/Front/index.htm "$d"/racket/index.html \
             "$d"/ghc/index.html "$d"/manual.html "$d"/langref-*.html "$d"/sqlite-doc-*/index.html; do
      [ -e "$f" ] && printf '<li><a href="file://%s">%s</a></li>\n' "$f" "${f#"$d"/}"
    done
    [ -f "$d/README.md" ] && sed -n 's/^- \(.*\)$/<li>\1<\/li>/p' "$d/README.md" | sed 's/`\([^`]*\)`/<code>\1<\/code>/g'
    printf '</ul>\n'
  done
}
if [ "$DRY_RUN" = 1 ]; then
  printf '   would write %s\n' "$DEV/index.html"
else
  page > "$DEV/index.html"
fi

say "~/dev ready: docs opens the docs page, jlab starts JupyterLab"
