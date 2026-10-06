# shellcheck shell=sh
# vikix-live.sh, in /etc/profile.d on Vikix's stick only (installer/build-image.sh
# puts it there). The first screen logs in by itself and starts the
# installer; the other screens (Alt+F2 ...) are plain shells.

if [ "$(tty)" = /dev/tty1 ] && [ ! -e /run/vikix-installer-started ]; then
  # A big font on a big screen: at 2560 pixels across, the console's own
  # letters are about a millimetre high.
  w=$(cut -d, -f1 /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo 0)
  [ "${w:-0}" -ge 2000 ] && setfont ter-v32n 2>/dev/null
  sudo touch /run/vikix-installer-started
  sudo vikix-installer
fi

if [ "$(tty)" = /dev/tty1 ]; then
  cat <<'EOF'

  Vikix's stick.
    sudo vikix-installer   install Void and Vikix on this computer
    vikix-hwreport | less  what this machine is, and what was found
    nmtui                  the network
  Other screens: Alt+F2 to Alt+F6 (user anon or root, password voidlinux).

EOF
fi
