# Neovim and Emacs

Vikix has two editors, Neovim and Emacs, each with a config ready to use, the language servers for the languages you added, and AI: a chat on the model Super+i uses, and your agent (the one Super+a starts) beside your code. Neither is installed until you ask for it:

```sh
vikix add neovim        # or: vikix add emacs; the developer bundle brings both
vikix remove emacs      # takes it away again; your files stay
```

`essentials` brings Emacs; `developer` and `everything` bring both. `$EDITOR` is `nvim` unless you set another.

## Starting them

| Type or press | What opens |
|---|---|
| `v FILE` | Neovim, in this terminal |
| `Super+x` | An Emacs window |
| `e FILE` | The file in a new Emacs window (the terminal waits until you close it) |
| `eg FILE` | The same, with the terminal free at once |
| `ec FILE` | Emacs inside this terminal |
| `eq` | Emacs with no config at all: for finding out whether the config is the problem |
| `emacs-restart` | A fresh Emacs, after you changed its config (it refuses while a file is unsaved, and asks before ending open chats) |

Emacs runs as a server from the moment you log in, so `Super+x` and `e` open a window at once. The first time Emacs starts on a new machine, it downloads its packages in the background: give it a few minutes before the first `e`.

## Who owns what

Neovim's config is Vikix's own, split in two like the desktop's:

| Where | Whose | What |
|---|---|---|
| `~/.local/share/vikix/nvim` | Vikix's | AstroNvim and Vikix's plugins. A link into `~/vikix`: `vikix update` keeps it current, so don't edit it |
| `~/.config/nvim` | yours | `init.lua` (your settings go at its end), your plugins in `lua/plugins/`, and `lazy-lock.json`, the plugins' versions |

