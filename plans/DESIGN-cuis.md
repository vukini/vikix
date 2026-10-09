# Vikix Cuis — design

Cuis Smalltalk as a Vikix citizen: installed, themed, with a door for `vikix eval` and the agent, and then the things a live image can do for the desktop.

Drafted 2026-10-03 with Vid. Kept honest like the other designs: what ships is deleted here, what changes is dated.

---

## The problem

Vikix has one live system, StumpWM: a program you can inspect and change while it runs, which is what makes the agent, the undo and the rules possible. Cuis is the other live system on the machine, and today it sits outside Vikix: installed by hand (README, "Languages": a release bundle into `~/apps/`, a launcher kept in `vukini/dotfiles`), with its own look, no theme, no `vikix doctor` line, no way for `vikix eval` or the agent to reach it, and nothing of Vikix's inside it.

Cuis is small (the whole image is a few megabytes), built for teaching, and every object on its screen can be grabbed, inspected and opened to its code. Those are Vikix's own values. Bringing it in gives the desktop a second live image, a graphical one, for the places where Lisp text and a browser page are the wrong face.

## What it is

1. **A feature**, `vikix add cuis`: the VM and base image pinned, Vikix's packages loaded, a theme that follows `vikix theme`, a launcher, a `.desktop` file, a doctor line.
2. **A door**, `vikix eval --cuis`, the same shape as Swank's, with the agent behind it.
3. **Apps in the image** that only a live, drawn system does well: the desktop as objects; the music sketchpad's face; lessons that change the running image.

## How it is built

**Packages, not an image.** Cuis packages (`.pck.st`) are plain text and diff in git; a prebuilt image doesn't. So nothing hand-made survives in the image:

```
 ~/.local/opt/cuis/           the VM and the base image, pinned (Vikix's)
 cuis/*.pck.st (this repo)    Vikix's packages: VikixTheme, VikixServer,
                              VikixDesktop, VikixMusic, VikixLessons
 ~/cuis/                      the user's packages and their working image (yours)
 vikix cuis rebuild           fresh base image + Vikix's packages + the user's,
                              saved as ~/cuis/vikix.image
```

- `vikix add cuis` downloads the VM and the image from the Cuis-Smalltalk-Dev release, pinned and checksummed as Ollama is, into `~/.local/opt/cuis/`; builds the image headless by filing in the packages; writes `~/.local/bin/cuis` (the launcher, with the `-ud` pinning that keeps user files out of `$PWD`, moved here from the dotfiles) and a `.desktop` file; adds the Super+m entry.
- `vikix update` rebuilds when Vikix's packages or the pin changed; the user's packages reload on top. `~/cuis/` is in `yours.list`, so `vikix undo` covers Smalltalk work. Cuis's own `.changes` file logs every method edit besides, which is the function time machine from IDEAS for free.
- **Theme:** `vikix theme NAME` writes `cuis/VikixTheme-NAME.st` from the `.theme` file (the colours, the font) and files it into any running image through the door; the next launch reads it from disk. Cuis's `Theme` class and its subclasses are made for this.
- **Font:** the Vikix font as a TrueType loaded into the image at build, so Cuis looks like the rest.
- **Doctor:** `vikix cuis doctor`: VM runs, image at the pin, packages loaded, the door answering. `vikix doctor` carries the line.

**The door.** `VikixServer`, a TCP listener on `127.0.0.1:4005`:

- The first line is the password, `~/.slime-secret` (the same file Swank uses), with five seconds to send it; a wrong or late one closes that client and never the server, as `swank-guard.lisp` does for Swank.
- Then one expression a line, `Compiler evaluate:` in the image, the printString back, errors as `error: …` instead of a debugger.
- `vikix eval --cuis '3 + 4'` from a shell (`bin/vikix-eval` learns a flag; the same Python, a different port and no Swank framing). `vikix mcp` gains `cuis_eval` behind `--allow-eval`, and a read-only `cuis_state` (image, packages, open windows).
- The allow-list idea from IDEAS applies: an expression is parsed and walked before it runs; Smalltalk's syntax is small enough that the walker is short. Sends to `Smalltalk`, `OSProcess`, file streams and the like are refused or asked.
- The server starts with the image when `~/.slime-secret` exists and stops when the image saves and quits. It never listens on any address but loopback.

