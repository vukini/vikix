#!/usr/bin/env bash
# tests/nodes.sh — vikix node keeps a node as a file, reaches it by SSH alone
# (keys only, a known host key or nothing, no prompt after add), lists this
# machine first with each node online or offline, keeps a node's last answer
# for when it is down, runs a command there with the exit status passed on,
# refuses a bad name, a duplicate and a node that isn't there, and never
# touches the node on remove.
#
# ssh is a stand-in: it records its arguments; a host with "down" in its name
# is unreachable (255); the probe (sh -s) runs on this machine with HOME in
# the test's "remote" home, so the probe itself is tested for real.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
mkdir -p "$t/bin" "$t/home" "$t/remote/vikix"
echo 0.99.1 > "$t/remote/vikix/VERSION"
log="$t/log"
cat > "$t/bin/ssh" <<STUB
#!/bin/bash
echo "ssh \$*" >> "$log"
host=
while [ \$# -gt 0 ]; do
  case \$1 in -o|-p) shift ;; --) shift; host=\$1; shift; break ;; -t) ;; *) host=\$1; shift; break ;; esac
  shift
done
case \$host in *down*) echo "ssh: connect to host \$host port 22: No route to host" >&2; exit 255 ;; esac
if [ "\$1" = sh ] && [ "\$2" = -s ]; then HOME="$t/remote" VIKIX_TEST_REMOTE=1 exec sh -s; fi
echo "ran on \$host: \$*"
exit "\${REMOTE_STATUS:-0}"
STUB
chmod +x "$t/bin/ssh"
# On the "remote", no desktop: the probe's pgrep finds nothing there.
printf '#!/bin/sh\n[ -n "${VIKIX_TEST_REMOTE:-}" ] && exit 1\nexec /usr/bin/pgrep "$@"\n' > "$t/bin/pgrep"; chmod +x "$t/bin/pgrep"
export PATH="$t/bin:$PATH" HOME="$t/home" VIKIX_NODE_TIMEOUT=2
fail=0
check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }
node() { : > "$log"; bash "$here/bin/vikix-node" "$@" > "$t/out" 2>&1; }
said() { grep -qE "$1" "$t/out"; }
logged() { grep -q "$1" "$log"; }
cfg="$t/home/.config/vikix/nodes"; st="$t/home/.local/state/vikix/nodes"

# --- the list with no node -----------------------------------------------------------
node list
check "with no node the list should still show this machine, online, as local" said "$(uname -n) +local +online"
check "with no node it should say how to add one" said 'vikix node add NAME USER@HOST'
check "the list's header names what runs there" said '^NAME +KIND +STATUS +SYSTEM +WHAT RUNS'

# --- add ---------------------------------------------------------------------------
node add atlas vid@atlas.example.com --port 2222
check "add should reach the node once, by ssh, without BatchMode (the host key is yours to confirm)" \
  bash -c "grep -q 'ssh .*-p 2222 -- vid@atlas.example.com sh -s' '$log' && ! grep -q 'BatchMode.*sh -s' '$log'"
check "add should then try the batch road, keys only" grep -q 'BatchMode=yes .*-- vid@atlas.example.com true' "$log"
check "add should say what it found" said 'node atlas added: .*vikix 0.99.1'
check "the node should be a file of the user's, with the host, the port and the kind" \
  bash -c "grep -qx 'host=vid@atlas.example.com' '$cfg/atlas' && grep -qx 'port=2222' '$cfg/atlas' && grep -qx 'kind=cloud' '$cfg/atlas'"
check "the nodes folder should be the user's alone" test "$(stat -c %a "$cfg")" = 700
check "add should be noted in the log" grep -q 'add atlas vid@atlas.example.com port 2222 kind cloud' "$st/log"
check "the answer should be kept, online" bash -c "grep -qx 'status=online' '$st/atlas' && grep -qx 'vikix=0.99.1' '$st/atlas'"
check "a second add of the same name should refuse" bash -c "! bash '$here/bin/vikix-node' add atlas other@host 2>/dev/null"
check "a name with a capital or a slash should refuse" \
  bash -c "! bash '$here/bin/vikix-node' add Atlas h 2>/dev/null && ! bash '$here/bin/vikix-node' add a/b h 2>/dev/null"
check "an unreachable host should not be added" \
  bash -c "! bash '$here/bin/vikix-node' add gone vid@down.example.com >/dev/null 2>&1 && [ ! -e '$cfg/gone' ]"
node add forge forge-build --kind build
check "--kind names the kind" grep -qx 'kind=build' "$cfg/forge"
check "a host alone (an ssh config name) is fine" grep -qx 'host=forge-build' "$cfg/forge"

