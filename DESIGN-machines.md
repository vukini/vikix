# Vikix Machines — design

Your laptops, your desktop and your phones as one Vikix: a private network between them, folders kept in step, the phone on the desk, and a new machine made yours in one step.

Drafted 2026-10-04 for TODO items 16 to 19, with the AI desktop (`ai-desktop.md`) and the Hermes gateway (TODO 13) as the things that need it. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

Vid will have four Vikix machines (the X1, the Z13, the AI desktop at work, and a VM or two) and two phones. Today each is an island:

- The AI desktop's whole point is to serve the laptops (`ai-desktop.md`: "reachable from the Z13 and the X1 over Tailscale only"), and the Hermes gateway wants a phone to reach the laptop. Neither has the network it needs.
- Notes go through Dropbox (`notes-sync`, shipped 2026-10-04) because it's what both phone apps share; everything else (projects, music, the Living Series repo) is git or nothing.
- A phone's notification, a photo taken for a book, a file to send to the laptop: each is a cable or a cloud.
- A new machine is a Void install, `vikix add` for each feature, and an afternoon of remembering settings. TODO 19 wants one file.

## What it is

Three features and one command.

- **`vikix add tailscale`**: the private network. Every machine and phone gets a stable name (`x1`, `z13`, `office`), reachable from anywhere, with nothing opened on the internet.
- **`vikix add syncthing`**: folders kept in step between machines directly, no cloud, with a bar note while it works.
- **`vikix add kdeconnect`**: the phone on the desk: its notifications here, files both ways, the phone as a remote, the clipboard shared.
- **`vikix machines`**: who is on the network and what runs where; `vikix export` and `import`; and the doors (`vikix eval`, `vikix ai use`, `vikix agent`) learning `--on NAME`.

## How it is built

```
          Tailscale (the private network: names, keys, nothing on the internet)
   ┌──────────┬──────────────┬───────────────┬──────────────┬──────────────┐
   x1         z13            office          void-vm        phones
   laptop     laptop         AI desktop      tests          Android, iPhone
   │          │              │                              │
   └── Syncthing: ~/src/living-series, ~/music, ~/Pictures/books ─┘ (laptops ↔ office)
   └── KDE Connect: notifications, files, clipboard, remote ──────────┘ (laptop ↔ phone)
   └── vikix machines: status, export/import, --on NAME for eval, ai use, agent
```

**Tailscale** (1.102.4 in Void, with a runit service). `vikix add tailscale` enables the service and runs `tailscale up` with a login in the browser; `vikix machines` shows the tailnet's devices with their Vikix versions where they run Vikix. MagicDNS gives the names. Vikix adds nothing to the firewall: Tailscale's interface is trusted by `ufw` (`vikix firewall` learns `allow in on tailscale0`), and nothing else comes in. The AI desktop's Ollama listens on its Tailscale address only, which `ai-desktop.md` already asks for. Headscale (a self-hosted control server) isn't in Void; Tailscale's free tier covers a family's devices, and the design doesn't depend on which control server is used.

**Syncthing** (2.1.5 in Void, a user service). `vikix add syncthing` enables it for the user, opens its page once for pairing (`vikix machines pair z13` prints the device id and the QR), and declares the Vikix folders: `~/src/living-series` is **not** one (it is git; two syncs fight), but `~/music`, `~/Pictures/books` (photos from the phone for the books) and `~/cuis` are. Syncthing's "send only" and "receive only" modes make the office a mirror that never writes back. The bar shows a quiet note while syncing and the alert colour on a conflict, with `vikix machines conflicts` listing the `.sync-conflict` files as `notes-sync` does for Dropbox. Syncthing can run over Tailscale with discovery off, so nothing is announced on any other network.

