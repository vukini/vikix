# Bugs

Small known problems, not yet fixed. Each says what happens, what is known, and the next step. A fix removes its entry in the commit that ships it. (Larger planned work is in `TODO.md`; ideas in `IDEAS.md`.)


## Esploro's iPhone under Drives: not yet tried with a phone

Noted 2026-10-05, by the guides check; the packages added 2026-10-11 (Vikix 0.72.x).

**What happens.** Esploro shows an iPhone under Drives and opens it with a click. `optional/esploro.list` now brings what its `src/phone.lisp` runs (libimobiledevice for `idevice_id`, `ideviceinfo` and `idevicepair`; ifuse; usbmuxd, whose udev rule starts the daemon when a phone is plugged in), and the README says so; no phone has been plugged into a fresh install yet.

**Next step.** Plug an iPhone into a machine that has the feature, trust the computer on the phone, and see the folder open in Esploro; if it doesn't, `idevicepair pair` and `ifuse /tmp/phone` by hand say which step is missing.

## The screen tests fail on a starved machine, and pass alone

Noted 2026-10-04 for `tests/main.sh` (twice that day, in parallel runs at a load of 15 to 25); seen again 2026-10-10 for registry, viri, docs and house, in a release's run beside the tester's and another session's, each passing alone straight after.

**What happens.** A test that drives a real StumpWM on a hidden screen (`tests/lib/wm.sh`) is reported FAILED when the machine is full, and passes alone on the same commit. The slots (`tests/run.sh`, one test a core across every session) bound the tests' own load, and `main` hasn't failed in a parallel run since; what fills the machine now is the rest (three agents, Emacs, a tester's run of two hours).

**What's known (2026-10-11).** Reproduced on purpose: `main` under twelve busy processes on four cores fails from `Super+Shift+o` on, and the checks after it that drive the desktop through `ask` (a `vikix-layout-pick` by `run-commands`) fail too, one with *StumpWM's main thread did not answer within 10 s* (`*vikix-eval-timeout*`, swank.lisp). Making `key` wait for a read the main thread answers changed nothing, and the reason is in `socket.lisp`: a read is given to the main thread for one slice, and when the main thread used no processor time in that slice it is taken for idle (a menu open) and the client thread answers the read itself; on a starved machine the main thread used none because it wasn't scheduled, so the read comes back at once, before the key's command ran. The dialog's fixed two seconds in `main` became a poll (0.72.x), which was right in itself.

**Next step.** Two things, either enough for the tests: tell starvation from idleness in `vikix-socket-in-main` (the main thread's state from `/proc/self/task/TID/stat`, running or waiting, beside its ticks), so a read waits for a busy-but-unscheduled main thread; or let the tests give their StumpWM a longer `*vikix-eval-timeout*` at `wm_start` and a `key` that waits for the main thread. Until then a screen test that fails in a full run and passes alone is load, not the change (`vikix-release-tests`: run the failed ones alone before releasing again).

## Alacritty sometimes fails to copy ("Failed to set new owner of XCB selection")

Noted 2026-10-02. Minor.

**What happens.** Now and then a copy in Alacritty (selecting text, or Ctrl+Shift+c) shows a yellow warning: `[WARN] Unable to store text in clipboard: Failed to set new owner of XCB selection`, with the log `/tmp/Alacritty-<pid>.log`. That copy is lost; copying again works.

**What it means.** Alacritty (copypasta / x11-clipboard) asks X to make it the selection's owner, then checks; the check fails when another client took the selection in between.

**Ruled out (2026-10-02).** clipmenud doesn't take ownership (`CM_OWN_CLIPBOARD=0`, clipmenu 6.2.0). No other clipboard manager or sync tool runs (autocutsel, GPaste, CopyQ, greenclip, KDE Connect, barrier). The `xclip` processes holding PRIMARY and CLIPBOARD were ordinary ones (a screenshot, a copy from a terminal).

**Suspect.** `virt-viewer` on the Windows VM shares the clipboard over SPICE, and may grab the host clipboard at the same moment when the guest echoes a copy. Not confirmed: Alacritty's log times are its running time on the monotonic clock, which stops during suspend, so they can't be matched to when the VM was open.

**Next step.** Note whether the VM window is open when it happens; or run a small logger (clipnotify, then the selection owner's window and its client, via `vikix eval` and `xlib:selection-owner`) until the next warning names the client. If it's SPICE: switch off clipboard sharing in the viewer, or accept a rare second copy.

## agent-waiting: a question with choices may arrive late (to confirm)

Noted 2026-10-04, with the plugin's rewrite (Vikix 0.71.160).

**What happens.** Nothing seen yet. The plugin's hook for Claude Code's AskUserQuestion (`PreToolUse` with that matcher → `agent-waiting question`) was written without being seen to fire: a throwaway `claude -p` session can't show such a question.

**What's known.** `PermissionRequest` and `Stop` were checked on Claude Code 2.1.289 and fire at once with what the plugin reads. If the question hook doesn't fire, the note comes from Claude's own notification some seconds later, without the question's words.

**Next step.** The next time a session asks a question with choices while its window isn't in front, look at the bar and at `~/.local/state/vikix/agents/`: the note's third line should be the question.
