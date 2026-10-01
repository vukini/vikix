# When something breaks

Start with:

```sh
vikix doctor
```

It checks the programs, services, links, the snapshot history, Swank's password and `vikix eval`, the agent's guide, USB drives, and the editors you chose (whether Emacs has Vikix's AI setup loaded, whether Neovim's plugins are installed and whose versions they are), and says what's missing.

## The install stopped

The one-line install (`curl -fsSL https://vikix.dev/install | bash`) checks the machine first, and stops before changing anything when:

- **it isn't Void**, or it's Void with musl: Vikix needs the glibc Void (voidlinux.org/download)
- **you're root**: run it as your normal user; it asks for sudo when it needs it
- **`~/vikix` is there but isn't a clone of Vikix**: move it aside and run it again

Once it's running, the stages up to the login stop at the first one that fails, since each needs the one before. It says which, and the whole run is in `~/.local/state/vikix/logs/install-<time>.log`. Fix what it says, then run that stage alone, and the install again; finished steps are skipped:

```sh
~/vikix/install.sh --only 30-lisp
~/vikix/install.sh
```

Sound, laptop hardware, a VM's guest tools and the features carry on past a failure, and the end of the run lists what failed.

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
- `Super+/` shows every key Vikix binds, grouped; `Super+F1` lists them, searchable. After `Ctrl+t`, wait a moment and StumpWM lists its own keys.
- In a VM, the host may take the key before the guest sees it: on Windows, Super+L locks Windows.

## Something's missing from the menu or the launcher

- **An entry isn't in Super+m** (JupyterLab, Zeal, Printers, Windows, Local AI, Dictation, Voice, Dropbox): it's left out until its feature is here. `vikix features` shows what you have; `vikix add python` (or `printing`, `windows`, `local-ai`, `dictation`, `voice` …) brings it, and the entry with it.
- **Super+m → *Apps* says "No apps yet"**, or a program is missing from it: each entry shows once its program is installed. `vikix add video` (or `graphics`, `blender`, `study`, `passwords`, `phone`, `cli-extras`) brings them.
- **A program isn't in the launcher (Super+d)**: the launcher lists programs that come with a `.desktop` file. Type its name as the file gives it: JupyterLab also answers to `jlab`. A program without one (most command-line tools) runs from a terminal, or from Super+m if Vikix has an entry for it.
- **The welcome didn't open, or you closed it**: `Super+m` → *Welcome*, or `vikix welcome` in a terminal.

## Adding a feature failed

`vikix add` names what didn't finish (a download, most often). The feature is recorded all the same, so `vikix add NAME` again, or the next `vikix update`, finishes the job. A feature with its own setup, like `windows`, is recorded only once its setup succeeds: it says what it needs first (KVM switched on in the BIOS, 40 GB free).

Dictation and voice build or download their parts once, as you, with no password. If `vikix add dictation` stops at the build, the end of the build's output is shown, and all of it is in `~/.local/state/vikix/logs/whisper-build.log`. A download that fails its checksum is deleted, never used; run the setup again.

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

In a terminal, `vikix undo` lists the files it will put back and asks first, so you can say no and choose another snapshot. An undo takes a snapshot of its own first, so `vikix undo` again takes it back. Then `Super+m` → *Reload config*, or log in again for things read at login (`.Xresources`, the idle times).

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

## Something on the network can't reach this computer

The firewall is on (`vikix firewall` shows it and its rules): only SSH, and the ports it was told about, are let in. A phone sending a file, another computer opening a server you started, a game: each needs its port let in, `vikix firewall allow PORT` (`53317` for LocalSend, if it was installed after the firewall went on). `vikix firewall close PORT` shuts it again. To check that the firewall is the cause, `vikix firewall off` for a minute, then `vikix firewall on`.

## The network feels slow