**KDE Connect** (26.08.1 in Void; `kdeconnectd` with the indicator, Qt). `vikix add kdeconnect` starts the daemon at login, pairs through the phone app (Android's KDE Connect, iOS's too), and the firewall opens its ports on `tailscale0` only, so pairing happens over the tailnet rather than the café's Wi-Fi. What Vikix adds: a bar note for the phone's battery and unread count (through the record store, as a plugin), `kdeconnect-cli --share FILE` behind an Esploro command "Send to phone", the phone's notifications through dunst with the usual colours, and the phone as a remote for Hype slides (TODO, presenting). Clipboard sharing is on; the password manager's clips are kept out, as the clipboard history already does.

**`vikix machines`**:

- `vikix machines`: a table of the tailnet's devices: name, online, Vikix version (asked through the door, below) or "not Vikix", what syncs there, phone or computer.
- `vikix export`: one file, `~/vikix-export-DATE.tar`, with the features list, the theme, the keyboard file, the web apps, the plugins list, `user.lisp` and `rules.lisp`, the notes config, the projects list, the Syncthing folder list; **never** the secrets folder, the Swank secret, the backup password or the agents' logins, and it says so in the file's first line. `vikix import FILE` on a fresh Vikix applies it: `vikix add` for each feature, the theme, the files into place with the usual `.vikix-bak` for anything in the way. `vikix import --from z13` does the same over the tailnet, asking the other machine to export.
- **`--on NAME`** for three doors. `vikix eval --on z13 '(current-group)'`: the Swank door over Tailscale, with each machine's own `~/.slime-secret` (the caller is asked for it once and keeps it in the secrets folder as `swank-z13`). `vikix ai use office`: Super+i, `llm`, `note ask` and the agents' `--local` go to the AI desktop's Ollama over the tailnet (TODO 12's `cloud` entry, pointed at your own machine). `vikix agent --on office`: a Claude Code session in a terminal here, with the office machine's files, through `ssh office` over the tailnet and the same snapshot-first start. Every door keeps the security plan's rules (`DESIGN-security.md`, item 3): the password, the deadline, the audit line, the allow-list; the network changes nothing about what a caller may do.

## Goals

1. **Every machine reaches every other by name, from anywhere, with nothing on the internet.** `ssh z13` from a hotel works; `nmap` from the hotel's network sees nothing.
2. **A folder is the same on two machines within a minute**, and a conflict is shown, never silently resolved.
3. **The phone is on the desk**: its notifications here, a file sent either way in one step, the clipboard shared.
4. **A new machine is yours in one step**: Void, the install line, `vikix import --from x1`, and it has your features, theme, keys and rules.
5. **The AI desktop serves the laptops** with no setting beyond `vikix ai use office`.

## Non-goals (this version)

- **Not a replacement for git.** Repos sync through GitHub as now; Syncthing never touches `~/src`.
- **Not a mail or calendar sync.** The desk (TODO 21) is its own design.
- **Not SSH open to the internet, ever.** The tailnet is the only way in; the firewall stays as `vikix firewall on` leaves it.
- **Not a self-hosted control server.** Tailscale's own is used; Headscale can come if Void packages it and someone wants it.
- **Not replacing Dropbox for notes yet.** The phones' Org apps need Dropbox; `notes-sync` stays until Syncthing on the phones is proven for a month.

## User stories

- As Vid at a hotel, I want `vikix agent --on office` to start a session on the office machine so that the big models and the work ERP's VM are a terminal away.
- As Vid, I want `vikix ai use office` once, and Super+i, `llm` and `note ask` to use the office GPU from then on.
- As the author, I want a photo taken on the phone to be in `~/Pictures/books/` on the laptop by the time I sit down.
- As anyone, I want a phone notification to appear in the corner here in the quiet colour, and the phone's battery in the bar.
- As someone setting up the Z13, I want `vikix import --from x1` to make it feel like the X1 without copying any key.
- As the family's IT, I want every machine listed in one table with "online" and "Vikix 0.72.3" beside it.

## Requirements

### Must have (P0)

