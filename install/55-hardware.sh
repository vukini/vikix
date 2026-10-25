#!/usr/bin/env bash
# 55-hardware — the laptop pieces that need root and can't be a package line.
#
#   - touchpad: tap to click, natural scrolling (config/x11/40-libinput.conf
#     into /etc/X11/xorg.conf.d; takes effect at the next X start)
#   - keys put right in udev's hardware database (config/udev/90-vikix-keys.hwdb
#     into /etc/udev/hwdb.d: the ROG Flow Z13's F6 made Print)
#   - Intel microcode: intel-ucode (installed by 10-packages from the
#     nonfree repo) only takes effect once the initramfs is rebuilt with
#     it inside, so the kernel package is reconfigured once per
#     intel-ucode version. Skipped on non-Intel CPUs.
#   - ~/Documents, ~/Downloads ... created if missing (xdg-user-dirs)

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

# --- touchpad -------------------------------------------------------------
conf=/etc/X11/xorg.conf.d/40-libinput.conf
if cmp -s "$VIKIX_DIR/config/x11/40-libinput.conf" "$conf"; then
  say "touchpad settings already in place"
else
  say "installing touchpad settings (tap to click, natural scrolling)"
  run sudo install -Dm644 "$VIKIX_DIR/config/x11/40-libinput.conf" "$conf"
fi

# --- keys put right (udev's hardware database) ------------------------------
# The file says which keyboards and why; a machine without them compiles a
# line that never matches. The change reaches a keyboard that is plugged in
# through a change event for every keyboard, after which X rebuilds its
# keymap and drops the layout's options, so on a running desktop the
# keyboard settings (~/.config/vikix/keyboard) are applied again.
hwdb=/etc/udev/hwdb.d/90-vikix-keys.hwdb
if cmp -s "$VIKIX_DIR/config/udev/90-vikix-keys.hwdb" "$hwdb"; then
  say "udev's keys file already in place"
else
  say "installing udev's keys file (the ROG Flow Z13's F6 as Print)"
  run sudo install -Dm644 "$VIKIX_DIR/config/udev/90-vikix-keys.hwdb" "$hwdb"
  run sudo udevadm hwdb --update
  run sudo udevadm trigger --subsystem-match=input --property-match=ID_INPUT_KEYBOARD=1 --action=change
  if [ -n "${DISPLAY:-}" ]; then
    run "$VIKIX_DIR/bin/vikix-keyboard"
  fi
fi

# --- USB4 and Thunderbolt drives (udev) --------------------------------------
# A USB4 SSD comes through Thunderbolt and waits, showing no disk, to be
# authorized; the rule does that as it arrives when the IOMMU protects
# memory, and tells udisks the disk behind it is a drive to mount (it calls
# a PCIe disk a system drive, and udiskie leaves those). Reloaded at once,
# and a drive waiting already gets its add event again; a disk already
# there is told its new standing with a change event.
rule=/etc/udev/rules.d/70-vikix-thunderbolt.rules
if cmp -s "$VIKIX_DIR/config/udev/70-vikix-thunderbolt.rules" "$rule"; then
  say "udev's Thunderbolt drives rule already in place"
else
  say "installing udev's Thunderbolt drives rule (a USB4 SSD authorized and mounted like a stick)"
  run sudo install -Dm644 "$VIKIX_DIR/config/udev/70-vikix-thunderbolt.rules" "$rule"
  run sudo udevadm control --reload
  if [ -d /sys/bus/thunderbolt/devices ]; then
    run sudo udevadm trigger --subsystem-match=thunderbolt --action=add
  fi
  for removable in /sys/bus/pci/devices/*/removable; do
    [ -f "$removable" ] && [ "$(cat "$removable")" = removable ] || continue
    run sudo udevadm trigger --subsystem-match=block --parent-match="${removable%/removable}" --action=change
  done
fi

# --- microcode in the initramfs --------------------------------------------
if grep -q GenuineIntel /proc/cpuinfo 2>/dev/null && pkg_installed intel-ucode; then
  ucode=$(xbps-query -p pkgver intel-ucode)
  marker="$VIKIX_STATE/initramfs-$ucode"
  if [ -e "$marker" ]; then
    say "initramfs already rebuilt for $ucode"
  else
    # Every installed kernel package: linux6.12, linux6.6 ...
    kernels=$(xbps-query -l | awk '$2 ~ /^linux[0-9]+\.[0-9]+-/ { sub(/-[^-]*$/, "", $2); print $2 }')
    for k in $kernels; do
      say "rebuilding the initramfs of $k with the microcode inside"
      run sudo xbps-reconfigure -f "$k"
    done
    run mkdir -p "$VIKIX_STATE"
    run touch "$marker"
  fi
else
  say "not an Intel CPU or intel-ucode not installed; no microcode step"
fi

# --- the standard folders --------------------------------------------------
if command -v xdg-user-dirs-update >/dev/null; then
  run xdg-user-dirs-update    # creates only what is missing; keeps existing choices
fi

say "hardware settings in place (touchpad applies at the next X start)"
