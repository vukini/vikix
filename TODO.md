# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0.

## Cleanups

1. **One failed stage stops `vikix update` before the migrations.** `bin/vikix` runs each stage under `set -e`, so a network hiccup in `45-editors` skips `cmd_migrate`. Collect the failures and report them at the end, as part two of the install does.
2. **`vikix update` doesn't re-run `20-services`.** A service that arrives with a new package stays off unless a migration turns it on. The stage is cheap and safe to re-run.
3. **Shared helpers for code copied between stages.** Adding the user to a group (20, 25, 70), enabling a runit service (20, 25, 70) and `problem()` (00, 25) could become `ensure_group`, `enable_service` and `problem` in `lib/common.sh`.
4. **`40-config` lists the helper scripts by hand.** Loop over `bin/vikix-*` instead (skipping `vikix-eval` and `vikix-session`), so a new helper can't be left out. The header comment already misses `vikix-net`.
5. **One lock command.** `i3lock -c 1e1e2e` is typed in `keys.lisp`, `commands.lisp` and `vikix-session`, and the key can start a second locker next to the one `xss-lock` runs. Lock through `xset s activate` or `loginctl lock-session`, and take the colour from the theme.
6. **No hardcoded `~/vikix`.** `70-vm.sh`, `90-finish.sh` and `bin/vikix-jupyter` should print `$VIKIX_DIR`.
7. **Docs out of step with the code.**
   - CLAUDE.md says update re-runs 10/40/45/65; it also runs 67.
   - The README's `dev` row lists python3, which lives in `base.list`.
   - The README's list of Vikix's files leaves out the `bin/*` links and the fontconfig file.
8. **`vikix-eval` tidy-up.** Two comments on one branch contradict each other. A truncated reply raises IndexError, which the `except` doesn't catch, so the user sees a traceback.
9. **Sync the package index once.** `10-packages` syncs it up to three times per run.

## Tests

1. **Check the StumpWM Lisp.** Nothing reads `config/stumpwm/**/*.lisp` before login, so a missing paren only shows up on the desktop. Have `sbcl --non-interactive` read every form.
2. **Lint the Python.** `lint.sh` only picks up shell scripts; add `python3 -m py_compile bin/vikix-eval`.
3. **Test the battery warner.** `vikix-battery` has a `VIKIX_POWER_SUPPLY` hook for a test that doesn't exist yet.
4. **Test "safe to re-run" and undo.** Run `40-config` and `60-login` twice in a temporary HOME and compare the results; round-trip snapshot → edit → undo.

## Features

1. **Themes for the whole desktop that survive a restart.** The theme changes only StumpWM, and resets to `:void` at every start. Alacritty, dunst, rofi, the lock screen and the wallpaper should switch with it.
2. **Show waiting updates.** Put a mark in the bar, or send a notification, when xbps or Vikix has updates.
3. **Notification controls.** Keys and menu entries for dunst's history, close-all and do-not-disturb (`dunstctl`).
4. **Idle and power.** Screen off (DPMS), suspend when idle on battery, and a "keep awake" toggle for films and talks.
5. **More screenshot modes, and screen recording.** Whole screen and focused window, not just a dragged area.
6. **Night light** (gammastep or redshift).
7. **Emoji picker and calculator in rofi.**
8. **A default wallpaper and a picker.**
9. **Printing** (CUPS).
10. **Backups beyond config files.** For example restic to a USB drive; `vikix snapshot` only covers `config/yours.list`.
11. **A short power menu on its own key.** Suspend, reboot and power off sit at the bottom of a 25-entry menu.
12. **Bluetooth in the bar.**
