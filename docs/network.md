# The Network Office

`vikix network`, or **Super+m → System → Network Office**, opens a graph of
the current local network in an Emacs frame of its own. Select a device to
inspect its common TCP ports, open a web interface, start SSH, or browse its
files through Emacs. Emacs must already be running with its server enabled;
the launcher never starts a second Emacs. Add it with `vikix add emacs` if
needed. Nmap comes with Vikix's network packages.

## Discovery is your choice

An unfamiliar network starts in **manual**. The Office initially shows only
what the computer already knows: its own address, the gateway and the
kernel's neighbour cache. These observations do not prove that every device
is still responding. **Discover devices**, or `d`, asks Nmap for replies on
the directly connected IPv4 subnets. Select a device and press `p` to inspect
its common TCP ports.

**Discovery preference**, or `c`, remembers one choice for this network:

| Choice | What happens on joining |
|---|---|
| `manual` | Show local information; discover devices and check ports only when asked |
| `discover` | Discover devices automatically; inspect ports when asked |
| `ports` | Discover devices, then check common TCP ports on the responding devices |

Changing the choice takes effect on the next refresh, within ten seconds
while the Office is open. The login session also watches network joins, so
saved choices work while the Office is closed. It announces a newly observed
network without opening a window. After the update that adds this feature,
log in again to start that watcher; opening the Office works immediately.
Automatic discovery runs once per attachment or changed preference, not
continuously. **Discover devices** runs it again on demand.

A saved choice belongs to the NetworkManager connection, its local subnets,
and the observed gateway IP and MAC addresses. A Wi-Fi name alone never
enables scanning. Missing gateway evidence leaves automatic discovery
unavailable: discover once and refresh, then choose a preference. A changed
gateway or subnet starts in Manual again. This identity prevents accidental
reuse of preferences; it does not authenticate a network against spoofing.

## Reading the graph

The graph's branches mean **on this local network**. They do not claim that
one device is physically plugged into another. The gateway is identified
from the routing table; an otherwise unidentified computer, server, printer
or appliance is labelled Device when no name is known. The detail pane gives
its IP address, MAC when known, and how it was observed. Choose another connected network above
the graph when both Ethernet and Wi-Fi are in use.

Press Tab to move between buttons and Enter to activate one, or click a
device. With SVG support, the branches are drawn as graphical cards;
otherwise the same buttons form a text tree. `g` refreshes, `s` stops the
Office's current request, and `q` closes its frame. Closing it ends its own
request; the session watcher still follows saved choices. Set Manual to stop
automatic discovery on that network.

## Names and identification

Discovery asks DNS for device names. When DNS has no name, it also tries
Avahi's mDNS/DNS lookup if `avahi-resolve-address` is installed and its daemon
is available. Each fallback gets at most one second, with ten seconds total
for the batch. Missing names do not hide devices. `status` and Manual refresh
still read local information only; name lookups happen during discovery or
inspection. A discovered name appears beside the IP in the tree, and the
details show where it came from.

Select a device and choose **Identify device**, or press `i`, to probe its
common TCP services for names and versions. This takes up to about 90 seconds,
plus the bounded name lookup. It can reveal an OS family such as Linux or
Windows. The details label it **Likely OS**, with the service that supplied
the clue; it is not a verified OS identity. A proxy, container or remote
service may describe something other than the host itself. When there is no
clue, the Office says **OS: unknown**. Ordinary discovery and automatic port
checks never run this deeper inspection. It uses Nmap's light service probes,
without sudo, privileged OS fingerprinting or vulnerability scans.

Choose **Friendly name**, or press `n`, to save your own label, such as
`Living-room NAS`. An empty name removes the label. The label takes precedence
in the tree; discovered names remain in the details. Names are tied to this
network and the device's MAC address, so a changed IP can keep its name and a
different device taking the old IP does not inherit it. If the gateway or
device MAC is unknown, discover or inspect the device, then refresh first.
A changed or randomized MAC needs a new label. These identifiers are not
proof against spoofing. Labels live beside discovery preferences and are
included in snapshots; they do not retain a device's scan history.

Port results distinguish open, closed and filtered ports; ports not checked
remain unknown. Nmap may group closed or filtered ports into a count. A
service name beside a port is a suggestion from its usual number unless a
service probe result is shown; even probe results are tentative. Browser
buttons are offered for common web ports; SSH terminal and Remote files for
port 22. SSH asks the remote user name and
handles host keys and authentication itself. Nothing logs in automatically.

## Limits and files

This first version discovers IPv4 networks of at most 1024 addresses. Port
inspection can also target one local IPv4 address with the command below.
Discovery uses unprivileged TCP probes, which can miss devices behind a
firewall or Wi-Fi client isolation. No response does not mean the device is
off. IPv6 sweeps, UDP checks, privileged OS fingerprints and full port scans are
not part of this version. Custom policy routing and overlapping routes
through another interface pause scanning. A network change cancels the scan
and discards its result. Route and network changes are checked between
bounded waits; they are not a firewall that prevents every packet in transit.

Preferences are yours, in `~/.config/vikix/network/preferences.json`
(`XDG_CONFIG_HOME` is honoured); the default path is included in snapshots.
Temporary observations live in
`$XDG_RUNTIME_DIR/vikix-network-UID/`; when that variable is absent the
directory is under `/tmp`, private to your user. Results expire after ten
minutes and departed networks are removed as the watcher or Office refreshes.
No device history or changes between visits are kept yet; only your labels
and discovery preferences persist.

For scripts, `vikix network status` prints JSON without scanning. Copy a
network's `id` from it into these commands:

```sh
vikix network discover ID
vikix network ports ID 192.0.2.20
vikix network identify ID 192.0.2.20
vikix network name ID 192.0.2.20 "Living-room NAS"
vikix network policy ID manual
```

`vikix network refresh` applies saved discovery preferences and returns the
same JSON. A missing command, failed scan or timeout is reported as a problem,
not presented as a successfully scanned empty network.
