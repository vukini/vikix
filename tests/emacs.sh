#!/usr/bin/env bash
# tests/emacs.sh — Emacs's AI setup (config/emacs/vikix-ai.el) and Python as an
# IDE (config/emacs/vikix-python.el), without the network.
#
#   45-editors links Vikix's part for Emacs (and not for Neovim alone), and
#   in a running Emacs reloads it when it changed, or says to restart when
#   that Emacs has none;
#   vikix-ai.el loads clean in a bare Emacs; and, when gptel is here, gptel's
#   default follows ~/.config/vikix/ai (local: llama3.2:3b or your first
#   model, or model=; claude: claude-sonnet-5, or model=), a change reaches a
#   running Emacs but a pick of yours stays until then, and C-c g says what's
#   missing (the key, Ollama, a model) instead of asking for a key; and,
#   when agent-shell is here, its agents are Vikix's four, each started by
#   vikix agent --acp, its transcripts are kept out of the project, and C-c a
#   says what's missing as the terminal does (vikix, the agent, then its
#   adapter; Aider to C-c A), with your agent from ~/.config/vikix/agent;
#   vikix-notes.el's C-c n: the agenda over the notes and their journal
#   (your own org-agenda-files kept), C-c n c into the inbox plugin's file,
#   and no notes folder said plainly;
#   vikix-python.el: a .py file gets the project's .venv (else the shared
#   one) for the language server, the REPL, pytest and ruff, the keys under
#   C-c p (the function, file or project under pytest in the project, the
#   run, ruff format now and on save, the venv made with uv), ruff's
#   findings beside eglot's, and what isn't installed said plainly.
#
# curl is a stand-in answering as Ollama would ($HOME/ollama: the JSON, or
# absent for "not running"). gptel and agent-shell come from the package
# folder VIKIX_TEST_ELPA, or emacs-void's in ~/.emacs.d, each part skipped
# without them; the real config with its packages is tests/editors.sh's
# (--all, network).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME VIKIX_EMACS_REPO VIKIX_STATE ANTHROPIC_API_KEY
here=$(cd "$(dirname "$0")/.." && pwd)
elpa=${VIKIX_TEST_ELPA:-$HOME/.emacs.d/elpa}
pkg() { find "$elpa" -maxdepth 1 -type d -name "$1-[0-9]*" 2>/dev/null | sort | tail -1; }
gptel=$(pkg gptel)
ashell=''
if [ -n "$(pkg agent-shell)" ] && [ -n "$(pkg acp)" ] && [ -n "$(pkg shell-maker)" ]; then
  ashell="$(pkg agent-shell) $(pkg acp) $(pkg shell-maker)"
fi
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }

if ! command -v emacs >/dev/null; then
  echo "(emacs needs Emacs; skipped here)"
  exit 0
fi

mkdir -p "$t/bin"
for c in typescript-language-server pyright-langserver bash-language-server; do printf '#!/bin/sh\n' > "$t/bin/$c"; done
cat > "$t/bin/curl" <<'EOF'
#!/bin/sh
[ -f "$HOME/ollama" ] || exit 7
cat "$HOME/ollama"
EOF
chmod +x "$t/bin/"*
export PATH="$t/bin:$PATH"
export GIT_CONFIG_GLOBAL="$t/gitconfig" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# --- 45-editors: the link ---------------------------------------------------
git init -q "$t/emacs-void"
git -C "$t/emacs-void" commit -q --allow-empty -m init
export VIKIX_EMACS_REPO="$t/emacs-void"
export HOME="$t/emacs-home"
mkdir -p "$HOME/.config/vikix"
echo emacs > "$HOME/.config/vikix/features"
out=$(bash "$here/install/45-editors.sh" 2>&1)
check "Vikix's part for Emacs should be a link into the checkout: $out" \
  test "$(readlink "$HOME/.local/share/vikix/emacs")" = "$here/config/emacs"
check "the config should be cloned" test -d "$HOME/.emacs.d/.git"
export HOME="$t/nvim-home"
mkdir -p "$HOME/.config/vikix"
echo neovim > "$HOME/.config/vikix/features"
bash "$here/install/45-editors.sh" >/dev/null 2>&1 || true
check "Neovim alone shouldn't bring Emacs's part" test ! -e "$HOME/.local/share/vikix/emacs"