**The apps,** each its own package, each loaded by `vikix add cuis` but harmless when unused:

1. **`VikixDesktop`: the desktop as objects.** A morph showing workspaces as columns, windows as rectangles with titles, the bar's state along the top, refreshed every second from `vikix eval '(vikix-desktop-json)'` (a Lisp function to add, the same data `vikix mcp`'s `desktop` tool already returns). Drag a rectangle to another column: Cuis sends `(move-window-to-group …)`. Click one, open its halo, inspect: the window's StumpWM properties. This is "look inside any window" from IDEAS, built as an app rather than inside the WM, so a learner can break it safely.
2. **`VikixMusic`: the sketchpad's face in Morphic.** `StepRow`, `PadGrid`, `Knob`, `Transport` and `Subtitle` morphs, talking to `vikix-music` over the same local socket the web view uses (`DESIGN-music.md`), so the two faces coexist and the protocol is settled once. The pattern language stays Lisp; a fifty-line s-expression reader in Smalltalk draws it. Built as the spike against the web view after music's Phase 0, and kept only if it wins or earns a second place.
3. **`VikixLessons`: lessons that change the running image.** The sibling of "Learn Lisp by changing your own desktop": each lesson is a morph with a task, and the image is the exercise book. For the children's account (TODO 33) and the two-ways taster. Cuis's own class list is short enough for an eleven-year-old to read whole.
4. **A docs adapter** (`DESIGN-docs.md`): class comments and method categories as documents; a hit opens the class in a browser in the image through the door.

## Goals

1. **Cuis is a Vikix program.** Installed, themed, launched, doctored and updated like Emacs or Nyxt; a user never fetches it by hand again.
2. **Reproducible.** `vikix cuis rebuild` on any machine gives the same image, from the pinned base and the packages in git.
3. **One door, same rules.** `vikix eval --cuis` and the agent's `cuis_eval` behave as Swank's do: loopback, a password, a guard, an allow-list.
4. **One app that explains it.** `VikixDesktop` shows a newcomer in ten seconds what a live image is: the desktop drawn as objects you can grab.

## Non-goals (this version)

- **Not a replacement for any StumpWM piece.** The window manager stays Lisp. A Smalltalk image is a program on the desktop, not the desktop.
- **Not Pharo or Squeak.** Cuis is chosen for its size and its teaching bent; the packages may file into the others, but Vikix won't carry them.
- **Not a second plugin system.** Vikix plugins stay Lisp. A Cuis package that wants a bar note or a key goes through the existing plugin kinds.
- **Not headless Smalltalk services.** Nothing in Vikix depends on a Cuis image running; the image is optional, as Emacs is.

## User stories

- As a Vikix user, I want `vikix add cuis` to give me a themed, working Cuis so that I don't follow a README paragraph and keep a launcher in another repo.
- As Vid, I want `vikix theme paper` to turn Cuis light along with everything else.
- As a learner, I want to drag a window's rectangle in Cuis and see the real window move so that I understand the desktop is objects.
- As the agent, I want `cuis_eval` so that I can help build a Cuis package the way I help with `user.lisp`, snapshot first.
- As a parent, I want a Cuis image with lessons on the children's account so that the child's first program changes something they can see.
- As anyone, I want `vikix undo` to cover `~/cuis/` so that trying is free.

## Requirements

### Must have (P0)

