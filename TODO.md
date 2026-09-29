# To do

What's left to add or clean up, most valuable first within each section. Delete an item when it ships. The first list was drawn up on 2026-09-26, from a review of 0.15.0. The editors (Neovim into Vikix, AI in Neovim and Emacs) have their own list: `TODO-editors.md`.

## Features

Built in this order: AI first, then newcomers, then the rest. Package facts were checked against void-packages on 2026-09-28. In Void: uv, espeak-ng, podman, tesseract-ocr, xcolor. Not in Void: ollama, llama.cpp, whisper.cpp, aichat, llm, piper-tts ("piper" in Void is a gaming-mouse tool). Those come from their official releases, uv, or a source build in the style of 65-languages: pinned, checksummed where the project publishes checksums, and in ~/.local.

### AI

1. **~/dev/ai.** A folder like the languages' (README, tools line, examples copied once): the Claude API from Python and from the shell; a local model through Ollama's API; embeddings in SQLite with sqlite-vec; and "ask my notes", a small search over a folder of Markdown (an Obsidian vault, say), local by default.

### Newcomers

2. **A key overlay.** Super+/ (and maybe holding Super for a second) shows a card of the Super keys, grouped, from *vikix-bindings*. And StumpWM's which-key-mode on, for the Ctrl+t keys.
3. **A mouse fallback, and familiar keys.** Clicking a workspace in the bar goes there; volume opens pavucontrol, Wi-Fi nmtui, Bluetooth blueman. Super+Space as a second launcher key.
4. **"Installing Void for Vikix", and "Your first hour".** A docs page with screenshots of void-installer: the glibc image, partitioning, a user in wheel, the network. Then a short one: the keys, part two, themes, update. Both linked from the site (the guides on vikix.dev, below).

### And then

5. **A firewall (ufw).** Deny incoming, allow outgoing, allow SSH. A runit service, and a Super+m entry that shows the status.
6. **More themes.** Three or four more (Gruvbox, Nord, Tokyo Night, a high-contrast one), each with a wallpaper. Then make Emacs and Neovim follow `vikix theme`.
7. **Whole-system undo.** When / is btrfs: snapper snapshots before each `vikix update`, and `vikix rollback` notes. Skip cleanly on ext4.
8. **The guides on vikix.dev.** A Docs link on the site to `docs/` on GitHub, or the four pages built into the site. Same words either way: `docs/` stays the source.
9. **Hype, DHH's Markdown presentation app, as a feature.** https://github.com/omacom/hype (MIT, Qt 6 and C++). Hype's code needs no change: its Omarchy ties are handled on Vikix's side. Checked in Void on 2026-09-28: every dependency is packaged (qt6-base, -declarative, -multimedia, -imageformats, -svg and their -devel; ffmpeg6-devel, libwebp-devel, source-highlight 3.1.9; gcc and make are in dev.list), and so are xdg-desktop-portal and xdg-desktop-portal-gtk. Steps:
    - **Build it** in the VM: `git clone https://github.com/omacom/hype && cd hype && ./bin/build`, then without a window `./build/hype render examples/welcome.md -o slides/`, then the editor, `./build/hype open examples/welcome.md`. Video may stutter in a VM: judge playback on real hardware.
    - **File dialogs:** Hype has no fallback, so Open and Save fail without a portal. Install and start xdg-desktop-portal and xdg-desktop-portal-gtk from the session. The session already runs under D-Bus (`dbus-run-session` in `.xinitrc`), which the portal needs.
    - **Its themes follow Vikix's:** `vikix theme` also writes each theme as `~/.config/omarchy/themes/<name>/colors.toml` (lines like `background = "#1a1b26"`), or sets OMARCHY_PATH, and keeps `~/.local/state/omarchy/current/theme/colors.toml` pointing at the current one, so the editor follows the desktop.
    - **Package it:** an xbps-src template, after Hype's `pkgbuild/PKGBUILD`, built in the style of 65-languages (pinned) until it's in void-packages; then a feature, `vikix add hype`.
    - **The AI side:** `hype skill install` puts a skill in `~/.claude/skills/`, so the agent can write the slides; a good example of an AI workflow for the site and the docs.
    - Prior art for running it outside Omarchy, with screenshots: the Mac port, https://github.com/gscalzo/HypeX.
