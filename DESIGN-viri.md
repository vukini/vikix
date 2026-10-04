# Viri — design

A workspace that scrolls sideways instead of tiling into a grid. Niri's idea, as a StumpWM group type.

Drafted 2026-10-03 with Vid. Kept honest like Esploro's: what ships is deleted here, what changes is dated.

---

## Where it stands (2026-10-03)

**Phase 0 is built** (`config/stumpwm/vikix/viri.lisp`, `tests/viri.sh`): `vikix viri [on|off]` and the Super+m entry turn the current workspace into a strip and back, its windows kept in the order they stood (frames left to right in tiles; columns in a strip); columns are half the screen, two show; Super+h/l walk along it and scroll, Super+Shift+h/l move a column; a new window opens right of the focused one and takes the focus; closing one focuses the column that took its place; dialogs float in the middle; StumpWM's own focusing (Super+`, the window list) scrolls to the window too. Tried in a hidden StumpWM, not yet lived in on the desktop.

What building it settled, against the plan below:

- **Built on the float group, not `group` or `dynamic-group`.** A strip is a float group whose windows Viri places: StumpWM's floating code does focus, raising, fullscreen and dialogs, and Viri overrides only adding, removing, focusing and the requests to move or resize.
- **Strip keys can't be a group keymap.** StumpWM searches `*top-map*` (where every Vikix key is) before any group's map, so a strip-only map would never be reached. Instead Super+h/j/k/l and the arrows run `vikix-focus` / `vikix-move`, which act on the strip there and are `move-focus` / `move-window` everywhere else. Super+r stays "remove split" and Super+Tab "last window" for now: width cycling and the overview get their keys when they're built.
- **Off puts the tiles back as they were** (0.71.94): the strip keeps the layout it was made from (`dump-group`) and restores it as Super+z does; at first off left every window in one frame.
- **Off-screen columns are moved past the edge**, not unmapped: they keep drawing and come back at once. Firefox throttling there is still to be watched on the desktop.
- **Sloppy focus (Vikix's) fights a moving strip.** When columns move under a still pointer, X says it entered whichever lands there, and that window took the focus back. The strip brings the pointer to the focused window after a layout, and drops the EnterNotify events its own moves caused.
- **Tile-only code met a strip:** layout undo recorded after every command with `dump-group`, which fails off tiles and opened the error menu each time (now it records only on tiles); Vikix's title bars stayed on windows leaving tiles (removed as they join a strip; columns got their own in 0.71.127).
- **Where you are** (0.71.95): the focused column has the tiles' accent border, and the bar's window list (%W) shows the strip in order with the columns on the screen in [brackets], each a click away.
- **Widths** (0.71.96): a strip is a list of columns, each with its windows top to bottom and a width (a third, a half, two thirds, all), scrolled by pixels; Super+r on a strip cycles the width (`vikix-width-or-remove`: `remove` on tiles), and the strip scrolls only as far as it must to show the focused column whole, so a neighbour can show in part, as in Niri.
- **Stacking** (0.71.97): Niri's consume-or-expel on Super+[ and Super+] rather than the planned Super+Shift+j/k, which move a window up and down its column instead; a column's windows share its height evenly.
- **The overview** (a menu, 0.71.105) is Super+o on a strip, not Super+Tab: Super+o already means "every window on this workspace, pick one" (expose, tiles only), and Super+Tab's "the last window" works on a strip too. Rule verbs `width` and `join` came in 0.71.104.
- **The agents see strips** (0.71.107): the MCP `desktop` tool gives each workspace's kind, and a strip's columns with their widths, windows and which are on the screen.
- **The window keys that only knew tiles** (0.71.126): lived in for a day, the strip met Super+g (an error: the contrib module asked a floating window for its frame), Super+Tab and Super+b/v ("command not found": StumpWM's own are tile-group commands), Super+p and Super+u (errors). Each key now runs a Vikix command that does its thing on a strip or says why not (`vikix-last-window`, `vikix-split`, `vikix-layout-undo`, `vikix-pointer`, `vikix-bring-window`, and Vikix's `goto-window` in the module's place). A column sent to a tiled workspace stayed floating there; it is tiled as it arrives.
- **Title bars** (0.71.127): a column's window has the tiles' title bar (its number and name, the accent when focused; Super+Ctrl+y switches them, as on tiles). The window sits below the bar inside its parent, the bar a child window above it, placed by `viri-layout`; a fullscreen window has none, and leaving fullscreen lays the strip out again (StumpWM puts the window back as a plain floating one).
- **Not done:** the drawn overview, `vikix project` saving a strip.

## The problem

Tiling has one weakness, and everyone who tiles knows it: the fourth window. Three windows side by side are fine; the fourth makes all of them too narrow, so you either close something, start a new workspace, or begin stacking and lose the side-by-side that made tiling worth it. Workspaces 1 to 9 are the usual escape, and they cost a decision ("where did I put the browser?") every time.

Niri's answer: the workspace is a strip wider than the screen. New windows join the strip at their natural width; the screen is a viewport you pan. Nothing shrinks when something opens; nothing is hidden on another workspace; you move left and right as along a desk. People who try it find the fixed grid feels cramped afterwards.

Niri is a Wayland compositor and Vikix is X11 on StumpWM, so it can't be installed. But StumpWM is a Lisp program whose layouts are classes, and a scrolling layout is a few hundred lines. Nobody has built one for StumpWM.

## What it is

**Viri**, a group type beside StumpWM's tiling and floating groups: `vikix viri` turns the current workspace into a strip, or makes a new one. Everything else about Vikix is unchanged: the bar, the keys, the agent, `user.lisp`.

```
  ◀──────────────────── the strip ────────────────────▶
  ┌────────┐┌──────────────┐┌────────┐┌──────────────┐┌────────┐
  │ Emacs  ││   Firefox    ││ kitty  ││   Esploro    ││ Ardour │
  │        ││              ││        ││              ││        │
  └────────┘└──────────────┘└────────┘└──────────────┘└────────┘
            ╔══════════════════════════════╗
            ║        the screen (viewport)  ║
            ╚══════════════════════════════╝
```

- **Columns.** The strip is a list of columns, left to right. A column is usually one window; `Super+Shift+j/k` stacks a second window above or below in the same column (Niri does this too), for a terminal under its editor.
- **Widths.** A column has a width from a small set: a third, a half, two thirds, full. `Super+r` cycles them. New windows get a half, or what a rule says (`(when-window (:class "Firefox") (width :two-thirds))`, in the rules language from IDEAS).
- **The viewport.** The screen shows as many whole columns as fit from a left edge. Focus moving past the edge scrolls the strip by one column, animated over about 150 ms if picom is on, instantly if not. `Super+h/l` move focus left and right along the strip, as they do between frames today.
- **Centring.** Optionally the focused column is kept centred (Niri's `center-focused-column`); default off, so the strip feels like a desk, not a carousel.
- **Moving.** `Super+Shift+h/l` move the focused column left or right. `Super+Shift+Return` opens a new window in a column of its own to the right of the focus, which is the common case.
- **Overview.** `Super+Tab` zooms out to show the whole strip small, every column labelled; type a letter or click to jump. This is the "where did I put it" answer that fixed workspaces never had.
- **Workspaces still exist.** 1 to 9 remain; each can be a strip or a tiling group. A Viri workspace per project is the natural pairing with `vikix project open`.

## How it is built

StumpWM's groups are CLOS classes with generic functions for adding, removing, resizing and focusing windows; `tile-group`, `float-group` and `dynamic-group` are the three shipped. Viri is a fourth:

```lisp
(defclass viri-group (group)
  ((columns  :initform '()  :accessor viri-columns)   ; list of column, left to right
   (left     :initform 0    :accessor viri-left)      ; index of the first visible column
   (centred  :initform nil  :accessor viri-centred-p)))

(defstruct column windows width)   ; width: :third :half :two-thirds :full
```

- `group-add-window` makes a new column after the focused one (or stacks, if the add came from the stack command) and calls `viri-layout`.
- `viri-layout` computes each visible column's x and width from `left` and the screen's width, and places each window with StumpWM's own `window-move-resize`; columns off-screen are moved off the visible area (X allows negative coordinates), not unmapped, so they keep rendering and reappear instantly.
- Focus changes go through `group-focus-window`; if the newly focused column isn't fully visible, `left` is adjusted and `viri-layout` runs again.
- The overview is a `select-from-menu` fallback first (column titles, pick one), and a drawn miniature later (StumpWM can draw with CLX; the keys card already does).
- Floating windows (dialogs) behave as in a tile group: StumpWM already handles transient windows above any group.
- `dump-group` / `restore-group` learn the new class, so a Viri layout saves with `vikix project` and `vikix layout save` (TODO 29, 50a).

Everything is in one file, `config/stumpwm/vikix/viri.lisp`, loaded through `errors.lisp` like the rest, so a bug in it opens the errors menu rather than taking the desktop down. `vikix eval '(vikix-viri-toggle)'` makes it live without a reload, which is also how the agent would help build it.

## Goals

1. **The fourth window costs nothing.** Open four, five, six windows on a strip: none shrinks, none hides.
2. **Where did I put it, answered.** From any column, the overview shows every window on the strip and reaches one in two keystrokes.
3. **Nothing else changes.** Every Vikix key that works in a tile group works in a strip or has an obvious strip meaning; the bar, rules, agent and `user.lisp` are untouched.
4. **Switchable per workspace, undoable.** `vikix viri` on, `vikix viri off` back to tiling with the same windows, and `vikix undo` for the `user.lisp` line that made it the default.

## Non-goals (this version)

- **Not a compositor, not animations for their own sake.** The scroll animates only if picom is running; without it the strip jumps, and that's fine.
- **Not touch or gesture input.** The Z13's screen could pan the strip with two fingers; later, with libinput gestures, after the keys are right.
- **Not vertical strips.** Niri scrolls sideways; a vertical variant is a different thing.
- **Not replacing tiling.** The tile group stays the default for new users; Viri is a choice per workspace, and may become the default only if Vid lives in it for a month and wants it so.

## User stories

- As someone with an editor, a browser, two terminals and a file manager open, I want all five full-size on one workspace so that I stop closing things to make room.
- As Vid, I want a project's workspace to be a strip, saved and restored by `vikix project open`, so that the desk is as I left it.
- As a newcomer, I want `Super+Tab` to show me everything on this workspace so that I never lose a window.
- As anyone, I want to turn the strip off and get my tiles back with the same windows.
- As a rule-writer, I want `(width :two-thirds)` for Firefox so that pages aren't squeezed.

## Requirements

### Must have (P0)

1. `viri-group` class with columns, widths, viewport, focus-scrolls-into-view; `vikix viri` / `vikix viri off` convert the current workspace keeping its windows.
   - [ ] Open six terminals on a strip: each keeps its width; `Super+l` six times visits each; none was resized
   - [ ] `vikix viri off` returns the same six windows to a tile group
2. Keys: `Super+h/l` focus along the strip, `Super+Shift+h/l` move column, `Super+r` cycle width, `Super+Shift+Return` new window in a new column, `Super+Shift+j/k` stack in column. All in `*vikix-bindings*` with blurbs, so Super+/ and Super+F1 show them.
3. Overview as a searchable menu of columns (`Super+Tab`).
4. `dump-group`/`restore-group` support, so `vikix project open` restores a strip.
5. Rules: `(width …)` honoured from `user.lisp` through the existing `vikix-rules` hook, or a `*viri-default-width*` and a per-class alist until the rules language exists.
6. Agent: the `desktop` MCP tool reports strips (columns, widths, which are visible) and `switch_workspace`/`focus_window` work on them.
7. The guide page: what a strip is, in the "Four words, explained" register, with a drawing.

### Should have (P1)

8. A drawn overview (miniature columns with titles) instead of the menu.
9. Centre-focused-column option.
10. Smooth scroll through picom (a few intermediate `viri-layout` frames over 150 ms), off when picom is absent or `*viri-animate*` is nil.
11. Mouse: scroll wheel on the bar's workspace area pans the strip; dragging a column border changes its width.

### Later (P2)

12. Two-finger pan on the Z13's touchscreen (libinput gestures → `vikix eval`).
13. Columns that span two monitors; today a strip belongs to one head.
14. A Viri lesson in "Learn Lisp by changing your own desktop": a group type is a good second chapter after a key.

## What success looks like

- Vid uses a strip as his main workspace for a month without turning it off (the honest test).
- `vikix doctor` reports no errors from `viri.lisp` across a week of reloads.
- The guide's drawing is enough: a newcomer in the VM finds the overview and the width key without reading the key card.

## Open questions

Blocking:
- **Negative coordinates or unmapping for off-screen columns?** (engineering, half a day in the VM) Moving windows off-screen keeps them rendering and makes return instant, but some programs (Firefox) throttle when unmapped and misbehave when partly visible; test both.
- **Does `dynamic-group` already give enough to subclass?** (engineering) StumpWM's dynamic group has master/stack logic that might fight the strip; subclassing `group` directly is cleaner but means reimplementing more. Read `dynamic-group.lisp` first.

Non-blocking:
- The name. "Viri" is Vid's; it echoes Niri and Vikix and is free as a command name (checked: nothing in Void is called viri).
- Default width for a new column: a half, or "as wide as the program asks" (its size hints) clamped to the set?
- Whether `Super+Tab` is free: today it may be bound to window cycling in StumpWM's own map; check `*vikix-bindings*` and `*top-map*`.

## Phasing

**Phase 0, a weekend:** the class, columns at a half each, `Super+h/l` scrolling the viewport, `vikix viri` on and off. No widths, no overview, no animation. Live in it for a week.

**Phase 1:** P0 items 1–7.

**Phase 2:** P1, the drawn overview first.

## Risks

- **Programs that resize themselves.** Some windows set size hints that fight a fixed column width (terminals snap to character cells, Firefox has minimums). StumpWM's tile groups already deal with hints; Viri must honour them the same way, which may mean columns not exactly a half.
- **It's lovely for one person and confusing for a newcomer.** Hence a choice per workspace, not the default, until it's lived in.
- **Overview without a compositor.** Drawing miniatures of windows needs their contents; without picom, the overview is titles only. The P0 menu version sidesteps this; the P1 drawn one may need `xcomposite` and is where effort could sink.
