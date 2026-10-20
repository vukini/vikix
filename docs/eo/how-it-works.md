# Kiel ĝi kunlaboras

## La baza sistemo kaj la funkcioj

`install.sh` (aŭ la unu-linia komando, `curl -fsSL https://vikix.dev/install | bash`) instalas **la bazan sistemon**: StumpWM kaj la panelo, terminalo, Firefox kaj dosier-administrilo, sono, Wi-Fi kaj Bluetooth, la aparataro de la portebla komputilo, ekran-kaptiloj, temoj, kopiaĵoj kaj la AI-agento. Poste vi reŝargas la sistemon, kaj la grafika interfaco komenciĝas.

Ĉio alia estas **funkcio**, kiu estas aldonata kiam vi volas:

- **Kio ekzistas:** `features.list` en la elŝutita dosieraro donas nomon al ĉiu funkcio kaj la pakaĵliston, kiun ĝi enhavas; `bundles.list` grupigas ilin (`essentials`, `developer`, `everything`). Pakaĵlisto, kiun neniu funkcio nomas, estas parto de la baza sistemo. `vikix features` montras ĉiujn, kun tiuj, kiujn vi markis.
- **Kion vi elektis:** `~/.config/vikix/features`, unu nomo por ĉiu linio. `vikix add` kaj `vikix remove` konservas ĝin; ĝi estas unu el viaj dosieroj, do ĝi havas ankaŭ funkcion por malfari la ŝanĝon. `./install.sh --with essentials` aldonas ilin dum la sama procezo kiel la instalado.
- **Unuopaj programoj:** `vikix pkg add NAME` kaj `vikix pkg drop NAME`, por tio, kio ne estas funkcio. Pakaĵlisto, kiun Vikix listigas kaj kiun vi forigas, estas stokata en `~/.config/vikix/packages-skip`, do ĝisdatigoj forlasas ĝin.
- **Kelkaj funkcioj memagrade instaliĝas:** funkcio povas esti instalado-komando anstataŭ pakaĵoj. `local-ai`, `llm`, `dictation`, `voice`, `notes`, `windows` kaj la aliaj agentoj (`opencode`, `codex`, `gemini`, `antigravity`, `aider`) ĉiu el ili eldonas komandon (`vikix ai setup`, `vikix dictate setup` …), kiu elŝutas kion ĝi bezonas, plejparte en `~/.local`; `vikix remove` eldonas ĝian forigan komandon. `features.list` donas nomon al ĉiu komando.
- **Kie ili aperas:** Super+m forigas enirojn por funkcioj, kiujn vi ne havas (JupyterLab, Printeroj, Fenestroj, loka AI, diktado …), Super+m → *Apps* montras la programojn de la funkciaj aplikoj, kiujn vi aldonis (video, grafiko, studo …), kaj la bonveniga ekrano ĉe via unua eniro (`vikix welcome`) havas selektilon por ili.

## De la eniro al la grafika interfaco

Ne ekzistas enira ekrano. Vi eniras en la teksta konzolo, kaj sur tty1 la grafika interfaco komenciĝas memagrade. La aliaj konzoloj (Ctrl+Alt+F2 …) restas simpla teksto, do se la grafika interfaco iam ne komenciĝas, vi ankoraŭ povas eniri tie kaj ripari ĝin.

