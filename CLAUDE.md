# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Vikix is an opinionated desktop layer for **glibc Void Linux** built around **StumpWM**: Void, supercharged. It was inspired by Omarchy but is its own thing: credit Omarchy as the inspiration, but don't call Vikix "Omarchy for Void". It is not a distribution; it's a set of bash install stages run on top of a plain Void install, plus the config it puts in place and a `vikix` command that keeps it current. Repo: github.com/vukini/vikix (MIT).

This folder sits inside an Obsidian vault, but it is a code repo: the vault's note conventions (frontmatter, tags, `_Index_of_*`) don't apply here. The `vikix-*.zip` files are old releases and are gitignored.

`site/` is the website, vikix.dev: static pages (`index.html`, `gallery.html`) sharing `site.css`, screenshots in `site/shots/` (each scene as `NAME-void.webp` and `NAME-paper.webp`, 960px copies in `small/`), no build, published by `.github/workflows/pages.yml` on each push that touches `site/` or `VERSION` (the workflow writes `VERSION` into the page). When a release adds something a visitor would care about (a key, a feature card), update the page in the same commit.

`docs/` holds the user's guides (the map of files, how it fits together, customizing, fixing). They name real paths, keys, variables and commands: when a change moves or renames one, update the guide in the same commit. `40-config` also makes them an Info manual, `~/.local/share/info/vikix.info` (`info vikix`, Emacs `C-h i`), through `lib/md2texi.py`, which knows only the Markdown the guides use; `tests/info.sh` fails on a broken link, a page missing from `docs/README.md`'s table, or a makeinfo warning.

`TODO.md` lists planned features and cleanups. Read it when asked what's next, and remove an item in the commit that ships it.

## Checking changes

No build step. The tests are scripts in `tests/`, and `.github/workflows/test.yml` runs the same scripts on GitHub (on each push and weekly):

```sh
tests/run.sh                  # about two minutes: lint, lisp, battery, home, services, backup (with restic), image, theme, bar, rofi, wallpaper, examples, drives, firmware, fingerprint, updates, notifications, idle, capture, nightlight, update, windows, ai, ai-local, llm, ai-keys, agents, swank (with Quicklisp), webapp, features, welcome, menu, info, and on Void packages + dry-run
tests/run.sh --all            # plus editors: Emacs and Neovim configs from scratch (minutes, network)
tests/lint.sh                 # bash -n, executable bits, shellcheck -S warning (must stay at zero)
DRY_RUN=1 bash install/<stage>.sh     # one stage, printing instead of changing
```

`lint.sh` uses `shellcheck` from PATH, or `uvx --from shellcheck-py shellcheck` when it isn't installed. A deliberate shellcheck exception gets a `# shellcheck disable=SCxxxx  # why` comment on the line before. A new kind of breakage found by hand should become a check in the matching test. Every test starts with `export VIKIX_SWANK_PORT=9`, so nothing it runs (a theme refresh, a doctor, an update's reload) reaches the live desktop's Swank; lint enforces it (it once sent test passwords to the real Swank and stopped it).

`DRY_RUN=1` works because every system change goes through `run` in `lib/common.sh`, which prints instead of executing. Any new change to the system must go through `run` (or check `DRY_RUN` itself, as `ensure_block` does), or dry runs lie.

Real testing happens in a VM. The dev machine has a libvirt VM `void-vm` (`virsh -c qemu:///system`) with the QEMU guest agent running, so commands can run inside the guest via `virsh qemu-agent-command void-vm '{"execute":"guest-exec",...}'` (then `guest-exec-status` for output). Inside the VM, the checkout is `~/vikix` and is updated with `git pull` or `vikix update`.

## Architecture

**The install is the base, then features** (from 0.47). `install.sh` runs `STAGES` in order: the base lists (every list no feature names), sound, laptop hardware, the login. It writes an empty choices file on a fresh machine (a machine with a migrations record keeps what it had), and `--with NAMES` then runs `vikix add` for them in the same run. The stages up to the login stop at the first failure; those in `GO_ON` (and the features) carry on and are summarised. It asks for sudo once (`sudo_keepalive`) and logs to `~/.local/state/vikix/logs/`. `install-1.sh` is the same as `install.sh`; `install-2.sh` runs `vikix add everything` (both kept for older instructions). A dry run keeps the choices it would write in `VIKIX_DRY_CHOICES`, so its stages see them.