# --- 45-editors and a running Emacs (a private one, on its own socket) ------
export HOME="$t/emacs-home"
sock="$t/emacs-sock"
if emacs -Q --daemon="$sock" >/dev/null 2>&1; then
  trap 'emacsclient -s "$sock" -e "(kill-emacs)" >/dev/null 2>&1 || true; rm -rf "$t"' EXIT
  live() { EMACS_SOCKET_NAME=$sock emacsclient -e "$1" 2>/dev/null; }
  out=$(EMACS_SOCKET_NAME=$sock bash "$here/install/45-editors.sh" 2>&1)
  check "an Emacs without the AI setup should be told to restart: $out" has "Emacs is running without Vikix's AI setup.*emacs-restart" "$out"
  live "(progn (load \"$HOME/.local/share/vikix/emacs/vikix-ai\" nil t) (setq vikix-ai--sum \"a-checksum-of-before\"))" >/dev/null
  out=$(EMACS_SOCKET_NAME=$sock bash "$here/install/45-editors.sh" 2>&1)
  check "an Emacs with an older AI setup should get the new one at once: $out" has "the new AI setup is in use" "$out"
  check "and then have it: $(live vikix-ai--sum)" test "$(live vikix-ai--sum)" = "\"$(sha256sum < "$here/config/emacs/vikix-ai.el" | cut -d' ' -f1)\""
  out=$(EMACS_SOCKET_NAME=$sock bash "$here/install/45-editors.sh" 2>&1)
  check "an Emacs with the current one should be left alone, quietly: $out" test -z "$(grep -i 'emacs.*ai setup' <<<"$out" || true)"
  printf '#+begin_src emacs-lisp\n  (load (expand-file-name "~/.local/share/vikix/emacs/vikix-python") t t)\n#+end_src\n' > "$HOME/.emacs.d/config.org"
  out=$(EMACS_SOCKET_NAME=$sock bash "$here/install/45-editors.sh" 2>&1)
  check "an Emacs whose config loads the Python setup should get it without a restart: $out $(live "(featurep 'vikix-python)")" test "$(live "(featurep 'vikix-python)")" = t
  emacsclient -s "$sock" -e "(kill-emacs)" >/dev/null 2>&1 || true
  trap 'rm -rf "$t"' EXIT
else
  echo "(no Emacs daemon could start here; the running Emacs part skipped)"
fi

# --- vikix-ai.el ------------------------------------------------------------
export HOME="$t/home"
mkdir -p "$HOME/.config/vikix/secrets"
out=$(emacs -Q --batch -l "$here/config/emacs/vikix-ai.el" 2>&1)
check "vikix-ai.el should load clean without gptel: $out" test -z "$out"

if [ -z "$gptel" ]; then
  echo "(gptel isn't here: set VIKIX_TEST_ELPA to a package folder with it; the chat skipped)"
else

ai() { printf '%b' "$1" > "$HOME/.config/vikix/ai"; }
models() { printf '{"models":[%s]}' "$1" > "$HOME/ollama"; }
# el FORMS — run in an Emacs with gptel and vikix-ai.el; prints what they message.
el() {
  emacs -Q --batch -L "$gptel" -l "$here/config/emacs/vikix-ai.el" \
    --eval "(progn (defun say (&rest a) (princ (concat (apply #'format a) \"\\n\"))) $1)" 2>&1 || true
}
# The default C-c g would start on, or what it says instead.
chat='(condition-case e (progn (vikix-ai--check (vikix-ai-sync)) (say "%s on %s" gptel-model (gptel-backend-name gptel-backend))) (user-error (say "stopped: %s" (cadr e))))'

ai 'use=local\nmodel=\n'; models '{"name":"qwen3:4b"},{"name":"llama3.2:3b"}'
out=$(el "$chat")
check "local should be llama3.2:3b when you have it: $out" has '^llama3.2:3b on Local' "$out"
models '{"name":"qwen3:4b"},{"name":"gemma3:1b"}'
out=$(el "$chat")
check "else your first local model: $out" has '^qwen3:4b on Local' "$out"
ai 'use=local\nmodel=gemma3:1b  # mine\n'
out=$(el "$chat")
check "model= should win (its comment dropped): $out" has '^gemma3:1b on Local' "$out"
ai 'use=local\nmodel=llama3.1:8b\n'
out=$(el "$chat")
check "a model you don't have should be said: $out" has "stopped: You don’t have the model llama3.1:8b" "$out"
models ''
ai 'use=local\n'
out=$(el "$chat")
check "no local model should be said: $out" has 'stopped: No local model yet' "$out"
rm "$HOME/ollama"
out=$(el "$chat")
check "Ollama not running should be said: $out" has "stopped: Local AI isn’t running: in a terminal, vikix ai setup" "$out"

ai 'use=claude\n'
out=$(el "$chat")
check "Claude with no key should say how to set one: $out" has 'stopped: Claude needs your Anthropic key: in a terminal, vikix ai key set anthropic' "$out"
echo 'sk-test' > "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
out=$(el "$chat (say \"key %s\" (gptel--get-api-key))")
check "a key set since login should be used: $out" has '^key sk-test' "$out"
check "Claude should be claude-sonnet-5, as Super+i's: $out" has '^claude-sonnet-5 on Claude' "$out"
rm "$HOME/.config/vikix/secrets/ANTHROPIC_API_KEY"
out=$(ANTHROPIC_API_KEY=sk-env el "$chat (say \"key %s\" (gptel--get-api-key))")
check "the session's key should do: $out" has '^key sk-env' "$out"
ai 'use=claude\nmodel=claude-opus-5\n'
out=$(ANTHROPIC_API_KEY=sk-env el "$chat (say \"first %s, images %S\" (car (gptel-backend-models vikix-ai-claude)) (get (quote claude-opus-5) :capabilities))")
check "Claude's model= should be first in the menu, with what gptel knows of Sonnet: $out" has '^first claude-opus-5, images (media' "$out"
check "and be the default: $out" has '^claude-opus-5 on Claude' "$out"