First see whether it's the connection or one program. `ping -c 5 1.1.1.1` should answer in tens of milliseconds with no loss; a speed test is `curl -o /dev/null -w '%{speed_download}\n' https://speed.cloudflare.com/__down?bytes=25000000` (bytes a second; times 8 for bits). Then Super+m → *Network use* (`sudo nethogs`) shows, like top, which program is sending and receiving how much: `m` switches between rates and totals, `q` leaves. If the connection is fast but a `git push` or `pull` is slow and nethogs shows `ssh` doing nothing, git is waiting, often for the SSH key's passphrase: `ssh-add -l` should list the key, and `ssh-add` adds it.

## Local AI doesn't answer

`vikix ai status` says whether Ollama is running and which model is loaded. Not running: `vikix ai setup` starts it (it starts with the desktop from then on), and its log is `~/.local/state/vikix/ollama.log`. Slow: that's the CPU; a smaller model (`vikix ai models`) answers faster, and `vikix ai stop` frees the memory a big one holds.

## `llm` doesn't answer

- **`No key found - add one using 'llm keys set anthropic'`**: don't; that makes a second copy of the key. Use `vikix ai key set anthropic`, then open a new terminal (keys reach new shells, not the one already open).
- **A connection error** with a local model: Ollama isn't running; `vikix ai status`, then `vikix ai setup`.
- **Not sure which model it uses**: `llm models default`. `vikix ai llm` explains its choice; `vikix ai llm --default MODEL` sets yours.

## `vikix eval` fails

- **Exit 2** means it couldn't reach StumpWM: it isn't running, or a menu or prompt is open. Close it and try again.
- **`… is another user's (uid N), not StumpWM's: the password isn't sent`**: something of another user's is listening on port 4004, most likely because your StumpWM isn't running (you're on a text console). `vikix eval` won't send it your Swank password. Start the desktop, or find out what that is: `ss -ltnp 'sport = :4004'`.
- **`error: …`** is an error in the Lisp you sent; the desktop is fine.

## An editor doesn't work

[Neovim and Emacs](editors.md#when-an-editor-doesnt-work) has what to try: the plugins' log, `eq` for Emacs without its config, and the language servers. `vikix doctor` says whether Emacs has Vikix's AI setup loaded and whether Neovim's plugins are in place. After `vikix update`, an Emacs that's running gets Vikix's new AI setup without a restart; one started before Vikix 0.59 is told to `emacs-restart`.

## The agent doesn't have the desktop's tools

After `vikix mcp register`, restart the agent: it reads its list of servers when it starts. Then `vikix mcp status` says whether Claude Code has it, which risky tools are on, how many servers are running and on which version, and the last calls. For Codex, Gemini CLI and OpenCode, `vikix mcp register` prints the lines to put in their settings yourself. A tool that says it was refused names what it would take (a workspace that exists, a theme you have); every call is in `~/.local/state/vikix/mcp.log`.

## Asking for help

Ask the agent first. `vikix diagnose` (or Super+m → *Something's wrong? Ask the agent*) writes a report of what's going on and hands it to your AI agent, asking what's wrong and how to fix it. The agent starts by reading and proposing (Claude Code in its plan mode, Codex read-only), asks before it changes anything, and a snapshot is taken first, so `vikix undo` takes its changes back. Its reports are kept in `~/.local/state/vikix/diagnose/` (the last five).

To ask a person, open an issue at github.com/vukini/vikix and attach the report `vikix debug` writes:

```sh
vikix debug            # writes ~/vikix-debug-<date>.txt, readable only by you
less ~/vikix-debug-*.txt
```

It starts with the problems at a glance (the lines in the logs that say something failed), then Vikix's version and checkout, your last snapshots, the system, the hardware and screens, your features, what `vikix doctor` says, the services, and Vikix's own lines from the logs: the session's start and end (`~/.local/state/vikix/session.log`), the last install and update (`~/.local/state/vikix/logs/`), and X's errors.

What's left out: other programs' log lines (a browser's carry the pages you had open), web addresses' paths (the site stays), secrets of every kind (API keys, tokens, passwords, private keys, whatever their shape), your home folder, user name, full name and machine name. The finished file is checked once more, and the command fails if anything secret-looking is left. Still, read it before you share it: nothing is sent anywhere by itself.

On GitHub, open a new issue and drag the file into the "Debug report" box: it's too long to paste.
