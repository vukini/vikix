# Finding your way around Vikix

These pages are for someone who has installed Vikix and wants to know where things are and how to make it their own. The main [README](../README.md) is the full reference: every key, every package list, every test. These pages are the map.

They are in the Vikix checkout, so they are on your machine too: `~/vikix/docs/`.

| Page | Read it when |
|---|---|
| [Where everything is](map.md) | You want to find a file: what Vikix put where, and whose it is |
| [How it fits together](how-it-works.md) | You want to know what happens between logging in and the desktop, or what `vikix update` does |
| [Making it yours](customize.md) | You want to change something: keys, startup programs, the bar, the theme, the terminal, packages |
| [When something breaks](fixing.md) | The desktop didn't start, a key stopped working, an update failed |

## Five things to know first

1. **Vikix sits on top of Void.** Underneath is an ordinary Void Linux: xbps for packages, runit for services, no systemd. Vikix adds a desktop (StumpWM), a set of programs, their config, and the `vikix` command. It doesn't replace anything of Void's.
2. **Every config file is either Vikix's or yours.** Vikix's files are symlinks into `~/vikix`, and `vikix update` replaces them. Your files are copies Vikix made once and never touches again. Change your files, not Vikix's. [Where everything is](map.md) says which is which.
3. **`~/.stumpwm.d/user.lisp` is where the desktop is yours.** It loads last, so anything in it wins over Vikix's defaults: keys, startup programs, the terminal, the menu, the bar.
4. **Your files have an undo.** `vikix snapshot` before a change, `vikix changes` after it, `vikix undo` to take it back.
5. **`Super+m` and `Super+F1` are the way in.** `Super+m` is the Vikix menu; `Super+F1` lists every key, and you can search it and run one from there. `vikix doctor` checks that everything is in place.
