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
- **The drawn overview** (0.71.130): Super+o on a strip is a card with the strip in small (a quarter of its size, less when it's long): a box per window with its title bar and what it is, a line around what's on the screen, a frame the arrows or h/j/k/l move, Enter to go, a digit for a window's number, `/` for the menu to type in. Titles only, as the risk below foresaw: X gives no picture of a window past the screen's edge, and none is asked of a compositor. The card is Vikix's own window with the drawing as its background (as a title bar is); its keys come through `*custom-key-event-handler*` with the keyboard grabbed (as the key card's). It closes when a window comes or goes, since it would show what isn't so.
- **Sliding, and centring** (0.71.135): when the strip is laid out at another scroll than it was drawn at, its windows are first moved there in eight steps over about 0.12 s, quick then slow (only moved; then laid out as before). The steps are a loop with sleeps in the main thread, not a timer (a timer's delay would be a fraction of a second, and a float there stops StumpWM's loop); only when a compositor owns `_NET_WM_CM_S0`, since without one each step makes every program redraw. `*viri-animate*` nil turns it off; `*viri-centre*` t keeps the focused column in the middle.
- **The mouse** (0.71.144): a column is a floating window to StumpWM, whose own mouse handling let one be carried anywhere and pulled to any size, lying over its neighbours until the next layout. The strip has its own `group-button-press`: Super and the wheel walk along it (the wheel on the bar's window names too); a title bar dragged, or Super and a drag, carries the column, which takes the place it's let go over; a side edge dragged, or Super and a right-button drag, changes the width a twentieth of the screen at a time. The overview's card takes clicks through StumpWM's click hook. Three things met on the way: a press outside the program's window (title bar, edge) isn't held by a grab, so a click's release is gone before the drag starts (the button's state is asked first); CLX's `process-event` answers NIL for an event that isn't the drag's as well as for a timeout (a clock tells them apart); and focusing the pressed window sent the pointer to its middle, because the pointer-keeping counted a window's edge as outside it.
- **The overview is every workspace's** (0.71.149): Vid liked the card enough to want it everywhere, so it left this file for `overview.lisp`: Super+o on any workspace draws all of them, tiles as their frames (with the windows behind a frame's listed in its box) and strips as before; the frame walks between workspaces by where the boxes are. StumpWM's expose, which Super+o was on tiles, is `g` on the card. `viri-overview-boxes` (the strip's geometry) stays here.
- **The guide page** (0.71.153, P0 item 7): `docs/strip.md`, with a drawing of the strip and the screen and, for the curious, what one press of Super+l sets off (`docs/diagrams/strip.mmd`, `strip-scroll.mmd`). The first-hour guide keeps a short paragraph and points to it.
- **Past the design: the ends, and a pinned column** (0.71.156). Super+Home and Super+End go to the first and last column. Super+\\ pins a column to the screen's left edge: the strip's weakness is that what you want in sight scrolls away, and Niri has no answer to it. The pinned column is the first of `viri-cols`, noted in `*viri-pinned*` (a table, not a slot: a running desktop's strips needn't change shape); `viri-spans` puts it at the screen's edge whatever the scroll and starts the others after it, so everything that goes by spans (placing, scrolling, the overview, the bar) needed little else. The key card is full on a 1366x768 screen at 103 keys, so moving a column to an end has commands (`vikix-move-end`) and no keys.
- **Tabbed columns** (0.71.159): Super+z on a strip (it only said so there, and the key card has no room for a new key) makes the column's windows tabs: `viri-place` gives each the whole column and hides all but the one the column shows, and the title bar draws a cell for each. Hidden, not left underneath: Vid's windows aren't solid when they haven't the focus, and the ones behind would show through. Noted in `*viri-tabbed*`, a table by column, since `viri-col` is a structure and a changed structure asks questions of a running desktop. The overview still draws a tabbed column's windows one above the other.
- **Uneven heights** (0.71.163): a column's stacked windows share its height by weights, 1 for an even share, kept by the window in `*viri-weights*`; `viri-heights` gives the pixels, and `viri-place` and the overview go by it. Super+v on a strip (the key for one above the other, which had nothing to do there; the key card is full) makes the window taller a step at a time and then all even; the edge between two stacked windows drags.
- **Fill the rest** (0.71.168): Super+b on a strip (the key for side by side, which had nothing to do there) gives the focused column the room the other columns wholly on the screen leave (Niri's expand-column-to-available-width), and scrolls so that the first of them stands at the edge. Beside the pinned column it takes the rest.
- **A whole column to another workspace** (0.71.174): Super+Shift+digit is `vikix-send`, which on a strip sends the column the window is in (`viri-send-column`): its windows are moved one by one, and on another strip they join the one column made for them (`*viri-arriving*`), which has the width and the tabs of the one that left. A window alone in its column goes as before. `gmove` itself is left as StumpWM made it.
- **A sliver of the neighbours** (0.71.177): `viri-scroll-to` no longer brings a column's edge to the screen's but leaves `*viri-peek*` pixels (24) of the next column in sight on each side that has one; where the column and its slivers don't fit, it is the column alone, as before. The scroll is now one clamp between two bounds instead of two rules, which is also what keeps a too-wide column still. The cost is that with two half columns on the screen and a third beyond, the one you aren't in is cut by the sliver's width; `(setf *viri-peek* 0)` is the old way.
- **A touchpad swipe** (0.71.179): three fingers swept on the touchpad run `vikix-focus`, so they walk along a strip and between a tiled workspace's splits (`bin/vikix-gestures`, started by the session). The plan was libinput's gestures, which need the user in the `input` group; the X server passes the same swipes to any client since XInput 2.4, so the listener asks it instead, through libX11 and libXi with ctypes (xinput's own `test-xi2` doesn't print them, and CLX has no XInput 2). Discrete steps, a `vikix eval` each: following the fingers pixel by pixel would need the listener inside StumpWM.
- **Done, as far as the design's P1 goes.** What's left is P2: a two-finger pan on a touchscreen, a strip across two monitors, the lesson. `vikix project` saves a strip since saved layouts did (`layouts.lisp`).

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
