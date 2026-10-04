#!/usr/bin/env bash
# 20-services — switch on the runit services named in services.list.
#
# Void uses runit, not systemd: enable_service (lib/common.sh) links a
# service's folder into /var/service. `vikix update` runs this stage too,
# so a service whose package arrives with an update is switched on.
#
# earlyoom gets Vikix's settings first (config/earlyoom/conf: which
# program goes when memory runs out, and which never), so its first start
# has them; changed later, it is restarted.
#
# Also adds you to the 'video' group so brightnessctl can change the
# screen brightness without sudo, and, once cups is installed, to
# 'lpadmin', so adding a printer asks for no root password. Both take
# effect at your next login.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

# A package that works over D-Bus (avahi, bluez, ...) brings a policy file
# that lets it take its name on the system bus, and the running dbus-daemon
# doesn't read new ones until the next boot. A service switched on before
# then runs but can't be reached: avahi did, so nothing found printers. So
# D-Bus rereads its config once, before the first new service starts.
: "${VIKIX_DBUS_SOCKET:=/run/dbus/system_bus_socket}"      # tests move these
: "${VIKIX_POLKIT_RULES:=/etc/polkit-1/rules.d}"

# earlyoom's settings, before it's switched on below. Its folder is there
# once the package is; both files are readable, so comparing needs no sudo.
oom=$VIKIX_SV_DIR/earlyoom
if [ -d "$oom" ]; then
  oom_changed=
  for f in conf vikix-killed; do
    cmp -s "$VIKIX_DIR/config/earlyoom/$f" "$oom/$f" && continue
    mode=644; [ "$f" = vikix-killed ] && mode=755
    say "earlyoom: Vikix's $f, which program goes when memory runs out ($oom/$f)"
    run sudo install -m "$mode" "$VIKIX_DIR/config/earlyoom/$f" "$oom/$f"
    oom_changed=1
  done
  # Already running with the old settings: started again with the new.
  if [ -n "$oom_changed" ] && [ -e "$VIKIX_SERVICE_DIR/earlyoom" ]; then
    run sudo sv restart earlyoom >/dev/null 2>&1 || warn "earlyoom didn't restart; its new settings hold from the next boot"
  fi
fi
reloaded=
while IFS= read -r sv; do
  if [ ! -d "$VIKIX_SV_DIR/$sv" ]; then
    say "service $sv: its package isn't installed; skipped (vikix add or vikix update switches it on once it is)"
    continue
  fi
  if [ ! -e "$VIKIX_SERVICE_DIR/$sv" ] && [ -z "$reloaded" ] && [ -S "$VIKIX_DBUS_SOCKET" ]; then
    say "D-Bus rereads its config, so new services can use it"
    run sudo dbus-send --system --type=method_call --dest=org.freedesktop.DBus \
      / org.freedesktop.DBus.ReloadConfig || warn "D-Bus didn't reload; new services may need a reboot"
    reloaded=1
  fi
  enable_service "$sv"
done < <(read_list "$VIKIX_DIR/services.list")

ensure_group video "for screen brightness"
# cups makes the lpadmin group; without the feature printing, there is none.
if getent group lpadmin >/dev/null; then
  ensure_group lpadmin "to add and manage printers"
  # CUPS already lets lpadmin manage printers; this lets the Printers app
  # (cups-pk-helper) do the same without asking for a password.
  # Only polkit's own user can read rules.d, so the comparison needs sudo;
  # -n never asks (the password was asked at the start; a dry run has none
  # and just shows the install).
  rules=$VIKIX_POLKIT_RULES/50-vikix-printers.rules
  if ! sudo -n cmp -s "$VIKIX_DIR/config/polkit/50-vikix-printers.rules" "$rules" 2>/dev/null; then
    say "letting the lpadmin group manage printers in the Printers app ($rules)"
    run sudo install -D -m 644 "$VIKIX_DIR/config/polkit/50-vikix-printers.rules" "$rules"
  fi
fi