1. **The feature**: pinned VM and image from the Cuis-Smalltalk-Dev release (checksummed), headless build loading `cuis/*.pck.st`, `~/.local/bin/cuis` with `-ud`, a `.desktop`, the Super+m entry, `~/cuis/` in `yours.list`, `features.list` and the README row.
   - [ ] On the test VM: `vikix add cuis && cuis` opens a themed image within 10 s of launch
   - [ ] `vikix cuis rebuild` twice gives images whose package list and theme are identical
2. **`VikixTheme`** written from the `.theme` file by `vikix theme`, filed in live when an image runs, read at launch otherwise; the Vikix font loaded.
   - [ ] `vikix theme paper` then `vikix theme void`: the running image follows both
3. **`VikixServer`** and `vikix eval --cuis`: loopback, password, five-second deadline, errors as text; `tests/cuis.sh` with `VIKIX_SWANK_PORT=9` and a port of its own so it never touches the live image.
   - [ ] A wrong password closes the client; the next correct one is served
   - [ ] `vikix eval --cuis '3 + 4'` prints `7`
4. **`vikix mcp`**: `cuis_state` (read) and `cuis_eval` (behind `--allow-eval`), listed by `vikix mcp tools`; the agents' skill names them.
5. **`vikix cuis doctor`** and the `vikix doctor` line.
6. **`VikixDesktop`**, first version: read-only. Workspaces and windows drawn, refreshed each second, halos and inspectors working on the morphs.

### Should have (P1)

7. `VikixDesktop` acts: drag to move a window between workspaces, click to focus, through `vikix eval`.
8. The expression walker: an allow-list of receivers and selectors for `cuis_eval`, as the Lisp one planned in IDEAS.
9. The docs adapter: class comments and categories into the catalogue; open-in-browser through the door.
10. `VikixMusic` as the spike against the web view, after music's Phase 0.

### Later (P2)

11. `VikixLessons` for the children's account, when that account exists.
12. Cuis packages as a kind in `vikix plugin` (loaded into the image on `sync`), if third-party Cuis packages become a thing people want.
13. The book: the other living image, beside the Common Lisp one.

## What Void has (checked 2026-10-03)

Nothing. Cuis is not in void-packages (neither is Squeak or Pharo), which is why the pinned release download is the route, as for Ollama and Reaper.

## Open questions

Blocking:
- **Which Cuis release to pin, and does its Linux VM bundle run on glibc Void without extra libraries?** (one try on the VM; the current launcher works on the X1, so probably yes)
- **Headless build:** does the Cuis VM run a build script with no display (`-headless` or an Xvfb)? (engineering, an hour) Decides whether `vikix add cuis` can build during install or only at first launch.
- **The font:** can Cuis load the Vikix TrueType at build time, or only through the UI? (engineering)

Non-blocking:
- Port 4005 is a guess; check nothing else in Vikix uses it, and write it beside Swank's 4004 in the guide.
- Does `VikixDesktop` poll (simplest) or does StumpWM push changes over the door? Polling first.
- Name of the Lisp function that returns the desktop as JSON; it should be the same one `vikix mcp`'s `desktop` tool uses.

## Phasing

**Phase 0, a weekend:** P0 items 1 and 3: the feature with the pinned download, the headless build with one package (`VikixServer`), and `vikix eval --cuis '3 + 4'` printing 7 on the VM. No theme, no apps.

**Phase 1:** the rest of P0: theme, MCP, doctor, read-only `VikixDesktop`.

**Phase 2:** P1, the acting `VikixDesktop` first.

## Risks

- **Two live systems, two ways to break things.** The door shares Swank's password and guard, and the allow-list comes early (P1), so an agent can't do in Cuis what it couldn't in StumpWM.
- **Morphic's look.** It is its own; a theme makes it match in colour and font, not in feel. Fine for a program, which is what Cuis is here.
- **Cuis moves fast.** The pin may lag; `vikix update` moves it deliberately, as for plugins, after a try on the VM.
- **The music face splits effort.** Two faces are one too many if both are half-done; the spike decides, and the loser is deleted from this file.
