---
title: "Vikix: Void, supercharged"
theme: void
font: "JetBrains Mono"
---

# Vikix

Void Linux, supercharged

<!-- A sample Hype presentation that comes with Vikix. Open it with: hype open ~/vikix/examples/hype/vikix-tour/presentation.md Copy the folder somewhere of your own before changing it: vikix update keeps ~/vikix as it is on GitHub. -->

---

# What it is

- A plain **Void Linux** install underneath
- **StumpWM**: a window manager written in Common Lisp
- One command keeps it current: `vikix update`

<!-- Not a distribution: bash install stages on top of Void, the config they put in place, and the vikix command. Inspired by Omarchy, its own thing. -->

---

![fit](work-void.webp)

---

# Keys first

- `Super+Return` a terminal
- `Super+d` the launcher
- `Super+a` the AI agent
- `Super+/` every key on one card

---

![fit](keys-void.webp)

---

# Change it while it runs

```lisp
;; ~/.stumpwm.d/user.lisp loads last, so it wins
(vikix-bind "s-M-y" "exec xterm")
(setf *vikix-terminal* "kitty")
```

<!-- vikix eval '(form)' sends Lisp to the running window manager; Emacs reaches it with SLIME on 127.0.0.1:4004. -->

---

# One theme, everywhere

| Theme | Look |
| --- | --- |
| void | dark, the default |
| paper | light |
| gruvbox | warm and retro |
| nord | cool arctic blues |
| tokyo-night | deep blue, neon |
| contrast | white on black, 7:1 |

<!-- vikix theme NAME: StumpWM, the terminals, rofi, notifications, the lock screen, the wallpaper, Emacs, Neovim, and Hype. -->

---

# Your files are yours

- Vikix's files are links into its checkout
- Yours are copies it never overwrites
- `vikix snapshot`, `vikix changes`, `vikix undo`

---

# Add what you need

- `vikix add python rust emacs`
- `vikix add hype` for slides like these
- `vikix features` lists the rest

---

# Make it yours.

vikix.dev