# --- the list ----------------------------------------------------------------------------
node list
check "the list should ask each node in batch mode, with the host key checked" \
  bash -c "grep -q 'BatchMode=yes -o StrictHostKeyChecking=yes .*-- vid@atlas.example.com sh -s' '$log'"
check "the list should show this machine first, then the nodes by name" \
  test "$(awk 'NR>1 {print $1}' "$t/out" | tr '\n' ' ')" = "$(uname -n) atlas forge "
check "a node that answers is online, with its system and what runs there" said '^atlas +cloud +online +\S+ / headless +up .*vikix 0.99.1'
check "the kind is shown" said '^forge +build +online'
sed -i 's/^host=.*/host=vid@atlas-down.example.com/' "$cfg/atlas"
node list
check "a node that doesn't answer is offline, its last answer kept" \
  bash -c "grep -qE '^atlas +cloud +offline +\S+ / headless' '$t/out' && grep -qx 'status=offline' '$st/atlas' && grep -qx 'vikix=0.99.1' '$st/atlas'"
node list --last
check "--last asks no node" test -z "$(grep 'sh -s' "$log" || true)"
check "--last says how long ago each answered" said '^atlas +cloud +offline 0m ago'

# --- status ------------------------------------------------------------------------------
sed -i 's/^host=.*/host=vid@atlas.example.com/' "$cfg/atlas"
node status atlas || true
check "status should name the node, its host and port" said 'node +atlas \(cloud\), vid@atlas.example.com port 2222'
check "status should give the system, the kernel and the load" \
  bash -c "grep -q '^kernel *$(uname -r)' '$t/out' && grep -qE '^up +[0-9]+[dhm].*load [0-9.]+' '$t/out'"
check "status should say what Vikix is there" said '^vikix +0.99.1 in ~/vikix'
check "status should list the programs running" said '^programs +\S'
sed -i 's/^host=.*/host=vid@atlas-down.example.com/' "$cfg/atlas"
node status atlas || true
check "a node down gives its last answer, saying so" bash -c "grep -q \"doesn't answer\" '$t/out' && grep -q 'last answer, 0m ago' '$t/out' && grep -q '^vikix *0.99.1' '$t/out'"
check "a node never reached and down fails" bash -c "! bash '$here/bin/vikix-node' status nowhere 2>/dev/null"
sed -i 's/^host=.*/host=vid@atlas.example.com/' "$cfg/atlas"

# --- run and shell ------------------------------------------------------------------------
node run atlas uname -a
check "run should run the words there, keys only, and print what came back" \
  bash -c "grep -q 'BatchMode=yes .*-- vid@atlas.example.com uname -a' '$log' && grep -q 'ran on vid@atlas.example.com: uname -a' '$t/out'"
rc=0; REMOTE_STATUS=3 node run atlas false || rc=$?
check "run's exit status is the command's" test "$rc" = 3
rc=0; node run atlas || rc=$?
check "run with nothing to run refuses" test "$rc" = 1
sed -i 's/^host=.*/host=vid@atlas-down.example.com/' "$cfg/atlas"
rc=0; node run atlas ls || rc=$?
check "run on a node down says so, not the command's status" bash -c "[ $rc = 1 ] && grep -q \"couldn't reach atlas\" '$t/out'"
sed -i 's/^host=.*/host=vid@atlas.example.com/' "$cfg/atlas"
node shell atlas
check "shell should be ssh with a terminal, your own prompts" bash -c "grep -q 'ssh -t -p 2222 -- vid@atlas.example.com$' '$log' && ! grep -q BatchMode '$log'"

# --- remove -----------------------------------------------------------------------------
node remove forge
check "remove should forget the node and its answer, touching nothing there" \
  bash -c "[ ! -e '$cfg/forge' ] && [ ! -e '$st/forge' ] && ! grep -q ssh '$log' && grep -q 'nothing on it was touched' '$t/out'"
check "remove should be in the log" grep -q 'remove forge forge-build' "$st/log"
check "removing a node that isn't there refuses" bash -c "! bash '$here/bin/vikix-node' remove forge 2>/dev/null"
check "a node that isn't there refuses everywhere" bash -c "! bash '$here/bin/vikix-node' run forge ls 2>/dev/null"

# --- help ------------------------------------------------------------------------------
check "-h prints the header" bash -c "bash '$here/bin/vikix-node' -h | grep -q '^vikix-node — '"

[ "$fail" = 0 ] && echo "nodes: ok"
exit "$fail"
