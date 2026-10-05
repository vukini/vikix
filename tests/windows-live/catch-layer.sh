#!/bin/bash
# catch-layer.sh: watch for a big override-redirect window from FreeRDP (a
# Windows program's layer, such as FACTS's message boxes) and, when one is shown,
# keep its depth and properties, its own pixels (xwd, under the compositor)
# and the screen as seen, in $OUT (/tmp/vikix-layer). Reads only; up to 4
# minutes. Start it, then make the program show its box. Not in tests/run.sh.
S=${OUT:-/tmp/vikix-layer}
mkdir -p "$S"; : > "$S/log"
end=$((SECONDS + 240)); got=0
while [ $SECONDS -lt $end ] && [ $got -lt 2 ]; do
  for id in $(xdotool search --class vikix-win 2>/dev/null); do
    info=$(xwininfo -id "$id" 2>/dev/null) || continue
    grep -q IsViewable <<<"$info" || continue
    grep -q "Override Redirect State: yes" <<<"$info" || continue
    w=$(awk '/Width:/{print $2}' <<<"$info")
    [ "${w:-0}" -gt 500 ] || continue
    grep -q "^$id$" "$S/seen" 2>/dev/null && continue
    echo "$id" >> "$S/seen"; got=$((got + 1))
    sleep 1   # let it be drawn
    { echo "=== $(date +%T) window $id"; xwininfo -id "$id"; xprop -id "$id"; } >> "$S/log" 2>&1
    xwd -silent -id "$id" > "$S/$id.xwd" 2>>"$S/log"
    import -window root -resize 50% "$S/$id-screen.png" 2>>"$S/log"
  done
  sleep 0.3
done
echo "done, $got caught" >> "$S/log"
