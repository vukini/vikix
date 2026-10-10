# Vikix Cuis — design

Cuis Smalltalk as a Vikix citizen: installed, themed, with a door for `vikix eval` and the agent, and then the things a live image can do for the desktop.

Drafted 2026-10-03 with Vid. Kept honest like the other designs: what ships is deleted here, what changes is dated. Picked up 2026-10-09 (TODO 88): Phase 0 is built, Phase 1 on 2026-10-10, see the dated notes.

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
 ~/.local/opt/cuis/base/      the release as the tag has it, Linux parts only (Vikix's)
 cuis/*.pck.st (this repo)    Vikix's packages: VikixServer, VikixTheme,
                              VikixDesktop (in), VikixMusic, VikixLessons
 ~/cuis/                      the user's: vikix.image and its .changes, NewPackages/
                              (their packages), UserChanges/, Logs/, preferences;
                              links to the release's Packages, CoreUpdates,
                              TrueTypeFonts and sources file, and Vikix to cuis/
 vikix cuis rebuild           fresh base image + its core updates + Vikix's packages
                              + the user's, saved as ~/cuis/vikix.image
```

> 2026-10-09, built: Cuis has no GitHub releases; a stable version is a tag of the repository (`#BaseForCuis7.8`, whose archive holds the VM for every platform, the base image *before* that version's 979 core updates, and the updates), so the pin is the tag's archive by checksum, and the build applies the updates (`-u`). Cuis finds its Packages, CoreUpdates and TrueTypeFonts beside the image's folder, or in it, and the sources file beside the image: so `~/cuis` is both Cuis's base and the user's folder, with links into the release. That makes `Feature require: 'Network-Kernel'` work from the user's image, and NewPackages (Cuis's own place for a user's packages) is where theirs go. The snapshot history covers `~/cuis` less the image, the changes file, Logs and UserChanges (`yours_exclude`).

- `vikix add cuis` (in, 2026-10-09: `bin/vikix-cuis`) downloads the tag's archive, pinned and checksummed as Ollama is, into `~/.local/opt/cuis/`; builds the image with no window (`-vm-display-null`, `-s build.st`, two seconds) by requiring the packages by path; writes `~/.local/bin/cuis` (a wrapper for `vikix cuis run`, which starts the image with `-ud ~/cuis`, replacing the dotfiles' launcher) and a `.desktop` file; the Super+m entry is in the registry (Apps). A package of Vikix's that doesn't load fails the build; one of the user's is warned of and left out.
- `vikix update` rebuilds when Vikix's packages or the pin changed (the stamp `~/cuis/.vikix-built`); the user's packages reload on top. `~/cuis/` is in `yours.list`, so `vikix undo` covers Smalltalk work. Cuis's own `.changes` file logs every method edit besides, which is the function time machine from IDEAS for free.
- **Theme:** in (2026-10-10). Not a file a theme, as planned, but one file, `~/.config/vikix/theme/cuis.st`, beside the other programs' theme files: a chunk file of `VikixTheme`'s colour methods and `fontFamilyName`, written by `vikix theme` and filed in by `VikixTheme loadFrom:` (the class itself, with `useUniformColors` and the loading, is the package `cuis/VikixTheme.pck.st`). Learned on the way: a method compiled outside a package's change set makes Cuis ask for a change set's name in a dialog, so the file-in runs under `ChangeSet installing: 'VikixTheme' do:` and marks the package clean after, as a package install does; and the build script is compiled whole before the packages load, so it names the class with `Smalltalk at:`. The windows already open are recoloured (`setWindowColor:`), which Cuis's own theme switch leaves to the next window.
- **Font:** in (2026-10-10): `VikixTheme loadFont:` at build, the Vikix font's folder (`~/.local/share/vikix/fonts`, `wm.ttf`); 2.5 s and 6 MB in the image. `vikix-font --family` tells `vikix theme` the family's name for the written class, and `PreferenceSet setDefaultFont:` takes it when the image has it, sizes unchanged.
- **Doctor:** in (Phase 0; 2026-10-10 adds the theme: the running image's `Theme current` is `VikixTheme`).

**The door.** `VikixServer`, a TCP listener on `127.0.0.1:4005` (in, 2026-10-09: `cuis/VikixServer.pck.st`, 200 lines; `vikix eval --cuis`):

- The first line is the password, `~/.slime-secret` (the same file Swank uses), with five seconds to send it; a wrong or late one closes that client and never the server, as `swank-guard.lisp` does for Swank. The image reads the file at each client, so a new secret needs no restart.
- Then a request: lines ending with a line of one dot (a line that starts with a dot gets one more), so an expression may span lines; `Compiler evaluate:` in the image's UI process (`UISupervisor whenUIinSafeState:`, thirty seconds, else "the image is busy"); back a line `ok` or `error`, the printString's lines or the error (`ZeroDivide`, `Error: not this way`) the same way, and a dot. UTF-8 both ways (`asUtf8Bytes` out: a String's own bytes aren't).
- `vikix eval --cuis '3 + 4'` from a shell prints `=> 7`; an error is `error: ...` and exit 1, nothing listening exit 2. `vikix mcp`'s read-only `cuis_state` is in (2026-10-10: `vikix cuis status --json`, whose live part is `VikixServer state` through the door). Still to come: `cuis_eval` behind `--allow-eval`, once the walker below exists. A test's shell (`VIKIX_SWANK_PORT` set) that names no `VIKIX_CUIS_PORT` of its own reaches no door, as it reaches no Swank (2026-10-10: a theme refresh in a test would have filed its theme into the desktop's image).
- The allow-list idea from IDEAS applies: an expression is parsed and walked before it runs; Smalltalk's syntax is small enough that the walker is short. Sends to `Smalltalk`, `OSProcess`, file streams and the like are refused or asked. Until it exists, an agent's `vikix eval --cuis` is held (exit 3, as the Lisp door holds): the user runs it.
- The launcher starts the server (`-d 'VikixServer startOn: 4005 secret: ...'`) when `~/.slime-secret` exists; the image's startUp and shutDown lists stop it before a save or quit and start it again, on the same port, when a saved image is opened. A port already taken leaves the door closed (`vikix cuis doctor` says so). It never listens on any address but loopback.

**The apps,** each its own package, each loaded by `vikix add cuis` but harmless when unused:

1. **`VikixDesktop`: the desktop as objects.** The read-only half is in (2026-10-10): a `SystemWindow` with a `LinearLayoutMorph` column a workspace and a `VikixWindowMorph` a window, kept by number between answers so a halo stays, stepped once a second; the model asks in a process of its own, so Morphic never waits. Not through `vikix eval` (the image can't run a program without FFI): `VikixSwank`, a client of StumpWM's Swank in a hundred lines (the password packet, `vikix-eval-for-agent`, the printed value unquoted), which is the road Phase 2's acts will take too. `vikix-desktop-json` is the function (windows.lisp), and `vikix mcp`'s `desktop` tool reads it now rather than carry the form itself. Left: drag a rectangle to another column, Cuis sending `(move-window-to-group …)`; the bar's state along the top.
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

1. **The feature**: in (2026-10-09), all of it but the theme: pinned archive, checksummed; headless build loading `cuis/*.pck.st`; `~/.local/bin/cuis` with `-ud`; a `.desktop`; the Super+m entry; `~/cuis/` in `yours.list`; `features.list`; the README section.
   - [ ] On the test VM: `vikix add cuis && cuis` opens a themed image within 10 s of launch
   - [x] `vikix cuis rebuild` twice gives images whose package list is identical (`tests/cuis.sh` builds from the real release when it is at hand)
3. **`VikixServer`** and `vikix eval --cuis`: in (2026-10-09): loopback, password, five-second deadline, errors as text; `tests/cuis.sh` with `VIKIX_SWANK_PORT=9` and a port of its own so it never touches the live image.
   - [x] A wrong password closes the client; the next correct one is served
   - [x] `vikix eval --cuis '3 + 4'` prints `=> 7`
4. **`vikix mcp`**: `cuis_state` is in (2026-10-10); `cuis_eval` (behind `--allow-eval`) waits for item 8.

### Should have (P1)

7. `VikixDesktop` acts: drag to move a window between workspaces, click to focus, through `VikixSwank` (2026-10-10: not `vikix eval`; see the apps).
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

Blocking, all three answered 2026-10-09 by trying on the X1:
- **Which Cuis release to pin:** the tag `#BaseForCuis7.8` (2026-05-29; Cuis has no GitHub releases). Its Linux VM (OpenSmalltalk 7.0-202603271636, Spur 64-bit) runs on glibc Void with libuuid and libz alone. Not yet tried on the test VM.
- **Headless build:** `squeak -vm-display-null IMAGE -ud DIR -u -s build.st` runs with no display and no Xvfb; `-headless` does the same. The whole build, 979 updates and the packages, takes two seconds, so `vikix add cuis` builds during install. The script must end in `Smalltalk quit` (`snapshot:andQuit:` doesn't exist in 7.8; `saveAndQuit` saves first).
- **The font:** `TrueTypeFontFamily readAllTrueTypeFontsIn: aDirectoryEntry` loads a folder of TrueType fonts from a script, so the Vikix font can come at build time (Phase 1).

Non-blocking:
- Port 4005: nothing else in Vikix uses it (checked 2026-10-09); it is in the README beside Swank's 4004 and Nyxt's 4006.
- `VikixDesktop` polls (2026-10-10), once a second, through Swank; a push would need the image to listen, which the door already does, so it is an option for later.

## Phasing

**Phase 0, a weekend:** done 2026-10-09 (a morning): P0 items 1 and 3, the feature with the pinned download, the headless build with one package (`VikixServer`), and `vikix eval --cuis '3 + 4'` printing 7, on the X1 (the VM is still to try). No theme, no apps.

**Phase 1:** done 2026-10-10: the theme and the font, `cuis_state`, the doctor's theme line, the read-only `VikixDesktop`; `tests/cuis.sh` drives the real image against a stand-in Swank (`tests/lib/fake-swank.py`).

**Phase 2:** P1, the acting `VikixDesktop` first.

## Risks

- **Two live systems, two ways to break things.** The door shares Swank's password and guard, and the allow-list comes early (P1), so an agent can't do in Cuis what it couldn't in StumpWM.
- **Morphic's look.** It is its own; a theme makes it match in colour and font, not in feel. Fine for a program, which is what Cuis is here.
- **Cuis moves fast.** The pin may lag; `vikix update` moves it deliberately, as for plugins, after a try on the VM.
- **The music face splits effort.** Two faces are one too many if both are half-done; the spike decides, and the loser is deleted from this file.