**Stages** (`install/NN-name.sh`) are run with `bash` and each sources `lib/common.sh`. Each must be safe to re-run: check first, then change. `vikix add` re-runs `10-packages` (the new feature's lists), `20-services`, and the editors', languages' and `~/dev` stages when an editor or a language comes. `vikix update` re-runs only `10-packages`, `20-services`, `40-config`, `45-editors`, `65-languages`, `67-dev`, then migrations; a failed stage is reported at the end and doesn't stop the rest. Shared steps live in `lib/common.sh` (`enable_service`, `ensure_group`, `problem`, …); use them rather than repeating the code.

**Data files, not code, for what gets installed:** `packages/*.list` (one list per concern; `lang-*.list` one per language), `features.list` (what `vikix add`/`remove` offer: each feature's lists, what it needs, and for some a setup command; a list no feature names is the base, installed everywhere; `optional/*.list` only ever come through a feature) and `bundles.list` (essentials, developer, everything), with the user's choices in `~/.config/vikix/features` (`lib/features.sh` reads them; no file means everything, as before 0.46), `services.list` (runit services), `mirrors.list` (mirrors `05-mirror` times), `config/yours.list` (files the snapshot history covers), `themes/*.theme` (colour palettes; `vikix theme` writes them out per program and StumpWM reads them), `dev/<language>/` (what `67-dev` puts in `~/dev`: `README.md` with a `<!-- tools -->` line it fills from `tools.list`, rewritten every update, and `examples/`, copied once). List files allow `#` comments; read them with `read_list`.

**Migrations** (`migrations/<unix-time>.sh`, see `migrations/README.md`). A fresh install gets changes from the stages; machines already installed only get them through a migration, which `vikix update` runs once each, oldest first, and records in `~/.local/state/vikix/migrations/`. `90-finish` marks all existing migrations as applied on a fresh install. So: if a change to a stage must reach existing machines and `vikix update` doesn't already re-run that stage, add a migration. Start it with a `# Why:` comment, and make it safe to run twice.

**File ownership** (the central rule, enforced by `40-config`):
- *Vikix's files* are symlinked into this checkout with `link_managed` (StumpWM `init.lisp` and `vikix/` layer, `.xinitrc`, `vikix.bash`, `bin/*` into `~/.local/bin`, the fontconfig alias, the Claude skill). Editing them here changes every install on the next `vikix update`.
- *The user's files* are copied once with `copy_user` and never overwritten (`user.lisp`, alacritty/picom/dunst/rofi configs, keyboard file, `.Xresources`). Changing a starter file in `config/` only affects new installs.
- Anything in the way is moved to `<name>.vikix-bak.<time>`, never deleted. Blocks in shared files like `~/.bashrc` go through `ensure_block`.
- *API keys* are neither: `vikix ai key set` keeps them in `~/.config/vikix/secrets/` (700, files 600), `lib/secrets.sh` exports them (the session and every shell), and the snapshot history never records that folder, whatever `yours.list` says (`yours_exclude` in `bin/vikix`, rewritten at every snapshot). Never print a key, and never let `set -x` run where one is read.

**Session and window manager.** Void has no StumpWM package: `30-lisp` installs Quicklisp and `lib/build-stumpwm.lisp` builds `~/.local/bin/stumpwm` with Swank inside. Login on tty1 starts X; `.xinitrc` runs `bin/vikix-session` under `dbus-run-session`, which starts the background programs (pipewire, dunst, picom, guest agents, …) and then StumpWM. `config/stumpwm/init.lisp` loads the layer files in `config/stumpwm/vikix/` in a fixed order (theme → groups → commands → windows → keys → help → webapps → modeline → swank-guard → swank), each wrapped so one broken file doesn't kill the desktop, then the user's `user.lisp` last.

**Live WM access.** Swank listens on `127.0.0.1:4004`; `vikix eval '(form)'` (`bin/vikix-eval`, Python) runs Lisp in the running StumpWM, in the `STUMPWM` package. It has a password, `~/.slime-secret` (made by `40-config`), sent raw as the first packet, as SLIME does; `swank-guard.lisp` keeps a wrong password from killing Swank's accept thread. The Windows VM is on the NAT bridge virbr0 (0.41.0), so it can't reach 127.0.0.1; before that it was on passt, which maps the guest's gateway to host loopback, which is why Swank got its password. Still, any new local service should authenticate, and never go on passt. `drop_keys` (lib/common.sh) clears API keys from the environment in the installer and `vikix update`.

**Snapshots of the user's files.** `vikix snapshot/changes/history/undo` keep a separate git repo at `~/.local/state/vikix/yours.git` whose work tree is `$HOME`, limited to `config/yours.list`. `vikix agent` snapshots before starting Claude Code.

**The installed agent's skill.** `config/claude/skills/vikix/SKILL.md` is linked to `~/.claude/skills/vikix` on installed machines and guides Claude Code running *on* a Vikix desktop (OpenCode reads it there too). `bin/vikix-agent --write-guide` (40-config, and every `vikix agent`) turns it into `~/.local/share/vikix/AGENTS.md` for the other agents (Codex, Gemini, Aider), so it stays the one source. Update it when commands, keys or file ownership change.

## Conventions

- Scripts: `set -euo pipefail`, print with `say`/`warn`/`die`, check `pkg_installed` before installing. Watch `pipefail` with assignments from pipelines that may legitimately fail (add `|| true`). Scripts run directly must be executable in git (`100755`).
- Comments explain *why* (Void quirks, ordering reasons), in plain short sentences. README.md is written the same way, with a table row per stage and per package list; keep it in step with the code.
- Releases: bump `VERSION`, commit as `Vikix X.Y.Z: <summary>`, and tag `vX.Y.Z`. The user pushes from their own terminal (`git push --follow-tags`), since their SSH key needs a passphrase that Claude Code's shell can't supply.
- Void specifics: runit services are enabled by symlinking `/etc/sv/<name>` into `/var/service/`; xbps repository overrides go in `/etc/xbps.d/` (same filename as in `/usr/share/xbps.d/`); `xbps` must be updated before other installs on a fresh system.
