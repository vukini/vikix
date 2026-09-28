# Everyday user review: `vikix debug` and `vikix diagnose` (Vikix 0.52.0)

Checked on 2026-09-28. The dev checkout is **0.52.0** (b24e6e6) and the installed `~/vikix` is **0.51.1**, so I ran everything with `bin/vikix` from the checkout. The running desktop's `~/.local/bin/vikix` still points to `~/vikix`.

## What I did

1. Read, as someone whose desktop has a problem would: `docs/fixing.md` ("Asking for help", plus the sections above it), README lines 727-728 and its test-table row, `vikix help`, `vikix debug --help`, `bin/vikix-debug --help`, the two Super+m entries (`commands.lisp:99-100`) and `.github/ISSUE_TEMPLATE/bug.yml`.
2. Ran `bin/vikix debug --out /home/vukini/.claude/jobs/9e7c4573/tmp/ux-debug.txt` on the real machine. It took 2.2 s, wrote 1066 lines (73 KB, mode 600) and exited 0.
3. Before reading the report, I checked with counts only. The key-shape grep (`sk-ant-|sk-proj-|pplx-|AIza|ghp_|github_pat_|gho_|xox[bp]-|glpat-`) found **0** lines. The value of each file in `~/.config/vikix/secrets` also appeared **0** times. The host name appeared 0 times and the user name 0 times. Only after that did I read the report.
4. Ran `vikix diagnose --use aider --local` with `env -i` in the throwaway home, with stdin from `/dev/null`. It did not refuse. It wrote the report, printed its messages, and started Aider on the local llama3.2:3b. Aider exited at once because stdin was empty, so no model was asked anything and nothing was sent to a paid model. **Side effect:** Aider created `/tmp/.git`, `/tmp/.aider.chat.history.md` and `/tmp/.aider.tags.cache.v4` in my working directory. I deleted them, since my own run had just made them (see F4).
5. Ran the scrubber (`lib/debug-scrub.py`) on sample text with `USER=void` and `USER=vikix` to see how it treats common words.

I pressed no keys and took no screenshots.

---

## Findings, most important first

