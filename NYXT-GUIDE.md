# Nyxt guide: notes for a future guide

Material for a guide to Nyxt on Vikix (a `docs/nyxt.md` some day, written by the `explainer` agent in the guides' style). Gathered with Vid on 2026-10-02, while Nyxt became Vikix's docs browser, took the desktop's colours and got a Swank for Emacs (0.71.47 to 0.71.61). **Tested** marks what was run against Nyxt 3.11.8 (Void's package), on a hidden display with Vid's settings; the rest are ideas, not yet tried.

## What Vikix sets up

- **Guides and docs open in Nyxt** (0.71.47). `vikix-docs-open FILE|URL...` sends local guides and docs to Nyxt when it's installed (the feature `lisp-apps`), else `xdg-open`. Super+m → *Vikix guide in the browser*, *Programming docs*, and the `docs` alias use it. A running Nyxt gets the page as a new buffer, through its socket (`$XDG_RUNTIME_DIR/nyxt/nyxt.socket`), and StumpWM brings its window forward (`vikix-raise-class "Nyxt"`). `~/.config/vikix/docs-browser` (one word, such as `firefox`) names another browser. The rest of the web stays with the default browser.
- **The desktop's colours** (0.71.52). `~/.local/share/vikix/nyxt/vikix.lisp` (Vikix's, a link to `config/nyxt/vikix.lisp`) builds a Nyxt theme from `vikix theme`'s palette. `vikix theme NAME` repaints a running Nyxt over its socket. That needs remote execution, which the same file switches on.
- **Your config**: `~/.config/nyxt/config.lisp`, copied once, then yours. It loads Vikix's part first; anything below that line wins. Take the line out to keep Nyxt's own colours. `vikix lisp-apps status` says whether yours loads it.
- **Swank for Emacs** (0.71.57): `127.0.0.1:4006`, only when `~/.slime-secret` has a password, guarded as StumpWM's is (a wrong password, or none within 5 seconds, ends only that connection). `(setf *vikix-swank-port* nil)` below the load line keeps it closed. StumpWM's Swank is 4004; 4005 is left for your own SLIME.

## Connecting from Emacs

1. `M-x slime-connect RET 127.0.0.1 RET 4006`. SLIME sends the password by itself. If it says the versions differ, answer `y`.
2. The REPL is in the package `nyxt-user`.
3. Emacs may be connected to StumpWM and Nyxt at once. A Lisp buffer sends to the *default* connection, the last one made. `M-x slime-list-connections` shows them: the **Port** column tells them apart (4006 Nyxt, 4004 StumpWM), `*` marks the default, `d` on a line makes it the default, `R` removes a dead one. `M-x slime-cycle-connections` also switches.

## Evaluating in a buffer

Use a Lisp file (say `~/nyxt.lisp`) that starts with:

```lisp
(in-package #:nyxt-user)
```

SLIME reads that line for the package; without it the forms run in `cl-user`, and `define-command-global` isn't found.

| Keys | What it sends |
|---|---|
| `C-M-x` | the top-level form around the cursor (the usual one for a `define-command-global`) |
| `C-c C-c` | the same, compiled, with warnings shown on the code |
| `C-x C-e` | the expression before the cursor, e.g. `(title (current-buffer))`; the result in the echo area |
| `C-c C-r` | the region |
| `C-c C-k` | the whole file |

`~/.config/nyxt/config.lisp` starts with the same `in-package` line, so it can be worked on the same way. `C-c C-k` on it is safe: Vikix's part starts Swank only once.

Without Emacs: `nyxt --remote --quit --eval '(...)'` runs Lisp in a running Nyxt over its socket (what `vikix theme` uses). Its output goes to Nyxt's log, `~/.local/share/nyxt/nyxt.log`, not to the terminal.

## Examples

### A command: open the page in Firefox (tested)

Some sites don't work well in WebKit; this hands the page to Firefox. It's in Ctrl+Space as soon as it's evaluated.

```lisp
(define-command-global open-in-firefox ()
  "Open the current page in Firefox."
  (uiop:launch-program (list "firefox" (render-url (url (current-buffer)))))
  (echo "Sent to Firefox: ~a" (title (current-buffer))))
```

