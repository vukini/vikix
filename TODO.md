# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0.

## Features

1. **Fingerprint (fprintd), for sudo and unlocking the screen.** An optional step that does nothing unless a reader is found. Enrol with `vikix fingerprint`. The PAM lines go in with ensure_block's care, and the password always keeps working. i3lock may still need the password; if so, say so plainly.
2. **A Windows VM for Windows-only work software.** An optional stage: virt-manager, qemu, libvirt (a runit service), the user in the libvirt group, and a README section on making a Windows guest with virtio drivers and a shared folder.
3. **OCR and a colour picker, in the Super+Ctrl+Print menu.** "Text from an area": maim -s, then tesseract-ocr (and its English data), then the clipboard and a notification. "Pick a colour": xcolor, with the hex to the clipboard.
4. **A firewall (ufw).** Deny incoming, allow outgoing, allow SSH. A runit service, and a Super+m entry that shows the status.
5. **`vikix debug`.** One file with the session and install logs, doctor's output, VERSION, the checkout's git status, uname, lspci/lsusb and xrandr, to attach to an issue or hand to Claude.
6. **More themes.** Three or four more (Gruvbox, Nord, Tokyo Night, a high-contrast one), each with a wallpaper. Then make Emacs and Neovim follow `vikix theme`.
7. **Whole-system undo.** When / is btrfs: snapper snapshots before each `vikix update`, and `vikix rollback` notes. Skip cleanly on ext4.
8. **An install menu.** `vikix pkg add` and `vikix pkg drop`: a fuzzy search over `xbps-query -Rs` with a preview, installing or removing with xi or xr. Also a Super+m entry. Dropping a package Vikix's lists name must stick: today `vikix update` installs it again (docs/customize.md says so). A list of your own, `~/.config/vikix/packages-skip`, read by `10-packages`, and in `yours.list`; then update the docs.
9. **The guides on vikix.dev.** A Docs link on the site to `docs/` on GitHub, or the four pages built into the site. Same words either way: `docs/` stays the source.

## To look into

1. **The lock screen once showed the desktop in the VM.** On 2026-09-27 xss-lock's `i3lock` had been running for two hours in `void-vm` (picom on xrender with the 0.23.0 starter), yet screenshots showed the desktop, with the bar's clock stale, and rofi couldn't grab the keyboard. A fresh lock covered the screen in every test afterwards: with and without picom, after a notification, a new window, StumpWM rearranging, a dark screen and rofi. A second clue the same day: a picom that had run for a while in the VM stopped showing newly opened windows (rofi's area showed the wallpaper) until it was restarted, and a fresh picom was fine. So the likelier story is picom showing a stale frame, not windows above the lock; the X screen under it may well have been locked. Still to find: what makes picom stop repainting in the VM (long idle with vsync? the screen going dark for real?), and whether it ever happens on real hardware. A pen-tester review in the VM, left locked through a long idle, would settle it. Later that day, testing Lazarus (Qt5) in the VM: its newly opened windows were often left unpainted by picom (xrender), though StumpWM had them and they showed at once without picom or after restarting it; rofi was always fine. Turning off open/close fading helped once and not the second time, so that isn't it. Since then the picom starter never fades i3lock, so a lock screen can't be caught half faded in. Next to try: `use-damage = false` in the picom starter, the usual fix for picom's xrender backend in VMs, where partial repaints get missed; then see if the stale frames stop.
