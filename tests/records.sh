#!/usr/bin/env bash
# tests/records.sh — vikix records, the store plugins keep what they found in:
#
#   add      one record or a list, from JSON on stdin; the same plugin, kind
#            and key updates rather than adds; a bad name, no title or bad
#            JSON is refused and adds nothing; the file is 600; two plugins
#            writing at once both land
#   search   full text over title and body: words as prefixes, a "phrase",
#            OR; newest first; by plugin; what an update changed is found,
#            what it replaced isn't
#   list     by plugin and kind, --since; get, with all its data
#   export   Org, JSON lines, CSV
#   forget   by plugin, kind and age, asking unless --yes
#   agents   the MCP server's records_search and records_get read it; no tool
#            writes it
#
# The store is a file in the test folder (VIKIX_RECORDS_DB).

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_RECORDS_DB="$t/records.db"
mkdir -p "$HOME"
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
r() { python3 "$here/bin/vikix-records" "$@"; }
now=$(date +%s)

echo '{"plugin": "flights", "kind": "search", "key": "DXB SIN 2026-10-03", "title": "DXB → SIN, Sat 3 Oct: from USD 364",
       "body": "Qatar Airways via Doha; Emirates direct 7h35", "data": {"cheapest": 364}, "link": "https://example.org/f1"}' | r add >/dev/null
echo '[{"plugin": "flights", "kind": "price", "key": "DXB LHR 12 Nov", "title": "DXB → LHR 12 Nov: AED 1295", "at": '$((now - 40 * 86400))'},
       {"plugin": "next-meeting", "kind": "joined", "title": "Board review (work, Teams)", "body": "joined at 14:30"}]' | r add >/dev/null
check "the store should be readable only by you" test "$(stat -c %a "$t/records.db")" = 600
out=$(r stats)
check "three records, by plugin and kind: $out" grep -qE '^flights/search +1 ' <<<"$out"

# The same key updates.
echo '{"plugin": "flights", "kind": "search", "key": "DXB SIN 2026-10-03", "title": "DXB → SIN, Sat 3 Oct: from USD 340",
       "body": "Singapore Airlines direct 7h20", "data": {"cheapest": 340}}' | r add >/dev/null
check "the same key should update, not add" test "$(r list flights --kind search --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')" = 1
check "search should find what the update brought" grep -q "USD 340" <<<"$(r search singapore)"
check "and not what it replaced" test "$(r search emirates)" = "no records"

# Search.
check "a word as a prefix" grep -q "Board review" <<<"$(r search boa)"
check "a phrase" grep -q "Board review" <<<"$(r search '"board review"')"
check "OR" test "$(r search singapore OR board | grep -c '/')" = 2
check "by plugin" test "$(r search singapore --plugin next-meeting)" = "no records"
check "accents don't matter" grep -q "DXB" <<<"$(r search 'sîngapore')"
check "a search of only punctuation finds nothing, without an error" test "$(r search '***')" = "no records"

# List, get.
check "--since leaves out the old" test "$(r list flights --since 30d | grep -c '/')" = 1
id=$(r list next-meeting --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
check "get gives all of it" grep -q '"joined at 14:30"' <<<"$(r get "$id" --json)"
check "get of a record that isn't there fails" bash -c "! python3 '$here/bin/vikix-records' get 9999 2>/dev/null"

# Refused, and nothing added.
before=$(r list --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')
for bad in '{"plugin": "Flights!", "kind": "x", "title": "t"}' '{"plugin": "f", "kind": "x"}' 'not json' '[{"plugin": "f", "kind": "x", "title": "ok"}, {"plugin": "f"}]'; do
  if echo "$bad" | r add >/dev/null 2>&1; then echo "FAIL: added: $bad"; fail=1; fi
done
check "a refused add should add nothing (a list, not half of it)" \
  test "$(r list --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')" = "$before"

# Two at once.
for i in $(seq 1 20); do echo '{"plugin": "a", "kind": "x", "title": "a'"$i"'"}' | r add >/dev/null & echo '{"plugin": "b", "kind": "x", "title": "b'"$i"'"}' | r add >/dev/null & done; wait
check "writes at the same time should all land" test "$(r list --limit 100 | grep -cE ' (a|b)/x ')" = 40
# The same key at the same time: one record, no writer failing on the
# unique index (a look, then an insert, let two both insert).
errs="$t/same-key.err"; : > "$errs"
for i in $(seq 1 12); do echo '{"plugin": "c", "kind": "x", "key": "k", "title": "c'"$i"'"}' | r add >/dev/null 2>>"$errs" & done; wait
check "the same key at once should fail no writer: $(head -3 "$errs")" test ! -s "$errs"
check "the same key at once should leave one record" test "$(r list c | grep -c ' c/x ')" = 1

# Export.
check "Org export: a heading a plugin" grep -qx '\* flights' <<<"$(r export --org)"
check "JSON lines export" test "$(r export --jsonl flights | wc -l)" = 2
check "CSV export" grep -q '^id,plugin,kind' <<<"$(r export --csv)"

# Forget.
r forget flights --older 30d </dev/null >/dev/null 2>&1 && { echo "FAIL: forget without --yes or a terminal"; fail=1; }
r forget flights --older 30d --yes >/dev/null
check "forget --older should take only the old" test "$(r list flights | grep -c '/')" = 1

# Agents: read, never write.
python3 - "$here/bin/vikix-mcp" <<'PY' || fail=1
import importlib.machinery, importlib.util, json, sys
loader = importlib.machinery.SourceFileLoader("vikix_mcp", sys.argv[1])
spec = importlib.util.spec_from_loader("vikix_mcp", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
found = json.loads(m.t_records_search({"query": "singapore"}))
assert found and found[0]["plugin"] == "flights", found
full = json.loads(m.t_records_get({"id": found[0]["id"]}))
assert full["data"]["cheapest"] == 340, full
newest = json.loads(m.t_records_search({"plugin": "next-meeting"}))
assert newest and newest[0]["kind"] == "joined", newest
names = [t[0] for t in m.TOOLS]
assert not [n for n in names if n.startswith("records") and n not in ("records_search", "records_get")], names
for t in m.TOOLS:
    if t[0].startswith("records"):
        assert t[4]["readOnlyHint"], t[0]
PY

[ "$fail" = 0 ] && echo "records: add (and update by key), search, list, get, export, forget, at once, and read only for agents"
exit "$fail"
