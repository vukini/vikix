# Vikix 0.55.0, Neovim from an everyday user's side (2026-09-29)

Checked on the running desktop: `~/vikix/VERSION` = 0.55.0, the repo's `VERSION` = 0.55.0. I only looked. I read files, ran `vikix doctor`, `vikix changes` and `vikix history`, and started Neovim headless and inside a private tmux server (no window on the desktop). To try `example.lua` I used a copy of the starter in the scratchpad, with its own `XDG_*` folders, so the real `~/.config/nvim`, `~/.local/share/nvim` and the lock state were not touched. No keys were sent to the desktop.

Neovim itself is in good shape. It starts cleanly and quickly, the start screen is right, and every example in `example.lua` works. The problems are in how the lock and the snapshots treat the user's own changes, and in how the update reports the switch.

---

## 1. Adding a plugin the way `example.lua` shows quietly makes the lock "yours", and updates stop moving Neovim's plugins on

**What happened.** The docs, the skill and the starter all say the lock becomes yours after **`:Lazy update`**. In practice any change to the plugin list does it. I uncommented the four examples in a scratch copy and started Neovim once. lazy.nvim rewrote `lazy-lock.json`, adding `zen-mode.nvim` and `catppuccin`. `45-editors` (`nvim_lock`) compares the whole file's sha256 with the one it recorded, so on the next Vikix lock it would decide the lock is the user's and stop. It would say so once, in the middle of a long update log:

    your ~/.config/nvim/lazy-lock.json has plugin versions of your own, so it stays.

For someone who only added zen-mode, that isn't true: they never chose any versions. From then on Vikix's part (`~/.local/share/vikix/nvim`) keeps moving, but the plugins under it stay where they were. When Vikix moves AstroNvim to `^7` (TODO-editors, "AstroNvim's major versions"), a new layer runs on old plugins, a combination nobody tested.

**Expected.** Adding my own plugin, or changing the colour scheme, should not cost me Vikix's tested versions. Only changing the versions of Vikix's plugins (`:Lazy update`) should.

**How to see it.**
1. In `~/.config/nvim/lua/plugins/example.lua`, take the `--` off the zen-mode line and start `nvim`.
2. `sha256sum ~/.config/nvim/lazy-lock.json` no longer matches the second field of `~/.local/state/vikix/nvim-lock`.
3. On the next update that ships a new lock, `nvim_lock` takes the "Yours" branch.

**Cost.** High, and invisible. This is the first thing the starter invites you to do, and the docs promise the opposite. You find out months later, when something breaks after a Vikix upgrade of AstroNvim.

**Suggestion.** Decide "yours" only from the entries Vikix ships. If every plugin in Vikix's lock still has the commit Vikix last shipped, write Vikix's new commits for those entries and keep the user's extra entries (a few lines of `jq` or Python, merging by key). At the least, reword the message ("…has plugins or versions of your own…") and correct `docs/customize.md`, the README "Editors" paragraph, `SKILL.md` line 45 and the starter's `init.lua` comment so they say that adding a plugin also counts.

**In TODO?** No. TODO-editors decision 1 describes "a lock the user changed", but not that adding a plugin counts as changing it.

---

## 2. `vikix changes` lists Vikix's new starter as the user's change, and `vikix undo` would delete it

**What happened.** The update takes its "after installing or updating" snapshot in `40-config` ("your files haven't changed since snapshot 80063af"). `45-editors` runs after that and copies the starter. So `vikix changes` now shows:

    .config/nvim/init.lua                | 18 ++++
    .config/nvim/lazy-lock.json          | 48 ++++++
    .config/nvim/lua/plugins/example.lua | 18 ++++

These are presented as my edits, and I made none of them. Worse, following `cmd_undo`'s code (I didn't run it): if the user next runs `vikix undo` to take back, say, a theme change, it snapshots, returns to 80063af and **removes files added since**. That is all three starter files. `~/.config/nvim/lua/plugins/` is left as an empty folder, Neovim starts without AstroNvim, and the next `vikix update` finds a folder that is "neither Vikix's starter nor a git clone; leaving it alone". The old config sits in `~/.config/nvim.vikix-bak.*`, which the user may not know about.