1. **`vikix add tailscale`**: the service, `tailscale up`, the firewall rule for `tailscale0`, a `vikix doctor` line (tailnet name, this machine's name, online).
   - [ ] From the VM, `ssh` to the dev machine by its MagicDNS name works with the firewall on and nothing else opened
2. **`vikix machines`**: the device table with Vikix versions where available.
3. **`vikix export` / `import`**, with the never-list enforced by a test that greps the archive for every secret the secrets folder holds (test values) and finds none.
   - [ ] On the VM: `vikix import FILE` from the dev machine's export gives the same features, theme and keyboard
4. **`vikix add syncthing`**: the user service, pairing through `vikix machines pair`, the Vikix folders declared, send-only for the office mirror, the bar note and `conflicts`.
5. **`vikix ai use NAME`**: Ollama on another Vikix machine over the tailnet; the office's Ollama bound to its Tailscale address only.
6. **`--on NAME` for `vikix eval`**, with per-machine secrets in the secrets folder, through the door module.

### Should have (P1)

7. `vikix add kdeconnect`: the daemon, pairing over the tailnet, firewall on `tailscale0` only, the bar plugin (battery, unread), Esploro's "Send to phone", notifications through dunst.
8. `vikix agent --on NAME` over `ssh`, snapshot first on the far machine.
9. `vikix import --from NAME` over the tailnet.
10. The Hermes gateway (TODO 13) reaching the laptop only over the tailnet, with its allow-list of senders.

### Later (P2)

11. Syncthing on the phones for notes, and Dropbox retired if it holds for a month.
12. A Vikix machine as a Tailscale exit node for the phones when on hotel Wi-Fi.
13. Wake-on-LAN for the office from the laptop (`vikix machines wake office`), through a Pi or the router if the office network allows.

## What Void has (checked 2026-10-04)

| Package | Version | Note |
|---|---|---|
| `tailscale` | 1.102.4 | with a runit service |
| `syncthing` | 2.1.5 | runs as the user |
| `kdeconnect` | 26.08.1 | Qt; the phone apps are Android's and iOS's |
| `wireguard-tools` | 1.0.20260223 | not needed; Tailscale carries WireGuard |
| Headscale, NetBird, LocalSend | not in Void | not used |

## Open questions

Blocking:
- **Does the office network allow Tailscale?** (Vid, IT) `ai-desktop.md` already lists it as undecided; the plan depends on it. If not, the office machine is reachable only from the office, and `--on office` works from home only through whatever IT allows.
- **Tailscale's login for a family.** (Vid) One account with every device, or one per person with sharing. Proposed: one, since the children's account is set aside.

Non-blocking:
- Which folders sync by default beyond `~/music`, `~/Pictures/books` and `~/cuis`; proposed: those three, and `vikix machines sync add FOLDER` for more.
- Whether `vikix export` includes `~/dev`'s examples (they're copied once and the user may have changed them). Proposed: no; they come back with `vikix add`.
- KDE Connect's clipboard sharing and the password manager: confirm the Bitwarden picker's clips are marked so KDE Connect skips them, or turn clipboard sharing off by default.

## Phasing

**Phase 0, a weekend:** `vikix add tailscale`, the firewall rule, `vikix machines` listing the devices; `ssh` between the X1 and the VM by name. If the office network says no, this phase still serves the laptops and the phones.

**Phase 1:** P0 items 2–6, export/import first because the Z13 needs it soonest.

**Phase 2:** P1, KDE Connect first.

## Risks

- **Two sync systems.** Dropbox for notes and Syncthing for the rest is one too many; the P2 item resolves it, and until then the guide says plainly which folder goes where.
- **A tailnet makes every machine a door to every other.** The security plan's door module and allow-list apply unchanged; `--on` adds reach, not permission. A lost laptop is removed from the tailnet in Tailscale's admin page, which the guide must say.
- **KDE Connect brings Qt and a daemon** to machines that may not want them; hence a feature of its own, not part of `tailscale`.
