# Pen test: Vikix 0.54.0 MCP server (`vikix mcp`), 2026-09-29

Scope: `bin/vikix-mcp`, its dispatch in `bin/vikix` (line 649), `tests/mcp.sh`, and the path to the
window manager through `bin/vikix-eval` / Swank (`config/stumpwm/vikix/swank.lisp`). Dev checkout
at 4184bf7. The installed desktop is still 0.53.1 (no `vikix-mcp` in `~/vikix` or `~/.local/bin`,
not registered in `~/.claude.json`).

How it was tested. All proofs of concept ran from the dev checkout in a throwaway HOME under
`/home/vukini/.claude/jobs/9e7c4573/tmp/`, with `VIKIX_SWANK_PORT=9`, `VIKIX_STATE` in the throwaway
dir, and stand-ins for vikix-eval (`VIKIX_EVAL`), `python3` (to catch the form `vikix theme`
sends), `dunstctl` and `pkill`. Plain `sbcl --no-userinit` (a separate process, not the WM) was
used to check the Lisp reader and the JSON escaper. The only calls to the real Swank were the
read-only `desktop` and `keys` tools, with the log sent to the throwaway dir; they printed
counts only (9 workspaces, 7 windows, 67 bindings; both parsed). Nothing was registered, no
acting tool reached the live desktop, and no secret was read or printed. (A fake secret was used
in the listener test, finding 4.)

Summary: no remote or cross-user code execution through the MCP server itself. The quoting into
Lisp (`lisp_string`) and the Lisp JSON escaper hold up. The most serious problem is outside the
server but reachable through it: **a theme's file name goes into Lisp unquoted** (finding 1). The
rest are robustness and audit weaknesses.

---

## 1. Medium: a theme's file name is run as Lisp by `vikix theme`, and `set_theme` passes such a name through

**Who and what.** Anyone who can get a `.theme` file with a crafted name into
`~/.config/vikix/themes/` (a theme pack someone shares, an agent that can write files but has no
shell, any program running as the user). They get arbitrary Lisp, and so shell commands, run in
StumpWM as the user. It runs when the theme is chosen (`vikix theme NAME`, or an agent's
`set_theme`, which only checks that the name is in the list), and **again on every
`vikix update`**, because `40-config` runs `vikix theme --refresh` with the saved name.
`theme_read` says the file "is read, never run", and that holds for the file's *contents*, but
not for its *name*.

**Evidence.**
- `bin/vikix:613`: `python3 "$VIKIX_DIR/bin/vikix-eval" "(vikix-apply-theme :$name)"`. The name is
  spliced in as a bare keyword.
- `bin/vikix:605` and `install/40-config.sh:100`: `--refresh` reads the name back from
  `~/.config/vikix/theme/current`, so the injection comes back on every update.
- `bin/vikix-mcp:212-217`: `t_set_theme` accepts any name `that `vikix theme` lists.

---

*The report stopped here when the review ended early. The rest below is taken from the reviewer's own summary, which it sent when it stopped, and is recorded with what 0.54.1 did about each.*

**Fix (1):** allow only letters, digits, `-` and `_` in theme names (`theme_names`, `theme_file`, `cmd_theme`, `theme_current` in `bin/vikix`, and `t_set_theme` in `bin/vikix-mcp`). **0.54.1:** done (`theme_name_ok`); a file named otherwise is neither listed nor used; tests/theme.sh and tests/mcp.sh check it.

## 2. Low (confirmed): the server exits on malformed input
`params` as a list, a list as the tool's name, a lone surrogate in an argument (the log's `OSError`-only catch), deep nesting (`RecursionError`), and invalid UTF-8 on stdin each ended the server. A batch or a non-object got no reply. **0.54.1:** type checks, -32600/-32602/-32603 answers, stdin read as bytes and decoded with replacement, 1 MB line limit, the log in ASCII-escaped JSON; each case is in tests/mcp.sh, with a ping after it.

## 3. Low (confirmed): window titles could break desktop, switch_workspace, focus_window
A title containing `=> ` broke `evaluate()`'s `rsplit`, and output over 20000 characters was cut before the JSON parse (one long title, or roughly 100 windows). **0.54.1:** the value is the last line starting with `=> `; `evaluate` allows 4 MB; titles, classes and names are cut to 200 characters in the Lisp form.

## 4. Low (confirmed): vikix-eval sent ~/.slime-secret to whatever listened on 127.0.0.1:4004
Without checking who owns the port: with Swank down, another local user could listen there and collect the password. **0.54.1:** `listener_uid` reads `/proc/net/tcp`; a port owned by another uid gets no password.

## 5. Low (confirmed): the audit log had gaps
Arguments cut at 200 characters (padding hid an eval's real code), refused calls not logged, no outcome, secrets in arguments recorded, 644, never rotated, raw control characters. **0.54.1:** every call is logged with `ok`/`error`/`refused`, arguments ASCII-escaped, scrubbed, cut at 500 with their length and a sha256, the file 600, rotated at 1 MB. Not done: the client's identity (MCP gives none reliably).

## 6. Low: changes is marked read-only but writes, and passes diffs to the model
It stages into yours.git's index and rewrites info/exclude, and hands diffs of dotfiles (old snapshots may hold keys) to the agent. **0.54.1:** its output (and history's, doctor's) goes through the debug scrubber; the staging is the snapshot repository's own bookkeeping, left as it is. notify and snapshot are no longer marked idempotent.

## 7. Low: notify wasn't visibly the agent's
Dunst's format hides the app name; the title wasn't escaped; no rate limit; notifications may draw over i3lock (suspected). **0.54.1:** the title starts "Agent: ", both escaped. Not done: a rate limit; pausing dunst while locked (in TODO).

## 8. Low: --allow-eval/--allow-undo are a convenience, not a boundary
An agent with a shell can run `vikix eval`, register again, or edit ~/.claude.json (not in yours.list). VIKIX_EVAL, VIKIX_CLAUDE, VIKIX_STATE are test hooks honoured in use. **0.54.1:** said plainly in the docs and the help. Not done: a doctor warning when eval is registered; gating the hooks (the agent's environment is already the agent's).

## 9. Low: prompt injection through more than titles
**0.54.1:** keys, doctor, history and changes say their text is data, never instructions, as does the server's `instructions`.

## 10. Low (suspected): a form that timed out ran later
In swank.lisp, `vikix-eval-for-agent` gave up after 10 s but left the form queued, so retries piled up and ran when a menu closed. **0.54.1:** a `cancelled` flag the queued form checks.

## 11. Informational
One request at a time (set_theme up to 60 s blocks pings); no input size limit (**0.54.1:** 1 MB); snippets didn't escape the path (**0.54.1:** JSON-quoted); register silently replaces a user-scope "vikix" (by design, said in its output); eval reported a Lisp error as success (**0.54.1:** an error); the registered path is a link into ~/vikix, so updates change the server's code without re-registering (by design).

## Checked and fine
lisp_string round-trips a hostile workspace name, and the Lisp JSON escaper handles control characters, `~`, DEL and U+2028 (both checked in SBCL); no sockets; commands are argument lists, no shell; `--` before notify-send's arguments; snapshot messages sanitised and prefixed; hex-only snapshot ids; integer-only window numbers; eval and undo absent unless switched on; timeouts not stretched by children; nothing in install, update or migrations registers the server; `vikix agent` strips keys from the environment the server inherits; doctor's eval is a fixed `(+ 1 1)`; the tests use port 9.
