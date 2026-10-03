#!/usr/bin/env bash
# tests/obsidian.sh — vikix obsidian (bin/vikix-obsidian), on a made-up vault:
#   - the vault is only read: nothing in it changes
#   - a note becomes Org with an ID (the same each time), its title, aliases
#     and tags from the name and front matter, other front matter as
#     properties; Markdown through pandoc (code, tasks), ’ … — kept
#   - [[links]] become org-roam id: links, also to a folder not converted
#     yet (its notes get the same IDs later), with the label after |;
#     a link to a folder left out, or to no note, stays text, and is reported
#   - ![[embeds]]: a picture copied to attachments/ and shown; a PDF linked;
#     a note embedded becomes a link; a note named like a file is a note
#   - a folder left out can't be converted; another one shares a name and
#     the nearer note is taken; the report says each, by kind
#   - converting again leaves a note changed since alone, unless --force
set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
command -v pandoc >/dev/null || { echo "(obsidian needs pandoc; skipped here)"; exit 0; }
python3 -c 'import yaml' 2>/dev/null || { echo "(obsidian needs python3-yaml; skipped here)"; exit 0; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t" XDG_CONFIG_HOME="$t/config" XDG_STATE_HOME="$t/state"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
ob() { python3 "$here/bin/vikix-obsidian" "$@"; }
v="$t/vault"
mkdir -p "$v/Books" "$v/Notes/Deep" "$v/Readwise" "$v/Assets" "$v/.obsidian"
cat > "$v/Books/Dune.md" <<'MD'
---
title: Dune, the book
aliases: [Dune]
tags:
  - scifi
author: Frank Herbert
---
It’s… about [[Arrakis|the desert planet]] — and [[Spice#Uses]] and [[Highlights]].
See [[Nowhere]] and [[Notes/Deep/Arrakis]]. A #favourite.

![[cover.png]]
![[Spice]]
![[map.pdf]]
[[C-stddef.h]]

- [ ] reread it
- [x] buy it

```sh
echo "[[not a link]] #notatag"
```
MD
printf '# Arrakis\n\nA planet.\n' > "$v/Notes/Deep/Arrakis.md"
printf 'Spice.\n' > "$v/Notes/Spice.md"
printf 'A note named like a header file.\n' > "$v/Notes/C-stddef.h.md"
printf 'From Readwise.\n' > "$v/Readwise/Highlights.md"
printf 'Another Arrakis, further away.\n' > "$v/Readwise/Arrakis.md"
printf 'PNG' > "$v/Assets/cover.png"; printf 'PDF' > "$v/Assets/map.pdf"
printf '{}' > "$v/.obsidian/app.json"
mkdir -p "$t/config/vikix"
printf 'vault = %s\nto = %s/notes/vault\nskip = Readwise, Assets\n' "$v" "$t" > "$t/config/vikix/obsidian"
before=$(cd "$v" && find . -type f -exec sha256sum {} + | sort)

out=$(ob)
check "the list should show the folders and what's left out: $out" grep -q 'Readwise .* left out' <<<"$out"
check "a folder left out can't be converted" bash -c "! python3 '$here/bin/vikix-obsidian' convert Readwise 2>/dev/null"
out=$(ob convert Books)
check "Books converted: $out" grep -q 'Books: 1 notes converted, 2 attachments' <<<"$out"
o="$t/notes/vault/Books/Dune.org"
org=$(cat "$o")
id_of() { python3 -c 'import uuid,sys; print(uuid.uuid5(uuid.UUID("6f1b8c1e-3a8e-4f43-9c1e-0b5a7e5d2a10"), sys.argv[1]))' "$1"; }
check "an ID from its place in the vault" grep -qx ":ID:       $(id_of Books/Dune.md)" <<<"$org"
check "the title from the front matter" grep -qx '#+title: Dune, the book' <<<"$org"
check "aliases" grep -qx ':ROAM_ALIASES: "Dune"' <<<"$org"
check "tags, the front matter's and the text's" grep -qx '#+filetags: :scifi:favourite:' <<<"$org"
check "other front matter as properties" grep -qx ':AUTHOR: Frank Herbert' <<<"$org"
check "a link with its label, to a folder not converted yet" grep -qF "[[id:$(id_of Notes/Deep/Arrakis.md)][the desert planet]]" <<<"$org"
check "a link into a heading goes to the note" grep -qF "[[id:$(id_of Notes/Spice.md)][Spice]]" <<<"$org"
check "a link into a folder left out stays text" grep -qF ' and Highlights.' <<<"$org"
check "a link to no note stays text" grep -qF 'See Nowhere and' <<<"$org"
check "a picture copied and shown" grep -qxF '[[file:../attachments/Assets/cover.png]]' <<<"$org"
check "the picture is there" test -f "$t/notes/vault/attachments/Assets/cover.png"
check "a PDF linked" grep -qF '[[file:../attachments/Assets/map.pdf][map.pdf]]' <<<"$org"
check "a note named like a file is a note" grep -qF "[[id:$(id_of Notes/C-stddef.h.md)][C-stddef.h]]" <<<"$org"
# shellcheck disable=SC1112  # the note's own curly apostrophe, on purpose
check "typography kept" grep -qF 'It’s… about' <<<"$org"
check "tasks" grep -qxF -- '- [X] buy it' <<<"$org"
check "code left alone" grep -qF 'echo "[[not a link]] #notatag"' <<<"$org"
check "the same-named note in a folder left out isn't a question" bash -c "! grep -q 'share a name' '$t/state/vikix/obsidian/report-Books.org'"
r=$(cat "$t/state/vikix/obsidian/report-Books.org")
for k in "a link into a folder left out" "a link to a note that isn't there" "a note embedded in another" "a link into a heading"; do
  check "the report should name: $k" grep -q "× $k" <<<"$r"
done
ob convert Notes >/dev/null
check "the linked note, converted later, has the ID the link uses" grep -qx ":ID:       $(id_of Notes/Deep/Arrakis.md)" "$t/notes/vault/Notes/Deep/Arrakis.org"

# Converting again: a note changed since is left alone, unless --force.
echo "* My own addition" >> "$o"
out=$(ob convert Books)
check "a note changed since is left alone" grep -q '^\* My own addition' "$o"
check "and reported: $out" grep -q 'changed since it was converted' "$t/state/vikix/obsidian/report-Books.org"
ob convert Books --force >/dev/null
check "--force rewrites it" bash -c "! grep -q 'My own addition' '$o'"

check "the vault is unchanged" test "$(cd "$v" && find . -type f -exec sha256sum {} + | sort)" = "$before"

[ "$fail" = 0 ] && echo "obsidian: Org with IDs, links (also ahead of their folder), embeds, front matter, typography, the report, a changed note left alone, the vault untouched"
exit "$fail"
