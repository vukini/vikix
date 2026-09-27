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

If it stops at **pulling Vikix**, the checkout has changes of its own:

```sh
git -C ~/vikix status     # what's changed
git -C ~/vikix stash      # set them aside, then vikix update again
```

To run one install stage again on its own (each is safe to re-run):

```sh
~/vikix/install.sh --only 40-config
~/vikix/install.sh --list      # all the stages
```

## `vikix eval` fails

- **Exit 2** means it couldn't reach StumpWM: it isn't running, or a menu or prompt is open. Close it and try again.
- **`error: …`** is an error in the Lisp you sent; the desktop is fine.

## Asking for help

Open an issue at github.com/vukini/vikix with:

- `vikix version`
- what `vikix doctor` says
- the relevant log: `~/.local/state/vikix/session.log` for the desktop, `~/.local/state/vikix/logs/` for an install or update
