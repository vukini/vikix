#!/usr/bin/env bash
# Why: from 0.42.0 each web app (vikix webapp) keeps a Chromium profile in
# ~/.local/share/vikix/webapps/, and most of it is cache: 2.3 GB of a
# 2.5 GB Superhuman profile, on the machine this was written on. The
# backup-exclude starter leaves the caches out, but that file is copied
# once, so machines installed before 0.42.0 would back all of it up. This
# adds the same lines to yours, in a marked block, once. The logins stay
# in the backup. Safe to run twice (ensure_block).
set -euo pipefail
. "$VIKIX_DIR/lib/common.sh"

exclude="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/backup-exclude"
if [ ! -f "$exclude" ]; then
  say "no backup-exclude file; nothing to do"
elif grep -qF 'vikix/webapps/*/Default/Cache' "$exclude"; then
  say "backup-exclude already leaves out the web apps' caches"
else
  ensure_block "$exclude" webapp-caches \
'# Web apps (vikix webapp): their logins stay in the backup, their caches do not
$HOME/.local/share/vikix/webapps/*/Default/Cache
$HOME/.local/share/vikix/webapps/*/Default/Code Cache
$HOME/.local/share/vikix/webapps/*/Default/Service Worker/CacheStorage
$HOME/.local/share/vikix/webapps/*/Default/GPUCache
$HOME/.local/share/vikix/webapps/*/GraphiteDawnCache
$HOME/.local/share/vikix/webapps/*/GrShaderCache
$HOME/.local/share/vikix/webapps/*/ShaderCache'
  say "backup-exclude: the web apps' caches are left out of backups now"
fi