**Expected.** Right after an update, `vikix changes` is empty, and undo only takes back what I did.

**How to see it.** `vikix history` (the newest entry is still "after … 0.53.1"), then `vikix changes`.

**Cost.** Medium. It confuses anyone who checks `vikix changes`, and it breaks Neovim for anyone who uses `vikix undo` before their next snapshot. `vikix agent` snapshots first, which hides the problem for agent users.

**Suggestion.** Take the "after updating" snapshot at the end of `vikix update` (after `67-dev`), or snapshot again at the end of `45-editors` whenever it copied the starter.

**In TODO?** No.

---

## 3. The message about the old config is buried under 320 lines of coloured Lazy output, and "unchanged" is ambiguous

**What happened.** In `~/.local/state/vikix/logs/update-20260929-135708.log` the switch is described in four good lines (lines 66 to 69):

    :: Neovim's config is now Vikix's own; your clone of nvim-void-linux, unchanged, goes to ~/.config/nvim.vikix-bak.20260929-135803
    :: copying Vikix's Neovim starter to ~/.config/nvim (yours from now on)

They are followed by about 320 lines of `Lazy! restore` progress with raw ANSI codes (`^[[35m[LuaSnip] ^[[0m…fetch…`) in both the terminal and the log. On a terminal, the lines about the old config scroll out of sight. The update's closing lines ("Vikix 0.55.0 is up to date") don't mention Neovim at all. Some smaller issues:
- "unchanged" can be read as "we moved it without changing it" or as "you hadn't changed it". It means the second.
- "Neovim's config is now Vikix's own" followed by "(yours from now on)" reads as a contradiction.
- It doesn't say what differs: `presence.nvim` (Discord status) was in the old config and is gone. `Lazy! clean` removed it (log line 389, `[presence.nvim] clean`).
- It doesn't say how to go back, or that the backup can be deleted.
- The log's first line says "Vikix 0.54.2: update" and its last says 0.55.0, so "0.54.2 → 0.55.0" would read better.

**Expected.** One short, visible paragraph at the end: what moved, where to, why, and what to do if I had changed it.

**Cost.** Medium, once per machine. A user who opens `nvim` afterwards sees a different start screen and has to go looking in the log.

**Suggestion.**
- Send the restore's output to the log only and print one line, e.g. "Neovim's plugins: 47 installed (1m 20s)".
- Reword: "Neovim's config is now built into Vikix. Your old one (nvim-void-linux, which you hadn't changed) is kept at ~/.config/nvim.vikix-bak.…; the new ~/.config/nvim is yours to edit. presence.nvim is no longer included."
- Repeat that line in the summary at the end of the update.

**In TODO?** No.

---

## 4. `example.lua` points to a help tag that doesn't exist

**What happened.** `example.lua` says "More: :h lazy.nvim-plugin-spec". In Neovim this gives `E149: No help for lazy.nvim-plugin-spec`. The real tag is `lazy.nvim-🔌-plugin-spec`, with an emoji, which nobody will type.

**How to see it.** In `nvim`, run `:h lazy.nvim-plugin-spec`.

**Cost.** Low to medium. It's the one pointer the starter gives, and it fails on the first try.

**Suggestion.** Use `https://lazy.folke.io/spec`, or ":h lazy.nvim, then /Plugin Spec".

**In TODO?** No.

---

## 5. No word on where plain settings and key mappings go

**What happened.** `example.lua` shows the AstroNvim way (`AstroNvim/astrocore` → `options.opt`). A user who wants `vim.opt.tabstop = 4` or one `vim.keymap.set` has to guess whether they can put plain Lua in `init.lua`. The skill (line 45) promises "plugins, settings, keys" in `lua/plugins/`, but there is no key mapping example anywhere in the starter.

**Cost.** Low to medium. It's the second most common thing people want after a plugin.

**Suggestion.**
- Add one comment line at the bottom of `init.lua`: "Plain Lua settings and mappings can go below this line; they run after Vikix's and AstroNvim's."
- Add one mapping example to `example.lua`: `{ "AstroNvim/astrocore", opts = { mappings = { n = { ["<Leader>z"] = { "<Cmd>ZenMode<CR>", desc = "Zen" } } } } }`.

