# Steam

Steam runs games, and through Proton most Windows games too. On a plain Void Linux it is a headache: Steam is a 32-bit program, Void keeps its 32-bit libraries in a repository of its own (multilib) that is off by default, and the right ones depend on your graphics card. One missing library stops the client; the next one stops the first game. Vikix does the whole of it in one command.

## Adding it

```sh
vikix add steam
```

Or pick it in the welcome (Super+m → Add software). It asks for your password once, then:

- **switches on the multilib repository** (and multilib-nonfree, for a proprietary NVIDIA driver), and points it at the mirror Vikix chose for you;
- **installs Steam** from Void's nonfree repository, with the 32-bit libraries every card needs and the Vulkan loader, both widths (`packages/optional/steam.list`; `vikix update` keeps them);
- **reads your graphics card** from `/sys/class/drm` and installs its Vulkan driver in both widths: Intel (`mesa-vulkan-intel`), AMD (`mesa-vulkan-radeon`), NVIDIA with the open driver (`mesa-vulkan-nouveau`), or with the proprietary one the 32-bit libraries of the very `nvidia` package you have;
- **raises your open-files limit** to 524288 in `/etc/security/limits.d/50-vikix-steam.conf`. Proton's esync opens a file for every object a Windows game makes, and Void's limit of 4096 is far too few. It takes effect at your next login.

Game controllers need nothing: Steam's udev rules tag them for your seat, and elogind hands them to you when you plug one in.

A card the setup doesn't know (a virtual machine's, say) still gets Steam, with a warning: games that need Vulkan won't run there.

## Playing

Super+m → Apps → Games (Steam), or type `steam`. The first start downloads the Steam client itself, about 500 MB, into `~/.local/share/Steam`; your games go there too. Log in, and install a game.

For Windows games, once, in Steam: Settings → Compatibility → **Enable Steam Play for all other titles**. Steam then runs them through Proton, its own Wine. Whether a game works is on [protondb.com](https://www.protondb.com); the ones that don't are mostly those whose anti-cheat refuses Linux.

A game in full screen takes the screen as any window does; Super+Tab and the workspace keys still work. A game that wants a window of its own size floats if you ask: a [rule](rules.md) such as `(when-window (:class "steam_app_12345") (float))`, the class from `xprop` or Super+Alt+? on the window.

## Seeing what is there

```sh
vikix steam status
```

says, line by line, whether the repository is on, Steam and its libraries are installed, what card was found and whether its driver is there, what the open-files limit is, and how much Steam's folder takes. `vikix doctor` checks the same once Steam is one of your features.

## When it doesn't work

- **Steam doesn't start, or a game doesn't.** `vikix steam status` first: a line beginning `--` is something missing, and `vikix steam setup` puts it back. Then start Steam from a terminal, `steam`, and read what it says: a line like `error while loading shared libraries: libXXX.so` names a 32-bit library that isn't there; `xbps-query -Rs XXX-32bit` finds its package.
- **A Windows game crashes with "eventfd: Too many open files".** You haven't logged in again since the setup: `ulimit -Hn` should say 524288.
- **No Vulkan, so Proton games fail.** `vikix steam status` shows the card and its packages. On a machine with two cards (Intel and NVIDIA, say) both are set up; a game then runs on the one the system gives it.
- **No sound in a game.** Steam talks to PulseAudio, which PipeWire answers for in Vikix (`pipewire-pulse`). `pactl info` should name it. Nothing 32-bit is needed for sound: Steam brings its own.
- **A controller isn't seen.** Plug it in after logging in, and check `loginctl` lists your session: elogind gives the seat's devices to the user logged in on it.

## Removing it

```sh
vikix remove steam
```

takes Steam and the 32-bit libraries away, with the card's 32-bit driver and the open-files limit. The card's 64-bit Vulkan driver stays, since any program that draws with Vulkan may use it, and so does the multilib repository (`sudo xbps-remove void-repo-multilib` switches it off). The client and your games, in `~/.local/share/Steam` and `~/.steam`, are yours and stay: delete the folders yourself for the disk back.