10. **Tutorials: `vikix learn c`.** A hands-on C course in the terminal, lessons checked on save, twelve tracks well past the basics, on a language-neutral runner. The plan, and the decisions it waits on, are in `TUTORIALS.md`. The steps: [C tutorials](#c-tutorials-vikix-learn-c), below.

## C tutorials: `vikix learn c`

Plan: Learning To Code project → "Vikix — C Tutorials Plan"
Standard: C23 (ISO/IEC 9899:2024). Free draft N3220:
https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3220.pdf

### Decide first
- [ ] Lesson style: working example first, then a small exercise? (or examples only)
- [ ] Audience: me first, or Vikix newcomers too? (sets where track 1 starts)
- [ ] Editors: terminal only, or an Emacs/Neovim key that runs the check?
- [ ] Put ~/learn/c/ in yours.list so `vikix undo` covers exercise work?
- [ ] Switch the plan from -std=c17 to -std=c23 (check the gcc/clang versions on Void)

### Phase 0: prove the feel
- [ ] bin/vikix-learn runner (language-neutral: each course folder carries its own compile/check)
- [ ] Commands: learn c | list | go NN | hint | reset NN | check
- [ ] Watch mode with entr; build with -Wall -Wextra -pedantic -g -fsanitize=address,undefined
- [ ] Design-recipe checks run one step at a time; show only the first failure
- [ ] Three sample lessons: one from track 1 (toolchain), 3 (functions), 4 (pointers)
- [ ] `make check` in learn/c/ regenerates every quoted output and diffs it (evidence rule)
- [ ] Lessons cite C23 sections (e.g. §6.5.7) against N3220
- [ ] Test in the container, then in the VM

### Later
- [ ] Phase 1: tracks 1–4
- [ ] Phase 2: tracks 5–8 + vikix-tutor skill (Super+a in a lesson folder)
- [ ] Phase 3: tracks 9–12 + capstones (Forth in C, tiny Lisp in C, vikix-battery in C)
- [ ] Reuse the runner for other languages: learn lisp / forth / haskell / sql

### Reference
- N3220 (C23), N1570 (C11), N1256 (C99): open-std.org/jtc1/sc22/wg14/www/docs/
- cppreference.com, C section: topic by topic, marks what changed in each version
- Bottom-Up C findings (14 measured surprises) → lesson material

## To look into

1. **The lock screen once showed the desktop in the VM.** On 2026-09-27 xss-lock's `i3lock` had been running for two hours in `void-vm` (picom on xrender with the 0.23.0 starter), yet screenshots showed the desktop, with the bar's clock stale, and rofi couldn't grab the keyboard. A fresh lock covered the screen in every test afterwards: with and without picom, after a notification, a new window, StumpWM rearranging, a dark screen and rofi. A second clue the same day: a picom that had run for a while in the VM stopped showing newly opened windows (rofi's area showed the wallpaper) until it was restarted, and a fresh picom was fine. So the likelier story is picom showing a stale frame, not windows above the lock; the X screen under it may well have been locked. Still to find: what makes picom stop repainting in the VM (long idle with vsync? the screen going dark for real?), and whether it ever happens on real hardware. A pen-tester review in the VM, left locked through a long idle, would settle it. Later that day, testing Lazarus (Qt5) in the VM: its newly opened windows were often left unpainted by picom (xrender), though StumpWM had them and they showed at once without picom or after restarting it; rofi was always fine. Turning off open/close fading helped once and not the second time, so that isn't it. Since then the picom starter never fades i3lock, so a lock screen can't be caught half faded in. Next to try: `use-damage = false` in the picom starter, the usual fix for picom's xrender backend in VMs, where partial repaints get missed; then see if the stale frames stop.
2. **A newly plugged screen stays dark until a layout is saved.** autorandr's udev rule runs `autorandr --batch --change --default default` on every plug. With no saved profiles, and no `default`, it does nothing: on 2026-09-28 a TV on HDMI was detected (`xrandr` said connected) but never turned on. Nothing tells the user to save a layout with Super+m. Options: fall back to a virtual profile (`--default horizontal`, which puts new screens to the right at their preferred mode) in both the udev path and vikix-session, if autorandr accepts virtual profiles there. Or `vikix doctor` and the docs could point to the save-layout entry. Careful with the preferred mode: a 4K TV on this X1's HDMI 1.4 port gets 4K@30, and 1080p60 is nicer. Also, udev's rule is autorandr's own (/usr/lib/udev/rules.d/40-monitor-hotplug.rules), so a different default means Vikix shipping its own rule in /etc/udev/rules.d.
3. **Local models on Intel graphics.** `vikix ai setup` keeps Ollama's Vulkan library (lib/ollama/vulkan). Try it on this X1's Intel graphics (OLLAMA_VULKAN=1, if that's still how it's switched on), and measure: faster than the CPU for 3-4B models? If so, a setting for it. llama.cpp built with Vulkan is the other route.
4. **Updates an agent can't forge.** The pen-tester's first finding on the agents (2026-09-28): an agent with the SSH agent could push to github.com/vukini/vikix, and `vikix update` pulls `main` unchecked, then runs stages with sudo, on every machine. 0.51.1 keeps the SSH agent from agents; still to do: `vikix update` pulls only signed tags (git verify-tag against a key shipped in the checkout), and the push key loaded with `ssh-add -c` (confirm each use) or kept out of the session's agent. Also from that review: installers pinned where the projects allow (OpenCode's comes from a moving branch, npm and uv take `@latest`), and checksums from somewhere other than the download's own host.
5. **Notifications over the lock screen, and an agent's notifications.** From the MCP pen-test (2026-09-29): vikix-lock doesn't pause dunst, so a notification may be drawn over i3lock (suspected, not seen): `dunstctl set-paused true` before i3lock, the old state back after. And a rate limit on the MCP notify tool. Also: `vikix doctor` could say when the MCP server is registered with --allow-eval.