**In TODO?** No.

---

## 6. `vikix doctor`'s Neovim line says the layout, not the health

**What happened.** `:: Neovim is Vikix's, with your part in /home/vukini/.config/nvim` is correct, and it warns when the link is missing. It says nothing about:
- whether the plugins are installed (`~/.local/share/nvim/lazy`),
- whether the lock is still Vikix's or has become the user's (finding 1),
- the backup of the old config.

**Suggestion.** Add the lock state to the line, and a hint when the lock is the user's:
- "Neovim is Vikix's (plugins at the versions Vikix tested); your part in ~/.config/nvim", or
- "…plugins at versions of your own; for Vikix's: cp … ; vikix update".

Also use `~` in the path, like the other lines should.

**In TODO?** No.

---

## 7. Neovim ignores `vikix theme`

With `vikix theme paper` (light), Neovim stays `astrodark`. The example shows how to change the colour scheme by hand, which is fine for now.

**In TODO?** Yes: TODO.md item 6 and TODO-editors "The editors follow `vikix theme`".

---

## 8. Small wording and consistency points

- **Switching off the Typst pack.** The docs say you can switch off "one of Vikix's plugins", but the Typst pack is an AstroCommunity `import`, not a single plugin. `enabled = false` on `"AstroNvim/astrocommunity"` would also disable the user's own community imports. Say which plugins to disable (`chomosuke/typst-preview.nvim`, and tinymist in Mason), or leave it out of the claim.
- **`update_notifications = true`** in `config/nvim/lua/vikix/init.lua`. AstroNvim reads `update_notification` (singular, see `astronvim/config.lua`), so this line does nothing. It's harmless because the default is true, but it's misleading to anyone copying it. The typo came over from the old template.
- **`docs/map.md` line 71**, "Neovim's part that's Vikix's", is awkward. Suggest "Vikix's part of Neovim: AstroNvim and Vikix's plugins (a link to config/nvim)", matching the skill's wording.
- **README, stage table, `45-editors` row**: "(an unchanged clone of the old `vukini/nvim-void-linux` is set aside for it)". "For it" is unclear. Suggest "…is moved to `~/.config/nvim.vikix-bak.<time>` to make room for the starter; one with your changes stays."
- **`docs/customize.md` "The editors"** never says where the old config went, or how to bring changes over from it (the update only says that in the "changed clone" case). One sentence would do: "Before 0.55, `~/.config/nvim` was a clone of nvim-void-linux; if you hadn't changed it, it's now `~/.config/nvim.vikix-bak.<time>`."

Otherwise the docs agree with each other and with the disk. README "Editors", `docs/customize.md`, `docs/map.md`, `docs/how-it-works.md`, the skill and `info vikix` (rebuilt 13:57, with the new text) all give the same paths (`~/.local/share/vikix/nvim` → `~/vikix/config/nvim`, `~/.config/nvim` with `init.lua`, `lua/plugins/example.lua`, `lazy-lock.json`), and `config/yours.list` covers `.config/nvim`.

---

## What felt good

- **Start-up.** `nvim` (alias `v`) opens in about 93 ms ("loaded 9/47 plugins in 93.39ms"), with nothing in `:messages`. The start screen shows a clean VIKIX / NVIM block header over AstroNvim's usual menu (New File, Find File, Recents, Find Word, Bookmarks, Last Session). It's centred and all the icons render.
- **The starter.** `init.lua` is 18 lines, and its comment explains the whole split in one paragraph. If Vikix's part is missing it prints a clear message instead of a Lua traceback.
- **`example.lua`.** Short, one line per common wish, and all four examples work as written: in the scratch copy I got catppuccin, relativenumber off, `:ZenMode` available and better-escape off.
- **Safe move.** The switch moved the old clone rather than deleting it, and only because it had no local edits (a clone with changes is left alone, with instructions). The lock the user starts with matches Vikix's byte for byte.
- **Vikix's part is small and readable.** Three plugin files, each with a one-line comment saying what it's for (signatures, `jk`, JSX snippets, `$` pairs, Typst).
- **The docs agree with each other**, and the README "Editors" paragraph explains the split in words a user understands.
