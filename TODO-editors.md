# Editors: Neovim in Vikix, and AI in both editors

The plan for Vikix's two editors, drawn up on 2026-09-29 from Vikix 0.52.1. The general list is `TODO.md`; this one is only the editors. Delete an item when it ships, and this file when it's empty.

The goal: Vikix supports two editors, Neovim and Emacs, and both work well with AI: a model for chat and edits, and an agent working in your project, using what Vikix already knows (your keys, your chosen agent, local models) and keeping its safety rules (a snapshot first, no keys in the agent's environment).

## Where things stood (0.52.1; Neovim's config moved into Vikix in 0.55.0)

- **The editors are features:** `vikix add emacs` / `vikix add neovim`, with the lists `emacs`, `neovim` and `editor-tools` (nodejs, for the npm language servers). `essentials` brings Emacs, `developer` and `everything` both.
- **Their configs were sister repos** (Emacs's still is), cloned by `install/45-editors.sh` and pulled by every `vikix update`: `~/.emacs.d` from `VIKIX_EMACS_REPO` (vukini/emacs-void), `~/.config/nvim` from `VIKIX_NVIM_REPO` (vukini/nvim-void-linux). Neovim's plugins are restored to `lazy-lock.json` at install; Emacs installs its packages in the daemon `vikix-session` starts.
- **Language servers:** Void's come with each `lang-*` list (ccls, gopls, ...), and `45-editors` puts typescript-language-server, pyright and bash-language-server in `~/.local` with npm.
- **Terminal agents are done:** `vikix agent --use claude|opencode|codex|gemini|aider`, `--local` through Ollama, one guide (`~/.local/share/vikix/AGENTS.md` and the skill), a snapshot first, and no API keys or SSH agent in the agent's environment.
- **The editors knew none of it** (Neovim's AI came in 0.57.0, part 3). Emacs has gptel with OpenAI and Perplexity, defaulting to Perplexity's `sonar-pro`, so a Vikix user without that key gets an error, and neither the Claude key (`vikix ai key`) nor local Ollama is offered.
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

Shipped in 0.56.0: `vikix agent --exec [NAME] [ARGS]` (the same start as `--use`: the guide, no keys or SSH agent, a snapshot, skipped when nothing changed; stdout left to the agent, Vikix's words on stderr, no questions, an error when it isn't installed), `vikix agent --which`, and `vikix ai use` alone printing Super+i's model. In 0.57.0: `vikix agent --acp [NAME]`, with the ACP adapters for Claude Code and Codex (`@agentclientprotocol/claude-agent-acp`, `codex-acp`, pinned in `bin/vikix-agent`) installed by `--install` with `npm --os=none` (no bundled copy of the agent: 56 MB, not 290), pointed at the installed agent. Gemini (`--acp`; `--experimental-acp` is deprecated) and OpenCode (`acp`) speak it themselves. Left:

- [ ] **Moving the adapters on:** a new pin reaches a machine only through `vikix agent --install NAME` (which adds or moves the adapter, and leaves the agent alone). `vikix update` could do it for installed agents, or a migration when a pin moves.
- [ ] **codex-acp and the installed Codex:** the adapter talks to `codex app-server`; an old Codex against a newer adapter wasn't tried (Codex isn't installed here).

## 3. AI in Neovim

Shipped in 0.57.0, in `config/nvim/lua/vikix/plugins/ai.lua`: AstroCommunity's CodeCompanion pack (keys under `<Leader>A`), the chat on `vikix ai use`'s model (Anthropic with the key from the session or `~/.config/vikix/secrets`, or Ollama; `model=` too), the four ACP agents started by `vikix agent --acp` (the presets' other commands, `--yolo`, removed), CodeCompanion's CLI agents as `vikix agent [--use NAME]` (so Aider too), and keys that say what's missing. Tried for real: Claude Code over ACP from Neovim answered; a local chat reached Ollama. `tests/editors.sh` checks the keys with no key and no agent. claudecode.nvim wasn't needed. Left:

- [ ] **A local model is slow in CodeCompanion's chat:** its instructions plus the project's rules (`CLAUDE.md`) are about 3,600 tokens, which llama3.2:3b on this X1's CPU reads at about 10 a second (six minutes before the first answer). For `use=local`: a shorter system prompt, and rules off?
- [ ] **The Vikix MCP server** for the agents CodeCompanion starts (part 5).

## 4. AI in Emacs

Shipped in 0.59.0 and 0.60.0, in `config/emacs/vikix-ai.el` (linked to `~/.local/share/vikix/emacs` by `45-editors`), which `emacs-void` loads when it is there (decision 3). gptel: the backends "Claude" (the session's key, or `~/.config/vikix/secrets`) and "Local" (Ollama's models as they are at each `C-c g`), the default following `vikix ai use` and `model=` (read again at each `C-c g` / `C-c G`; a pick of yours stays until the file changes), and `C-c g` saying what's missing before gptel asks for a key. Agents: agent-shell with Vikix's four ACP agents, each started by `vikix agent --acp`; `C-c a` a chat with your agent, `C-c A` your agent in a terminal (vterm, `vikix agent`, so Aider too); each says what's missing. Everything is guarded: without the file nothing changes, and the agents check for `vikix` on PATH. `tests/emacs.sh`, and `tests/editors.sh` loads the checkout's part. Tried for real: Claude and llama3.2:3b answered through gptel, Claude Code over ACP through agent-shell's client. claude-code-ide.el and aidermacs weren't needed.

## 5. Afterwards, in Vikix

- [ ] **vikix.dev: screenshots of AI in each editor** (void and paper), for the gallery. The page has a line for it, "AI in your editor", since 0.61.0.
- [ ] **The editors follow `vikix theme`** (TODO.md item 6): easy for Neovim now that it's in Vikix (the layer reads the palette `vikix theme` writes); for Emacs, a theme file written the same way.
- [ ] **The Vikix MCP server** (`vikix mcp`, since 0.54.0): registered for the agents the editors start too.

## Other agentic editors (for the docs, not for Vikix to install)

Worth a line in `docs/editors.md` (the guide, since 0.61.0); none of them a feature for now. Recheck before writing it: this is from mid-2026.

- **Zed:** official Linux builds, a script that installs into `~/.local`; runs ACP agents (Claude Code, Gemini) itself. Needs Vulkan: may struggle on old GPUs and in the VM. The one GUI editor that might one day be a feature.
- **VS Code:** Void's `vscode` is the open-source build, with Open VSX rather than Microsoft's marketplace, so some extensions (Copilot) aren't there.
- **Cursor, Windsurf:** proprietary Electron editors. Cursor is an AppImage (needs `fuse` on Void). They work, but aren't Vikix's style.
- **In the terminal:** everything `vikix agent --use` offers, next to either editor.
