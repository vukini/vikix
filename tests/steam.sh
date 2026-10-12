#!/usr/bin/env bash
# tests/steam.sh — vikix-steam, with stand-ins for xbps and /sys:
#
#   setup      reads the card from the drm tree and installs its Vulkan driver
#              in both widths (Intel: mesa-vulkan-intel and -32bit; NVIDIA with
#              the nvidia package: nvidia-libs-32bit and the multilib-nonfree
#              repository; nouveau: mesa's); switches on multilib before the
#              list, records the feature, installs the list through 10-packages,
#              writes the open-files limit for the user; refuses another
#              architecture before changing anything; goes on with a warning
#              for a card it doesn't know; a second run installs nothing again;
#              a dry run changes nothing and records nothing
#   status     a line a thing, ok or --
#   check      silent when Steam isn't chosen; exit 1 naming what's missing
#   uninstall  the card's 32-bit driver and the limit go; the 64-bit driver,
#              the repository and ~/.local/share/Steam stay
#   the Apps menu has Steam, features.list names the list and the commands
#
# Nothing real runs: sudo, xbps-query and xbps-uhelper are scripts in $t/bin
# that note how they were called; installed packages are the lines of
# $t/installed.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
export VIKIX_DRM="$t/drm" VIKIX_LIMITS_DIR="$t/limits"
mkdir -p "$HOME" "$t/bin" "$VIKIX_STATE"
calls="$t/calls"; installed="$t/installed"
: > "$calls"; : > "$installed"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
has()   { grep -q -- "$1" <<<"$2"; }
me=$(id -un)

# xbps-query: -l lists $t/installed as xbps does; -R knows every name; a
# bare name is installed when it's a line of the file.
cat > "$t/bin/xbps-query" <<EOF
#!/bin/sh
case \$1 in
  -l) while read -r p; do echo "ii \$p-1.0_1 a package"; done < "$installed" ;;
  -R) exit 0 ;;
  -*) exit 0 ;;
  *) grep -qx -- "\$1" "$installed" ;;
esac
EOF
# sudo: notes the call; an install adds the packages to the file, a remove
# takes them out; install(1) and rm run for real, under $t.
cat > "$t/bin/sudo" <<EOF
#!/bin/bash
echo "sudo \$*" >> "$calls"
case "\$1 \$2" in
  "xbps-install -y"|"xbps-install -Sy") shift 2; for p; do [ "\$p" = xbps ] || echo "\$p" >> "$installed"; done ;;
  "xbps-remove -y") shift 2; for p; do grep -vx -- "\$p" "$installed" > "$installed.new" || true; mv "$installed.new" "$installed"; done ;;
  "install -D") exec install "\${@:2}" ;;
  "rm -f") exec rm "\${@:2}" ;;
esac
exit 0
EOF
printf '#!/bin/sh\necho "${VIKIX_TEST_ARCH:-x86_64}"\n' > "$t/bin/xbps-uhelper"
chmod +x "$t/bin/xbps-query" "$t/bin/sudo" "$t/bin/xbps-uhelper"
export PATH="$t/bin:$PATH"
choices="$HOME/.config/vikix/features"
steam() { bash "$here/bin/vikix-steam" "$@"; }

