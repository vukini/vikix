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
# The downloads (the HTML docs and the Zeal docsets, a few GB, from sites
# that are sometimes very slow) happen only with VIKIX_DOCS=1, which is
# what `vikix docs` sets. The installer and `vikix update` run this stage
# without it: they make the folders and the page, and say what is missing.
#
# ~/dev is yours: nothing here is ever deleted or overwritten. Downloads
# already done are skipped, so `vikix docs` only adds what is new.
# VIKIX_DEV_DIR moves the folder.

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
# The next `vikix docs` tries again.
fetch() {
  # --continue-at -: a retry resumes the partial file instead of starting over.
  run curl -fL --retry 2 --continue-at - --connect-timeout 20 --speed-limit 10000 --speed-time 60 \
    -o "$2" "$1" && return 0
  warn "could not download $1"
  return 1
}

# want WHAT — true when downloads are on; otherwise count WHAT as missing,
# so the end of the stage can say that `vikix docs` would add it.
DOCS=${VIKIX_DOCS:-0}
missing=()
want() {
  [ "$DOCS" = 1 ] && return 0
  missing+=("$1")
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
have rustc                     && langs+=(rust)
have javac                     && langs+=(java)
have ocaml                     && langs+=(ocaml)
have julia                     && langs+=(julia)
have fpc                       && langs+=(pascal)
# shellcheck disable=SC2088  # messages: the ~ is for reading, not expanding
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
  elif want "the Python $pv docs"; then
    say "downloading the Python $pv docs"
    fetch "https://docs.python.org/$pv/archives/python-$pv-docs-html.zip" "$tmp/py.zip" &&
      run unzip -q "$tmp/py.zip" -d "$d"
  fi
fi

if has lisp; then
  d=$(docs_dir lisp)
  if [ -d "$d/HyperSpec" ]; then
    say "Common Lisp HyperSpec already there"
  elif want "the HyperSpec"; then
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
  elif want "the Lua manual"; then
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
  elif want "the Zig $zv reference"; then
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
  elif want "the SQLite docs"; then
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

if has rust; then
  docs_dir rust >/dev/null
  link_doc rust /usr/share/doc/rust/html rust        # the rust-doc package
  note rust '# Rust docs

- `rust/book/index.html` here — The Rust Programming Language (rust-doc)
- `rust/std/index.html` here — the standard library
- `cargo doc --open` — the docs of your project and everything it uses
- Zeal: the Rust docset'
fi

if has java; then
  docs_dir java >/dev/null
  note java '# Java docs

- `jshell` — try a line of Java at once
- `javap java.util.List` — what a class offers
- Zeal: the Java docset (the standard library)'
fi

if has ocaml; then
  docs_dir ocaml >/dev/null
  note ocaml '# OCaml docs

- `man ocaml`, `man ocamlfind`, `dune --help`
- https://ocaml.org/manual — the manual; https://ocaml.org/docs — tutorials
- `opam install utop ocaml-lsp-server` — a better REPL, and the language server for the editors'
fi

if has julia; then
  docs_dir julia >/dev/null
  note julia '# Julia docs

- in `julia`, type `?` then a name: the docs of anything loaded
- `juliaup update` — a newer Julia; `juliaup status` — the ones you have
- Zeal: the Julia docset'
fi

if has pascal; then
  docs_dir pascal >/dev/null
  note pascal '# Free Pascal and Lazarus docs

- `vikix-lazarus` — the Lazarus IDE; F1 on a word opens its help
- https://www.freepascal.org/docs.html — the language and library reference
- `man fpc` — the compiler'
fi

# --- Zeal docsets ------------------------------------------------------------
# Each docset's feed lists the same file on several mirrors. A mirror
# slower than 200 KB/s for 15 seconds is dropped for the next one.
declare -A docset=([c]=C [python]=Python [lisp]=Common_Lisp [racket]=Racket
                   [haskell]=Haskell [lua]=Lua [go]=Go [ruby]=Ruby [sql]=SQLite
                   [rust]=Rust [java]=Java [julia]=Julia)
run mkdir -p "$ZEAL"
for lang in "${langs[@]}" bash; do
  if [ "$lang" = bash ]; then name=Bash; else name=${docset[$lang]:-}; fi
  [ -n "$name" ] || continue
  if [ -d "$ZEAL/$name.docset" ]; then
    say "Zeal docset $name already there"
    continue
  fi
  want "the $name docset" || continue
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
# It looks like vikix.dev, with no fonts or scripts fetched from anywhere:
# the page is for reading offline. The site's fonts are used if installed,
# Iosevka and Noto otherwise. It opens in the desktop's current theme; the
# button switches it, and the browser remembers.

# doc_label PATH — a readable name for a doc, from its path under docs/.
doc_label() {
  local f
  case $1 in
    python-*-docs-html/index.html) f=${1#python-}; printf 'Python %s documentation' "${f%%-*}" ;;
    HyperSpec/Front/index.htm) printf 'Common Lisp HyperSpec' ;;
    racket/index.html)         printf 'Racket documentation' ;;
    ghc/index.html)            printf 'GHC User&rsquo;s Guide' ;;
    manual.html)               printf 'Lua reference manual' ;;
    langref-*.html)            f=${1#langref-}; printf 'Zig %s language reference' "${f%.html}" ;;
    sqlite-doc-*/index.html)   printf 'SQLite documentation' ;;
    rust/book/index.html)      printf 'The Rust Programming Language' ;;
    rust/std/index.html)       printf 'The Rust standard library' ;;
    *)                         printf '%s' "$1" ;;
  esac
}

