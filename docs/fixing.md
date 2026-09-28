# When something breaks

Start with:

```sh
vikix doctor
```

It checks the programs, services, links, the snapshot history and `vikix eval`, and says what's missing.

## The desktop didn't start

You'll be left at the text console, or with a black screen.

1. Go to another console: **Ctrl+Alt+F2**, and log in there.
2. Read what the session printed: `less ~/.local/state/vikix/session.log` (the one before is `session.log.old`). Every command it ran is there, followed by any error.
3. Some usual causes:
   - **`stumpwm: not found`**, or a Lisp error before StumpWM starts: rebuild it with `vikix rebuild-wm`.
   - **A problem in a file you changed** (`.bash_profile`, `.bashrc`, `.Xresources`): `vikix changes` shows what's different since the last snapshot, and `vikix undo` puts it back.
   - **X itself failed**: its log is `/var/log/Xorg.0.log` (look for lines starting `(EE)`).
4. Log out of this console (`exit`), go back with **Ctrl+Alt+F1**, and log in there again.

## A red error after a reload or login

`Vikix: error in user.lisp:` followed by the error means StumpWM couldn't run something in your `user.lisp`. Everything else loaded, so the desktop works. Fix the line and reload (`Super+m` → *Reload config*), or take the file back with `vikix undo`.

`Vikix: error in keys.lisp` (or another of Vikix's files) is a bug in Vikix. `vikix update` may already have the fix. If not, please report it.

## A key doesn't work

- `Super+m` → *What does a key do?*, then press the key. It says what the key is bound to, if anything.
- `Super+F1` lists every key Vikix binds.
- In a VM, the host may take the key before the guest sees it: on Windows, Super+L locks Windows.

## Something on screen stopped updating

If the bar's clock stops, or windows open but don't show, the compositor (picom) is probably stuck. Restart it from a terminal:

```sh
pkill picom; picom -b
```

## Settings went wrong

```sh
vikix history        # snapshots of your files, newest first
vikix changes ID     # what a snapshot changed
vikix undo           # back one snapshot
vikix undo ID        # back to that snapshot
```

Then `Super+m` → *Reload config*, or log in again for things read at login (`.Xresources`, the idle times).

A file that was in the way of one of Vikix's links was moved aside, not deleted. To find those:

```sh
find ~ -name '*.vikix-bak.*' 2>/dev/null
```

## An update failed

The end of the run names the stages that failed, and the whole run is in `~/.local/state/vikix/logs/update-<time>.log`. The other stages still ran. Most failures are the network; run `vikix update` again.

**Changes made in the checkout** (`~/vikix`: an edit by hand, or by another program) would stop the pull, so the update sets them aside first, and says so, at the start and again at the end. Nothing is deleted. They're in a patch file you can read:

```sh
ls ~/.local/state/vikix/checkout-changes/        # one file per update that set something aside
less ~/.local/state/vikix/checkout-changes/<date>.patch
```

A change you want to keep belongs in your own files (`~/.stumpwm.d/user.lisp` …; see [Making it yours](customize.md)): the checkout is replaced by every update. Editors' leftovers (`#file#`, `file~`) are ignored, so they never stop it.

**Commits made in the checkout** do stop the update: Vikix can't update over them. It says so, with the commands to keep them as patch files and put the checkout back as released. **A clash left in the checkout** (Vikix's files with `<<<<<<<` marks, from putting set-aside changes back by hand) stops it too, with the commands to fix it; the desktop may not start until then.

Otherwise, if it stops at **pulling Vikix**, it's the network or GitHub: run `vikix update` again.

To run one install stage again on its own (each is safe to re-run):

```sh
~/vikix/install.sh --only 40-config
~/vikix/install.sh --list      # all the stages
```

## Local AI doesn't answer

`vikix ai status` says whether Ollama is running and which model is loaded. Not running: `vikix ai setup` starts it (it starts with the desktop from then on), and its log is `~/.local/state/vikix/ollama.log`. Slow: that's the CPU; a smaller model (`vikix ai models`) answers faster, and `vikix ai stop` frees the memory a big one holds.

## `llm` doesn't answer

- **`No key found - add one using 'llm keys set anthropic'`**: don't; that makes a second copy of the key. Use `vikix ai key set anthropic`, then open a new terminal (keys reach new shells, not the one already open).
- **A connection error** with a local model: Ollama isn't running; `vikix ai status`, then `vikix ai setup`.
- **Not sure which model it uses**: `llm models default`. `vikix ai llm` explains its choice; `vikix ai llm --default MODEL` sets yours.

## `vikix eval` fails

- **Exit 2** means it couldn't reach StumpWM: it isn't running, or a menu or prompt is open. Close it and try again.
- **`error: …`** is an error in the Lisp you sent; the desktop is fine.

## Asking for help

Ask the agent first. `vikix diagnose` (or Super+m → *Something's wrong? Ask the agent*) writes a report of what's going on and hands it to your AI agent, asking what's wrong and how to fix it. The agent asks before it changes anything, and a snapshot is taken first, so `vikix undo` takes its changes back.

To ask a person, open an issue at github.com/vukini/vikix and attach the report `vikix debug` writes:

```sh
vikix debug            # writes ~/vikix-debug-<date>.txt, readable only by you
less ~/vikix-debug-*.txt
```

It has Vikix's version and checkout, the system, the hardware and screens, your features, what `vikix doctor` says, the services, and the ends of the logs: the session's (`~/.local/state/vikix/session.log`), the last install and update (`~/.local/state/vikix/logs/`), and X's errors. Your API keys, passwords, home folder, user name and machine name are taken out before anything is written, and the finished file is searched for keys once more. Still, read it before you share it: nothing is sent anywhere by itself.