### F1. The bug-report form on GitHub doesn't know about `vikix debug` (High)
- **What happened:** A user who goes to github.com/vukini/vikix/issues gets `bug.yml`. It asks them to paste `tail -n 50` of the newest log, and "Anything else" suggests `vikix changes`. It never mentions `vikix debug`. So the new feature is missing from the one place every reporter passes through, and helpers will keep getting 50 lines of whichever log happens to be newest, which can be `lazarus-build.log` or `ollama.log`.
- **Expected:** The form says: run `vikix debug` (or Super+m → *A report of what's going on*), read it, then drag the file into the box.
- **How to see it:** `.github/ISSUE_TEMPLATE/bug.yml`, the `log` field.
- **Cost:** It affects every issue, so the feature's main purpose (a helper gets the whole picture) is lost.
- **Suggestion:** Change the `log` field's description to "Attach the report `vikix debug` writes (drag `~/vikix-debug-*.txt` here). Can't run it? Paste the end of the newest log: …". Keep the tail command as a fallback.
- **In TODO.md:** No.

### F2. The session-log section is mostly other programs' noise, and it can show which sites you visited (High)
- **What happened:** "The session's log" is `tail -n 300`. Of its 246 non-blank lines:

  | Source | Lines |
  |---|---|
  | GLib/Gtk/Gjs warnings from the file manager, Foliate and Firefox | 67 |
  | Zeal lines | 55 |
  | Firefox JavaScript warnings, with full stack traces | 35 |
  | Chromium lines | 4 |
  | The same "MESSAGE: Reloading settings (with the old files)" | 65 |
  | Lines mentioning Vikix | 1 |

  "The time before" section (the previous session, 80 lines) is much the same.

  The browser lines carry the web addresses of sites that were open (a chat service's asset URLs, an analytics URL with a long hash), a browser-extension UUID, and a FUSE mount named after a program. Other lines carry file names from `~/Downloads` and `~/Pictures/Screenshots` (from `vikix-image '…'`). None of this is a key or a password, so the scrubber is right to leave it. But the header says "Keys, passwords, your home path, user and machine names are taken out", and the terminal says "names are taken out". A user who trusts that and shares without reading 1066 lines publishes some of their browsing on a public issue tracker.
- **Expected:** This section should show what went wrong with the desktop, and say plainly what it still contains.
- **How to see it:** Run `vikix debug`, then `grep -nE 'JavaScript|^zeal|GLib' ~/vikix-debug-*.txt | wc -l`.
- **Cost:** Every report. The helper has to dig through it. There is a real privacy surprise for someone who shares without reading it, and "read it before you share it" is a big ask at 1000+ lines.
- **Suggestion (smallest first):**
  1. Say what stays, in both the header and the terminal message: "Not taken out: file names and web addresses that programs printed into the logs. Skim 'The session's log' before sharing."
  2. Filter the session log: keep `vikix-session`'s own `+ …` trace, `MESSAGE:` lines (without repeats), lines naming Vikix/StumpWM/SBCL, and "Unhandled"/backtrace blocks. Drop lines from browsers (`JavaScript`, `console.`, `…@https://`, `moz-extension://`, `google_apis/gcm`), `zeal.`, and `(prog:pid): G*-WARNING/CRITICAL`. Say how many lines were left out.
  3. Collapse lines that repeat one after another ("… ×65").
- **In TODO.md:** No.

### F3. The report misses what a helper asks first: the start of the session, a summary of what failed, and what changed recently (Medium)
- **What happened:**
  - **The start of the session is cut off.** Taking only the end of the log drops `vikix-session`'s start-up trace and any `Vikix: error in X.lisp` message printed at login. In a long session (1122 lines here, 2925 in the one before) those are hundreds of lines above the tail. They are exactly what `docs/fixing.md` "A red error after a reload or login" is about.
  - **No summary of what failed.** The last update's `!! the docked Lazarus IDE didn't build; see …/lazarus-build.log` happens to be visible, but 167 of the 200 lines shown are Neovim plugin-sync lines (`[LuaSnip] fetch | …`). The first ~200 lines, with the git pull, the version change, and the `10-packages`/`20-services`/`40-config` stages, are cut off. The last install's 200 lines are 142 lines of curl progress meters, and the `!!` lines from the rest of that log aren't shown. The log it points to (`lazarus-build.log`) isn't included.
  - **No "what changed".** It doesn't show the version before the last update, `vikix changes` (the user's own edits since the last snapshot, which the issue form already asks for), or whether `user.lisp` differs from the starter file.
  - **Not all of doctor's checks are in it.** It runs `vikix doctor`, but the links it checks aren't shown, and neither is which checkout `~/.local/bin/vikix` points to. That matters on a machine with two checkouts, like this one: the report says 0.52.0 while the desktop runs 0.51.1.
- **Cost:** Most helpers' first reply would be "what does the start of session.log say / what did you change / what failed?", which costs a round trip on each issue.
- **Suggestion:** Add a short **"Problems at a glance"** section at the top. It would hold every `!!`/`xx` line from the last install and update, doctor's warnings, `Vikix: error in` lines and `Unhandled` lines from both session logs, the names of failed stages, and the version before and after the last update (from the update log's first `::` line). Add `head -n 60 session.log`, the tail of any log that a `!!` line names, `vikix changes --stat` (file names only), and `readlink -f ~/.local/bin/vikix`. Then cut the update and install tails to the lines that aren't progress (drop curl meters and `[plugin] fetch|status|checkout` lines).
- **In TODO.md:** No.

### F4. `vikix diagnose` with Aider starts it in the current folder, and Aider's default answer makes that folder a git repository (Medium, for Aider users)
- **What happened:** With no terminal, diagnose didn't refuse or warn. It launched Aider, which said "No git repo found, create one…? (Y)es/(N)o [Yes]" and created one in my working directory. The running StumpWM's working directory is `~`, so Super+m → *Something's wrong? Ask the agent* with Aider as the default agent starts it in the home folder. A stressed user pressing Enter there turns `~` into a git repo, and Aider builds a repo map over their whole home.
- **Expected:** diagnose starts the agent somewhere harmless (for example `~/.local/state/vikix`, or a folder made for the purpose) or passes Aider `--no-git`. Also, when stdin isn't a terminal, it says "run this in a terminal" instead of starting the agent.
- **How to see it:** `cd /tmp && vikix diagnose --use aider --local </dev/null`, then `ls -a /tmp` (you'll need to delete `/tmp/.git` afterwards).
- **Cost:** Only for Aider users, but the mess lands in `$HOME` and is confusing to undo.
- **Suggestion:** In `cmd_diagnose`, `cd "$VIKIX_STATE"` before the `exec`, and add `--no-git` for Aider when it's started by diagnose. Add a `[ -t 0 ] || die "vikix diagnose talks with you: run it in a terminal"` check.
- **In TODO.md:** No.

### F5. The report is too long for the local models diagnose offers (Medium)
- **What happened:** The report is about 73 KB, roughly 20k tokens. `diagnose --local` gives it to llama3.2:3b on a 2-core laptop CPU, which will take a very long time or have its context truncated. The message warns "expect minutes per answer", but a small model that can only see part of the report tends to guess. With Aider, the question also isn't passed: the user has to retype the long "ask it: …" sentence by hand.
- **Suggestion:** Once F2/F3's filtering exists, hand a local model just the "Problems at a glance" section plus doctor's output (a `--brief` report), and keep the full file for a person or a cloud agent. For Aider, pass the question with `--message` for the first turn, or tell the user to type just "read the report and tell me what's wrong".
- **In TODO.md:** No.

### F6. `vikix debug --help` prints an error (Low, but it's the first thing a careful user types)
- **What happened:** `vikix debug --help` and `vikix debug -h` both print `xx vikix debug [--out FILE]` and exit 1, and `vikix diagnose --help` does the same. `bin/vikix-debug --help` shows a good page, and `vikix ai --help` works, so this is inconsistent. The red `xx` makes it look as if something is already broken, which is the wrong feeling for a tool you reach for when things are broken.
- **Suggestion:** In `cmd_debug` and `cmd_diagnose`, make `-h|--help` print the header (the same `sed` as the top-level case) and return 0.
- **In TODO.md:** No.

### F7. The places where people meet problems don't point to the new commands (Low-Medium)
- **What happened:**
  - `vikix doctor` ends a failure with `!! see above`, and doesn't suggest `vikix diagnose`.
  - `vikix update`'s "these stages failed: … Fix them, then: vikix update" doesn't suggest it either.
  - `docs/fixing.md` opens with "Start with: vikix doctor". "Asking for help" is the last section, and "…is a bug in Vikix… please report it" (line 27) and "The desktop didn't start" (which works from tty2 with no DISPLAY, since the report skips Screens) don't link to it.
  - In `vikix help`, `diagnose` has no line of its own. It is tucked into "(vikix diagnose: and ask the agent)", which reads oddly, and `debug` sits between `eval` and `agent`, away from `doctor`.
  - The name "debug" suggests turning on debug output rather than "write a report". The Super+m label fixes this, but the command line doesn't.
- **Suggestion:** Add one line to doctor's and update's failure messages: "Stuck? vikix diagnose asks your agent; vikix debug writes a report for an issue." Move the two commands next to `doctor` in `vikix help`, each on its own line. In `fixing.md`, mention `vikix diagnose` right under "Start with vikix doctor", and link "please report it" to "Asking for help".
- **In TODO.md:** No.

### F8. The scrubber turns common words into `[user]` when the user name is a common word (Low)
- **What happened:** The user name is replaced wherever it appears as a whole word. With `USER=void`, `ID="void"` from `/etc/os-release` becomes `ID="[user]"`. With `USER=vikix`, every `vikix update` in the logs becomes `[user] update`. On this machine the user name is also the GitHub owner, so the remote shows as `git@github.com:[user]/vikix.git`, which hides whether the user pulls from upstream or a fork. Replacing the host name word by word has the same problem for host names like `void` or `laptop`.
- **Suggestion:** Replace the user name only where it's clearly a name: `/home/USER`, `USER@`, and `for USER`/`user USER`. Or skip whole-word replacement when the name is `void`, `vikix`, `dev`, `user`, `admin`, or appears in the unscrubbed report more often than it would as a name. Leave `github.com/vukini/` alone.
- **In TODO.md:** No.

### F9. How to attach it, and where the files pile up (Low)
- **What happened:**
  - The docs say "attach the report", but not how: drag the file into the issue's text box, or use "Paste, drop, or click to add files".
  - At 72,899 characters, this report is longer than GitHub's 65,536-character limit for an issue body, so someone who pastes it gets an error.
  - Each `diagnose` (and each Super+m use) leaves another `~/vikix-debug-*.txt` in the home folder. `docs/map.md` does say "yours to delete".
  - After the Super+m entry, the path is only in the terminal, which closes on Enter.
- **Suggestion:** In `fixing.md` and the terminal message, say "drag the file into the issue (it's too long to paste)". Have `diagnose` write its report under `~/.local/state/vikix/` (only `debug`'s copy needs to be easy to find in a browser's file picker). After the Super+m entry, show the file (`less`) or copy its path to the clipboard.
- **In TODO.md:** No.

---

## What felt good

- **Fast and quiet:** 2.2 s, one line of progress, and a closing message that says where the file is, that only you can read it, that nothing was sent, and where to report. The wording is calm and clear.
- **Safety done properly where it matters:** the file is 600 from its first byte (umask), the stored keys' actual values are removed whatever their shape, and there's a second key-shape scan over the finished file that reports only line numbers and refuses to hand over a file that fails. My checks found no keys, and neither the home path, user name nor machine name leaked.
- **Clear, labelled sections**, each showing the exact command that produced it. A helper can re-run any of them, and a missing program says "(X isn't installed)" instead of failing.
- **Works away from the desktop:** with no DISPLAY it skips the screens and carries on, which suits the "desktop didn't start, log in on tty2" case.
- **The Super+m labels** ("Something's wrong? Ask the agent" / "A report of what's going on (vikix debug)") are the best names this feature has. They say what you get, and the terminal waits for Enter.
- **diagnose's lead-in:** it says which model is used and how slow it will be, takes a snapshot first, and says `vikix changes` / `vikix undo`. It is reassuring and true.
- **The docs' promise ("read it before you share it: nothing is sent anywhere by itself")** is honest. Keep it, and add a line on what isn't removed (F2).