# The cloud: a backend at the address in the file, the key by name.
ai 'use=cloud\n'
out=$(el "$chat")
check "the cloud with no key should say how to set one: $out" has 'stopped: The cloud service needs its key: in a terminal, vikix ai key set openrouter' "$out"
echo 'sk-or' > "$HOME/.config/vikix/secrets/OPENROUTER_API_KEY"
out=$(el "$chat (say \"key %s host %s\" (gptel--get-api-key) (gptel-backend-host gptel-backend))")
check "the cloud should be OpenRouter's gpt-4o-mini unless said: $out" has '^openai/gpt-4o-mini on Cloud' "$out"
check "with the key set since login, at openrouter.ai: $out" has '^key sk-or host openrouter.ai' "$out"
rm "$HOME/.config/vikix/secrets/OPENROUTER_API_KEY"
ai 'use=cloud\nmodel=gpt-oss:120b\ncloud_url=https://api.groq.com/openai/v1\ncloud_key=groq\ncloud_model=llama-3.3-70b\n'
out=$(GROQ_API_KEY=gsk-env el "$chat (say \"key %s host %s\" (gptel--get-api-key) (gptel-backend-host gptel-backend))")
check "another service, its key by name and cloud_model= (not model=, the local one's): $out" has '^llama-3.3-70b on Cloud' "$out"
check "at its address: $out" has '^key gsk-env host api.groq.com' "$out"
ai 'use=claude\nmodel=claude-opus-5\n'