page() {
  local l d f n theme mode=dark
  theme=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/vikix/theme/current" 2>/dev/null || echo void)
  [ "$theme" = paper ] && mode=light
  printf '<!doctype html>\n<html lang="en" data-theme="%s" data-vikix="%s">\n' "$mode" "$theme"
  cat <<'EOF'
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>~/dev — offline docs</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='12' fill='%231e1e2e'/%3E%3Ctext x='30' y='47' font-family='monospace' font-weight='800' font-size='44' text-anchor='middle' fill='%23cdd6f4'%3Ev%3C/text%3E%3Ccircle cx='50' cy='44' r='5' fill='%2389b4fa'/%3E%3C/svg%3E">
<style>
/* The two Vikix themes, as on vikix.dev: paper (light) and void (dark). */
:root {
  --bg: #eff1f5; --bg2: #e6e9ef; --bg3: #dce0e8;
  --fg: #4c4f69; --subtle: #636679; --dim: #9ca0b0; --line: #ccd0da;
  --accent: #1c5bd6; --green: #327a1f;
  --display: "Martian Mono", "IBM Plex Mono", "Iosevka", ui-monospace, monospace;
  --body: "Schibsted Grotesk", "Noto Sans", system-ui, sans-serif;
  --mono: "IBM Plex Mono", "Iosevka", ui-monospace, monospace;
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --bg: #1e1e2e; --bg2: #181825; --bg3: #11111b;
  --fg: #cdd6f4; --subtle: #a6adc8; --dim: #585b70; --line: #313244;
  --accent: #89b4fa; --green: #a6e3a1;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 400 16px/1.6 var(--body); -webkit-font-smoothing: antialiased; }
.wrap { max-width: 1180px; margin-inline: auto; padding-inline: 24px; }
@media (max-width: 600px) { .wrap { padding-inline: 16px; } }
a { color: var(--accent); text-underline-offset: 3px; }
a:hover { text-decoration-thickness: 2px; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; border-radius: 4px; }
code, kbd { font-family: var(--mono); }
code { font-size: .88em; background: var(--bg2); border: 1px solid var(--line); padding: .05em .35em; border-radius: 4px; }
kbd { font-size: .82em; padding: .1em .45em; border-radius: 5px; background: var(--bg2); border: 1px solid var(--line); border-bottom-width: 2px; white-space: nowrap; }
h1, h2 { font-family: var(--display); letter-spacing: -.02em; line-height: 1.12; margin: 0; }
p { margin: 0; }

/* the top bar, styled like the StumpWM mode line */
.top { position: sticky; top: 0; z-index: 2; background: color-mix(in srgb, var(--bg3) 88%, transparent); backdrop-filter: blur(10px); border-bottom: 1px solid var(--line); font: .86rem var(--mono); }
.top .wrap { display: flex; align-items: center; gap: 20px; height: 46px; }
.logo { font: 800 1rem var(--display); letter-spacing: -.03em; color: var(--fg); }
.logo span { color: var(--accent); }
.top nav { display: flex; gap: 14px; flex: 1; overflow-x: auto; scrollbar-width: none; }
.top nav a { color: var(--subtle); text-decoration: none; white-space: nowrap; }
.top nav a:hover { color: var(--fg); }
.theme-btn { font: inherit; color: var(--subtle); background: none; border: 1px solid var(--line); border-radius: 6px; padding: 4px 10px; cursor: pointer; white-space: nowrap; }
.theme-btn:hover { color: var(--fg); border-color: var(--dim); }
.theme-btn b { color: var(--accent); font-weight: 600; }
@media (max-width: 520px) { .theme-btn .tb-cmd { display: none; } .top .wrap { gap: 12px; } }

.hero { padding-block: 56px 36px; display: grid; gap: 18px; }
.eyebrow { font: 500 .78rem var(--mono); letter-spacing: .12em; text-transform: uppercase; color: var(--subtle); }
.eyebrow b { color: var(--accent); font-weight: 600; }
.hero h1 { font-size: clamp(1.9rem, 4.2vw, 3rem); font-weight: 800; letter-spacing: -.05em; }
.hero h1 em { font-style: normal; color: var(--accent); }
.lede { font-size: 1.1rem; color: var(--subtle); max-width: 62ch; }
.keys { display: flex; flex-wrap: wrap; gap: 8px 22px; font-size: .92rem; color: var(--subtle); }
.search { font: .95rem var(--mono); color: var(--fg); background: var(--bg2); border: 1px solid var(--line); border-radius: 8px; padding: 10px 14px; width: min(100%, 420px); }
.search::placeholder { color: var(--dim); }
.search:focus { outline: none; border-color: var(--accent); }

.langs { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 20px; padding-block: 8px 64px; }
@media (max-width: 400px) { .langs { grid-template-columns: 1fr; } }
.card { border: 1px solid var(--line); border-radius: 12px; padding: 22px 24px; display: grid; gap: 12px; align-content: start; background: var(--bg); scroll-margin-top: 62px; }
.card:target { border-color: var(--accent); }
.card header { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; }
.card h2 { font-size: 1.05rem; font-weight: 600; letter-spacing: -.01em; }
.card header span { font: .76rem var(--mono); color: var(--dim); }
.card ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; font-size: .94rem; color: var(--subtle); }
.card li { padding-left: 14px; position: relative; }
.card li::before { content: "›"; position: absolute; left: 0; color: var(--dim); }
.card li.doc::before { color: var(--green); }
.card li.doc a { font-weight: 500; }
.card .none { color: var(--dim); font-size: .92rem; }
.card[hidden] { display: none; }
.empty { display: none; color: var(--subtle); padding-bottom: 64px; }

footer { border-top: 1px solid var(--line); padding-block: 24px 40px; font: .8rem var(--mono); color: var(--dim); }
</style>
<header class="top">
  <div class="wrap">
    <span class="logo">vikix<span>.</span></span>
    <nav aria-label="Languages">
EOF
  for l in "${langs[@]}"; do printf '      <a href="#%s">%s</a>\n' "$l" "$l"; done
  cat <<'EOF'
    </nav>
    <button class="theme-btn" id="themeBtn" type="button" aria-label="Switch theme"><span class="tb-cmd">vikix theme </span><b id="themeName">void</b></button>
  </div>
</header>
<main class="wrap">
  <section class="hero">
    <p class="eyebrow"><b>~/dev</b> · offline docs</p>
    <h1>Every doc, <em>offline</em>.</h1>
    <p class="lede">Each language's own documentation, kept on this machine. Zeal searches every docset at once.</p>
    <div class="keys">
      <span><kbd>docs</kbd> opens this page</span>
      <span><kbd>jlab</kbd> starts JupyterLab here</span>
      <span><kbd>vikix docs</kbd> downloads what is missing</span>
    </div>
    <input class="search" id="q" type="search" placeholder="Filter: a language or a doc  ( / )" aria-label="Filter the docs" autocomplete="off">
  </section>
  <div class="langs" id="langs">
EOF
  for l in "${langs[@]}"; do
    d="$DEV/$l/docs"
    printf '  <article class="card" id="%s">\n    <header><h2>%s</h2><span>~/dev/%s</span></header>\n    <ul>\n' "$l" "$l" "$l"
    n=0
    for f in "$d"/python-*-docs-html/index.html "$d"/HyperSpec/Front/index.htm "$d"/racket/index.html \
             "$d"/ghc/index.html "$d"/manual.html "$d"/langref-*.html "$d"/sqlite-doc-*/index.html \
             "$d"/rust/book/index.html "$d"/rust/std/index.html; do
      [ -e "$f" ] || continue
      printf '      <li class="doc"><a href="file://%s">%s</a></li>\n' "$f" "$(doc_label "${f#"$d"/}")"
      n=$((n + 1))
    done
    # The README's list, as the page's: escaped first (it is yours to edit),
    # then `code` and bare links.
    if [ -f "$d/README.md" ]; then
      f=$(sed -n 's/^- \(.*\)$/\1/p' "$d/README.md" |
        sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
            -e 's/`\([^`]*\)`/<code>\1<\/code>/g' \
            -e 's#\(https\?://[^ <]*\)#<a href="\1">\1</a>#g' \
            -e 's/^/      <li>/; s/$/<\/li>/')
      [ -n "$f" ] && { printf '%s\n' "$f"; n=$((n + 1)); }
    fi
    printf '    </ul>\n'
    [ "$n" = 0 ] && printf '    <p class="none">No offline docs here yet.</p>\n'
    printf '  </article>\n'
  done
  cat <<'EOF'
  </div>
  <p class="empty" id="empty">No language or doc matches that.</p>
</main>
<footer><div class="wrap">Written by <code>vikix update</code> from what is in ~/dev; changes here are overwritten.</div></footer>
<script>
(function () {
  var root = document.documentElement, btn = document.getElementById("themeBtn"), name = document.getElementById("themeName");
  function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
  function paint() { name.textContent = root.getAttribute("data-theme") === "light" ? "paper" : "void"; }
  var saved = store("vikix-dev-theme");
  if (saved === "dark" || saved === "light") root.setAttribute("data-theme", saved);
  paint();
  btn.addEventListener("click", function () {
    var mode = root.getAttribute("data-theme") === "light" ? "dark" : "light";
    root.setAttribute("data-theme", mode); store("vikix-dev-theme", mode); paint();
  });

  var q = document.getElementById("q"), cards = document.querySelectorAll(".card"), empty = document.getElementById("empty");
  q.addEventListener("input", function () {
    var s = q.value.trim().toLowerCase(), shown = 0;
    cards.forEach(function (c) {
      var on = !s || c.textContent.toLowerCase().indexOf(s) >= 0;
      c.hidden = !on; if (on) shown++;
    });
    empty.style.display = shown ? "none" : "block";
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "/" && document.activeElement !== q) { e.preventDefault(); q.focus(); }
    if (e.key === "Escape" && document.activeElement === q) { q.value = ""; q.dispatchEvent(new Event("input")); q.blur(); }
  });
})();
</script>
EOF
}
if [ "$DRY_RUN" = 1 ]; then
  printf '   would write %s\n' "$DEV/index.html"
else
  page > "$DEV/index.html"
fi

# shellcheck disable=SC2088
say "~/dev ready: docs opens the docs page, jlab starts JupyterLab"
if [ "${#missing[@]}" -gt 0 ]; then
  say "${#missing[@]} offline docs not downloaded; vikix docs gets them (a few GB, can take an hour)"
fi
