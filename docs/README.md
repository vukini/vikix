# Finding your way around Vikix

These pages are for someone who has installed Vikix and wants to know where things are and how to make it their own. The main [README](../README.md) is the full reference: every key, every package list, every test. These pages are the map.

They are on your machine too, in three forms: as these files in `~/vikix/docs/`, as web pages with the diagrams drawn as pictures (`Super+m` → *Vikix guide in the browser*), and as an Info manual. Read that with `Super+m` → *Vikix guide* (in Emacs if you have it, otherwise in a terminal), `C-h i` then *Vikix* in Emacs, or `info vikix` in a terminal.

| Page | Read it when |
|---|---|
| [Where everything is](map.md) | You want to find a file: what Vikix put where, and whose it is |
| [How it fits together](how-it-works.md) | You want to know what the base and the features are, what happens between logging in and the desktop, or what `vikix update` does |
| [Making it yours](customize.md) | You want to change something: keys, startup programs, the bar, the theme, the terminal, what's installed |
| [Neovim and Emacs](editors.md) | You write code or text in Neovim or Emacs: which files are yours, the language servers, AI beside your code |
| [Working with AI](ai.md) | You want the agent to change something for you, a model on the laptop, `llm` in a pipe, dictation, to talk with the AI, to ask your notes, or to give the agent the desktop as tools |
| [Windows in a window](windows.md) | You need a program that only runs on Windows |
| [When something breaks](fixing.md) | The install or the desktop didn't start, a key or a menu entry is missing, an update failed, you want a report to ask the agent or a person |

## Six things to know first

1. **Vikix sits on top of Void.** Underneath is an ordinary Void Linux: xbps for packages, runit for services, no systemd. Vikix adds a desktop (StumpWM), a set of programs, their config, and the `vikix` command. It doesn't replace anything of Void's.
2. **The install is the base; the rest you add.** The base is a whole desktop: terminal, browser, files, sound, Wi-Fi, Bluetooth, the AI agent. Languages, editors, LibreOffice, printing, Windows and local AI are **features**: `vikix features` lists them, `vikix add NAME` installs one, `vikix remove NAME` takes it away again, and `vikix update` keeps what you chose.
3. **Every config file is either Vikix's or yours.** Vikix's files are symlinks into `~/vikix`, and `vikix update` replaces them. Your files are copies Vikix made once and never touches again. Change your files, not Vikix's. [Where everything is](map.md) says which is which.
4. **`~/.stumpwm.d/user.lisp` is where the desktop is yours.** It loads last, so anything in it wins over Vikix's defaults: keys, startup programs, the terminal, the menu, the bar.
5. **Your files have an undo.** `vikix snapshot` before a change, `vikix changes` after it, `vikix undo` to take it back.
6. **`Super+m`, `Super+/` and `Super+F1` are the way in.** The welcome that opened at your first login is there too (`Super+m` → *Welcome*), and so is *Add software*, for the languages, editors and the rest. `Super+m` is the Vikix menu (an entry for a feature you don't have is left out until you add it); `Super+/` shows every key at a glance, and `Super+F1` lists them so you can search and run one from there. `vikix doctor` checks that everything is in place.