```
login on tty1
  └─ ~/.bash_profile          the "vikix startx" block: on tty1, with no X yet, exec startx
      └─ ~/.xinitrc           Vikix's: runs vikix-session inside dbus-run-session
          └─ vikix-session    everything that lasts as long as the desktop; its output goes to
              │               ~/.local/state/vikix/session.log
              ├─ INFOPATH, so Emacs and `info` find the Vikix manual
              ├─ .Xresources, the keyboard, screen layout (autorandr), the wallpaper
              ├─ ssh-agent, one for the whole session
              ├─ pipewire, dunst, clipmenud, udiskie (USB drives), picom
              ├─ idle times, night light, the locker (xss-lock → vikix-lock)
              ├─ the Emacs daemon (with the feature emacs), the battery warner, the update checker,
              │  the polkit password box
              ├─ the Network Office watcher: discovery at joins only for networks you enabled
              ├─ Ollama, for local AI models, once `vikix ai setup` installed it
              └─ ~/.local/bin/stumpwm             the last line; when it exits, the session ends
                  └─ ~/.stumpwm.d/init.lisp
                      ├─ vikix/errors.lisp       when something fails, ask what to do
                      ├─ vikix/theme.lisp        colours and fonts
                      ├─ vikix/groups.lisp       workspaces 1–9, more by name
                      ├─ vikix/registry.lisp     every command once: its key, its place in Super+m
                      ├─ vikix/commands.lisp     Vikix's commands and the Super+m menu
                      ├─ vikix/windows.lisp      focus, gaps, layout undo
                      ├─ vikix/rules.lisp        rules for windows: (when-window ...)
                      ├─ vikix/viri.lisp         a workspace that scrolls sideways
                      ├─ vikix/drawer.lisp       a few everyday programs at the screen's edge
                      ├─ vikix/layouts.lisp      saved layouts
                      ├─ vikix/overview.lisp     every workspace drawn small (Super+o)
                      ├─ vikix/resume.lisp       your windows back after a restart
                      ├─ vikix/day.lisp          what had the screen, noted for vikix day
                      ├─ vikix/why.lisp          why did that happen? what the desktop did, and what made it
                      ├─ vikix/what.lisp         what is this? the bar's field under the pointer, or the window in front
                      ├─ vikix/used.lisp         what gets used: the keys and commands, counted for vikix used
                      ├─ vikix/keys.lisp         binding the Super keys, and the rule they keep
                      ├─ vikix/help.lisp         Super+/ and Super+F1
                      ├─ vikix/webapps.lisp      your web apps: their keys and Super+m entries
                      ├─ vikix/modeline.lisp     the bar
                      ├─ vikix/rescue.lisp       a way out when the desktop is stuck: a watcher, Super+Ctrl+Alt+Escape
                      ├─ vikix/door.lisp         an agent's Lisp walked against one list before it runs; what fails waits for you
                      ├─ vikix/swank-guard.lisp  a wrong or missing password can't take Swank down
                      ├─ vikix/swank.lisp        Swank on 127.0.0.1:4004 (with a password), for Emacs and `vikix eval`
                      └─ vikix/socket.lisp       Vikix's own socket beside it, `$XDG_RUNTIME_DIR/vikix.sock`: `vikix eval`'s first road
                      ├─ rules.lisp              yours: your rules for windows, when you have any
                      └─ user.lisp               yours, last
```

