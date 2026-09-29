# Editors: Neovim in Vikix, and AI in both editors

The plan for Vikix's two editors, drawn up on 2026-09-29 from Vikix 0.52.1. The general list is `TODO.md`; this one is only the editors. Delete an item when it ships, and this file when it's empty.

The goal: Vikix supports two editors, Neovim and Emacs, and both work well with AI: a model for chat and edits, and an agent working in your project, using what Vikix already knows (your keys, your chosen agent, local models) and keeping its safety rules (a snapshot first, no keys in the agent's environment).

## Where things stand (0.52.1)

- **The editors are features:** `vikix add emacs` / `vikix add neovim`, with the lists `emacs`, `neovim` and `editor-tools` (nodejs, for the npm language servers). `essentials` brings Emacs, `developer` and `everything` both.
- **Their configs are sister repos**, cloned by `install/45-editors.sh` and pulled by every `vikix update`: `~/.emacs.d` from `VIKIX_EMACS_REPO` (vukini/emacs-void), `~/.config/nvim` from `VIKIX_NVIM_REPO` (vukini/nvim-void-linux). Neovim's plugins are restored to `lazy-lock.json` at install; Emacs installs its packages in the daemon `vikix-session` starts.
- **Language servers:** Void's come with each `lang-*` list (ccls, gopls, ...), and `45-editors` puts typescript-language-server, pyright and bash-language-server in `~/.local` with npm.
- **Terminal agents are done:** `vikix agent --use claude|opencode|codex|gemini|aider`, `--local` through Ollama, one guide (`~/.local/share/vikix/AGENTS.md` and the skill), a snapshot first, and no API keys or SSH agent in the agent's environment.
- **The editors know none of it.** Neovim has no AI plugins. Emacs has gptel with OpenAI and Perplexity, defaulting to Perplexity's `sonar-pro`, so a Vikix user without that key gets an error, and neither the Claude key (`vikix ai key`) nor local Ollama is offered.
- **A gap in the agent rules:** the Emacs daemon starts in the session, so it has every exported API key. An agent started from inside Emacs (or from a Neovim terminal, in a shell with the keys) inherits them all and skips the snapshot.

## Decisions to make first

1. **Neovim's lock file.** When `vikix update` ships a newer `lazy-lock.json`: move the user's plugins forward only when their lock is still exactly one Vikix shipped (suggested), always, or never.
2. **The sister repo `nvim-void-linux`** once Neovim is in Vikix: archive it with a README pointing to Vikix, or keep it as a personal config, used with `VIKIX_NVIM_REPO`.
3. **Emacs's AI setup:** in `emacs-void` itself (the repo knows about Vikix), or in a small `vikix-ai.el` that Vikix keeps current and the config loads when it's there (the repo stays personal). The second is suggested.
4. **Agents in the editors: ACP first or Claude first.** ACP (Agent Client Protocol) is one package per editor for every agent, which matches `vikix agent --use`. The Claude-only bridges (claude-code-ide.el, claudecode.nvim) go deeper: diagnostics, and the agent's diffs in ediff or Neovim's diff view. Suggested: ACP first, the Claude bridges as a second choice.
5. **A snapshot for every agent an editor starts.** Suggested yes, as for Super+a; the cost is more snapshots (skip one when nothing changed since the last).
6. **gptel's backends in `emacs-void`:** keep OpenAI and Perplexity as extras, with Claude and local added and the default following `vikix ai use`.

## 1. Neovim into Vikix

Why: `nvim-void-linux` is AstroNvim's template. Of its 515 lines in 15 files (6 commits), six files are switched off by the template's `if true then return {} end` line, and `astrocore.lua`, `none-ls.lua` and `README.md` are still template examples. What was chosen is about 40 lines: the Typst pack, `lsp_signature.nvim`, `better-escape`, a LuaSnip rule (JSX in JavaScript files), an autopairs rule (`$…$` in TeX), the dashboard header, `presence.nvim`. Owning it in Vikix makes every later step here one commit, and `EDITOR=nvim` already makes Neovim Vikix's default editor.

It is the StumpWM split again: Vikix's layer, updated; the user's file, copied once and never overwritten.

- [ ] **Vikix's layer:** `config/nvim/lua/vikix/`: the AstroNvim import, the Typst pack, lsp_signature, better-escape, the LuaSnip and autopairs rules. Reached through the checkout (runtimepath), so `vikix update` keeps it current.
- [ ] **Leave out:** `presence.nvim` (tells Discord which file you're editing: not a default for everyone), the template's leftovers (the `fooscript` filetypes, empty none-ls sources, the switched-off files, the template README).
- [ ] **A Vikix dashboard header** instead of ASTRO NVIM.
- [ ] **The starter:** `config/nvim/starter/`, copied to `~/.config/nvim` with `copy_user`: an `init.lua` that bootstraps Lazy, imports `vikix`, then the user's `lua/plugins/` (loaded last, so theirs win), and an empty `lua/plugins/` with a short example comment.
- [ ] **The lock:** Vikix's tested `lazy-lock.json` in `config/nvim/`, copied with the starter and restored with `Lazy! restore` (as now). Can't be a link into the checkout: Lazy rewrites it and the checkout would be dirty, which stops `vikix update`. Then decision 1.
- [ ] **`install/45-editors.sh`:** for Neovim, copy the starter and restore the lock instead of cloning. `VIKIX_NVIM_REPO` still works, as "bring your own config": when it's set, clone that and skip the starter.
- [ ] **A migration** (`# Why:`, safe twice): a clone of `nvim-void-linux` with no local changes is moved to `~/.config/nvim.vikix-bak.<time>` and replaced with the starter; a clone with changes, or of another repo, is left alone, with a line saying how to switch.
- [ ] **`tests/editors.sh`:** test the checkout's config (starter + layer) instead of cloning, so a broken config is caught in the commit that breaks it. Keep the treesitter check.
- [ ] **Lint the Lua** (optional): selene (the repo has a `selene.toml`) or stylua in `tests/lint.sh`, through uvx or cargo if not installed.
- [ ] **`bin/vikix` doctor:** it checks `~/.config/nvim` as a clone (line ~236); check the starter and the layer instead.
- [ ] **`config/yours.list`:** add `~/.config/nvim/` (minus the lock?), so the user's Neovim files are in the snapshot history.
- [ ] **Docs:** `docs/map.md` (`.config/nvim/` is yours, the layer is Vikix's), `docs/customize.md` "The editors", README (the 45-editors row), the skill, CLAUDE.md if file ownership's list changes.
- [ ] **Decision 2**, then act on the sister repo.
- [ ] **Later, AstroNvim's major versions are Vikix's work** (v5 → v6 needed nvim-treesitter's main branch for Neovim 0.12): check Void's `neovim` version against AstroNvim's needs in the test.

## 2. A safe way for an editor to start an agent

Why: the gap above. Editors should start agents through Vikix, not directly.

- [ ] **`vikix agent --exec NAME [ARGS]`** (name to be settled): non-interactive, for editors. Takes the snapshot (decision 5), drops the keys and the SSH agent, points the agent at the guide as `--use` does, then `exec`s it. No prompts, no "press Enter", nothing on stdout but the agent's (ACP talks over stdin/stdout).
- [ ] **ACP adapters** where an agent needs one: install them with the agent (`vikix agent --install`), npm into `~/.local` (nodejs comes with `editor-tools`). Check which agents speak ACP themselves and which need an adapter (Claude Code and Codex needed one as of mid-2026; Gemini CLI had it built in; OpenCode had support).
- [ ] **What the editors read,** documented and stable: the chosen agent (`~/.config/vikix/agent`), the model for `vikix ai use`, Ollama at `127.0.0.1:11434`. Maybe one command that prints them (`vikix agent --which`, `vikix ai use` with no argument), so the editors don't parse Vikix's files.
- [ ] **`tests/agents.sh`:** `--exec` drops the keys, takes a snapshot, prints nothing of its own, and works with the stand-in agents the test already uses.
- [ ] **Docs:** `docs/ai.md` (agents from the editors), the skill.

## 3. AI in Neovim

In Vikix's layer, once part 1 has shipped.

- [ ] **Chat and edits: CodeCompanion.nvim,** with two adapters: Claude (the `ANTHROPIC_API_KEY` from `vikix ai key`) and Ollama; the default follows `vikix ai use`. Check whether astrocommunity has a pack for it.
- [ ] **Agents: CodeCompanion's ACP support,** each agent started with `vikix agent --exec`. Check that its command can be set to that.
- [ ] **Second choice: claudecode.nvim** (Claude Code's IDE protocol, as its VS Code extension uses: the open file, the selection, diffs in Neovim), with its terminal command set to `vikix agent --exec claude`.
- [ ] **Keys** under one leader group (`<Leader>a`?), shown by which-key.
- [ ] **No key, no Ollama, no agent:** Neovim starts quietly, and the AI keys say what to do (`vikix ai key set`, `vikix ai setup`, `vikix agent --install`).
- [ ] **Test:** a start with no keys and no network shows no errors.

## 4. AI in Emacs

In `emacs-void` or `vikix-ai.el` (decision 3).

- [ ] **gptel: add Claude and Ollama.** Claude with the key from the session (the daemon has it: no need for `exec-path-from-shell` here), Ollama at `127.0.0.1:11434` with the models `vikix ai models` lists. The default follows `vikix ai use`, not Perplexity. Keep OpenAI and Perplexity as extras (decision 6).
- [ ] **Agents: agent-shell (ACP),** each agent started with `vikix agent --exec`. Check that its command can be set.
- [ ] **Second choice: claude-code-ide.el** (or claude-code.el), with its CLI path set to the Vikix command.
- [ ] **Aider: aidermacs,** if Aider is the chosen agent, through the same command.
- [ ] **Keys:** next to gptel's `C-c g` / `C-c G`.
- [ ] **Everything guarded:** the Vikix parts do nothing when Vikix isn't there (no `vikix` on PATH), so the config still works on another machine.
- [ ] **`tests/editors.sh`:** a first start with no keys and no network shows no errors (it already fails on errors at first start).

## 5. Afterwards, in Vikix

- [ ] **`docs/editors.md`:** the two editors (Neovim is Vikix's and yours to extend; Emacs is a sister repo), how the configs are owned and updated, their keys and aliases (`v`, `e`, `eg`, `ec`, `eq`, `emacs-restart`, Super+x), language servers per feature, AI in each (chat, agents, local), bring your own config. A row in `docs/README.md`'s table (`tests/info.sh` checks it), only the Markdown `lib/md2texi.py` knows.
- [ ] **The skill** (`config/claude/skills/vikix/SKILL.md`) and so `AGENTS.md`: where the editors' configs live and which part is the user's.
- [ ] **vikix.dev:** a feature card, "AI in your editor", with a screenshot of each editor (void and paper).
- [ ] **The editors follow `vikix theme`** (TODO.md item 8): easy for Neovim once it's in Vikix (the layer reads the palette `vikix theme` writes); for Emacs, a theme file written the same way.
- [ ] **The Vikix MCP server** (TODO.md item 2), when it comes: registered for the agents the editors start too.

## Other agentic editors (for the docs, not for Vikix to install)

Worth a line in `docs/editors.md`; none of them a feature for now. Recheck before writing it: this is from mid-2026.

- **Zed:** official Linux builds, a script that installs into `~/.local`; runs ACP agents (Claude Code, Gemini) itself. Needs Vulkan: may struggle on old GPUs and in the VM. The one GUI editor that might one day be a feature.
- **VS Code:** Void's `vscode` is the open-source build, with Open VSX rather than Microsoft's marketplace, so some extensions (Copilot) aren't there.
- **Cursor, Windsurf:** proprietary Electron editors. Cursor is an AppImage (needs `fuse` on Void). They work, but aren't Vikix's style.
- **In the terminal:** everything `vikix agent --use` offers, next to either editor.
