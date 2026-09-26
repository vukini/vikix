# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0.

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