Ĉiu dosiero en tiu listo estas ŝargata aparte, po unu parto (formato). Se iu parto enhavas eraron, malgranda menuo demandas, kion fari: preteriri tiun parton kaj ŝargi la reston, malfermi la dosieron ĉe tiu linio en Emacs, aŭ, por `user.lisp`, ŝargi prefere vian lastan kopion. Do, tajperaro en `user.lisp` kostas nur tiun linion, neniam vian sistemon. Eraroj, kiujn StumpWM mem ne detektas (ekzemple, en tempigilo), uzataj por restartigi la tutan sistemon; nun la menuo proponas daŭrigi unue. Vidu [Kiam la sistemo demandas, kion fari](fixing.md#kiam-la-grafika-interfaco-demandas-kion-fari).

La propraj dosieroj de Vikix estas kompilataj unufoje kaj konservataj en `~/.cache/vikix/fasl/`: la unua ŝargo post ŝanĝo de dosiero legas ĝin el ĝia teksta formo, kiel priskribite, kaj kompilas ĝin en la fono; de tiam ĝi estas ŝargata el la kompilata kopio, kio prenas kvinon de la tempo, ĝis ĝi denove ŝanĝiĝas. Kopio apartenas al la teksto de la dosiero kaj al la teksto de ĉiu dosiero antaŭ ĝi en la listo, do ŝanĝo komence de la listo ankaŭ kaŭzas rekompilon de la postaj. `errors.lisp`, `registry.lisp` (kienaj komandoj konas la linion, en kiu ili estas skribitaj), la dosieroj de la kromprogramoj kaj viaj ĉiam estas legataj el sia teksta formo. Kopio, kiu malsukĉesas, estas forigita kaj la teksto ŝargata, do eraro neniam kostas pli ol antaŭe. `vikix times files` montras la lastan ŝargitan dosieron, dosiero po dosiero.

La vortoj de la baraĵo (la laŭteco, la reto, Bluetooth, Dropbox...) estas demandataj de malgrandaj programoj ĉiujn dek sekundojn per sia propra fadeno, ne per la ĉefa fadeno de StumpWM: programo, kiu malrapide respondas, prokrastas sian propran vorton en la baraĵo, neniam viajn klavojn. La sama validas por komando, kiu deziras programan respondon (ne ĝenu, nokta lumo, la listo de la agentoj, regulo skribita post kopio): la programo funkcias en sia propra fadeno, kaj la sistemo daŭrigas ĝis la respondo estas tie.

Ĉe la unua eniro, StumpWM ankaŭ malfermas la bonvenigan ekranon (`vikix welcome`, en terminalo): aldoni programojn, la gravajn klavojn, temon, la klaviataran aranĝon, la gvidilon. Post ke ĝi estis montrita, ĝi aperas denove nur per `Super+m` → *Welcome*.

**Kial ne estas sistemaj uzantaj servoj:** Void uzas runit, kiu nur funkcias sistemajn servojn. Programoj, kiuj apartenas al via laborsesio, estas startigitaj per `vikix-session` kaj finiĝas kun ĝi. Por startigi unu el viaj per la sistemo, vidu [startigajn programojn](customize.md#lanĉu-programon-per-la-labortablo).

**StumpWM estas funkcianta programo en Lisp.** Ĝiaj agordoj ne estas legataj el agorda dosiero unufoje; ili estas Lisp-kodo, kiun ĝi funkcias. Do, post redaktado de `user.lisp`, diru al ĝi refunkciigi la dosierojn: `Super+m` → *Reload config*. Vi ankaŭ povas ŝanĝi ĝin dum ĝi funkcias, sen dosiero: `vikix eval '(message "hi")'` el terminalo, aŭ REPL el Emacs (`M-x slime-connect`, `127.0.0.1`, `4004`).

### Kiel `vikix eval` atingas StumpWM

Por la interesatoj: `vikix eval` estas malgranda programo en Python, kiu komunikas kun StumpWM per soketo. Via kodo neniam funkcias en la programo en Python; ĝi estas sendata kaj funkcigata interne de StumpWM. Ĝia unua itinero estas la propra soketo de Vikix, `$XDG_RUNTIME_DIR/vikix.sock` (`socket.lisp`): dosiero, kiun nur vi povas malfermi, en dosierujo, kiu estas nur via, do nenio estas sendata por pruvi, kiu vi estas. Fadeno de Vikix respondas tie: formato, kiu nur legas la staton de la sistemo (kiuj fenestroj estas kie, kion klavo funkcijas, la reguloj) iras unue al la ĉefa fadeno, do ĝi sekvas la laboron jam tie. Se tiu fadeno dormas sen respondi, kiel ĝi faras en menuo, la fadeno de la soketo respondu anstataŭe al la legi. Fadeno, kiu atendas tempon por la CPU, ricevas pli multe da tempo por respondi; mankaj observoj ankaŭ. Je la fino, legi, kiu ne komencis, ankoraŭ povas esti respondita per la fadeno de la soketo; unu, kiu jam funkcias, raportas tempolimon anstataŭ funkcii dufoje. Ĉio, kio agas aŭ desegnas, restas en la ĉefa fadeno, la fadeno, kiu posedas la X-konektilon, do ĝi povas tuŝi fenestrojn kaj la baraĵon sen danĝero. Sen tiu soketo (sesio sen elogind, aŭ sistemo antaŭ ĝi), `vikix eval` komunikas kun StumpWM laŭ la maniero, kiel Emacs faras, per Swank, kaj ĉio funkcias en la ĉefa fadeno:

![vikix eval sendas vian Lisp-on al Swank, kiu funkcigas ĝin en la ĉefa fadeno de StumpWM kaj sendas reen, kion ĝi eldonis](diagrams/vikix-eval.svg)

Du aferoj tenas ĝin sekura. La pasvorto en `~/.slime-secret` signifas, ke nur vi povas funkcigi kodon tie, kaj `swank-guard.lisp` certigas, ke kliento kun malĝusta aŭ malrapida pasvorto estas forigita sen malaktivigi Swank. Kaj se StumpWM estas okupita (menuo estas malfermita, ekzemple), `vikix eval` rezignas post 10 sekundoj kun mesaĝo, kaj la kodo neniam funkcias poste, neatendite. Ĝi ankaŭ rigardas, kiu posedas la porton, antaŭ ol ĝi sendas la pasvorton: se la aŭskultanto ĉe 4004 estas de alia uzanto (via StumpWM ne funkcias, kaj iu alia prenis la porton), ĝi ĉesas tie. Kaj kiam la sendanto estas agento (`vikix eval` sub Claude Code aŭ alia agento, aŭ la MCP-servilo `eval`), la formoj pasas la pordon unue (`door.lisp`): legas sen funkcii, kontrolas, kaj funkcias nur kiam ĉiu funkcio, kiun ili vokas, estas sur la listo de la pordo; la resto atendas por vi sub `Super+m` → *Door* ([AI](ai.md#la-pordo)).

### Kiel `vikix mcp` atingas ĝin

Por la interesatoj: `vikix mcp register` donas al via agento la sistemon kiel iloj ([Laboro kun AI](ai.md#la-labortablo-kiel-iloj-mcp)). La servilo estas `bin/vikix-mcp`, programo en Python kun nenio krom la norma biblioteko. Ĝi ne aŭskultas sur la reto: la agento startigas `vikix-mcp serve` mem kaj komunikas kun ĝi per sia `stdin` kaj `stdout`, unu JSON-RPC-mesaĝo por linio, do nur tiu agento povas uzi ĝin.

- **Rigardante:** `desktop`, `keys` kaj `rules` sendas fiksitajn Lisp-formatojn per `vikix eval`, la vojo supre, kaj StumpWM respondas en JSON. `doctor`, `history`, `changes` kaj `themes` funkcias la komandon `vikix`, kaj tio, kio revenas, pasas tra la sama filtrilo kiel `vikix debug` (`lib/debug-report.py`) antaŭ ol la agento vidas ĝin; `version` legas la `VERSION` de la kopio.
- **Agante:** `set_theme`, `switch_workspace` kaj `focus_window` kontrolas, kion la agento petis, kontraŭ la sistemo unue (temo ekzistas, laborspaco ekzistas, nombro de fenestro estas sur ĝi). Nur tiu kontrolita valoro atingas Lisp, kiel eskapa ĉeno, aŭ komando, kiel unu argumento; neniam ŝelo. `run_command` prenas la nomon de unu el la komandoj de la sistemo, kaj la sistemo mem decidas: `registry.lisp` enhavas ĉiun komandon kun ĝia ŝlosilo kaj ĝia loko en la menuo, kaj funkcias por agento nur tiujn, kiuj estas markitaj `:agent t` tie (`vikix-agent-run`); `commands` listigas ilin. Do, agento neniam ricevas komandon, kiun la sistemo ne havas.
- **Konservante rekordon:** ĉiu voko, ankaŭ tiuj malakceptitaj, iras en `~/.local/state/vikix/mcp.log` (600), kun longaj argumentoj tranĉitaj kaj sekretoj forigitaj.
- **Restante aktualigita:** antaŭ ol ĝi legas ĉiu peton, la servilo komparas siajn proprajn dosierojn (`bin/vikix-mcp`, `lib/debug-report.py`, `VERSION`) kun tio, kiel ili estis kiam ĝi komencis. Kiam `vikix update` ŝanĝis ilin, kaj ili kompilas, ĝi `exec`s la novan version en la sama procezo, kun la peto ankoraŭ atendanta en la kanalo, kaj diras al la agento, ke ĝiaj iloj eble ŝanĝiĝis.

## Kion `vikix update` faras

1. **Tiras Vikix** en `~/vikix` (`git pull --ff-only`), kaj poste komencas el la nova versio de si mem.
2. **Aktualigas Void**: `xbps-install -Su`, unue xbps.
3. **Funkciigas ses instalajn etapojn denove**, ĉiu sekura por ripeti:
   - `10-packages`: instalas ĉion novan en la listoj de la bazo kaj de viaj funkciaĵoj, forlasante vian liston de esceptoj.
   - `20-services`: aktivigas servojn, kiujn novaj pakaĵoj alportis.
   - `40-config`: ligas la dosierojn de Vikix denove, kopias iniciigilojn, kiujn vi ne havas, skribas la dosierojn de la temo denove, faras ĉi tiujn gvidilojn en la Info-manlibron kaj la retejojn, kaj prenus kopion de viaj dosieroj.
   - `45-editors`: por la redaktoroj, kiujn vi elektis, tiras la agordojn de Emacs kaj refunkciigas la agordan de Vikix en Emacs, kiu funkcias (viaj konversacioj restas malfermitaj), kaj movas la kromprogramojn de Neovim kiam Vikix testis pli novajn (se vi ne movis ilin mem).
   - `65-languages`: por la lingvoj, kiujn vi elektis: PicoLisp, Lazarus, Julia.
   - `67-dev`: la `~/dev`-dosierojn README, novajn ekzemplojn, kaj `~/dev/ai`, kie troviĝas `uv`.
4. **Funkciigas migradojn**: unufojajn korektojn por maŝinoj, kiuj estis instalitaj antaŭ iu ŝanĝo, ĉiu funkcigata unufoje (enregistrita en `~/.local/state/vikix/migrations/`).
5. **Alportas `llm` al sia pinita versio**, se vi havas ĝin (`vikix ai llm`).
6. **Aktualigas viajn proprajn programojn**: tio, kion vi instalis per `pipx` (`pipx upgrade-all`), per `uv tool install` (ĉiu, escepte la pinita `llm` kaj Piper de Vikix), kaj per `cargo install` (kiam `cargo install-update` estas tie: `cargo install cargo-update`, unufoje). Go ne povas aktualigi ĉion, kion ĝi instalis; funkcigu `go install NAME@latest` denove por ĉiu.
7. **Refunkciigas StumpWM**, do novaj klavoj, la baraĵo kaj la menuo funkcias tuj; la ekrano diras, kiu versio nun funkcias (`Super+m` → *Reload config* diras la saman).

### Po unu parto

`vikix update` faras ĉiun el la supre priskribita. Se vi volas nur unu parton:

```sh
vikix update core     # Vikix only: steps 1, 3 (10-packages, 20-services, 40-config), 4 and 7. Seconds.
vikix update system   # Void's packages only: step 2
vikix update tools    # 45-editors, 65-languages, 67-dev, then steps 5 and 6
```

La kora parto ankoraŭ instalas paketon, kiun ne ekzistis en la listoj de Vikix (eldono, kiu bezonas novan programon), sed ne aktualigas alian parton de Void. Programoj el `cargo install` kaj `go install` estas en via PATH (`~/.cargo/bin`, `~/go/bin`), el la bloko en `~/.bash_profile`.

La servilo `vikix mcp` de agento, kiu jam funkcias, mem ekkonas la novan version kaj lanĉas ĝin en sia sekva voko, do la agento ne bezonas rekonekti.

Etapo, kiu malsukĉesas, ne haltigas la reston; ili estas nomitaj al la fino. La tuta procezo estas registrita en `~/.local/state/vikix/logs/update-<tempo>.log`.

Ĝi petas vian sudo-pasvorton unufoje. Ĝi neniam petas ion alian, kaj ĝi neniam ŝanĝas viajn dosierojn: nur la ligiloj de Vikix, la dosieroj, kiujn ĝi skribas por vi, kaj la markitaj blokoj en `~/.bashrc` kaj `~/.bash_profile`.

La indikilo montras `updates 12` (pakoj de Void), `Vikix update`, aŭ ambaŭ, kiam estas io, kion necesas apliki. `vikix-updates` kontrolas unu minuton post eniro kaj poste ĉiun 6 horojn.

## De kiuj dosieroj temas

Ĉi tio estas la regulo, kiun ĉio sekvas.

- **Dosieroj de Vikix** estas simbolaj ligiloj en `~/vikix`. Tiel la ĝisdatigo atingas ilin: la elŝuto ŝanĝas la dosieron, kaj ĉiu ligilo vidas la ŝanĝon. Ĝi estas ankaŭ la kialo, kial vi ne devus redakti ilin. La redaktado ŝanĝus la elŝuton, kaj la sekva elŝuto rifuzus anstataŭigi ĝin.
- **Viaj dosieroj** komencas kiel kopioj de la bazaj dosieroj de Vikix. Post tio, ili estas viaj: neniu ĝisdatigo ŝanĝas ilin, eĉ se la baza dosiero de Vikix ŝanĝiĝas. Kiam ŝanĝo *devas* atingi ekzistantajn kopiojn (ekzemple, nova inkludanta linio), migrado faras precize tiun ŝanĝon kaj nenion alian.
- **Markitaj blokoj.** Kelkaj kunhavataj dosieroj, kiel `~/.bashrc`, havas blokojn, kiujn Vikix havas inter `# >>> vikix Nomo >>>` kaj `# <<< vikix Nomo <<<`. Vikix reskribas la internon de siaj blokoj, kaj nenion alian en la dosiero.
- **Nenio estas forigitaj.** Dosiero, kiu estas en la vojo de unu el la ligiloj de Vikix, estas movita al `Nomo.vikix-bak.<tempo>`.

La maniero ŝanĝi ion de Vikix estas anstataŭigi ĝin el unu el viaj dosieroj. Tiu por la labortablo estas `user.lisp`, kiu estas ŝarĝata laste: rebindu klavon, agordu variablon, redifinu komandon. [Farante ĝin via](customize.md) enhavas ekzemplojn.

## Temoj

Temo estas malgranda dosiero de nomitaj koloroj (`~/vikix/themes/vikix-dark.theme`). `vikix theme Nomo` faras tri aferojn:

1.  ŝparas la nomon en `~/.config/vikix/theme/current`
2.  skribas la kolorojn de ĉiu programo en `~/.config/vikix/theme/` (alacritty, kitty, rofi, la ŝirmilo) kaj `~/.config/dunst/dunstrc.d/10-vikix-theme.conf`
3.  remetas StumpWM, reŝargas dunst, kaj agordas la tapeton de la temo, se vi elektis sekvi la temon (alie la tapeto ŝanĝiĝas laŭvice)

Viaj propraj konfiguraj dosieroj *inkluzivas* tiujajn skribitajn dosierojn. Tiel la koloroj de la temo aperas, kaj ĉio, kion vi agordas post la inkludo, venkas. Tiel la temo atingas viajn dosierojn sen Vikix redaktante ilin.

## Momentbildoj

Viaj dosieroj (listigitaj en `~/vikix/config/yours.list`) havas historion en `~/.local/state/vikix/yours.git`. Momentbildo estas prenita post ĉiu instalado kaj ĝisdatigo (kaj denove unufoje, kiam la baza dosiero de Neovim estas en la loko), antaŭ ĉiu sesio de AI-agento (`Super+a`, kaj agento, kiu komencas redaktilon), kaj ĉiam kiam vi lanĉas `vikix snapshot`. `vikix undo` remet viajn dosierojn kiel ili estis unu momentbildo antaŭe, kaj mem estas momentbildo, do dua malfarado renversas ĝin.

Dosierujo en la listo, kiu estas git-klono de si mem, kiel konfiguraj dosieroj de Neovim, kiun vi alportis, estas forlasita: ĝi havas sian propran historion. API-ŝlosiloj neniam estas registritaj, kion ajn la listo diras.

Ĝi kovras viajn agordojn, ne viajn dokumentojn. Por tiuj, `vikix backup`.
