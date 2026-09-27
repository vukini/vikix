# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0.

## Features

1. **A default wallpaper and a picker**, and a wallpaper per theme.
2. **Printing** (CUPS).
3. **Backups beyond config files.** For example restic to a USB drive; `vikix snapshot` only covers `config/yours.list`.
4. **A short power menu on its own key.** Suspend, reboot and power off sit at the bottom of a 25-entry menu.
5. **Bluetooth in the bar.**

## To look into

1. **The lock screen once showed the desktop in the VM.** On 2026-09-27 xss-lock's `i3lock` had been running for two hours in `void-vm` (picom on xrender with the 0.23.0 starter), yet screenshots showed the desktop, with the bar's clock stale, and rofi couldn't grab the keyboard. A fresh lock covered the screen in every test afterwards: with and without picom, after a notification, a new window, StumpWM rearranging, a dark screen and rofi. Find what raises windows over `i3lock` (a pen-tester review in the VM, leaving it locked for a long idle).
