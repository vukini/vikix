# Editors: Neovim in Vikix, and AI in both editors

The plan for Vikix's two editors, drawn up on 2026-09-29 from Vikix 0.52.1. The general list is `TODO.md`; this one is only the editors. Delete an item when it ships, and this file when it's empty.

The goal: Vikix supports two editors, Neovim and Emacs, and both work well with AI: a model for chat and edits, and an agent working in your project, using what Vikix already knows (your keys, your chosen agent, local models) and keeping its safety rules (a snapshot first, no keys in the agent's environment).

## Where things stood (0.52.1; Neovim's config moved into Vikix in 0.55.0)

- **The editors are features:** `vikix add emacs` / `vikix add neovim`, with the lists `emacs`, `neovim` and `editor-tools` (nodejs, for the npm language servers). `essentials` brings Emacs, `developer` and `everything` both.
- **Their configs were sister repos** (Emacs's still is), cloned by `install/45-editors.sh` and pulled by every `vikix update`: `~/.emacs.d` from `VIKIX_EMACS_REPO` (vukini/emacs-void), `~/.config/nvim` from `VIKIX_NVIM_REPO` (vukini/nvim-void-linux). Neovim's plugins are restored to `lazy-lock.json` at install; Emacs installs its packages in the daemon `vikix-session` starts.
- **Language servers:** Void's come with each `lang-*` list (ccls, gopls, ...), and `45-editors` puts typescript-language-server, pyright and bash-language-server in `~/.local` with npm.
- **Terminal agents are done:** `vikix agent --use claude|opencode|codex|gemini|aider`, `--local` through Ollama, one guide (`~/.local/share/vikix/AGENTS.md` and the skill), a snapshot first, and no API keys or SSH agent in the agent's environment.
- **The editors know none of it.** Neovim has no AI plugins. Emacs has gptel with OpenAI and Perplexity, defaulting to Perplexity's `sonar-pro`, so a Vikix user without that key gets an error, and neither the Claude key (`vikix ai key`) nor local Ollama is offered.
- **A gap in the agent rules:** the Emacs daemon starts in the session, so it has every exported API key. An agent started from inside Emacs (or from a Neovim terminal, in a shell with the keys) inherits them all and skips the snapshot.

## Decisions (settled by Vid, 2026-09-29: the suggested answer each time)

1. **Neovim's lock file.** When `vikix update` ships a newer `lazy-lock.json`, the user's plugins move forward only when their lock is still exactly one Vikix shipped. A lock the user changed is left alone, with a line saying how to take Vikix's.
2. **The sister repo `nvim-void-linux`:** archived once Neovim is in Vikix, with a README pointing to Vikix. `VIKIX_NVIM_REPO` stays, for anyone bringing their own config.
3. **Emacs's AI setup:** a small `vikix-ai.el` that Vikix keeps current and the config loads when it's there. `emacs-void` stays personal.
4. **Agents in the editors: ACP first.** One package per editor for every agent, matching `vikix agent --use`. The Claude-only bridges (claude-code-ide.el, claudecode.nvim) are the second choice.
5. **A snapshot for every agent an editor starts:** yes, as for Super+a, skipped when nothing changed since the last one.
6. **gptel's backends:** Claude and local added, the default following `vikix ai use`; OpenAI and Perplexity kept as extras.

## 1. Neovim into Vikix

Shipped in 0.55.0: Vikix's part in `config/nvim` (linked to `~/.local/share/vikix/nvim`), the starter copied to `~/.config/nvim`, the tested lock moved on only while it's untouched, an unchanged clone of `nvim-void-linux` set aside by `45-editors` (which every update runs, so no migration was needed), `tests/nvim.sh`, the editors test on the checkout's config, doctor, `yours.list`, the docs. The Lua is compiled by `tests/nvim.sh`; selene or stylua weren't added. Left:

- [ ] **Archive `nvim-void-linux`** (decision 2): a README pointing to Vikix, then archive it on GitHub. Only after machines have updated past 0.55.0: until then their `vikix update` pulls it.
- [ ] **AstroNvim's major versions are Vikix's work now** (v5 → v6 needed nvim-treesitter's main branch for Neovim 0.12): when v7 comes, move `version = "^6"` in `config/nvim/lua/vikix/init.lua` and the lock together, after `tests/editors.sh nvim`.

## 2. A safe way for an editor to start an agent

Shipped in 0.56.0: `vikix agent --exec [NAME] [ARGS]` (the same start as `--use`: the guide, no keys or SSH agent, a snapshot, skipped when nothing changed; stdout left to the agent, Vikix's words on stderr, no questions, an error when it isn't installed), `vikix agent --which`, and `vikix ai use` alone printing Super+i's model; tests in `tests/agents.sh` and `tests/ai-keys.sh`; README, `docs/ai.md`, the skill. Left, for parts 3 and 4, once the editors' packages are chosen:

- [ ] **ACP adapters** where an agent needs one: install them with the agent (`vikix agent --install`), npm into `~/.local` (nodejs comes with `editor-tools`). Check which agents speak ACP themselves and which need an adapter (Claude Code and Codex needed one as of mid-2026; Gemini CLI had it built in; OpenCode had support).

## 3. AI in Neovim

In Vikix's layer, once part 1 has shipped.

- [ ] **Chat and edits: CodeCompanion.nvim,** with two adapters: Claude (the `ANTHROPIC_API_KEY` from `vikix ai key`) and Ollama; the default follows `vikix ai use`. Check whether astrocommunity has a pack for it.
- [ ] **Agents: CodeCompanion's ACP support,** each agent started with `vikix agent --exec`. Check that its command can be set to that.
- [ ] **Second choice: claudecode.nvim** (Claude Code's IDE protocol, as its VS Code extension uses: the open file, the selection, diffs in Neovim), with its terminal command set to `vikix agent --exec claude`.
- [ ] **Keys** under one leader group (`<Leader>a`?), shown by which-key.
- [ ] **No key, no Ollama, no agent:** Neovim starts quietly, and the AI keys say what to do (`vikix ai key set`, `vikix ai setup`, `vikix agent --install`).
- [ ] **Test:** a start with no keys and no network shows no errors.

## 4. AI in Emacs

In `vikix-ai.el`, which Vikix keeps current and `emacs-void` loads when it is there (decision 3).

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
- [ ] **The editors follow `vikix theme`** (TODO.md item 6): easy for Neovim now that it's in Vikix (the layer reads the palette `vikix theme` writes); for Emacs, a theme file written the same way.
- [ ] **The Vikix MCP server** (`vikix mcp`, since 0.54.0): registered for the agents the editors start too.

## Other agentic editors (for the docs, not for Vikix to install)

Worth a line in `docs/editors.md`; none of them a feature for now. Recheck before writing it: this is from mid-2026.

- **Zed:** official Linux builds, a script that installs into `~/.local`; runs ACP agents (Claude Code, Gemini) itself. Needs Vulkan: may struggle on old GPUs and in the VM. The one GUI editor that might one day be a feature.
- **VS Code:** Void's `vscode` is the open-source build, with Open VSX rather than Microsoft's marketplace, so some extensions (Copilot) aren't there.
- **Cursor, Windsurf:** proprietary Electron editors. Cursor is an AppImage (needs `fuse` on Void). They work, but aren't Vikix's style.
- **In the terminal:** everything `vikix agent --use` offers, next to either editor.
