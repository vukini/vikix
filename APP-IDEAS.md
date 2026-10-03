# App ideas

Programs worth trying on Vikix, and what each would become if it earned a place. Versions and "in Void" are from void-packages `master`, checked 2026-10-03; a program not in Void would come from its official release, pinned and checksummed, as Ollama does. Nothing here is decided; when one is picked up it moves to `TODO.md` with its feature name and is deleted from here.

## In the terminal

| Program | Void | What it is | If it earns a place |
|---|---|---|---|
| **Jujutsu** (`jj`) | 0.45.1 | Version control on top of git: every working-copy change is a commit by itself, conflicts are stored rather than blocking, `jj undo` reverses any operation; works on existing git repos without converting them | The closest thing to Vikix's snapshot-and-undo in the wider world. Try on `~/src`; if it sticks, `vikix add jj` with the git config it needs, and `vikix changes` learns its log |
| **Ghostty** | 1.1.3 | GPU terminal by Mitchell Hashimoto; fast, native-feeling, one plain config file | A side-by-side with Alacritty on the X1 and the Z13; if it wins, `vikix theme` writes its config too |
| **Zellij** | 0.45.1 | A terminal workspace with a key bar at the bottom, so nobody memorises tmux | One layout per project, opened by `vikix project open` |
| **Yazi** | 26.9.1 | Terminal file manager: image previews, async, plugins | A scout for Esploro: its preview and search are worth studying, not adopting |
| **Nushell** | 0.115.1 | A shell where every command returns a table | Not a login shell; something `vikix` scripts could call for structured output |
| **Difftastic** | 0.67.0 | Diffs that understand syntax | One `git config` line; `vikix changes --words` |
| **delta** | 0.19.2 | Diffs that look like GitHub's, in the terminal | Same |
| **Helix** | 25.07.1 | A modal editor in Rust with tree-sitter and LSP built in, no plugins to install | A third editor in the editors feature for people who find Neovim's setup heavy; `TODO-editors.md` |

## For documents and offline

| Program | Void | What it is | If it earns a place |
|---|---|---|---|
| **Typst** | 0.15.1 | A typesetting system to replace LaTeX: fast, readable source, instant preview (`typst watch`) | The Living Series books' PDF route; the Neovim plugin is already in Vikix |
| **Kiwix** (`kiwix-tools`) | 3.7.0 | Offline Wikipedia, Stack Exchange, Project Gutenberg as `.zim` files, served locally (English Wikipedia without images about 50 GB) | An adapter in the docs catalogue (`DESIGN-docs.md`); `vikix add kiwix` with a picker of `.zim` files sized against the disk |
| **Glow** | 3.0.0 | Markdown rendered in the terminal | The terminal route of `vikix docs open` |

## For music (beside `DESIGN-music.md`)

| Program | Void | What it is | If it earns a place |
|---|---|---|---|
| **Strudel** | browser, no install | TidalCycles in the browser, strudel.cc | Twenty minutes with it before Phase 0 of the music design: the best existing answer to what a pattern language feels like, and what a codeless layer over one could be |
| **Sonobus** | not in Void; Linux release | Low-latency jamming over the network with other musicians, peer to peer | A real reason for TODO item 22 on the Z13 |
| **Bespoke Synth** | not in Void; Linux release | A modular synth that is a canvas you draw on | The music design's "shipped sounds" answered with instruments instead of samples |
| **Cardinal** | not in Void; Linux release | VCV Rack as an LV2/VST plugin | Same, inside Ardour |
| **Surge XT** | not in Void; Linux release | A serious free synthesizer | Same |

## Ideas rather than programs

- **Niri's scrolling layout.** A Wayland compositor where a workspace scrolls sideways without end instead of tiling into a fixed grid; windows keep their size and you pan. Won't run on X, but StumpWM is programmable enough for it as a group type. Worked out as `DESIGN-viri.md`.
- **Zed's collaboration.** Zed (not in Void; a Linux build exists) lets two people edit one buffer live. The idea for Vikix is not Zed but the feature: Emacs has `crdt.el`, which does the same between two Emacsen. A `vikix pair` over Tailscale (TODO 16) for teaching a child or a friend from another machine.