Then: Ctrl+Space, `open-in-f`, Enter. Edit it and `C-M-x` again to replace it live, no restart.

### An auto-rule: no dark mode on the guide pages (tested)

Nyxt's settings (its auto-config) may turn dark mode on for every page; Vikix's guide has colours of its own. With the rule the guide shows light and other pages stay dark; without it, the guide is turned dark.

```lisp
;; Vikix's guide pages have their own colours: no dark mode there.
(define-auto-rule
    `(match-regex ,(format nil "^file://~a\\.local/share/vikix/guide/"
                           (namestring (user-homedir-pathname))))
  :excluded '(nyxt/mode/style:dark-mode))
```

- `define-auto-rule`: when a page's address matches the test, change its modes. `:excluded` turns modes off, `:included` turns them on.
- The test is evaluated, and its result called with the URL. The other tests: `match-domain`, `match-host`, `match-port`, `match-scheme`, `match-url`, or a URL string for one page exactly.
- Rules apply as a page loads: reload (`r`) or open the page fresh to see one.
- `match-regex` takes several patterns. `~/dev`'s docs too: add `,(format nil "^file://~adev/" (namestring (user-homedir-pathname)))`. Python's and Rust's docs have dark themes of their own, which dark mode would turn back to light.

### Small things to try (tested)

- `(mapcar #'title (buffer-list))` with `C-x C-e`: your open pages.
- `(render-url (url (current-buffer)))`: the current address.
- `M-.` on any Nyxt name (`render-url`, `print-status`) jumps into Nyxt's source in `/usr/share/nyxt/source/`; `M-,` comes back.

### Ideas, not yet written

From small to big:

1. **Commands that join Nyxt to the desktop**: add the page to a project's log (`vikix project log NAME "read: <title> <url>"`); open the site as a web app (`vikix webapp`); show a file in Esploro; send the window to a workspace (`vikix eval`).
2. **How pages load**: rewrite addresses (reddit → old.reddit, YouTube → a lighter front end); block domains (Nyxt's request hook); per-site rules (scripts off on one site).
3. **The page itself**: JavaScript run from Lisp to gather a page's code blocks, strip it to its text, or fill in a form. "Send this code block to a terminal" would be built this way.
4. **Your own Ctrl+Space sources**: every doc under `~/dev`; `vikix project` folders; links from Obsidian notes.
5. **Your own `nyxt:` pages** (Spinneret, HTML written as Lisp, built when opened): a start page with the projects and their next steps, `vikix today`, the key card made from StumpWM.
6. **A `vikix learn c` lesson page** with a **Check** button that runs the checker and shows the result beside the lesson.

## Things learned the hard way (for the guide's "when it goes wrong")

- **"invalid number of arguments: 3" on `C-x C-e`.** Nyxt's Swank is built into it and older than MELPA's SLIME, which sends the evaluating calls lines and width, and the macroexpand calls an environment. Since 0.71.60 Vikix's part wraps those calls. The REPL itself always worked.
- **Changes to Vikix's part need a Nyxt restart.** The theme follows `vikix theme` live, but a new `vikix.lisp` (after `vikix update`) is read when Nyxt starts. Quitting and starting Nyxt brings the tabs back.
- **A Nyxt process that isn't a browser.** A `nyxt URL` started while another Nyxt was closing can be left behind: a process, but no window StumpWM lists and no socket. It holds nothing useful; `pkill -x nyxt`, then start Nyxt.
- **Nothing on 4006?** Nyxt isn't running, or started without `~/.slime-secret` (its log says "Swank not started"), or something else held the port (also in the log).
- **A config.lisp copied before 0.71.58** guards the load with `probe-file`, which passes a link whose file has gone (SBCL), so a moved checkout stops the rest of the file. The starter now catches `load`'s `file-error` instead: `(handler-case (load ...) (file-error () nil))`.
- **Remote eval and Swank output** go to Nyxt's log or the REPL, never to the shell that sent them.
