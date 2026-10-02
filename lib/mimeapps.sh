# lib/mimeapps.sh — the starter's default programs, for a mimeapps.list
# copied before they were there. Sourced by 40-config and vikix add.
#
# ~/.config/mimeapps.list is yours: copied once from config/xdg/, never
# overwritten. So a default added to the starter later (office files to
# LibreOffice, say) never reached it, and a one-time migration missed every
# program installed after it ran: .docx then opened in whatever claimed it
# (Calibre's e-book editor). This adds, on each update, each default of
# the starter that your file doesn't set, once its program is installed.
# A type you set is never changed; each line is offered once (recorded in
# ~/.local/state/vikix/mimeapps-offered), so one you delete stays deleted.

# app_installed APP.desktop — is there a desktop entry of that name?
app_installed() {
  local dir
  for dir in ${VIKIX_APP_DIRS:-"${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications /usr/share/applications}; do
    [ -e "$dir/$1" ] && return 0
  done
  return 1
}

# mime_defaults FILE — the TYPE=APP lines of its [Default Applications]
mime_defaults() {
  awk '/^\[/ { in_defaults = ($0 == "[Default Applications]"); next }
       in_defaults && /^[^#;[:space:]][^=]*=./ { print }' "$1" 2>/dev/null
}

# mime_sets FILE TYPE — does FILE's [Default Applications] set TYPE?
mime_sets() {
  mime_defaults "$1" | cut -d= -f1 | grep -qxF -- "$2"
}

# fill_mime_defaults STARTER MINE OFFERED
fill_mime_defaults() {
  local starter=$1 mine=$2 offered=$3 line type app new=() seen=()
  [ -f "$mine" ] && [ -f "$starter" ] || return 0
  while IFS= read -r line; do
    type=${line%%=*} app=${line#*=}
    grep -qxF -- "$line" "$offered" 2>/dev/null && continue
    if mime_sets "$mine" "$type"; then
      seen+=("$line")                       # yours: left as it is
    elif app_installed "${app%%;*}"; then
      new+=("$line") seen+=("$line")
    fi                                      # not installed yet: next time
  done < <(mime_defaults "$starter")
  if [ "${#new[@]}" -gt 0 ]; then
    say "default programs from Vikix's starter for: $(printf '%s\n' "${new[@]}" | cut -d= -f1 | tr '\n' ' ')"
    if [ "$DRY_RUN" = 1 ]; then
      printf '   would add to %s: %s\n' "$mine" "${new[*]}"
    else
      local tmp
      tmp=$(mktemp)
      # After the last line of [Default Applications], or a new section at
      # the end; written back in place (not mv), so a link stays a link.
      awk -v add="$(printf '%s\n' "${new[@]}")" '
        # add has no newline at its end: $(...) drops it.
        function flush() { if (in_defaults && !done) { printf "%s\n", add; done = 1 } }
        /^\[/ { if (in_defaults) { flush(); in_defaults = 0 }
                if ($0 == "[Default Applications]") in_defaults = 1 }
        in_defaults && /^[[:space:]]*$/ { blank = blank $0 "\n"; next }
        { printf "%s", blank; blank = ""; print }
        END { flush(); if (!done) printf "\n[Default Applications]\n%s\n", add; printf "%s", blank }
      ' "$mine" > "$tmp" && cat "$tmp" > "$mine"
      rm -f "$tmp"
    fi
  fi
  if [ "${#seen[@]}" -gt 0 ] && [ "$DRY_RUN" != 1 ]; then
    mkdir -p "$(dirname "$offered")"
    printf '%s\n' "${seen[@]}" >> "$offered"
  fi
}