# card DRIVER VENDOR [N] — a card in the drm tree, with an output beside it
# (card0-eDP-1), which has no device of its own.
card() {
  local n=${3:-0} d
  d="$VIKIX_DRM/card$n/device"
  mkdir -p "$d" "$VIKIX_DRM/card$n-eDP-1"
  echo "$2" > "$d/vendor"
  mkdir -p "$t/drivers/$1"; ln -sfn "$t/drivers/$1" "$d/driver"
}
reset() { rm -rf "$VIKIX_DRM" "$VIKIX_LIMITS_DIR" "$choices"; : > "$calls"; : > "$installed"; }
# before A B — A's first call comes before B's
before() { local a b; a=$(grep -n -- "$1" "$calls" | head -1 | cut -d: -f1); b=$(grep -n -- "$2" "$calls" | head -1 | cut -d: -f1); [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; }

# --- the data -----------------------------------------------------------------------
check "features.list names optional/steam with the setup and uninstall commands" \
  grep -q '^steam *| *optional/steam *| *| *vikix steam setup *| *vikix steam uninstall *|' "$here/features.list"
check "the Apps menu has Steam" grep -q '"Games (Steam)" *(run-shell-command "steam") "steam"' "$here/config/stumpwm/vikix/commands.lisp"
for p in steam libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit mesa-dri-32bit vulkan-loader-32bit; do
  check "the list has $p" grep -q "^$p " "$here/packages/optional/steam.list"
done

# --- an Intel laptop ----------------------------------------------------------------
reset; card i915 0x8086
out=$(steam setup 2>&1) || { echo "FAIL: setup on Intel failed: $out"; fail=1; }
check "setup names the card: $out" has 'Intel card (i915): mesa-vulkan-intel mesa-vulkan-intel-32bit' "$out"
check "multilib is switched on" grep -q '^sudo xbps-install -Sy void-repo-multilib$' "$calls"
check "multilib-nonfree isn't, for an Intel card" bash -c "! grep -q 'void-repo-multilib-nonfree' '$calls'"
check "multilib comes before the list" before 'void-repo-multilib' 'xbps-install -y steam'
check "the feature is recorded" grep -qx steam "$choices"
check "the list went in through 10-packages" grep -q '^sudo xbps-install -y steam libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit mesa-dri-32bit libva-32bit vulkan-loader vulkan-loader-32bit$' "$calls"
check "the card's driver, both widths" grep -q '^sudo xbps-install -y mesa-vulkan-intel mesa-vulkan-intel-32bit$' "$calls"
check "the limit is written for the user" grep -q "^$me	hard	nofile	524288$" "$VIKIX_LIMITS_DIR/50-vikix-steam.conf"
check "the limits file is readable by all" test "$(stat -c %a "$VIKIX_LIMITS_DIR/50-vikix-steam.conf")" = 644
check "setup ends with how to start" has 'Apps → Games (Steam)' "$out"

out=$(steam status 2>&1)
check "status: the repository is on: $out" has 'ok  repository void-repo-multilib is on' "$out"
check "status: steam is installed" has 'ok  steam is installed' "$out"
check "status: all the 32-bit libraries" has 'ok  the 32-bit libraries, all 8' "$out"
check "status: the card and its packages" has 'ok  mesa-vulkan-intel-32bit' "$out"
check "status: the limit" has 'ok  open files' "$out"
check "status: Steam hasn't run yet" has "Steam hasn't run yet" "$out"
out=$(steam check 2>&1) || { echo "FAIL: check with everything there failed: $out"; fail=1; }
check "check says all is well in a line" has 'Steam has its repository' "$out"

: > "$calls"
out=$(steam setup 2>&1) || { echo "FAIL: a second setup failed: $out"; fail=1; }
check "a second setup installs nothing again" bash -c "! grep -q 'xbps-install -y' '$calls'"

# Something taken away: check says what, and exits 1.
grep -vx mesa-vulkan-intel-32bit "$installed" > "$installed.new"; mv "$installed.new" "$installed"
out=$(steam check 2>&1) && { echo "FAIL: check with the 32-bit driver missing passed"; fail=1; }
check "check names what's missing: $out" has "mesa-vulkan-intel-32bit isn't installed" "$out"
out=$(steam status 2>&1)
check "status marks it --: $out" has -- '--  mesa-vulkan-intel-32bit' "$out"

# Uninstall: the 32-bit driver and the limit go; the rest stays.
echo mesa-vulkan-intel-32bit >> "$installed"
mkdir -p "$HOME/.local/share/Steam"; echo game > "$HOME/.local/share/Steam/game"
: > "$calls"
out=$(steam uninstall 2>&1) || { echo "FAIL: uninstall failed: $out"; fail=1; }
check "uninstall removes the 32-bit driver" grep -q '^sudo xbps-remove -y mesa-vulkan-intel-32bit$' "$calls"
check "uninstall keeps the 64-bit driver" grep -qx mesa-vulkan-intel "$installed"
check "uninstall keeps the repository" bash -c "! grep -q 'xbps-remove.*void-repo' '$calls'"
check "uninstall removes the limit" test ! -e "$VIKIX_LIMITS_DIR/50-vikix-steam.conf"
check "uninstall keeps the games" test -f "$HOME/.local/share/Steam/game"
check "uninstall says the games stay: $out" has 'are yours and stay' "$out"

# Not chosen: check is silent.
rm -f "$choices"
out=$(steam check 2>&1) || { echo "FAIL: check when not chosen failed"; fail=1; }
check "check says nothing when Steam isn't chosen: $out" test -z "$out"

# --- NVIDIA, proprietary -----------------------------------------------------------
reset; card nvidia 0x10de; echo nvidia >> "$installed"
out=$(steam setup 2>&1) || { echo "FAIL: setup on NVIDIA failed: $out"; fail=1; }
check "NVIDIA: multilib-nonfree too" grep -q '^sudo xbps-install -Sy void-repo-multilib-nonfree$' "$calls"
check "NVIDIA: the nvidia package's 32-bit libraries: $out" grep -q '^sudo xbps-install -y nvidia-libs-32bit$' "$calls"
check "NVIDIA: no mesa Vulkan driver" bash -c "! grep -q 'mesa-vulkan' '$calls'"

# The proprietary driver without its package: a warning, and nothing for it.
reset; card nvidia 0x10de
out=$(steam setup 2>&1) || { echo "FAIL: setup on NVIDIA without a package failed: $out"; fail=1; }
check "NVIDIA without nvidia: says so: $out" has 'no nvidia, nvidia470 or nvidia390 package' "$out"
check "NVIDIA without nvidia: nothing 32-bit for it" bash -c "! grep -q 'libs-32bit' '$calls'"

# Two cards: both are served.
reset; card i915 0x8086; card nouveau 0x10de 1
out=$(steam setup 2>&1) || { echo "FAIL: setup with two cards failed: $out"; fail=1; }
check "two cards: both drivers" grep -q '^sudo xbps-install -y mesa-vulkan-intel mesa-vulkan-intel-32bit mesa-vulkan-nouveau mesa-vulkan-nouveau-32bit$' "$calls"
check "two cards: multilib-nonfree isn't needed for nouveau" bash -c "! grep -q 'multilib-nonfree' '$calls'"

# --- a card it doesn't know: Steam, a warning, no Vulkan ----------------------------
reset; card virtio-pci 0x1af4
out=$(steam setup 2>&1) || { echo "FAIL: setup on a VM's card failed: $out"; fail=1; }
check "a VM's card: warned: $out" has "a virtual machine's card (virtio-pci): no Vulkan driver known" "$out"
check "a VM's card: Steam all the same" grep -q 'xbps-install -y steam ' "$calls"
check "a VM's card: no driver installed" bash -c "! grep -q 'mesa-vulkan\|libs-32bit' '$calls'"

# --- another architecture: refused before anything ----------------------------------
reset; card i915 0x8086
out=$(VIKIX_TEST_ARCH=aarch64 steam setup 2>&1) && { echo "FAIL: setup on aarch64 went ahead"; fail=1; }
check "aarch64: says why: $out" has 'Steam is for x86_64 machines, and this is aarch64' "$out"
check "aarch64: nothing changed" test ! -s "$calls"
check "aarch64: not recorded" test ! -e "$choices"

# --- a dry run: words only ------------------------------------------------------------
reset; card amdgpu 0x1002
out=$(DRY_RUN=1 steam setup 2>&1) || { echo "FAIL: dry run failed: $out"; fail=1; }
check "dry run: says what it would do: $out" has 'would run: sudo xbps-install -y mesa-vulkan-radeon mesa-vulkan-radeon-32bit' "$out"
check "dry run: would write the limit" has 'would run: sudo install -D -m 644' "$out"
check "dry run: sudo never ran" test ! -s "$calls"
check "dry run: nothing recorded" test ! -e "$choices"
check "dry run: no limits file" test ! -e "$VIKIX_LIMITS_DIR/50-vikix-steam.conf"

# help, as every command's.
out=$(steam help 2>&1)
check "help is the header" has 'vikix steam setup' "$out"

[ "$fail" = 0 ] && echo "steam: the card's driver (Intel, NVIDIA, nouveau, two cards, unknown), the repository, the list, the limit, status, check, uninstall, aarch64 refused, a dry run"
exit "$fail"
