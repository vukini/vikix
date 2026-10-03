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

## Languages (checked against void-packages 2026-10-03)

Vikix has eighteen language lists (Lisp's covers Common Lisp, Racket, Scheme and PicoLisp). The gaps are ways of thinking, not popularity. Each addition is the established pattern: a `packages/lang-*.list`, a `~/dev/<lang>` with three examples, a `README.md` and a `tools.list`; about an hour apiece. Ranked by fit with the books in progress.

| Language | Void | The way of thinking | Why for Vikix |
|---|---|---|---|
| **SWI-Prolog** | 10.0.2 | Logic programming: say what is true, let the machine search | The full Prolog beside Pilog, which Vid singled out as what makes PicoLisp special; a debugger, constraint libraries, *Learn Prolog Now!* free online. `lang-prolog` |
| **Erlang** and **Elixir** (Gleam too) | 28.2, 1.19.5, 1.18.1 | Actors; systems that stay up and are changed while running | The third living system beside StumpWM and Cuis: hot code loading, a shell into a running program, the Observer showing every process. One list, `lang-erlang`, with `iex` as the friendly door |
| **Assembly** (`nasm`, `gdb`, `objdump`) | in `developer` already or a package away | The machine itself | The evidence machine for *Build a Computer in Your Head* and the memory project: `make run` on forty lines, then `objdump -d` on the C example beside it. `lang-asm` |
| **GNU APL** (kona, a K, too; BQN not in Void) | 2.0 | Arrays: a whole matrix is one symbol | Another way to think about numbers for the Living Maths line; `~/dev/apl` examples from the maths books |
| **Janet** | 1.42.1 | A tiny Lisp that embeds in C | Into `lang-lisp`: the bridge between the C course and the Lisp ones |
| **Clojure** with **babashka** | 1.12.5, 1.13 | The Lisp most people are paid to write; scripting that starts in milliseconds | Into `lang-lisp`; Java is already installed |
| **Tcl/Tk** | 8.6.18 | A window on screen from any language in ten lines | If Pascal ever goes, the cheapest GUI maker; Python has Tk already |

**Tools for the books, not languages** (a `maths` feature rather than a `lang-*`): **Maxima** 5.49 (a computer algebra system that runs on SBCL, so Common Lisp underneath: the symbolic engine for the physics and maths series, and `(load "maxima")` from your own Lisp is a chapter), **Octave** 11.1, **R** 4.6.1, **PARI/GP** 2.17.

**Not in Void, so not now:** Lean 4, Idris 2, Agda, Coq (proofs; through `elan` or opam later, and Lean matters if the physics book goes formal), BQN, Crystal, Dart, Kotlin, Swift, Elm.

**Pascal** stays as it is for now (decided 2026-10-03): Void's fpc 3.2.0 and Lazarus 2.2.0 are two major versions behind and Lazarus 3+ needs FPC 3.2.2, which may be why the docked IDE build fails (TODO "to look into" 6). The options when it's revisited: drop the feature (`vikix remove pascal` already covers installed machines; the site says "twenty languages" in two places), keep only Void's packages and delete the docked build, or build FPC 3.2.2 and Lazarus 4 from pinned source as StumpWM is built. The one thing only Pascal offers here is a drag-and-drop GUI builder for native programs; FPC also cross-compiles to Windows, which the VM could run through RemoteApp.

## Ideas rather than programs

- **Niri's scrolling layout.** A Wayland compositor where a workspace scrolls sideways without end instead of tiling into a fixed grid; windows keep their size and you pan. Won't run on X, but StumpWM is programmable enough for it as a group type. Worked out as `DESIGN-viri.md`.
- **Zed's collaboration.** Zed (not in Void; a Linux build exists) lets two people edit one buffer live. The idea for Vikix is not Zed but the feature: Emacs has `crdt.el`, which does the same between two Emacsen. A `vikix pair` over Tailscale (TODO 16) for teaching a child or a friend from another machine.