Emacs's config is a separate repository, the author's own ([emacs-void](https://github.com/vukini/emacs-void)):

| Where | Whose | What |
|---|---|---|
| `~/.emacs.d` | a git clone | The config, `config.org`. `vikix update` pulls it; a change of yours there can stop the pull (the update says so and carries on) |
| `~/.local/share/vikix/emacs` | Vikix's | `vikix-ai.el`, the AI setup, and `vikix-theme.el`, which makes Emacs follow `vikix theme`. A link into `~/vikix`, kept current by `vikix update`; the config loads them when they're there |

Both are in [Where everything is](map.md), with the rest of your files.

## Neovim

Neovim is [AstroNvim](https://astronvim.com) with a few choices of Vikix's: Typst with a live preview (`:TypstPreview`), a function's parameters shown while you type its call, `jk` or `jj` to leave insert mode, and the AI keys below. `Space` is the leader: press it and wait, and a menu shows what comes next.

Your own plugins go in `~/.config/nvim/lua/plugins/`, one or more files that each return plugin specs. They load after Vikix's, so yours win. `example.lua` there shows a plugin more, an AstroNvim setting, one of Vikix's plugins switched off, and another colour scheme. Plain settings (`vim.opt.…`) and keys (`vim.keymap.set(…)`) can go at the end of `~/.config/nvim/init.lua`, after the line that loads Vikix's part.

The plugins are installed at the versions Vikix tested, and `vikix update` moves them on when Vikix tests newer ones. Plugins you add keep their own versions. After a `:Lazy update` of yours, Vikix's plugins keep your versions too: updates leave them alone and say once how to take Vikix's again.

## Emacs

Emacs's config is organised in `~/.emacs.d/config.org`, one section per concern (completion, Org, Lisp, languages, tools), and each section explains itself. Emacs reads it at start. SLIME in it talks to the running window manager on port 4004 (see [How it fits together](how-it-works.md)).

To change it, edit `config.org` and run `emacs-restart`. `vikix update` brings Vikix's new AI setup into an Emacs that's running, with your chats left open; an Emacs started without it (before Vikix 0.59) is told to restart, and `vikix doctor` says which you have. The clone is yours to change, but a change there can stop `vikix update` from pulling the author's newer version: keep your changes in a commit of your own, or in a config of your own (below).

## Language servers

A language server is what lets the editor complete names, jump to a definition and underline mistakes as you type. Each comes with its language, so `vikix add c` brings C's, and both editors find them on PATH:

| Language | Server | Comes with |
|---|---|---|
| C, C++ | `ccls`, `clangd` | `vikix add c` |
| Go | `gopls` | `vikix add go` |
| Rust | `rust-analyzer` | `vikix add rust` |
| Zig | `zls` | `vikix add zig` |
| Lua | `lua-language-server` | `vikix add lua` |
| JavaScript, TypeScript | `typescript-language-server` | either editor (npm, in `~/.local/bin`) |
| Python | `pyright` | either editor (npm) |
| Bash | `bash-language-server` | either editor (npm) |
| OCaml | `ocaml-lsp-server` | `opam install ocaml-lsp-server`, after `vikix add ocaml` |

Neovim also gets `efm-langserver`, which runs linters and formatters. In Emacs, eglot starts the server when you open a C, C++, JavaScript, TypeScript, Python, Zig or Odin file.

## AI in the editors

Both editors do the same four things, each on the settings you already made for the desktop:

| | Neovim | Emacs |
|---|---|---|
| A chat on the model Super+i uses | `Space A c` | `C-c g` |
| Ask about the selection, or change it | `Space A q` | `C-c g` with a selection, or `C-c G` (gptel's menu) |
| A chat with your agent | `Space A g` | `C-c a` |
| Your agent in a terminal | `Space A t` | `C-c A` |

**The chat** follows `vikix ai use`: `local` for a model on this laptop (`vikix ai setup` first), or `claude` for Claude (with your key: `vikix ai key set anthropic`). A model set with `model=` in `~/.config/vikix/ai` is used here too. Emacs reads that file again at each `C-c g`, so a change reaches an Emacs that's already open; a model you pick in gptel's menu stays until the file changes. On a laptop's CPU a local model can take minutes to begin answering, because it first reads the chat's instructions (Neovim's are long); Claude answers in seconds.

**Your agent** is the one Super+a starts (Claude Code unless you chose another: `vikix agent --default NAME`). The editors start it the same way, with `vikix agent`: it gets the guide to Vikix, no API keys or SSH agent (the editors have them, the agent doesn't need them), and a snapshot first, so `vikix changes` shows what it did and `vikix undo` takes it back. It signs in with its own login, the one it uses in a terminal. In a chat it talks over ACP (the Agent Client Protocol): Claude Code, Codex, Gemini CLI and OpenCode speak it, and `vikix agent --install NAME` adds one with what it needs (running it again for an agent you have adds only what's missing). Aider doesn't: its place is the terminal key.

In Emacs, each agent chat's transcript is kept in `~/.local/state/vikix/agent-shell/`, one file per chat, named after the project, in a folder only you can read; not in the project, where agent-shell would put it. Screenshots and images you give the agent do go in the project's `.agent-shell/`, which agent-shell keeps out of git.

`C-c a` goes back to the chat this project already has; in a folder without one it asks first (*New shell* starts one here), and `C-u C-c a` always starts another. In Neovim, a chat's top line says who answers before you type.

Nothing starts or connects until you press a key. When something's missing (a key, the local model, the agent or its adapter), the key says what to type, and does nothing else. [Working with AI](ai.md) has the rest: keys, local models, and choosing an agent.

## A config of your own

To use your own config for either editor, install Vikix with `VIKIX_NVIM_REPO=` or `VIKIX_EMACS_REPO=` set to your repository, or put yours in the folder yourself: a git clone at `~/.config/nvim` or `~/.emacs.d` is pulled by updates, and any other folder of yours is left alone.

In a Neovim config of your own, Vikix's plugins aren't there. In an Emacs config of your own, the AI setup can still be: load it after your gptel setup,

```elisp
(load (expand-file-name "~/.local/share/vikix/emacs/vikix-ai") t t)
```

and bind `vikix-ai-agent` and `vikix-ai-agent-terminal` to keys of yours. On a machine without Vikix the file isn't there, and the line does nothing.

## When an editor doesn't work

- **Neovim's plugins didn't install:** their output is in `~/.local/state/vikix/logs/nvim-plugins.log`. `:Lazy` shows each plugin, and `:checkhealth` what's missing.
- **Emacs opens with errors:** try `eq`. If Emacs is fine without its config, the config is the problem: the errors are in `*Messages*` (`C-h e`). After a fix, `emacs-restart`.
- **A language server doesn't start:** check it's there (`command -v gopls`); the language's feature brings it (`vikix add go`).
- **An AI key does nothing but print a message:** do what it says. `vikix doctor` checks the rest, and [When something breaks](fixing.md) has more.