# In one Emacs: a pick of yours stays, until the file changes.
models '{"name":"llama3.2:3b"}'
out=$(ANTHROPIC_API_KEY=sk-env el "(progn $chat
  (setq-default gptel-backend vikix-ai-local gptel-model 'llama3.2:3b)
  (vikix-ai-sync) (say \"kept %s\" gptel-model)
  (with-temp-file (expand-file-name \"ai\" vikix-ai-config) (insert \"use=local\n\"))
  $chat)")
check "a model you picked should stay while the file is the same: $out" has '^kept llama3.2:3b' "$out"
check "and a change to the file should reach a running Emacs: $out" has '^llama3.2:3b on Local' "$out"

# gptel's own C-c g: stopped before it asks for a buffer or a key.
ai 'use=claude\n'
out=$(el '(condition-case e (progn (require (quote gptel)) (call-interactively (quote gptel))) (user-error (say "stopped: %s" (cadr e))))' </dev/null)
check "gptel itself should stop with Vikix's words, not ask for a key: $out" has 'stopped: Claude needs your Anthropic key' "$out"

# The menu: Claude and Local first; the config's backends without a key
# out of it (emacs-void's OpenAI, gptel's own ChatGPT) until there is one.
ai 'use=local\n'; models '{"name":"llama3.2:3b"}'
menu='(progn (require (quote gptel)) (require (quote gptel-openai))
  (gptel-make-openai "OpenAI" :key (lambda () (getenv "OPENAI_API_KEY")) :models (quote (gpt-4o)))
  (gptel-make-openai "Mine" :key (lambda () "sk-mine") :models (quote (m1)))
  (vikix-ai-sync)
  (say "menu %S" (mapcar (function car) gptel--known-backends))
  (say "retired %S" (seq-filter (lambda (m) (string-prefix-p "claude-3" (symbol-name (if (consp m) (car m) m)))) (gptel-backend-models vikix-ai-claude))))'
out=$(env -u OPENAI_API_KEY bash -c "$(declare -f el); here='$here' gptel='$gptel' el '$menu'")
check "the menu should start with Claude and Local, and leave out what has no key: $out" has '^menu ("Claude" "Local" "Mine")' "$out"
check "Claude's retired models shouldn't be offered: $out" has '^retired nil' "$out"
out=$(OPENAI_API_KEY=sk-x bash -c "$(declare -f el); here='$here' gptel='$gptel' el '$menu'")
# gptel's own "ChatGPT" backend went in October 2026; either listing is right.
check "with its key, a backend should be back in the menu: $out" has '^menu ("Claude" "Local" "Mine" "OpenAI"\( "ChatGPT"\)\{0,1\})' "$out"

# A check that fails leaves the default as it was.
out=$(el "(progn (vikix-ai-sync) (say \"before %s\" gptel-model)
  (with-temp-file (expand-file-name \"ai\" vikix-ai-config) (insert \"use=local\nmodel=llama3.1:8b\n\"))
  (condition-case e (funcall (eval (cadr (interactive-form (quote vikix-ai--before-chat))) t) nil) (user-error (say \"stopped: %s\" (cadr e))))
  (say \"after %s\" (default-value (quote gptel-model))))")
check "a missing model should be said: $out" has "stopped: You don’t have the model llama3.1:8b" "$out"
check "and gptel's default stay as it was: $out" has '^after llama3.2:3b' "$out"

# The native compiler's warnings about agent-shell and gptel: quiet, unless you chose.
out=$(emacs -Q --batch -l "$here/config/emacs/vikix-ai.el" --eval "(progn (require (quote comp-run) nil t) (require (quote comp) nil t) (princ (format \"native %S\" native-comp-async-report-warnings-errors)))" 2>&1 || true)
check "the native compiler's warnings should be quiet: $out" has 'native silent' "$out"

fi

# --- agents -----------------------------------------------------------------
if [ -z "$ashell" ]; then
  echo "(agent-shell isn't here: set VIKIX_TEST_ELPA to a package folder with it; the agents skipped)"
else
  # vikix and the adapters are stand-ins: only whether they're there
  # counts. The PATH has only them (and the system's), not your agents.
  mkdir -p "$t/agents" "$HOME/.local/bin"
  cat > "$t/agents/vikix" <<'EOF2'
#!/bin/sh
[ "$*" = "agent --list" ] && printf '%s\n' \
  '* claude    -             Claude Code (Anthropic): your Claude login' \
  '  gemini    -             Gemini CLI (Google): your Google login; needs Node (vikix add javascript)'
exit 0
EOF2
  chmod +x "$t/agents/vikix"
  emacs=$(command -v emacs)
  apath="$t/agents:/usr/bin:/bin"
  # ag FORMS — as el, with agent-shell (and no autoloads: it's required).
  ag() {
    local l=() d
    for d in $ashell; do l+=(-L "$d"); done
    PATH=$apath "$emacs" -Q --batch "${l[@]}" -l "$here/config/emacs/vikix-ai.el" \
      --eval "(progn (defun say (&rest a) (princ (concat (apply #'format a) \"\\n\"))) $1)" 2>&1 || true
  }
  ready='(condition-case e (progn (vikix-ai--agent-ready (vikix-ai--agent)) (say "ready %s" (vikix-ai--agent))) (user-error (say "stopped: %s" (cadr e))))'
  out=$(ag "(progn (require 'agent-shell)
    (say \"agents %S\" (mapcar (lambda (m) (map-elt (funcall m) :identifier)) agent-shell-agent-configs))
    (with-temp-buffer (let ((c (agent-shell-anthropic-make-claude-client :buffer (current-buffer))))
      (say \"claude %s %S\" (map-elt c :command) (map-elt c :command-params))))
    (say \"codex %S\" agent-shell-openai-codex-acp-command)
    (say \"gemini %S\" agent-shell-google-gemini-acp-command)
    (say \"opencode %S\" agent-shell-opencode-acp-command)
    (cl-letf (((symbol-function (quote agent-shell-cwd)) (lambda () \"/home/me/proj/\")))
      (let ((f (funcall agent-shell-transcript-file-path-function)))
        (say \"transcript %s %o\" (file-relative-name f (expand-file-name \"~\")) (file-modes (file-name-directory f))))))")
  check "agent-shell should offer Vikix's four agents: $out" has '^agents (claude-code codex gemini-cli opencode)' "$out"
  check "transcripts should go to Vikix's folder, yours alone, not the project: $out" has '^transcript .local/state/vikix/agent-shell/proj-[0-9-]*\.md 700' "$out"
  check "Claude Code should start through vikix agent --acp: $out" has '^claude vikix ("agent" "--acp" "claude")' "$out"
  for a in codex gemini opencode; do
    check "$a should start through vikix agent --acp: $out" has "^$a (\"vikix\" \"agent\" \"--acp\" \"$a\")" "$out"
  done
  out=$(ag "$ready")
  check "your agent should be claude when none is chosen, and said missing as the terminal says it: $out" \
    has "stopped: claude isn’t installed: Claude Code (Anthropic): your Claude login.  To install it, in a terminal: vikix agent --install claude" "$out"
  printf '#!/bin/sh\n' > "$HOME/.local/bin/claude"; chmod +x "$HOME/.local/bin/claude"
  out=$(ag "$ready")
  check "with the agent but not its adapter, the adapter should be named: $out" \
    has "stopped: claude is installed, but not its ACP adapter, for editors.  In a terminal: vikix agent --install claude (adds only the adapter)" "$out"
  printf '#!/bin/sh\n' > "$HOME/.local/bin/claude-agent-acp"; chmod +x "$HOME/.local/bin/claude-agent-acp"
  out=$(ag "$ready")
  check "with the adapter, claude should be ready: $out" has '^ready claude' "$out"
  printf 'agent=aider\n' > "$HOME/.config/vikix/agent"
  out=$(ag "(progn (keymap-global-set \"C-c A\" (quote vikix-ai-agent-terminal)) $ready)")
  check "Aider (no ACP) should point to the terminal's key: $out" has "stopped: Aider doesn’t speak ACP: C-c A runs it in a terminal" "$out"
  printf 'agent=gemini  # mine\n' > "$HOME/.config/vikix/agent"
  out=$(ag "$ready")
  check "your agent= should be used, and a missing agent said: $out" has "stopped: gemini isn’t installed: Gemini CLI (Google)" "$out"
  out=$(apath=/usr/bin:/bin ag "$ready")
  check "without vikix, agents should say they start through it: $out" has "stopped: vikix isn’t on PATH" "$out"
fi

# vikix-notes.el, in a bare Emacs (org-roam's part needs MELPA: tried by hand).
n="$t/notes-home"
mkdir -p "$n/Dropbox/notes" "$n/.config/vikix/plugins/inbox" "$n/mine"
printf '#+title: Work\n\n* TODO Send the report\n* Plain heading\n' > "$n/Dropbox/notes/work.org"
printf '#+title: Mine\n\n* TODO Not a note\n' > "$n/mine/elsewhere.org"
echo "file = $n/Dropbox/notes/in.org" > "$n/.config/vikix/plugins/inbox/settings"
notes() { HOME=$n emacs --batch -Q -l "$here/config/emacs/vikix-notes.el" --eval "$1" 2>&1 | grep -v '^Loading\|^Clipboard\|^Org mode\|^$' || true; }
out=$(notes '(progn (require (quote org-agenda)) (princ (format "key %S\n" (key-binding (kbd "C-c n a")))) (vikix-notes-agenda) (princ (with-current-buffer org-agenda-buffer-name (buffer-string))))')
check "C-c n a should be the notes' agenda: $out" has '^key vikix-notes-agenda' "$out"
check "the agenda should list the notes' TODOs: $out" has 'TODO Send the report' "$out"
check "and only the notes': $out" bash -c "! grep -q 'Not a note' <<<\"\$1\"" _ "$out"
out=$(notes "(progn (require (quote org)) (setq org-agenda-files (list \"$n/mine/\")) (vikix-notes-todos) (princ (with-current-buffer org-agenda-buffer-name (buffer-string))))")
check "your own org-agenda-files should be kept: $out" has 'Not a note' "$out"
mkdir -p "$n/Dropbox/notes/journal"
printf '#+title: 2026-10-03\n\n* TODO From the journal\n' > "$n/Dropbox/notes/journal/2026-10-03.org"
out=$(notes '(progn (require (quote org-agenda)) (vikix-notes-todos) (princ (with-current-buffer org-agenda-buffer-name (buffer-string))))')
check "the journal's TODOs should be in it too: $out" has 'TODO From the journal' "$out"
notes '(progn (vikix-notes-capture) (insert "Captured in Emacs") (org-capture-finalize))' >/dev/null
check "C-c n c should write to the inbox plugin's file" grep -qx '\* Captured in Emacs' "$n/Dropbox/notes/in.org"
check "with when it was written" grep -qE '^:CREATED: +\[' "$n/Dropbox/notes/in.org"
out=$(notes "(progn (find-file \"$n/Dropbox/notes/work.org\") (princ (format \"notes %S\n\" auto-revert-mode)) (find-file \"$n/mine/elsewhere.org\") (princ (format \"mine %S\n\" auto-revert-mode)))")
check "a notes file should follow the phones' changes (auto-revert), and only a notes file: $out" \
  bash -c 'grep -q "^notes t" <<<"$1" && grep -q "^mine nil" <<<"$1"' _ "$out"
out=$(notes "(progn (require (quote org)) (find-file \"$n/Dropbox/notes/in.org\") (dolist (x (org-refile-get-targets)) (princ (format \"target %s\\n\" (car x)))))")
check "C-c C-w should offer the notes files and their top headings: $out" \
  bash -c 'grep -qx "target work.org" <<<"$1" && grep -qx "target work.org/Plain heading" <<<"$1" && grep -qx "target in.org/Captured in Emacs" <<<"$1"' _ "$out"
check "and only the notes': $out" bash -c "! grep -q 'elsewhere' <<<\"\$1\"" _ "$out"
out=$(notes "(progn (require (quote org)) (setq org-refile-targets (quote ((nil :maxlevel . 2)))) (find-file \"$n/Dropbox/notes/in.org\") (dolist (x (org-refile-get-targets)) (princ (format \"target %s\\n\" (car x)))))")
check "your own org-refile-targets should be kept: $out" bash -c "! grep -q 'work.org' <<<\"\$1\"" _ "$out"
rm -rf "$n/Dropbox/notes/journal"
out=$(notes '(princ (vikix-notes-journal-directory))')
check "C-c n j should make the journal folder first (the first auto-save failed without it): $out" test -d "$n/Dropbox/notes/journal"
rm -rf "$n/Dropbox"
out=$(notes '(progn (princ (format "key %S\n" (key-binding (kbd "C-c n a")))) (condition-case e (vikix-notes-agenda) (user-error (princ (cadr e)))))')
check "without the notes folder, C-c n a should say so: $out" has 'No notes yet in' "$out"

# --- vikix-python.el ----------------------------------------------------------
# A project with a venv of its own (stand-ins: its python says whether
# pytest is in it, by $HOME/has-pytest; ruff formats "x=1" and finds one
# unused import), and a file in no project.
export HOME="$t/py-home"
mkdir -p "$HOME/proj/.venv/bin" "$HOME/proj/pkg" "$HOME/loose" "$HOME/dev/python/.venv/bin"
touch "$HOME/proj/pyproject.toml"
cat > "$HOME/proj/.venv/bin/python" <<'EOF'
#!/bin/sh
[ "$1 $2" = "-c import pytest" ] && { [ -f "$HOME/has-pytest" ]; exit; }
exit 0
EOF
cp "$HOME/proj/.venv/bin/python" "$HOME/dev/python/.venv/bin/python"
cat > "$t/bin/ruff" <<'EOF'
#!/bin/sh
case $1 in
  format) sed 's/^x=1$/x = 1/' ;;
  check)  cat >/dev/null; name=$(echo "$@" | sed 's/.*--stdin-filename \([^ ]*\).*/\1/'); echo "$name:1:8: F401 \`os\` imported but unused"; exit 1 ;;
esac
EOF
cat > "$t/bin/pyright-langserver" <<'EOF'
#!/bin/sh
printf 'PATH=%s\nVIRTUAL_ENV=%s\n' "$PATH" "$VIRTUAL_ENV" > "$HOME/pyright-env"
exec cat
EOF
chmod +x "$t/bin/ruff" "$t/bin/pyright-langserver" "$HOME/proj/.venv/bin/python" "$HOME/dev/python/.venv/bin/python"
printf 'import os\n\ndef test_a():\n    assert 1\n\nclass TestX:\n    def test_b(self):\n        assert 1\n' > "$HOME/proj/pkg/test_a.py"
printf 'x=1\n' > "$HOME/loose/l.py"
touch "$HOME/has-pytest"
out=$(emacs -Q --batch -l "$here/config/emacs/vikix-python.el" 2>&1)
check "vikix-python.el should load clean in a bare Emacs: $out" test -z "$out"
# py FORMS — run in an Emacs with vikix-python.el, compile standing in; prints what they say.
py() {
  "$TIMEOUT" --kill-after=2s 20s "$EMACS" -Q --batch -l "$here/config/emacs/vikix-python.el" --eval "(progn (setq print-escape-newlines t)
    (defun say (&rest a) (princ (concat (apply #'format a) \"\\n\")))
    (defun compile (cmd &rest _) (say \"compile [%s] %s\" (abbreviate-file-name default-directory) cmd))
    (defmacro stopped (form) (list 'condition-case 'e form (list 'user-error (list 'say \"stopped: %s\" (list 'apply (quote #'format) (list 'cdr 'e))))))
    $1)" 2>&1 | grep -v 'python-indent-offset\|^$' || true
}
TIMEOUT=$(command -v timeout); EMACS=$(command -v emacs)
mkdir -p "$t/bare"; ln -s "$(command -v grep)" "$t/bare/grep"   # a PATH with neither ruff nor uv
open='(find-file (expand-file-name "proj/pkg/test_a.py" "~"))'
out=$(py "(progn $open
  (say \"mode %s venv %s lighter %s\" vikix-python-mode (abbreviate-file-name vikix-python--venv) (vikix-python--venv-name))
  (say \"path %s\" (abbreviate-file-name (car (split-string (getenv \"PATH\") \":\"))))
  (say \"virtual_env %s\" (abbreviate-file-name (getenv \"VIRTUAL_ENV\")))
  (say \"exec %s\" (abbreviate-file-name (car exec-path)))
  (say \"repl %s %s %s\" (abbreviate-file-name python-shell-virtualenv-root) python-shell-interpreter python-shell-interpreter-args)
  (say \"key %S\" (key-binding (kbd \"C-c p t\")))
  (with-temp-buffer (say \"elsewhere %s\" (car (split-string (getenv \"PATH\") \":\")))))")
check "a .py file in a project should get the mode, its .venv, and the mode line saying so: $out" has '^mode t venv ~/proj/.venv lighter .venv$' "$out"
check "the venv's bin should be first on the buffer's PATH: $out" has '^path ~/proj/.venv/bin$' "$out"
check "and VIRTUAL_ENV set: $out" has '^virtual_env ~/proj/.venv$' "$out"
check "and first in exec-path: $out" has '^exec ~/proj/.venv/bin$' "$out"
check "the REPL should run the venv's python (it has no ipython): $out" has '^repl ~/proj/.venv python -i$' "$out"
check "C-c p t should be the test key: $out" has '^key vikix-python-test' "$out"
check "another buffer's PATH should be as it was: $out" has "^elsewhere $t/bin$" "$out"
touch "$HOME/proj/.venv/bin/ipython"; chmod +x "$HOME/proj/.venv/bin/ipython"
out=$(py "(progn (setq python-shell-interpreter \"ipython\" python-shell-interpreter-args \"-i --simple-prompt\") $open (say \"repl %s %s\" python-shell-interpreter python-shell-interpreter-args))")
check "your interpreter should stay when the venv has it: $out" has '^repl ipython -i --simple-prompt$' "$out"
rm "$HOME/proj/.venv/bin/ipython"
out=$(py '(progn (find-file (expand-file-name "loose/l.py" "~")) (say "venv %s %s" (abbreviate-file-name vikix-python--venv) (vikix-python--venv-name)))')
check "a file in no project should get the shared venv: $out" has '^venv ~/dev/python/.venv dev$' "$out"
mv "$HOME/proj/.venv" "$HOME/proj/venv-aside"
out=$(py "(progn $open (say \"venv %S %s\" vikix-python--venv (vikix-python--venv-name)) (defun y-or-n-p (q) (say \"asked %s\" q) nil) (vikix-python-venv-command))")
check "a project without its own venv should get none, not the shared one (its packages aren't there): $out" has '^venv nil no venv' "$out"
check "and C-c p v should offer to make it: $out" has '^asked No venv for ~/proj/. Make one there with uv venv? ' "$out"
mv "$HOME/proj/venv-aside" "$HOME/proj/.venv"
out=$(py "(progn (find-file (expand-file-name \"loose/l.py\" \"~\")) (defun y-or-n-p (q) (say \"asked %s\" q) nil) (vikix-python-venv-command))")
check "on the shared venv, C-c p v should say so and offer one of the folder's own: $out" has '^asked The shared venv (~/dev/python/.venv) for ~/loose/. Make one there with uv venv? ' "$out"
out=$(py "(progn (with-current-buffer (get-buffer-create \" *markdown-code-fontification:python-mode*\") (python-mode)) $open (say \"hidden %S\" (buffer-local-value 'vikix-python-mode (get-buffer \" *markdown-code-fontification:python-mode*\"))))")
check "a buffer without a file (markdown's hidden ones) shouldn't get the mode: $out" has '^hidden nil' "$out"
rm -r "${HOME:?}/dev"
out=$(PATH="$t/bare" py '(progn (find-file (expand-file-name "loose/l.py" "~")) (say "venv %S %s" vikix-python--venv (vikix-python--venv-name)) (say "repl %s" python-shell-interpreter) (stopped (vikix-python-venv-command)))')
check "no venv at all should be said, and the REPL left as yours: $out" has '^venv nil no venv' "$out"
check "the REPL left as it was: $out" has '^repl python3$' "$out"
check "C-c p v without uv should say so: $out" has "stopped: No venv, and uv isn.t installed to make one: in a terminal, vikix add python" "$out"
cat > "$t/bin/uv" <<'EOF'
#!/bin/sh
[ "$1" = venv ] && mkdir -p .venv/bin && printf '#!/bin/sh\nexit 0\n' > .venv/bin/python && chmod +x .venv/bin/python
EOF
chmod +x "$t/bin/uv"
out=$(py '(progn (find-file (expand-file-name "loose/l.py" "~")) (defun y-or-n-p (&rest _) t) (vikix-python-venv-command) (say "venv %s %s" (abbreviate-file-name vikix-python--venv) (vikix-python--venv-name)))')
check "C-c p v with uv should make the venv there and use it: $out" has '^venv ~/loose/.venv .venv$' "$out"
check "saying so: $out" has 'venv made: .*/loose/.venv; the next REPL and language server use it' "$out"
rm "$t/bin/uv"

# The tests and the run: pytest on the function, the class's method, the
# file, the project; in a compilation buffer, in the project.
out=$(py "(progn $open
  (goto-char (point-min)) (search-forward \"assert 1\") (vikix-python-test)
  (search-forward \"assert 1\") (vikix-python-test)
  (goto-char (point-min)) (stopped (vikix-python-test))
  (vikix-python-test-file) (vikix-python-test-project) (vikix-python-run))")
check "C-c p t should run pytest on the function at point, in the project, with the venv's python: $out" has '^compile \[~/proj/\] .*/proj/.venv/bin/python -m pytest pkg/test_a.py::test_a$' "$out"
check "a method by its class: $out" has 'pytest pkg/test_a.py::TestX::test_b$' "$out"
check "outside a function, said: $out" has 'stopped: Not inside a function' "$out"
check "C-c p T the file: $out" has 'pytest pkg/test_a.py$' "$out"
check "C-c p P the project: $out" has 'pytest$' "$out"
check "C-c p r runs the file: $out" has '^compile \[~/proj/\] .*/proj/.venv/bin/python pkg/test_a.py$' "$out"
rm "$HOME/has-pytest" 2>/dev/null || true
out=$(py "(progn $open (stopped (vikix-python-test-file)))")
check "without pytest in the venv, said with how to add it: $out" has 'stopped: pytest isn.t in this venv: in a terminal, uv pip install pytest (in .*/proj/)' "$out"
touch "$HOME/has-pytest"

# ruff: the format (point kept), on save unless turned off, and the findings.
out=$(py "(progn (find-file (expand-file-name \"loose/l.py\" \"~\")) (goto-char (point-max)) (vikix-python-format) (say \"text %S point %d\" (buffer-string) (point))
  (erase-buffer) (insert \"x=1\\n\") (save-buffer) (say \"saved %S\" (buffer-string))
  (vikix-python-format-on-save) (erase-buffer) (insert \"x=1\\n\") (save-buffer) (say \"saved %S\" (buffer-string)))")
check "C-c p f should format with ruff, point kept: $out" has '^text "x = 1\\n" point 7$' "$out"
check "a save should format: $out" has '^saved "x = 1\\n"' "$out"
check "C-c p F should turn that off here, saying so: $out" has 'ruff format on save: off, in this buffer' "$out"
check "and the save then leave the text alone: $out" has '^saved "x=1\\n"' "$out"
out=$(py "(progn $open (setq-local flymake-diagnostic-functions '(eglot-flymake-backend)) (run-hooks 'eglot-managed-mode-hook)
  (say \"backends %S\" flymake-diagnostic-functions)
  (let (got) (vikix-python--ruff-flymake (lambda (d &rest _) (setq got (or d 'none))))
    (with-timeout (5 (say \"no answer\")) (while (not got) (accept-process-output nil 0.1)))
    (dolist (d (and (listp got) got)) (say \"found %s at %d: %s\" (flymake-diagnostic-type d) (flymake-diagnostic-beg d) (flymake-diagnostic-text d)))))")
check "ruff's backend should stand beside eglot's after eglot takes the buffer: $out" has '^backends (vikix-python--ruff-flymake eglot-flymake-backend)' "$out"
check "ruff's findings should be flymake's: $out" has '^found :warning at 8: F401 `os` imported but unused' "$out"
out=$(PATH="$t/bare" py "(progn $open (say \"backends %S\" flymake-diagnostic-functions) (stopped (vikix-python-format)) (erase-buffer) (insert \"x=1\\n\") (save-buffer) (say \"saved %S\" (buffer-string)))")
check "without ruff, C-c p f should say so: $out" has "stopped: ruff isn.t installed: in a terminal, vikix add python" "$out"
check "a save be plain: $out" has '^saved "x=1\\n"' "$out"
check "and python.el's own backend left as it was: $out" has '^backends (python-flymake t)' "$out"
printf 'import os\n\ndef test_a():\n    assert 1\n\nclass TestX:\n    def test_b(self):\n        assert 1\n' > "$HOME/proj/pkg/test_a.py"

# The language server starts with the venv's PATH (a stand-in records it).
out=$(py "(progn (require 'eglot) (setq eglot-connect-timeout 2 eglot-autoshutdown t) $open (eglot-ensure) (run-hooks 'post-command-hook) (sit-for 3) (say \"done\"))")
check "eglot's server should start with the venv first on PATH: $(cat "$HOME/pyright-env" 2>&1)" grep -q "^PATH=$HOME/proj/.venv/bin:" "$HOME/pyright-env"
check "and VIRTUAL_ENV set" grep -q "^VIRTUAL_ENV=$HOME/proj/.venv$" "$HOME/pyright-env"

# The IDE layout: code left, the REPL top right, the tests' output below.
out=$(py "(progn (defun run-python (&rest _) (get-buffer-create \"*Python*\")) (defun python-shell-get-buffer () (get-buffer \"*Python*\")) $open (vikix-python-ide)
  (say \"windows %d selected %s\" (length (window-list)) (buffer-name (window-buffer (selected-window))))
  (say \"right %s below %s\" (buffer-name (window-buffer (window-in-direction 'right))) (buffer-name (window-buffer (window-in-direction 'below (window-in-direction 'right)))))
  (say \"mode %s\" (with-current-buffer \"*compilation*\" major-mode)))")
check "C-c p i should give three windows with the code selected: $out" has '^windows 3 selected test_a.py' "$out"
check "the REPL right and the compilation buffer below it: $out" has '^right \*Python\* below \*compilation\*' "$out"
check "ready for the first test: $out" has '^mode compilation-mode' "$out"
out=$(py "(progn $open (stopped (vikix-python-docs)))")
check "C-c p d without the docs should say so: $out" has "stopped: The offline docs aren.t here: vikix add python puts them in ~/dev/python/docs" "$out"

[ "$fail" = 0 ] && echo "emacs: Vikix's part is linked, gptel follows vikix ai use, agents start through vikix agent, the notes' agenda, capture and refile targets, and Python's venv, tests, ruff and layout"
exit "$fail"
