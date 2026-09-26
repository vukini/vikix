#!/usr/bin/env bash
# 50-audio — PipeWire, set up the way the Void handbook describes.
#
# Without systemd, PipeWire is started by your session (see
# bin/vikix-session). These links tell it to also start WirePlumber
# (the session manager) and the PulseAudio stand-in, and point ALSA at it.
# Per-user links for PipeWire; system-wide for ALSA, as the handbook does.

set -euo pipefail
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

conf="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d"
run mkdir -p "$conf"

for ex in /usr/share/examples/wireplumber/10-wireplumber.conf \
          /usr/share/examples/pipewire/20-pipewire-pulse.conf; do
  dest="$conf/$(basename "$ex")"
  if [ -e "$dest" ]; then
    say "$(basename "$ex") already linked"
  else
    run ln -s "$ex" "$dest"
  fi
done

run sudo mkdir -p /etc/alsa/conf.d
for ex in /usr/share/alsa/alsa.conf.d/50-pipewire.conf \
          /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf; do
  dest="/etc/alsa/conf.d/$(basename "$ex")"
  if [ -e "$dest" ]; then
    say "$(basename "$ex") already linked"
  else
    run sudo ln -s "$ex" "$dest"
  fi
done
