#!/usr/bin/env bash
# 55-hardware — the laptop pieces that need root and can't be a package line.
#
#   - touchpad: tap to click, natural scrolling (config/x11/40-libinput.conf
#     into /etc/X11/xorg.conf.d; takes effect at the next X start)
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
