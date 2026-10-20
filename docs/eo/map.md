# Kien ĉio estas

Kion Vikix metas sur via aparato, kie, kaj de kiu ĝi estas. Tri tipoj de dosieroj:

- **De Vikix**: simbolika ligilo en la ĉefdosierujo. `vikix update` anstataŭigas ĝin. Ne redaktu ĝin; via ŝanĝo perdiĝus, kaj `vikix update` haltigus, ĉar ĝi uzas `git pull --ff-only`.
- **Via**: unufoje kopita el baza dosiero en `~/vikix/config/`, poste neniam plu tuŝita. Redaktu senhezite. Ĉi tiuj havas historion: vidu [malkonfaron](customize.md#antaŭ-ol-vi-ion-ŝanĝas).
- **Kreita por vi**: kreita per komando de Vikix kaj denove skribita ĉiufoje, kiam tiu komando ekzekutas. Ne redaktu ilin; ŝanĝu la bazon, el kiu ili estas kreitaj.

`ls -l` diferencigas la unuan kaj la duan: dosieroj de Vikix montras `-> /home/you/vikix/...`.

## Via hejma dosierujo

```
~/
├── vikix/                     the checkout: Vikix itself (see below)
│
├── .stumpwm.d/
│   ├── init.lisp              Vikix's   loads Vikix's layer, then rules.lisp and user.lisp
│   ├── vikix/                 Vikix's   the layer: errors, theme, groups, registry, commands, windows, rules, viri, drawer, layouts, overview, resume, day, why, used, keys, help, webapps, modeline, plugins, rescue, door, swank-guard, swank, socket
│   ├── rules.lisp             yours     your rules for the desktop: copied once, every example switched off; Super+Shift+t adds to it (rules.md)
│   ├── user.lisp              yours     your StumpWM settings; loaded last, so they win
│   └── modules/               stumpwm-contrib, cloned by 30-lisp (swm-gaps, ttf-fonts, ...)
│
├── .xinitrc                   Vikix's   runs vikix-session inside dbus-run-session
├── .bash_profile              yours     with Vikix's marked blocks: PATH, read .bashrc, startx on tty1
├── .bashrc                    yours     with one marked block at the top that reads vikix.bash
├── .Xresources                yours     text size (Xft.dpi) and cursor size
├── .sbclrc                    yours     loads Quicklisp (added by 30-lisp)
├── .slime-secret              yours     Swank's password (600): Emacs and vikix eval send it
│
├── .config/
│   ├── vikix/
│   │   ├── vikix.bash         Vikix's   aliases, prompt, fzf/zoxide/atuin setup
│   │   ├── keyboard           yours     layout and XKB options
│   │   ├── network/preferences.json  yours  discovery choice for each network (Network Office)
│   │   ├── plugins.list       yours     the plugins you added (vikix plugin add); "NAME from REPO at COMMIT" is one from another repository, at the commit you pinned; "#off " in front, one switched off
│   │   ├── tray               yours     the tray in the bar: on or off (vikix tray switches it), and the applets it starts
│   │   ├── plugins/NAME/      yours     your settings for plugin NAME (copied once)
│   │   ├── obsidian           yours     vikix obsidian's vault, where its notes go, and the folders it leaves out
│   │   ├── idle               yours     minutes before lock, dark screen, suspend (make it; see customize.md)
│   │   ├── backup             yours     where backups go, and the reminder's days
│   │   ├── backup-exclude     yours     what backups leave out
│   │   ├── backup-password    yours     the backup password (never in snapshots)
│   │   ├── secrets/           yours     API keys, one file each (vikix ai key), and windows-password, your Windows account's (vikix windows apps); never in snapshots
│   │   ├── ai                 yours     which model Super+i uses: use=local, claude or codex, model=, translate_model=, effort=, languages=
│   │   ├── agent              yours     which agent Super+a starts (vikix agent --default NAME)
│   │   ├── dictation          yours     dictation's model: base.en, small or large-v3-turbo (vikix dictate models)
│   │   ├── voice              yours     how the AI talks back: voice=, speak=, idle= (vikix voice)
│   │   ├── notes              yours     the folder `note` reads: folder=, skip=, embed= (note index)
│   │   ├── projects           yours     where `vikix project` looks: root=, depth=, logs= (copied once, all comments)
│   │   ├── features           yours     the features you chose (vikix add, vikix remove, vikix features)
│   │   ├── packages-skip      yours     packages you dropped (vikix pkg drop); updates leave them out
│   │   ├── windows            yours     where the Windows VM's disk is
│   │   ├── webapps            yours     your web apps: NAME URL [KEY] (vikix webapp)
│   │   ├── docs-browser       yours     the browser for guides and docs, one word (make it; Nyxt without it, when installed)
│   │   ├── docs-links         yours     your own links for the catalogue, a URL and its title a line (make it; listed, never fetched)
│   │   ├── wallpaper          yours     a link to the picture you chose
│   │   ├── wallpaper-off      yours     exists if you set the wallpaper with your own tool
│   │   ├── titlebars-off      yours     exists if you turned the title bars off (Super+Ctrl+y)
│   │   ├── gestures           yours     the touchpad's sweeps: fingers, distance, natural (vikix gestures)
│   │   ├── wallpaper-theme    yours     exists if the wallpaper follows the theme instead of cycling
│   │   ├── wallpaper-minutes  yours     how often the wallpaper changes when cycling (vikix-wallpaper cycle MINUTES; 30 without it)
│   │   ├── themes/            yours     your own themes (NAME.theme, NAME.jpg)
│   │   └── theme/             written   each program's colours, and `current`, the theme you chose (`vikix theme`); GTK's and Qt's too: `mode` (dark or light), xsettingsd.conf, gtk4.css, qt6ct-colors.conf
│   ├── alacritty/alacritty.toml   yours  imports ../vikix/theme/alacritty.toml
│   ├── picom/picom.conf           yours  the compositor: shadows, fading, backend
│   ├── dunst/dunstrc              yours  notifications
│   ├── dunst/dunstrc.d/10-vikix-theme.conf   written   the theme's colours for dunst
│   ├── rofi/config.rasi           yours  the launcher and menus
│   ├── gammastep/config.ini       yours  night light times and colours
│   ├── mimeapps.list              yours  which program opens which kind of file
│   ├── fontconfig/conf.d/50-vikix-iosevka.conf   Vikix's   monospace means Iosevka
│   ├── autorandr/                 yours     screen layouts, one folder each (Vikix's are auto-…); predetect.d/vikix, Vikix's, lays out a screen with none
│   ├── udiskie/config.yml         yours, if you make it: replaces Vikix's udiskie settings
│   ├── nyxt/config.lisp           yours     with the feature lisp-apps: Nyxt's settings, in Lisp; loads Vikix's part first (the desktop's colours)
│   └── nvim/                      yours     with the feature neovim: init.lua (your settings at its end), your plugins in lua/plugins/, lazy-lock.json
│
├── .emacs.d/                  with the feature emacs: a git clone of the Emacs config (vukini/emacs-void)
├── .claude/skills/vikix       Vikix's   tells Claude Code how Vikix works: SKILL.md, the short first page, and a page a subject
│
├── .local/
│   ├── bin/
│   │   ├── vikix, vikix-*     Vikix's   the command and its helpers
│   │   ├── stumpwm            built     the window manager, built by 30-lisp (`vikix rebuild-wm`)
│   │   └── pil, claude, ...   installed by 65-languages, the npm language servers, Claude Code
│   ├── share/applications/*.desktop   Vikix's   JupyterLab, vikix-image, Lazarus in the launcher (Super+d); your web apps' too, Lem's and the Listener's (lisp-apps), Esploro's, and the Windows programs you added (vikix-win-NAME.desktop, vikix windows apps add)
│   ├── share/vikix/fonts/wm.ttf       built     the bar's font, made by vikix-font
│   ├── share/vikix/nvim               Vikix's   Vikix's part of Neovim: AstroNvim and Vikix's plugins (a link to config/nvim)
│   ├── share/vikix/nyxt/vikix.lisp    Vikix's   Vikix's part of Nyxt: its colours from vikix theme's palette, followed live, and Swank on 127.0.0.1:4006 with ~/.slime-secret (a link to config/nyxt)
│   ├── share/vikix/epubcheck/         fetched   epubcheck, W3C's EPUB validator: a pinned release, checked against its checksum (vikix publish setup)
│   ├── share/vikix/hunspell/          fetched   the spelling's dictionaries: LibreOffice's British English, Esperanto and Arabic, pinned and checksummed (vikix publish setup)
│   ├── share/vikix/publish            Vikix's   the make targets a book's Makefile includes (epub, pdf, check), and the build behind them (a link to lib/publish)
│   ├── share/vikix/emacs              Vikix's   Vikix's part of Emacs: vikix-ai.el, gptel on vikix ai use's model and your agent in agent-shell; vikix-theme.el, the theme following vikix theme; vikix-notes.el, the notes under C-c n (a link to config/emacs)
│   ├── share/info/vikix.info          written   these guides as an Info manual (`info vikix`)
│   ├── share/man/man1/*.1             written   a man page for every vikix command (`man vikix`, `man vikix-backup`) and for your plugins' commands (`man inbox`), made from what each -h prints; other programs' pages here are left alone
│   ├── share/vikix/guide/             written   these guides as web pages, with the diagrams (Super+m → Vikix guide in the browser: in Nyxt when it's installed, through vikix-docs-open)
│   ├── share/dbus-1/services/org.freedesktop.FileManager1.service   Vikix's   the browsers' "Show in folder" opens Esploro (vikix add esploro)
│   ├── share/vikix/wallpapers/        fetched   Vid's wallpapers, a git clone (vikix add wallpapers; a link to ~/wallpapers if that's a clone of it)
│   ├── share/vikix/whisper/           fetched   dictation's model and voice detector (vikix dictate)
│   ├── share/vikix/piper/             fetched   the voice the AI talks with (vikix voice)
│   ├── share/vikix/notes/index.db     written   note's index: passages of your notes and their embeddings (folder 700; note index)
│   ├── share/vikix/AGENTS.md          written   the skill as a guide for Codex, Gemini, Antigravity, Aider (linked as ~/.codex/AGENTS.md, imported by ~/.gemini/GEMINI.md, included by ~/.gemini/antigravity-cli/rules/vikix.md)
│   ├── opt/picolisp/          built     PicoLisp, from source (with the feature lisp)
│   ├── share/vikix/plugins/   Vikix's   the plugins repo at its pinned commit (vikix plugin sync)
│   ├── share/vikix/plugins-from/NAME/  Vikix's   a plugin from another repository: its repository at the commit you pinned (vikix plugin add NAME --from REPO, vikix plugin pin)
│   ├── share/vikix/records.db made       what plugins found and kept (vikix records; SQLite, 600)
│   ├── share/vikix/docs/index.db made    the docs catalogue (vikix docs, Super+F2): every document's title and words; made again from the files
│   ├── opt/lem/               built     Lem, the editor in Common Lisp (vikix add lisp-apps)
│   ├── opt/mcclim/            built     McCLIM's Listener, with Clouseau (vikix add lisp-apps)
│   ├── opt/esploro/           built     Esploro, the file explorer: its command, and emacs/esploro.el, its window in Emacs (vikix add esploro)
│   ├── opt/hype/              built     Hype, Markdown slides (vikix add hype); ~/.local/bin/hype runs it
│   ├── opt/ollama/            built     Ollama, for local AI models (vikix ai setup)
│   ├── opt/whisper.cpp/       built     dictation's speech-to-text, built for this computer (vikix dictate setup)
│   ├── share/libvirt/images/  the Windows VM's disk and its driver disc (not backed up)
│   ├── share/vikix/webapps/   each web app's own Chromium profile: its logins (caches not backed up)
│   └── state/vikix/           Vikix's record of this machine (see below)
│
├── quicklisp/                 Common Lisp libraries; StumpWM is built from here
├── .lazarus/                  Lazarus with the docked IDE, built by 65-languages
│
├── dev/                       yours, with parts written for you (see below); a folder per language you added
├── learn/c/                   yours: your work in vikix learn c, one folder a lesson (copied once; the checks stay in ~/vikix/learn)
├── .ollama/models/            local AI models (vikix ai models): big, not backed up
├── vikix-debug-*.txt           the reports vikix debug writes (yours to delete; vikix diagnose's are in ~/.local/state/vikix/diagnose/)
├── .config/io.datasette.llm/  llm's settings and its log of everything asked (vikix ai llm)
├── journal/                   yours     the diary: a day a file, written by vikix day (700; what you write under Notes is kept)
├── Pictures/Screenshots/      Shift+Print and friends
├── Videos/Recordings/         Super+Ctrl+v
├── Windows/                   yours     drive Z: in the Windows VM (vikix windows); ~/Documents is drive Y: there once vikix windows apps setup has run
└── Restored/                  `vikix backup restore` puts files here, never over yours
```

### `~/.local/state/vikix`: la registro de ĉi tiu maŝino

| Pado | Kio |
|---|---|
| `logs/` | Unu registro por ĉiu instalado kaj por ĉiu `vikix update`, nomita laŭ la dato. Ankaŭ la longa eliro de kelkaj kompiloj, forigita de la registro de la ĝisdatigo: `nvim-plugins.log` (Neovim-aj kromprogramoj), `whisper-build.log` (diktaĵo), `lazarus-build.log` (la Lazarus IDE); kaj `windows-app.log`, kion FreeRDP diris ĉiufoje kiam oni malfermis Vindoza programo (`vikix windows app`) |
| `session.log`, `session.log.old` | Ĉio, kion la labortabla sesio eldonis, ĉi tiu ensaluto kaj la antaŭa. La unua loko por serĉi kiam la labortablo ne startiĝas. |
| `yours.git` | La historio de viaj dosieroj (`vikix snapshot`, `changes`, `history`, `undo`). Git-deponejo, kies laborarbara arbo estas `~`, limigita al la dosieroj en `~/vikix/config/yours.list` |
| `errors/` | Ĉiu eraro, kiun la labortablo renkontis, unu dosiero por ĉiu, kun ĝia trakcado: eraro en `user.lisp` aŭ Vikix-dosiero, aŭ eraro, kiun StumpWM ne kaptis ([Kiam io rompiĝas](fixing.md#kiam-la-grafika-interfaco-demandas-kion-fari)). La plej novaj 50 estas konservataj |
| `user-last-snapshot.lisp` | La kopio de via lasta kopio de `user.lisp`, skribita kiam vi elektis ŝarĝi ĝin anstataŭe de difektita versio |
| `migrations/` | Kiuj unikaj korektoj ĉi tiu maŝino ricevis |
| `day/` | Kio estis sur la ekrano, por `vikix day`: `screen-YYYY-MM.log`, unu linio kiam la labortabularo, projekto, programo aŭ dosierujo antaŭe ŝanĝiĝis (neniam titolo de fenestro; 600), kaj `docs.log`, la dokumentoj malfermitaj el la katalogo. Neniu el la unuaj estu konservata: `(setf *vikix-day-on* nil)` en `user.lisp` |
| `docs/random-deck` | Gvidaj paĝoj, kiuj ankoraŭ estos montrataj en ĉi tiu rondo per `vikix docs random`, unu dosiernomo por ĉiu linio (600). Malplena aŭ mankanta dosiero komencas novan rondon; nove aldonitaj gvidiloj aliĝos al la sekva rondo |
| `docs/watch.pid`, `docs/watch.log` | La observo pri `~/src` (`vikix docs watch on`): ĝia procezo, kaj kion ĝi legis |
| `welcome` | La paŝoj de la bonveniga programo, kiujn vi plenumis (`vikix welcome`); la fakto, ke ĝi ekzistas, signifas, ke la bonveniga programo jam estis montrita, do ĝi ne malfermiĝos denove ĉe la ensaluto |
| `checkout-changes/` | Ŝanĝoj, kiujn iu faris en `~/vikix`, forigitaj de `vikix update` kiel dosieroj de ŝanĝoj (vidu [Kiam io rompiĝas](fixing.md#ĝisdatigo-malsukĉesis)) |
| `diagnose/` | La lastaj kvin raportoj, kiujn `vikix diagnose` donis al via agento |
| `mcp.log`, `mcp-servers/` | Ĉiu vokado, kiun agento faris al `vikix mcp`, ankaŭ tiuj rifuzitaj (600), kaj la serviloj, kiuj nun funkcias, kun iliaj versioj (`vikix mcp status` legas ambaŭ) |
| `session.env` | La montrilo, la D-Bus kaj la dosierujo de ĉi tiu sesio (600), por `vikix mcp` komencita de agento, kiu ne pasigas ilin (Codex) |
| `agent-shell/` | La babilaĵoj de la agento de Emacs, unu transskribaĵo por ĉiu babilaĵo, nomita laŭ la projekto (700) |
| `nvim-lock.json` | La versioj de kromprogramoj, kiujn Vikix lastfoje lasis en via `~/.config/nvim/lazy-lock.json`: kiel ĝisdatigo scias, ĉu vi movis ilin mem |
| `voice-chat` | La konversacio de Super+F10: la ID de la LLM por ĝi, kaj kiam ĝi estis lastfoje uzata |
| `dictating` | Nur dum la diktaĵo aŭskultas (Super+F9): la procezo de la registrigilo, do la sekva premo povas haltigi ĝin |
| `jupyter.log` | La mesaĝoj de JupyterLab (`jlab`) |
| `ollama.log` | La registro de la loka AI (vikix ai); unu malnova estas konservata kiel `ollama.log.old` |
| `updates` | Kion la kampo `updates` de la vizo montras, skribita de `vikix-updates` ĉiujn 6 horojn |
| `mimeapps-offered` | La defaŭltaj programoj de la lanĉilo, kiuj jam estis ofertitaj al via `~/.config/mimeapps.list` (aldonitaj aŭ viaj konservitaj), do ĉiu estas ofertita unufoje |
| `wallpaper-now`, `wallpaper-queue`, `wallpaper-shown`, `wallpaper.lock` | La bildo, kiun la ŝanĝanta tapeto montras, la bildoj, kiuj ankoraŭ estos montritaj en ĉi tiu rondo, kaj tiuj, kiujn ĝi jam montris, kaj la blokado, kiu tenas ĝian observanton (`vikix-wallpaper --watch`) al unu |
| `initramfs-*` | Indikas, ke la initramfs estis rekonstruita kun ĉi tiu mikrokodo |
| `soak/` | Ĉiuj specimenoj de ĉiu `vikix times soak`: unu CSV por ĉiu provo: responda tempo de StumpWM, memoro, fenestroj, temporiziloj, ĉiujn dek sekundojn |
| `times.log`, `times-measured.log` | Kiom longe aĵoj daŭris: ĉiu ensaluto kaj Rekonfiguri en ĉi tiu labortablo, kaj ĉiu `vikix times measure` ([Kiam io rompiĝas](fixing.md#la-labortablo-funkcias-malrapide)) |
| `windows-apps.json` | La programoj en la Start-menuo de Vindozo, kiel `vikix windows apps` lastfoje legis ilin: kie `vikix windows app NAME` trovas programon |
| `windows-launcher.json` | La Vindoza programoj, kiujn vi metis en la lanĉilon (`vikix windows apps add`): mankanta eniro estas reskribita de `vikix update` aŭ `vikix windows apps restore` |
| `obsidian/` | La registro de `vikix obsidian`: kiuj dosierujoj de la kuvo estas konvertitaj, ĉiu notlibro kiel ĝi estis skribita (do unu, kiun vi ŝanĝis de tiam, lasas ĝin tiel), kaj la raporto de ĉiu dosierujo |

### `~/dev`

Dosierujo por ĉiu lingvo, kiun vi aldonis (`vikix add python` …), kreita de `67-dev`: `~/dev/<language>/README.md` (la iloj en ĉi tiu maŝino, kaj kie lerni; **reskribita ĉe ĉiu ĝisdatigo**, do konservu viajn notojn en alia dosiero), `examples/` (kopiata unufoje, via), kaj `docs/` (plenigita per `vikix docs get`). `~/dev/index.html` ligas ĉiun senretan dokumenton. `~/dev/ai` estas la sama sen propra lingvo: malgrandaj programoj, kiuj vokas Claude kaj la lokajn modelojn ([AI](ai.md#viaj-propraj-programoj-devai)). Ĉio alia, kion vi metas en `~/dev`, estas lasita tiel, kiel ĝi estas.

## La ĉekpunkto: `~/vikix`

Ĉio, kio estas Vikix. `readlink -f ~/.local/bin/vikix` trovas ĝin, se vi klonis ĝin aliloke.

| Pado | Kio |
|---|---|
| `VERSION` | La versio, kiun vi havas (`vikix version`, aŭ `vikix --version`; Super+m → *Rekonfiguri* ankaŭ diras ĝin) |
| `install.sh`, `install/` | La instalilo (la bazo, poste la funkciaĵoj `--with`) kaj ĝiaj etapoj, `NN-name.sh`. Ĉiu estas sekura por denove kuri: `./install.sh --only 40-config` |
| `bin/` | `vikix` kaj ĝiaj helpiloj, ligitaj al `~/.local/bin`. Ĉiu komenciĝas per komento, kiu diras, kion ĝi faras. |
| `config/` | Ĉio, kio finiĝas en via hejmo: la dosieroj ligitaj tie, kaj la lanĉiloj kopiataj unufoje |
| `config/stumpwm/vikix/` | La tavolo de StumpWM. Legu ĝin por vidi, kiel klavo, la vizo aŭ la menuo estas kreitaj, kaj poste ŝanĝu ĝin de `user.lisp` |
| `config/yours.list` | La dosieroj, kiujn la historio de la kopio kovras |
| `config/what/` | Paĝo por ĉiu speco de aĵo, kiun `vikix what` klarigas (procezo, klavo, ĉiu kampo de la vizo): mallonga paragrafo, poste la gvidilo, la manlibro kaj la dosiero, kiujn vi legos |
| `packages/*.list` | Kio estos instalita, unu listo por ĉiu koncerno, `lang-*.list` unu por ĉiu lingvo. `packages/optional/` enhavas listojn, kiujn nur funkciaĵo alportas, kiel la Vindoza VM |
| `features.list`, `bundles.list` | Kion `vikix add` ofertas: la listoj de ĉiu funkciaĵo, kaj la pakaĵoj (esencaj, por programistoj, ĉio). Listo, kiun neniu funkciaĵo nomas, estas la bazo |
| `services.list` | La runit-servoj, kiujn Vikix ŝaltas |
| `examples/` | Ekzemploj por kopii kaj ŝanĝi: `hype/vikix-tour/`, prezentado de Hype (`vikix add hype`) |
| `learn/` | La kursoj, kiujn `vikix learn` funkcias (`learn/c/`): la teksto, la ekzemplo kaj la ekzerco de ĉiu leciono, kopiata unufoje al via `~/learn/c/`, kaj ĝiaj kontroliloj, kiuj restas ĉi tie |
| `themes/` | La temoj, kiuj venas kun Vikix (`vikix-dark`, `vikix-light`, `gruvbox-dark`, `nord-dark`, `tokyo-night-dark`, `contrast-dark`) kaj iliaj tapetbildoj, kreitaj de `lib/make-wallpaper.py` |
| `dev/` | La README-oj kaj ekzemploj, el kiuj `~/dev` estas kreita |
| `migrations/` | Unufojaj korektoj por maŝinoj instalitaj antaŭ ŝanĝo |
| `lib/` | Komunaj ŝelaj helpiloj, kaj la skripto, kiu konstruas StumpWM |
| `docs/` | Ĉi tiuj paĝoj |
| `site/` | La retejo, vikix.dev, kaj `site/install`, la instala komando de unu linio |
| `tests/` | La testoj: `tests/run.sh` |

La ĉekpunkto estas Git-deponejo. `git -C ~/vikix log` montras, kion ĉiu versio ŝanĝis.

## Ekster via hejmo

Kio Vikix ŝanĝas sur la sistemo mem. Ĉio alia sub `/` restas kiel Void lasis ĝin, plus la pakaĵoj.

| Pado | Kio | Per |
|---|---|---|
| `/etc/xbps.d/*-repository-*.conf` | La spegulo, la plej rapida, kiu estis trovita ĉe la instalado; la dosiero de la multlibra deponejo aldonas ilin kun la funkciaĵo steam | `05-mirror`, `vikix steam setup` |
| `/var/service/*` | Ligoj, kiuj ŝaltas la servojn en `services.list`, kaj NetworkManager | `20-services`, `25-network` |
| `/etc/ufw/` | La agordoj kaj reguloj de la fajrovalo: ŝaltita, nenio eniras krom SSH kaj la permesitaj havenoj (`vikix firewall`) | `25-network`, `vikix firewall` |
| `/etc/polkit-1/rules.d/50-vikix-printers.rules` | Kun la funkciaĵo pri elprintado: la grupo `lpadmin` administras la printernojn sen pasvorto | `20-services` |
| `/etc/security/limits.d/50-vikix-steam.conf` | Kun la funkciaĵo steam: via forta limo de malfermaj dosieroj estas plialtigita al 524288, por esync de Proton | `vikix steam setup` |
| `/etc/alsa/conf.d/` | Ligoj, kiuj sendas programojn de ALSA al PipeWire | `50-audio` |
| `/etc/X11/xorg.conf.d/40-libinput.conf` | Tuŝplato: la tuŝo permesas klakon, natura ruliĝo | `55-hardware` |
| `/etc/udev/hwdb.d/90-vikix-keys.hwdb` | La klavoj estas agorditaj: la klavo F6 de la ROG Flow Z13 estas Print (`config/udev/90-vikix-keys.hwdb` diras, kiuj klavoj kaj kial) | `55-hardware` |
| `/boot/initramfs-*` | Rekonstruita kun la mikro-kodo de Intel | `55-hardware` |
| `/etc/udev/rules.d/60-vboxguest.rules` | Nur por VirtualBox: la kunhavita interŝanĝilo | `70-vm` |
| Grupoj | Vi estas aldonita al `video`, `network`, `lpadmin` (kaj `vboxsf` en VirtualBox) | `20-services`, `25-network`, `70-vm` |

dhcpcd kaj wpa_supplicant estas malŝaltitaj per `25-network`, ĉar NetworkManager faras ilian laboron.

## Kio Void tenas

Ne de Vikix, sed vi volos ilin:

| Kio | Kie |
|---|---|
| Servoj, kiujn vi povas ŝalti | `/etc/sv/` (ŝaltu unu: `sv-on NAME`) |
| Servoj, kiuj estas ŝaltitaj | `/var/service/` (listigu ilin: `svls`) |
| Ĉu servo funkcias | `sudo sv status NAME` |
| Dosieroj de pakaĵoj | `xl NAME` (`xbps-query -f`) |
| Kiu pakaĵo havas dosieron | `xbps-query -o /path/to/file` |
