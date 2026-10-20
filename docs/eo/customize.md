# Personigu ĝin

Ĉiu sekcio diras, kiun dosieron vi devas ŝanĝi kaj kiel fari, ke la ŝanĝo efikiĝu. Ĉiu dosiero ĉi tie apartenas al vi, do neniu ĝisdatigo transskribos ĝin. [Ĉio troviĝas ĉi tie](map.md); tie estas la kompleta listo.

## Antaŭ ol vi ion ŝanĝas

```sh
vikix snapshot "before: bigger bar font"   # record your files as they are
# ... make the change ...
vikix changes                              # see exactly what changed
vikix undo                                 # changed your mind: back to the snapshot
```

En terminalo, `vikix undo` unue listigas la dosierojn, kiujn ĝi reiros kaj demandas. Diru "ne", se tio ne estas la celita versio (AI-agento kreas unu kiam ĝi komenciĝas, do la antaŭa eble estas de la agento), kaj elektu alian el `vikix history` per `vikix undo ID`. Post reigo, `Super+m` → *Reload config* igas StumpWM denove uzi la malnovajn agordojn. `vikix undo --help` montras ĉiujn kvar komandojn kune.

Aŭ demandu la AI-agenton: `Super+a` lanĉas Claude Code (aŭ la agenton, kiun vi elektis), kiu konas ĉi tiujn regulojn (el `~/.claude/skills/vikix`) kaj kreas version antaŭ la lanĉo. [Laborado kun AI](ai.md) diras kiel.

## La labortablo: `~/.stumpwm.d/user.lisp`

Ĉio pri StumpWM estas en ĉi tiu ununura dosiero: klavoj, programoj, kiuj lanĉiĝas, la menuo, la baraĵo. Ĝi ŝarĝiĝas post ĉiuj dosieroj de Vikix, do ĉio, kion vi agordas ĉi tie, venkas. Apliku ŝanĝon per `Super+m` → *Reload config*. Se estas eraro, la mesaĝo aperas sur la ekrano, kaj ĉio alia ankoraŭ ŝarĝiĝas.

Por vidi, kiel Vikix faras ion antaŭ ol ŝanĝi ĝin, legu ĝian nivelon en `~/vikix/config/stumpwm/vikix/`: `keys.lisp` por la klavoj, `commands.lisp` por la menuo, `modeline.lisp` por la baraĵo.

### Klavoj

```lisp
(vikix-bind "s-w" "exec chromium")         ; change what a key does
(vikix-bind "s-M-o" "exec obsidian")       ; a new key: Super+Alt+o
(undefine-key *top-map* (kbd "s-M-s"))     ; drop one of Vikix's keys
```

`s-` estas Super, `C-` estas Ctrl, `M-` estas Alt, `S-` estas Shift, kaj majuskla litero ankaŭ signifas Shift: `s-O` estas Super+Shift+o, `s-M-o` estas Super+Alt+o. La komando estas komando de StumpWM: `exec PROGRAM` lanĉas programon, kaj `Super+m` → *Ĉiuj komandoj* listigas la aliajn.

Tia klavo-kombino funkcias, kaj nenio alia pri ĝi scias. Por ke ĝi aperu en la klavkarto (`Super+/`), en la klava helpo (`Super+F1`) kaj ankaŭ en `Super+m`, skribu ĝin kiel komandon, kiel Vikix skribas siajn proprajn:

```lisp
(define-vikix-command obsidian "Obsidian: my notes"
  :run "exec obsidian" :key "s-M-o"
  :menu "Apps" :needs "obsidian")
```

La nomo (`obsidian`) estas via elekto; la vortoj post ĝi estas tio, kion la ŝlosilkarto kaj la menuo diras. `:run` estas la komando kaj `:key` estas ĝia ŝlosilo. `:menu` metas ĝin en `Super+m`, en tiu sekcio de ĝi (Starto, Helpo, Vikix, AI, Laboro, Notifoj, Labortablo, Fenestroj, Sistemo, Aplikoj); forlasu ĝin por nur ŝlosilo. `:label` donas al la menuo vortojn malsamajn ol tiuj de la ŝlosilkarto, kaj `:needs` nomas programon aŭ dosieron (`"~/..."`) sen kiu la menuo forlasas la eniron. Forlasu `:key` por menu-eniro sen ŝlosilo; tiam `:do` povas preni Lisp-formon anstataŭ `:run`. `:agent t` permesas al via AI-agento ekzekuti ĝin laŭnome, sen peti vin ĉiufoje ([Laboro kun AI](ai.md#la-labortablo-kiel-iloj-mcp)): nur por io, kion oni povas facile remeti, kiel oni faris. Eraro en la formo estas indikata kiam `user.lisp` estas ŝargata, kun tio, kio estas erara.

### Ŝlosiloj ene de mapo

La ŝlosilkarto estas plena, do kelkaj ŝlosiloj malfermas *mapon* anstataŭe: `Super+Ctrl+Space` la ŝlosiloj de la aranĝo (`m` ĉefa kaj stakita, `s` strio, `g` reto, `t` kahelaroj, `w` larĝo, `h` alteco, `u` kaj `r` nuligu kaj refaru, `Space` la menuo), `Super+Alt+d` la ŝlosiloj de la labortablo (`n` nova labortablo, `w` laboranto sur unu, `r` uzu unu denove, `c` fermu unu, `h` ĝia transdono, `o` la Oficejo, `t` testu la laboron de labortablo, `p` paŭzu ĝian agenton aŭ lasu ĝin, `i` noto por ĝi, `x` forigu ĝin). La ŝlosiloj de la mapo aperas en malgranda karto dum ĝi estas malfermita; ŝlosilo agas kaj la karto restas, do `w`, `w`, `w` trairas la larĝojn, kaj Escape, la ŝlosilo por malfermi, denove, aŭ duongiganta minuto da silento fermas ĝin (`(setf *vikix-map-timeout* 60)` en `user.lisp` por pli, `5` por malpli). Ŝlosilo, kiu startigas programon, unue fermas la mapon. La ŝlosilkarto havas la ŝlosilon, kiu malfermas mapon, kies vortoj nomas ĝiajn ŝlosilojn; la listo de `Super+F1` kaj la tabelo de la README havas ĉiu el ili kiel *do m*, kaj `vikix used` kalkas ĉiu el ili kiel sian propran ŝlosilon.

Por meti vian komandon en mapon, donu al ĝi `:map` kun la nomo de la mapo kaj la ŝlosilo: `:map "layout x"`, flanke de `:key` aŭ anstataŭe de ĝi. Via propra mapo estas komando, kies `:run` estas `vikix-map NOME`, kun ŝlosilo; la komandoj kun `:map "NOME k"` skribitaj post ĝi estas ĝiaj ŝlosiloj:

```lisp
(define-vikix-command music "Music keys: p play or pause, n next, b back"
  :run "vikix-map music" :key "s-M-u")
(define-vikix-command music-play "Play or pause"
  :run "exec playerctl play-pause" :map "music p")
(define-vikix-command music-next "Next track"
  :run "exec playerctl next" :map "music n")
```

La komandoj de la mapo estas tiuj, kiujn la karto diras pri ĝi, do nomu ties ŝlosilojn tie post kolonoj, kun komo inter ili, en la ordo, en kiu vi volas, ke ili aperu. La regulo por ŝlosiloj taksas ŝlosilon ene de mapo laŭ la ŝlosilo, kiu malfermas la mapon (mapo de programoj funkcias per Super+Alt, mapo de ŝaltiloj per Super+Ctrl).

La propraj komandoj de Vikix estas skribitaj simile, ĉiuj en unu dosiero, `registry.lisp` en la tavolo de Vikix: ĝiaj ŝlosiloj, ĝia menuo kaj tio, kion agentoj povas ekzekuti, ĉio venas de tie. La pli malnova metodo ankoraŭ funkcias, kaj tio estas tio, kion faras kromprogramo aŭ reta aplikaĵo: aldoni al la listo la karton kaj la helpdokumento, el kiuj ĝi estas konstruita, kaj ligi la ŝlosilon.

```lisp
(push '("s-M-o" "exec obsidian" "Obsidian") *vikix-bindings*)
(vikix-bind "s-M-o" "exec obsidian")
```

La karto grupigas ĉiun klavon laŭ tio, kion ĝi faras: programo komencita per `exec` estas en la grupo *Aplikoj* (aŭ *AI kaj voĉo*, *Ekranfotografioj kaj registrado* ktp, se Vikix konas la programon), kaj ĉio alia estas en la grupo *Aŭtru*. Por elekti la grupon mem, metu ĝin kiel la kvaran elementon: `'("s-t" "exec obsidian" "Obsidian" "Notes")`. Via propra grupo aperas post tiuj de Vikix.

Post `Ctrl+t`, la prefikso de StumpWM, aperas la klavoj, kiuj povas sekvi, se vi atendas (la reĝimo which-key de StumpWM, kiun Vikix aktivigas). Por malaktivigi ĝin, metu `(vikix-which-key nil)` en user.lisp. Ne alvoku `(which-key-mode)` tie: ĝi ŝaltas kaj malŝaltas, do ĉiu refreŝigo ŝanĝus ĝin.

`Super+m` → *Kion faras klavo?* montras, al kio estas ligita ĉiu klavo nun.

### La regulo por klavoj

Ĉiu modifikilo krom Super signifas ion specifan. La klavoj de Vikix sekvas tion, kaj ankaŭ la klavoj de la kromprogramoj kaj de la retaj aplikoj. Via klavo estas plej facile memorebla, se ĝi faras tion:

| Klavoj | Kion ili servas | Ekzemplo de Vikix |
|---|---|---|
| Super | Ĉiutage: la ses ĉefaj aplikoj (terminalo, lanĉilo, navigilo, dosieroj, redaktilo, agento), la malgrandaj iloj, fokuso kaj tio, kio estas farata al la fenestro, en kiu vi estas | `Super+Return`, `Super+w`, `Super+h`, `Super+q`, `Super+f` |
| Super+Shift | La sama klavo, movante la fenestron: movu ĝin, sendu ĝin al labra spaco, alportu unu ĉi tien. Aŭ la alia funkcio de la klavo: refaru, antaŭa | `Super+Shift+h`, `Super+Shift+3`, `Super+Shift+g`, `Super+Shift+u` |
| Super+Alt | Malfermu ion alian: ĉiun alian aplikon, ĉiun retan aplikon kaj kromprogramon | `Super+Alt+p` projektoj, `Super+Alt+v` pasvortoj, `Super+Alt+m` poŝto |
| Super+Ctrl | Ŝanĝu ion sur la labortablo | `Super+Ctrl+a` tenu veka, `Super+Ctrl+l` nokta lumo, `Super+Ctrl+d` ne ĝenu, `Super+Ctrl+g` interspaco |

Do, nova apliko estas sur Super+Alt kaj litero, via propra ŝanĝo estas sur Super+Ctrl. Klavoj sen Super konservas siajn proprajn funkciojn: Print (Shift konservas dosieron, Ctrl estas la fenestro, Super la ekrano) kaj la propraj klavoj de la laptopo.

Sendi fenestron al labra spaco estas Super+Shift kaj la cifero sur ajna klavaro: Vikix demandas al la klavaro, kion Shift+cifero tajpas (`!` sur usona klavaro) kaj ligas tion, denove post `Super+m` → *Apliki klavaraj agordoj*. Sur klavaro, kie la ciferoj mem bezonas Shift (franca), ĝi estas Super+Ctrl kaj la cifero.

### Labraj spacoj post la naŭ

Estas naŭ labraj spacoj, `Super+1` ĝis `Super+9`, kaj ili ĉiam estas tie. `Super+Left` kaj `Super+Right` iras al la spaco apud ĉi tiu, laŭ la ordo de la baraĵo kaj ĉirkaŭ la fino, kio estas kiel oni atingas labran spacon post la naŭ per klavo; kun `Shift` la fenestro venas kune, kaj vi kun ĝi (sur strio, ĝia tuta kolumno). La literoj `h` `j` `k` `l` restas ene de la labra spaco: la fokuso iras tien, kaj kun `Shift` la fenestro faras tion. Kiam ĉiuj naŭ havas fenestrojn, kaj io volas labran spacon por si mem, la labora tablo (`vikix agents worker`) aŭ projekto (`vikix project open`), estas kreita la dek-a, nomita laŭ ĝi: `wifi-fix`, `novel`. `Super+0` malfermas la nomitajn labrajn spacojn kiel mapon: litero po unu, la unua litero de ĝia nomo, kiun neniu antaŭa uzis (`office` estas `o`, `cuis` estas `c`), kaj la litero iras tien, do `Super+0`, `o` estas la Oficejo; `/` en la mapo tajpas nomon anstataŭe (Tab kompletigas; la paletro, `Super+Space`, ankaŭ listigas ilin, kaj la superrigardo, `Super+o`, desegnas ilin). `Super+Shift+0` estas la sama mapo, sendante la fenestron al tiu, kiun vi elektas, dum vi restas tie, kie vi estas. Nova nomo, tajpita ĉe ĉiu el ili, kreas tuj labran spacon kun tiu nomo, ĉu unu el la naŭ estas malplena aŭ ne, ĉar vi petis ĝin laŭnome; do `Super+Shift+0`, `/`, `reading`, Enter metas la fenestron sur labran spacon nomitan `reading`. Nomitaj labra spacoj estas forigitaj, kiam vi forlasas ĝin sen fenestro, post unu minuto, almenaŭ, do la baraĵo neniam pleniĝas per malplenaj nomoj. Labraj spacoj, kiujn vi kreas en `user.lisp` (`gnewbg`), neniam estas tuŝataj, kaj la regulo `(workspace "reading")` nomas tiun, kiu ekzistas.

**Refariligo de ili.** Post tago, la fenestroj estas sur 3, 5 kaj 8. `Super+m` → *Fenestroj* → *Labra spaco: refariligu ilin* (la komando `vikix-refile-workspaces`; de la ŝelo, `vikix eval '(vikix-refile-workspaces)'`) movas ĉiun labran spacon maldekstren al la plej proksima malplena, laŭeble, do ili finiĝas sur 1, 2 kaj 3 en la ordo, en kiu ili estis. Ĉiu konservas sian aranĝon: ĝiajn kadrojn, kio flosas, strio kaj ĝiaj kolumnoj, reto aŭ reĝimo de ĉefa kaj stapo, kaj `Super+u` ankoraŭ forigas siajn proprajn ŝanĝojn. La nomitaj labraj spacoj post la naŭ ne havas tien, al kie movi, kaj restas. Ĝi diras, kio moviĝis: `Refariligite: 3 al 1, 5 al 2, 8 al 3.` Se vi preferus konservi labran spacon 1 kiel hejmo, kiu neniam pleniĝas, `(setf *vikix-refile-from* 2)` en `user.lisp` komencas la refariligon de 2.

`vikix doctor` nomas klavon, kiu rompas la regulon: kromprogramo aŭ reta apliko, kiu ne estas sur Super+Alt, via propra programo sur pura Super, ŝanĝo ie ajn. La klavo ankoraŭ funkcias; la kuracisto nur diras tion. Kion Vikix konsideras kiel ĉiutage, ŝanĝo aŭ movo estas tri mallongaj listoj ĉe la supro de `~/vikix/config/stumpwm/vikix/keys.lisp`; aldonu vian propran komandon al unu en `user.lisp`, `(push "my-toggle" *vikix-key-switches*)`, kaj la kuracisto scias tion.

### Kiujn klavojn vi uzas?

Antaŭ ol vi movas klavon aŭ forlasas unu, rigardu, kion vi premis. La labortablo kalkulas ĉiun klavon, kiu faras komandon, ĉiu eniraĵo, kiun vi elektas en menuo aŭ en la paletro, kaj ĉiu komando, kiun vi tajpas:

```
$ vikix used
Counting since 5 Oct 2026 (12 days).

Keys
     412  Super+Return                 Terminal
     388  Super+Space                  Everything in one box: windows, commands, projects ...
      97  Super+f                      Fullscreen on/off

Menu entries
      14  Reload config

61 of 107 keys never pressed: vikix used never
```

`vikix used never` listigas la klavojn, kiujn vi neniam premis de la komenco de la nombrado: tiuj, kiujn vi povas uzi por io, kion vi deziras. `vikix used all` montras ĉiun nombradon kaj kiam ĉiu estis lastfoje uzata; `vikix used forget` rekomencas. Super+m havas ĝin kiel *Kion vi uzas*. La nombradoj de la pordo estas en la sama dosiero, tio, kion la Lisp-kodo de la programo vokas kaj kion la pordo enhavas, kaj `vikix door used` legas ilin ([la pordo](ai.md#la-pordo)).

Nur nomoj kaj nombroj estas konservataj: la klavo, la komando, al kiu ĝi estas ligita, la vortoj de menuero. Neniam la titolo de fenestro, kaj nenio, kion vi tajpas en programon. La nombradoj estas en `~/.local/state/vikix/used`, tekstdosiero, kiun vi povas legi aŭ forigi, kaj nenio sendas ĝin ie ajn.

### Lanĉu programon per la labortablo

```lisp
(at-login (run "syncthing --no-browser"))
```

`at-login` ekzekutatas unufoje ĉiufoje, kiam vi ensaliras. `user.lisp` ekzekutatas denove ĉiufoje, kiam la sistemo refreŝiĝas, kaj la regulo ne: ne necesas aldoni `pgrep -x … ||` antaŭe por eviti la lanĉon de dua kopio. Regulo, kiun vi aldonas dum vi estas ensaligita, ekzekutatas dum la refreŝiĝo, kiu ĝin aktivigas, unufoje. Ĝi estas en `rules.lisp` aŭ en `user.lisp` ([Reguloj por la labortablo](rules.md)).

### Reguloj: kion la labortablo faras memstare

Regulo estas unu linio, kiu diras, kie fenestro aperos kiam ĝi malfermiĝas, aŭ kio okazas je certa horo de la tago, kiam la baterio estas malplena, aŭ kiam vi ensaliras:

```lisp
(when-window (:class "Firefox") (workspace 2))                 ; Firefox opens on workspace 2
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(at "09:00" :weekdays (open-project "vikix"))                  ; each working day at nine
(when-battery-below 20 (notify "Battery at 20%" "Where's the charger?"))
```

Ili loĝas en sia propra dosiero apud `user.lisp`, `~/.stumpwm.d/rules.lisp`, kiu estas inkluzivita en ĉiuj ekzemploj kaj komence estas malŝaltita. `Super+Shift+t` kreas ĝin por vi, por la fenestro antaŭe, kaj `vikix rules` listigas ilin, klarigas, kial fenestro aperis tie, kie ĝi aperis, kaj provas ilin sur la nun malfermitaj fenestroj.

[Reguloj por la labortablo](rules.md) estas ilia paĝo: ĉiuj aferoj, kiujn regulo povas kongrui kaj fari, kiel vidi, kion viaj reguloj faris, kaj kio okazas, se unu el ili funkcias neĝuste.

### Konservitaj aranĝoj

La aranĝo de labortablo, la dividoj kaj kiu fenestro situas en ĉiu el ili (aŭ la kolumnoj de strio, iliaj larĝoj kaj kio estas staplita), konservita per nomo kaj poste reuzata:

```sh
vikix layout save writing     # this workspace, as it is now
vikix layout writing          # back as it was
vikix layout list             # the ones saved
vikix layout rm writing
```

Aŭ Super+m, *Agordo: konservu ĉi tiun labortablon* kaj *Agordo: remetu ĉi tiun labortablon*. Regulo ankaŭ povas remeti ĝin: `(when-window (:class "Emacs" :title (:has "novel")) (layout "writing"))`.

Ĉiu estas simpla Lisp-dosiero en `~/.config/vikix/layouts/`, kiun oni povas legi kaj modifi: fenestroj estas priskribitaj per sia klaso kaj titolo, ne memorataj kiel la fenestroj kiuj ili estis, kaj la loko kaj grandeco de divido estas partoj de la ekrano, do agordo ankoraŭ funkcias post kiam la fenestroj estis fermitaj kaj malfermitaj denove, aŭ sur alia ekrano. Remetante unu, oni kunigas la fenestrojn sur la labortablo kun la konservitaj (unue la sama programo, poste la plej proksima titolo); fenestro, kiun ĝi ne mencias, restas, kaj konservita fenestro, kiu ne estas malfermita, estas denove malfermita kaj metita kiel ĝi aperas (`vikix layout NAME --no-start` nur nomas ĝin). Ĉiu konservita fenestro diras kiel: ĝia `:command` kaj `:directory`, kiuj estas legitaj de la programo kiam la agordo estis konservita; terminalo revenas en la dosierujo de sia ŝelo (kun tio, kio ruliĝis en ĝi, se tio ne estis la ŝelo), Emacs-fenestro kiel `emacsclient -c` sur la dosiero, kiun ĝi montris, Esploro sur sia dosierujo. Ĉar agordo povas malfermi programojn, legu unu, kiun vi ricevis, antaŭ ol vi remetu ĝin. Agordo de strio igas la labortablon strio, agordo de kahelaraj fenestroj igas ilin kahelaj. Flosaj fenestroj ne estas konservitaj.

### Viaj fenestroj revenas post rekrajo

La labortablo konservas ĉiun labortablon memstare, ĉiun kvin minutojn kaj kiam ĝi finiĝas: kiuj fenestroj, kie ili estas, kaj kiel ĉiu estis malfermita. Post rekrajo, la eniro petas, ĉu oni remetu ilin; Eni faras tion. Ĉiu labortablo estas metita reen kiel ĝi estis, ĝiaj programoj estas denove malfermitaj en siaj dosierujoj, kaj vi finiĝas sur la labortablo, sur kiu vi estis.

```sh
vikix resume           # what is saved, and what a login does
vikix resume now       # bring them back now (Super+m, Bring my windows back)
vikix resume always    # at login, bring them back without asking
vikix resume never     # at login, leave it
vikix resume ask       # at login, ask first: how it starts out
```

Kio revenas, estas tio, kion oni povas denove lanĉi: terminalo en la dosierujo, kie ĝi estis, kun la programo, kiu funkciis en ĝi; programo per sia komanda linio; retaplikaĵo; Emacs-fenestro sur sia dosiero. Kion programo havis malferma interne, estas ĝia propra afero kaj ĝi revenigos ĝin: Firefox malfermos siajn etikedojn, redaktilo siajn dosierojn. AI-agento, lanĉita per Super+a, revenos kiel nova sesio en sia dosierujo (en Claude Code, `claude --continue` daŭrigas la lastan konversacion tie). Flosantaj fenestroj kaj dialogoj ne estas konservataj.

La konservitaj labortabloj estas aranĝoj, kiel tiuj supre, konservitaj aparte en `~/.local/state/vikix/resume/`; la elekto estas unu vorto en `~/.config/vikix/resume`.

### La traro

Kelkaj programoj, kiujn vi volas ofte kaj por momento: kalkulilo, viaj dosieroj, paĝo da notoj. `Super+Ctrl+b` glitas ilin de la dekstra rando de la ekrano, unu super la alia, super via fenestro, sur ajna labortablo, kie vi estas; la samo denove glitas ilin for. Ili daŭre funkcias dum ili estas for, do la kalkulilo konservas siajn kalkulojn kaj la dosieroj sian dosierujon. La fenestroj sube ne estas movataj aŭ malgrandigitaj.

Kiel aperas, la traro enhavas terminalon kaj PCManFM. Viaj estas listo en `user.lisp`, de supra ĝis suba, ĉiu estas nomo kaj la komando, kiu lanĉas ĝin:

```lisp
(setf *vikix-drawer-apps*
      '(("Calculator" "speedcrunch")
        ("Files" "esploro --new ~" :class "Emacs" :title "Esploro")
        ("Notes" "emacsclient -c -n -a '' -F '((name . \"Notes\"))' ~/notes.org"
         :class "Emacs" :title "Notes")))
(setf *vikix-drawer-side* :left)     ; the edge: :right as it comes
(setf *vikix-drawer-width* "35%")    ; of the screen, or pixels: 500
```

Programo estas lanĉata la unuan fojon, kiam la fenestro aperas, kaj denove, kiam vi fermas ĝin. Ĝia fenestro aperas en la fenestro, sendepende de la reguloj, kiujn vi difinis por tiu programo: regulo, kiu movigas SpeedCrunch al labr-areo 1, ankoraŭ validas por SpeedCrunch, kiun vi lanĉas mem, sed ne por la fenestro. La fenestro konas fenestron laŭ la programo, kiu kreis ĝin. Kiam alia programo kreas la fenestron, oni povas determini ĝin per la sama metodo, kiun uzas regulo (`:class`, `:instance`, `:title`, `:role`): Emacs-kadro estas kreata de la Emacs-servero, sendepende de tio, kio lanĉis ĝin, kaj dua PCManFM-fenestro estas kreata de la unua PCManFM. `xprop WM_CLASS WM_NAME` kaj klako sur fenestro montras ĝian klason (la dua vorto) kaj ĝian titolon.

En alia labr-areo la klavo movigas la fenestron tien. Fenestro de la fenestro, kiu estas tileita per `Super+t`, estas ordinara fenestro de tiam, kaj ĝia programo estas lanĉata denove por la fenestro la sekvan fojon. Sur horizonta strio, la fenestro aperas super la kolumnoj. Ĝi glitas, kiam la komponanto funkcias, kiel horizonta strio (`*viri-animate*`).

### La terminalo, fokuso kaj tiparoj

```lisp
(setf *vikix-terminal* "kitty")            ; what Super+Return opens
(setf *mouse-focus-policy* :click)         ; focus on click, not when the pointer moves over a window
(setf *vikix-font-size* 13)                ; the bar, menus and messages
(vikix-set-font)
```

La interspaco inter fenestroj (Super+Ctrl+g) estas 10 pikseloj, 9 pikseloj ĉe la rando de la ekrano. La interna interspaco estas ĉe ĉiuj flankoj de ĉiu fenestro, do du fenestroj estas duoble pli for unu de la alia. Por ŝanĝi ilin aŭ aktivigi ilin post ĉiu ensaluto:

```lisp
(setf swm-gaps:*inner-gaps-size* 3         ; 6px between windows
      swm-gaps:*outer-gaps-size* 3)        ; plus this at the screen edge
(swm-gaps:toggle-gaps-on)                  ; gaps from login on
```

### La menuo Super+m

La menuo malfermiĝas al ĝiaj sekcioj: Starto, Helpo, Vikix, AI, Laboro, Notifoj, Labortablo, Fenestroj, Sistemo, Aplikoj kaj Potenco, la lasta. Ĉiu linio diras, kion la sekcio enhavas. Eniri (aŭ Dekstre) malfermas unu, kaj Escape (aŭ Maldekstre) revenas; dua Escape fermas la menuon. Tajpado ĉe la supro serĉas tra ĉiuj eniroj de ĉiuj sekcioj samtempe, do `printers`, `theme` aŭ `F10` estas nur unu paŝo for (simplaj vortoj, en ajna ordo kaj ajna kazo; la nomo de klavo kalkas, do `ctrl+d` trovas, kion Super+Ctrl+d faras). Eniro, kiu havas klavon, montras ĝin dekstre, ankaŭ ret-apliko kaj kromprogramo.

Komando skribita per `define-vikix-command` kaj `:menu` jam estas en sia sekcio (Klavoj, supre). La menuo mem estas listo, kiun vi povas ŝanĝi kiel tuto. Ĉiu eniro estas etikedo kaj aŭ komando aŭ Lisp-formo; tiam, se vi volas, kion ĝi bezonas: programo en PATH, aŭ dosiero (`"~/..."`); kaj tiam ĝia sekcio. Eniro, kies bezono ne estas tie, estas forlasita el la menuo, kaj tiel Vikix kaŝas JupyterLab aŭ Presilojn ĝis vi aldonas iliajn funkciojn (kaj, en `*vikix-apps-menu*`, kiun la sekcio Aplikoj montras, ĉiu videa, grafika aŭ studa programo ĝis ĝi estas instalita):

```lisp
(setf *vikix-menu*
      (append *vikix-menu*
              '(("Obsidian" (run-shell-command "obsidian") "obsidian" "Apps")   ; in Apps, and only with obsidian installed
                ("Keys"     vikix-keys nil "Help")                              ; needs nothing; in Help
                ("Tides"    (run-shell-command "tides")))))                     ; no section: in one called Yours
```

Sekcio povas havi propran nomon (`"Navigado"`): ĝi aperas post la sekcio de Vikix, antaŭ la sekcio "Power". Sekcio kun unu eniraĵo ne estas vico, kiun oni malfermu: la eniraĵo mem estas ĉe la supro. En sekcio, la eniraĵoj konservas la ordon de la listo, escepte ke linioj pri la sama temo (`Layout: save ...`, `Layout: put back ...`) restas kune.

### La breto

`Super+Ctrl+h` kaŝas la breton sur la ekrano, kie vi estas, kaj la fenestroj okupas la spacon; la samo ripetita remalfermas ĝin (`Super+m` → *La breto ŝaltita/malŝaltita (kaŝu ĝin por la tuta ekrano)* estas la sama). Ĝi ne memoras: la breto estas denove tie post *Reload config* kaj ĉe la sekva ensaluto.

La muso ankaŭ funkcias sur ĝi: la numero de labrestacio aperas tie, la titolo de fenestro metas ĝin en fokuson, la volumeno malfermas la miksilon (la rado turnas ĝin supren kaj malsupren, la mez-butono senŝaltas ĝin), la reto malfermas la elekton de Wi-Fi (`vikix wifi`: ĝi unue skanas, poste listigas la retojn; per kablo, `nmtui`), kaj Bluetooth malfermas ĝiajn agordojn. Klako sur ajna alia kampo (la baterio, la horloĝo, `updates`) montras kio ĝi estas: la karto `Super+Alt+?` aperas por ĉiu objekto, sur kiu la kursoro estas (`vikix what`). Kampo, kiun Vikix skribas, estas transformita en areon kun nomo per `vikix-ml-what` en `modeline.lisp`, kaj tiel la klavo scias, sur kiu objekto la kursoro estas. La klakeblaj partoj estas `^(:on-click ...)`-areoj kreitaj per `vikix-ml-clickable` en `modeline.lisp`; kiam ili koincidas, kiel longa titolo de fenestro sub la kampoj sur la dekstro, la plej mallarĝa venkas.

La breto estas unu formatiga ŝnuraro. Vikix agordas ĝin en `modeline.lisp`:

```lisp
"%J  %W^>%R%K%X%Y%G%Q%U%A%D%Z%O%T%V%E%d"
```

`%J` la labortaboj, `%W` la fenestroj, `^>` alineigas la reston dekstre: `%R` rek (aŭ mikrofono, dum diktado estas aktiva), `%F` tempo de fokuso kaj ĝia paŭzo, `%K` veka, `%X` win (la Windows VM), `%Y` ai (loka modelo ŝargita), `%G` mem (malalta memoro, kaj restantaj programoj), `%Q` silento, `%U` ĝisdatigoj, `%A` kopio, `%D` usb, `%Z` Dropbox, `%O` reto, `%T` Bluetooth, `%V` laŭteco, `%E` baterio, `%d` dato kaj tempo. Agordu viajn proprajn en `user.lisp` por forigi aŭ reordigi kampojn:

```lisp
;; no Bluetooth, and the time without the date
(setf *time-modeline-string* "%H:%M"
      *screen-mode-line-format* "%J  %W^>%R%K%X%Y%Q%U%A%D%Z%O%V%E%d")
```

Via propra kampo povas esti listo de elementoj `(:eval FORM)`, kiu estos ekzekutata ĉiufoje kiam la breto estas redesegnita (ĉiun 10 sekundojn). Certigu, ke la formo estas rapida, ĉar la tuta labortablo atendas dum ĝia ekzekuto:

```lisp
(setf *screen-mode-line-format*
      (list "%J  %W^>%R%K%X%Y%Q%U%A%D%Z%O%T%V%E"
            '(:eval (format nil "load ~a  " (first (uiop:split-string (uiop:read-file-string "/proc/loadavg")))))
            "%d"))
```

### Unue provu ĝin en aktiva stato

`vikix eval` faras, ke Lisp-kodo funkcias en la aktiva StumpWM, do vi povas provi ŝanĝon antaŭ ol skribi ĝin:

```sh
vikix eval '(vikix-bind "s-t" "exec obsidian")'
```

Ĉi tio daŭras ĝis la sekva refreŝigo aŭ ensaluto. Kiam ĝi faras tion, kion vi volas, metu la saman linion en `user.lisp`.

## La aspekto

| Por ŝanĝi | Faru |
|---|---|
| La tuta temo | `vikix theme vikix-light` (aŭ `Super+m` → *Temo*, kiu montras ĉiun temon sur la ekrano dum vi moviĝas al ĝi; Escape remet la vian). `vikix theme` listigas ilin: `vikix-light`, `vikix-dark`, `contrast-dark`, `gruvbox-dark`, `nord-dark`, `tokyo-night-dark`, kaj la via; ĉiu nomo finiĝas per `-light` aŭ `-dark`. La malnovaj nomoj (`void`, `paper`, `nord`, ...) ankoraŭ funkcias. La terminala sesio de agento (Codex, Claude Code) estas la sola, kiu ne sekvas ĉi tiun regulon: ĝia TUI legas la fonon de la terminalo unufoje, kiam ĝi komenciĝas, kaj daŭre afiŝas ĝin, do post ŝanĝo de malhela al hela, ĝia teksto estas pastelkolora sur kremkolora. La ŝanĝo nomas ĉi tiajn sesiojn en la terminalo kaj kiel notifon; rekomencu ilin por ke ili korekte afiŝiĝu (`vikix agents resume DESK` rekomencas la konversacion). |
| Temo, kiun vi mem kreis | `cp ~/vikix/themes/vikix-dark.theme ~/.config/vikix/themes/mine-dark.theme`, ŝanĝu la kolorojn, `vikix theme mine-dark`. Bildo apud ĝi, `mine-dark.jpg`, fariĝas ĝia tapeto. La nomo povas enhavi nur literojn, ciferojn, `-` kaj `_` (`my-theme`, ne `my theme`): dosiero kun alia nomo ne estos listita aŭ uzata. |
| La koloroj de la terminalo de agento | `agent_asks`, `agent_released` kaj `agent_pushed` en la tema dosiero: kion la fenestra listo de la horizontalo, la titolo-baraĵo kaj la Oficejo montras dum la agento atendas vin, dum ĝia liberigita skribotablo atendas `gup`, kaj unufoje, kiam tio estos sendita ([Agentoj en laboro](agents.md#labortablo-por-ĉiu)). Temo sen ili uzas siajn `color3`, `color2` kaj `color6`. |
| Temo de Omarchy | `vikix theme import bjarneo/omarchy-ash-theme` (POSCEDANTO/REPO en GitHub, aŭ `https://` git-URL). La temoj de [Omarchy](https://omarchy.org) kaj tiuj de ĝia komunumo ĉe [themes.omarchy.org](https://themes.omarchy.org) estas git-deponejoj kun `colors.toml`. La koloroj fariĝas `~/.config/vikix/themes/ash.theme` (la nomo de la deponejo sen `omarchy-` kaj `-theme`; donu alian kiel la sekvan vorton), la unua bildo en `backgrounds/` fariĝas ĝia tapeto, kaj Vikix ŝanĝiĝas al ĝi (`--no-switch` ne faras tion). Nenio en la deponejo estas elprenita, kaj la resto de ĝi estas forlasita. `--force` anstataŭigas temon, kiun vi havas, kun la sama nomo; la malnovaj dosieroj estas konservitaj kiel `.vikix-bak`. |
| La tapeto | Ĝi rotacias: nova bildo ĉiun 30 minutojn el la kolekto de Vid (la funkcio `wallpapers`, kiun nova instalado havas), `~/Pictures/Wallpapers` kaj `~/wallpapers`. `vikix-wallpaper cycle 60` por ĉiun horon, `vikix-wallpaper next` por alia nun. Por konservi unu: `Super+m` → *Tapeto*, aŭ `vikix-wallpaper FILE`; *Temo* tie sekvas la temon, *Ciklo* rotacias denove. `vikix update` alportas la novajn bildojn de la kolekto. *Mia propra ilo* en la selektilo haltigas Vikix-on de tuŝado de ĝi, por feh aŭ nitrogen. |
| Terminala skriftotipo, grandeco, interspaco | `~/.config/alacritty/alacritty.toml`. Ĉiuj malfermaj fenestroj ŝanĝiĝas tuj. |
| GTK kaj Qt-programoj (Firefox, PCManFM, LibreOffice) | Ili sekvas la temon memstare: malhela kun malhela temo, hela kun hela temo, tuj. GTK 4-programoj ankaŭ prenas ĝiajn kolorojn. Por konservi la saman aspekton, sendepende de la temo: viaj reguloj en `~/.config/gtk-4.0/gtk.css`, sub la linio, kiu importas la temon; por Qt, `qt6ct` |
| La koloroj de unu programo, konservante la temon por la resto | Difinu ilin en la agorda dosiero de tiu programo, post la linio, kiu inkluzivas la temon. Por dunst, nova dosiero post la temo: `~/.config/dunst/dunstrc.d/90-mine.conf`. |
| Teksta grandeco sur ekrano kun alta rezolucio | `Xft.dpi` en `~/.Xresources` (la dosiero sugestas valorojn), poste denove ensalutu. |
| Programo, kies fenestroj devas flosi antaŭe, kiel dialogoj | `(push "Class" *vikix-dialog-classes*)` en `user.lisp`, la klaso estante la dua vorto, kiun `xprop WM_CLASS` elprintas kiam vi klakas la fenestron. Dialogoj, fenestroj de pasvortoj (zenity, polkit, ssh-askpass, pinentry) jam faras tion. |
| Ombroj, translidiĝo, travidebleco | `~/.config/picom/picom.conf`. picom refreŝigas la dosieron kiam ĝi ŝanĝiĝas. Por ŝanĝi `backend`, unue `pkill picom`, poste redaktu, poste `picom -b`: ŝanĝi ĝin dum picom funkcias povas frostigi la ekranon. |
| Notifoj: kie, kiom daŭre, kiom grandaj | `~/.config/dunst/dunstrc`, poste `dunstctl reload`. |
| La lanĉilo kaj menuoj | `~/.config/rofi/config.rasi`. |

## La maŝino

| Por ŝanĝi | Faru |
|---|---|
| Klaviatara aranĝo, Caps Lock | `Super+m` → *Bonvenigu* → *Agordu vian klaviaturan aranĝon* elektas unu el listo kaj aplikas ĝin. Aŭ redaktu `~/.config/vikix/keyboard` (`VIKIX_KB_LAYOUT`, elekteblaj opcioj kiel `ctrl:nocaps`), poste `Super+m` → *Apliku klaviaturaĵajn agordaĵojn*. La komencilo interŝanĝas Caps Lock kaj Left Ctrl. |
| Kiam la ekrano ŝargiĝas, malŝaltas, estas metita en reĝimon de ripozo | Kreu `~/.config/vikix/idle` kun unu el `LOCK=10`, `SCREEN_OFF=11`, `SUSPEND=20` (minutoj; `SUSPEND=0` malaktivigas reĝimon de ripozo; reĝimo de ripozo funkcias nur kiam la aparato estas ŝargata), poste denove ensalutu. |
| Horoj kaj intenseco de nokta lumo | `~/.config/gammastep/config.ini`. `Super+Ctrl+l` ŝaltas kaj malŝaltas ĝin. |
| Kiu programo malfermas apartan tipon de dosiero | `~/.config/mimeapps.list`, aŭ `xdg-mime default org.pwmt.zathura.desktop application/pdf`. |
| Ekranoj en skribotablo | Ekranon, kiun vi enŝovas, ekbrilas memstare, dekstre de la ekrano de la portebla komputilo, kun la tapeto sur ĝi, kaj revenas en la sama maniero la sekvan fojon. `Super+Ctrl+p` (aŭ la ekrana ŝlosilo de la portebla komputilo) por spegula projekcio, nur la alia ekrano, nur la ekrano de la portebla komputilo, aŭ aranĝu ilin mane; tio, kion vi elektas, estas memorita por tiuj ekranoj. |
| Kio estas forlasita en la kopiaĵoj | `~/.config/vikix/backup-exclude`. |

### Kiam la baterio elĉerpiĝas

La observilo `vikix-battery` de la sesio avertas je 15% kaj aŭtomate metas la komputilon en reĝimon de ripozo je 5% aŭ malpli dum elĉerpiĝo, post kiam ĝi kontrolas, ĉu ekzistas ŝargilo. La ekrana ŝargilo `xss-lock` de la sesio ŝargiĝas antaŭ ol la komputilo estas metita en reĝimon de ripozo. Reĝimo de ripozo pro malplena baterio ankoraŭ aplikiĝas, eĉ se *daŭrigi aktivan* estas ŝaltita aŭ `SUSPEND=0`: tiuj agordaĵoj kontrolas nur reĝimon de ripozo. Post ĝisdatigo al ĉi tiu konduto, eliru kaj reeniru por komenci la novan observilon.

Ĝi kontrolas la unuan baterion unufoje en minuto, ĉiun 15 sekundojn kiam la ŝarĝo estas malalta. Post sukcesa peto pri reĝimo de ripozo, ĝi atendas du minutojn antaŭ ol denove kontroli, por doni al vi tempon por konekti la ŝargilon post kiam vi vekigas la komputilon. Se reĝimo de ripozo malsukĉesas, ĝi avertas kaj refaras la provon post minuto. `vikix-battery --once` elprintas kaj avertas sen meti la komputilon en reĝimon de ripozo. La ŝarĝaĵa medio `VIKIX_BATTERY_LOW` kaj `VIKIX_BATTERY_CRITICAL` forigas la procentaĵojn (1 <= kritika <= malalta <= 100).

Reĝimo de ripozo ankoraŭ konsumas energion. Enŝovu la ŝargilon antaŭ ol la ceteraj ŝargoj elĉerpiĝas; ĉi tio ne agordas hibernacion aŭ konservas la memoron post totala perdo de energio.

## La ŝelo

`~/.bashrc` estas via. La bloko de Vikix estas ĉe la supro kaj ŝarĝas ĝiajn pseŭdonimojn kaj prompton (`~/.config/vikix/vikix.bash`), do tio, kion vi skribas sube, venkos:

```sh
alias gs='git status'          # your aliases
PS1='\w \$ '                   # your own prompt
export EDITOR=nvim
```

Ne redaktu inter la linioj `# >>> vikix … >>>` kaj `# <<< vikix … <<<`; Vikix reskribas tiujn.

**API-ŝlosiloj ne iru ĉi tien.** Linio `export ANTHROPIC_API_KEY=...` en `~/.bashrc` restas por ĉiam en la historio de viaj dosieroj. Uzu `vikix ai key set anthropic` anstataŭe: ĉiu ŝelo ankoraŭ ricevas la variablon (vidu la [LEG-DOSIERON](../../README.md#api-keys)). `alias` listigas ĉiun aliason, kaj la [LEG-DOSIERO](../../README.md#shell-aliases) klarigas ilin.

## Programoj kaj servoj

- **Instali programon:** `vikix pkg add NAME`, aŭ `vikix pkg add` sole por serĉi ĉiun pakon en Void kun priskribo apud ĉiu (Super+m → *Instali programon*). `xi NAME` funkcias ankaŭ. Ĝi restas instalita, kaj `vikix update` tenas ĝin ĝisdata kune kun ĉio alia.
- **Aldoni aŭ forigi funkcion:** lingvo, redaktilo, LibreOffice, presado, video- kaj grafikaj programoj, Vindozo, loka AI, diktado kaj voĉo, alia AI-agento. `vikix features` listigas ilin kaj markas tiujn, kiujn vi havas; `vikix add rust` instalis unu, kaj ĉiu ĝisdatigo tenas ĝin; `vikix remove rust` forigas tion, kion ĝi nur bezonis, post montri al vi la liston. Paketoj aldonas plurajn samtempe: `vikix add essentials` (Emacs, C, Python, Lisp), `developer`, `creative` (video, grafikoj, Blender), `everything`. Viaj elektoj estas en `~/.config/vikix/features`. La programoj de la funkciaj paketoj (video, grafikoj, blender, studo, pasvortoj, telefono, cli-extras) estas en `Super+m` → *Aplikoj*, ĉiu post ĝia instalado. Vindozo (`vikix windows setup`, vidu [Vindozo en fenestro](windows.md)) kaj retaj aplikoj (la unua `vikix webapp add`) elektas sian funkcion mem.
- **Forigi programon:** `vikix pkg drop NAME`, aŭ `vikix pkg drop` sole por elekti el tio, kio estas instalita (Super+m → *Forigi programon*). Tiu, kies nomo estas en la listo de Vikix, eniras vian liston de forigendaj, `~/.config/vikix/packages-skip`, do `vikix update` ne remetas ĝin; `vikix pkg list` montras ĝin, kaj `vikix pkg add NAME` forigas unu el la listo. Por tuta lingvo aŭ redaktilo, `vikix remove` estas la pli bona maniero: ĝi diras tion. (`xr NAME` forigas ankaŭ pakon, sed ĝisdatigo reinstalus ĝin.)
- **Propra lanĉilo-ejo:** la lanĉilo (Super+d) listigas la `.desktop`-dosierojn en `~/.local/share/applications`. Metu vian tie, kun `Name=` kaj `Exec=`; linio `Keywords=` (`Keywords=jlab;notebook;`) igas ĝin aperi por aliaj vortoj, kiujn vi povus tajpi, kiel `jlab` trovas JupyterLab.
- **Ŝalti servon:** `sv-on NAME` (la servoj estas en `/etc/sv/`), `sv-off NAME`, `svls` por listigi. Ĉi tiuj estas sistemaj servoj. Programo por via labortabula sesio iras en `user.lisp` anstataŭe ([supre](#lanĉu-programon-per-la-labortablo)).

## Retaj aplikoj

Tiu retejo, kiun vi uzas kiel programon (poŝto, CRM, kalendaro), povas havi fenestron, lanĉilo-ejon kaj propran ŝlosilon:

```sh
vikix webapp add superhuman            # presets: superhuman, fastmail, gmail, outlook, outlook-live
vikix webapp add crm https://crm.example.com --key s-M-k   # Super+Alt+k: web apps' keys are on Super+Alt
vikix webapp key crm none              # change its key, or drop it
```

Via listo estas `~/.config/vikix/webapps`, unu `NOMO URLO [ŜLOSO]` por ĉiu linio; redakti ĝin mane ankaŭ funkcias (viaj komentoj restas), poste `Super+m` → *Reŝarĝi konfiguracion*; `vikix webapp list` montras linion, kiun ĝi ne povas uzi. Por lanĉi unu ĉe eniro, aldonu `(run-shell-command "vikix-webapp launch NOMO")` al `user.lisp`. Vidu la [LEGISTON](../../README.md#web-apps).

## La redaktiloj

Emacs kaj Neovim havas funkciojn: `vikix add emacs`, `vikix add neovim`. La konfiguracio de Neovim estas dividita kiel tiu de la labortablo: la parto de Vikix estas `~/.local/share/vikix/nvim`, kaj `~/.config/nvim` estas via (viaj kromprogramoj iras en ĝian `lua/plugins/`, kaj venkas). La konfiguracio de Emacs estas git-klono de la aŭtoro ĉe `~/.emacs.d`, kiun `vikix update` alprenas, kaj la agordaĵo de Vikix pri AI por ĝi estas `~/.local/share/vikix/emacs`. [Neovim kaj Emacs](editors.md) enhavas la reston: klavoj, lingvaj servoj, AI en ĉiu, kaj alporti propran konfiguracion.

## Projektoj

`vikix project` listigas la dosierojn sub `~/src`, kiuj havas `log.md`, kaj aldonas ilin al siaj logoj ([la LEGISTO](../../README.md#projects-vikix-project) enhavas la komandojn kaj la strukturon de la logo). La loko, kie ĝi serĉas, estas `~/.config/vikix/projects`, via; ĝi komencas kiel nur komentoj, do la ĉiuagaj valoroj restas ĝis vi forkomentigas linion:

```sh
root=~/src            # a folder your projects are in; one line each, as many as you like
root=~/work
depth=2               # how far down: 2 makes ~/src/series/book a project of the collection "series"
logs=~/src/project-logs   # a public repo ~/src/NAME with no log.md of its own uses logs/NAME/log.md
```

La ŝanĝo tuj efikas: ĉiu `vikix-projekto` denove legas ĝin. Projekto, kies konstruado ne estas `build.sh`, `make`, `src/build.sh` aŭ `npm run build`, tion diras en la Stato de ĝia registro, kun linio `- Konstruado: KOMANDO`, kaj simile por ĝiaj kontrolaj procezoj kun `- Kontrolo: KOMANDO`. `vikix project new NAME` aldonas projekton (dosierujon en la unua `root=`) kun ĝia registro; `vikix today` estas la tago tra ĉiuj el ili. `Super+Alt+p` (aŭ `Super+m` → *Projektoj*) elektas unu per rofi kaj malfermas terminalon en ĝia dosierujo kaj ĝia registro en Emacs (en `$EDITOR`, Neovim kiel defaŭlto, sen Emacs); la terminalo estas `$VIKIX_TERMINAL`, `alacritty` se vi ne difinis alian.

`vikix project open NAME` (aŭ Super+Alt+p) metas projekton en apartan labortablon, la unuan malplenan el la naŭ (novan tablon nomitan laŭ la projekto, kiam ĉiuj naŭ estas uzataj, vidu *Labortabloj post la naŭ*), kun terminalo en ĝia dosierujo kaj ĝia registro en la redaktilo. Organizu ilin kiel vi volas: kiam vi foriras de tiu labortablo, ĝia aranĝo estas konservata (kiel aranĝo nomata `project-NAME`, vidu *Konservitaj aranĝoj*), kaj la venontan fojon kiam vi malfermas la projekton, ĝi revenos tiel. Dum la labortablo de la projekto ankoraŭ estas malfermita, malfermi ĝin denove simple iras tien. `vikix project save` tuj konservas ĝin. Fenestro, kiu enhavas la konservitan aranĝon kaj ne estas malfermita, ekzemple, navigilo, estas rekomencita kaj metita en ĝian lokon.

`vikix day` tenas taglibron de la samaj projektoj: kiom da tempo ĉiu havis la ekranon, ĝiaj eniroj kaj ŝanĝoj, dosiero tage en `~/journal` ([la README](../../README.md#projects-vikix-project) diras, kion ĝi legas). Ĝia dosierujo estas `folder=~/Notes/journal` en `~/.config/vikix/day`, dosiero, kiun vi kreas; kaj `(setf *vikix-day-on* nil)` en `user.lisp` haltigas, ke la labortablo notu, kio estas sur la ekrano.

**Kie mi estis?** Kiam vi revenas al la portebla komputilo post dek minutoj aŭ pli, notifo kun tiu titolo diras, kie vi estis: kiom da tempo vi foriris, la projekto, kun kiu vi laboris, kaj ĝia venonta paŝo, la dosieroj, kiujn Emacs ne konservis, via lasta komando, kaj via lasta notoj se vi havas la [enirejan kromprogramon](plugins.md#inbox-notoj-de-ĉie). `Super+m` → *Kie mi estis? (la projekto, ĝia venonta paŝo, tio, kio ne estas konservita)* denove montras ĝin, kaj `vikix back` en terminalo diras pli: la lasta ŝanĝo de la projekto kaj viaj lastaj kelkaj komandoj. Ĝi nur legas tion, kio estas konservita, la taglibro-registro de la ekrano inter ili, do ne ekzistas karto dum `*vikix-day-on*` estas `nil`. Por atendi pli longe, aŭ neniam montri ĝin, en `user.lisp`:

```lisp
(setf *vikix-back-after* 1800)   ; seconds away before the card: half an hour (600 as it comes)
(setf *vikix-back-after* nil)    ; never; vikix back still answers when you ask
```

## Viaj dokumentoj, kaj viaj paĝoj por "kio estas ĉi tio?"

`Super+F2` serĉas en katalogo de ĉiuj dokumentoj sur la komputilo (`vikix docs`), kaj `Super+Alt+?` klarigas ion en la formo de karto (`vikix what`). Via ununura dosiero, `~/.config/vikix/docs`, aldonas vian propran tekston al ambaŭ. Kreu ĝin per linioj kiel ĉi tiuj:

```
own=~/books                       # every Markdown file under it, read a section at a time
own=~/books site/out/*.html       # these HTML pages too (patterns from that folder)
own=~/papers **/*.pdf             # PDFs by their text: a row a page, opened at the page
agents=~/books/unix-by-hand       # open this folder to the AI agents; the rest of yours stays closed
what=~/books/what                 # your pages for vikix what
```

La dokumentoj de dosierujo `own=` estas linioj de la katalogo, unu por ĉiu dosiero kaj unu por ĉiu dua nivela titolo (`##`, aŭ `<h2>` kun ID aŭ etikedo `data-at`), do la serĉo trovas la sekcion, kaj tiel ankaŭ ĉapitro trovas paĝon. Ili malfermiĝas en la dokumenta navigilo ĉe tiu sekcio, kun la sama stilo kiel la gvidlibro (`Ctrl+Enter`: la dosiero en Emacs). Ili estas fermitaj por la agentoj `docs_search` kaj `docs_read`, kaj por `vikix docs ask` kiam agento ekzekutas ĝin, ĝis linio `agents=` malfermas dosierujon por ili. PDF nomita laŭ ŝablono estas legata per la teksto de ĝiaj unuaj dudek paĝoj (`pdftotext`; skanita versio estas listita nur per sia nomo) kaj malfermiĝas ĉe la paĝo de la rezulto en zathura, evince aŭ mupdf.

Dua dosiero, `~/.config/vikix/docs-links`, enhavas viajn proprajn ligilojn: URL kaj ĝia titolo sur unu linio, en ajna ordo (`https://example.org/sv La sv-paĝo`, `# komentoj` permesitaj). Ili estas rezultoj de la fonto `web` krom la retejoj de la instalitaj pakaĵoj kaj la ligiloj, kiujn la lingvaj gvidlibroj en `~/dev` listigas, ĉiu kun globo en la listo: la ununura speco de rezulto, kiu malfermiĝas en la reto (via defolta navigilo), kaj nenio el ili estas iam ajn alirita, nek kiam la katalogo estas legata, nek kiam ĝi estas serĉata, nek por respondo de `vikix docs ask`.

Dosierujo `what=` enhavas viajn paĝojn, unu dosiero por unu speco de objekto (`process.md`, `service.md` kaj `service-sshd.md` por unu objekto): alineo per viaj vortoj, kiu anstataŭigas la Vikix-an en la karto, poste linioj dirantaj kie legi plu, viaj antaŭ la Vikix-aj:

```
A process is a program while it runs. (Your words, sixty at most.)

chapter: unix-by-hand/ch04-processes.md#A program that is running
chapter: site/out/page.html#bus
see: port
```

`chapter:`-linio nomas dosieron en unu el viaj `own=`-dosieroj kaj sekcion de ĝi: la vortoj de la titolo por Markdown, la ID de la elemento por HTML. `vikix what check` diras, kiuj linioj ne nomas ion, `vikix what gaps` listigas, kio ankoraŭ ne havas paĝon aŭ ĉapitron (la tipoj, la kampoj de la naviga strio, la servoj, kiuj funkcias ĉi tie): listo de skribaj elementoj, prenita de la maŝino. ("unix-by-hand" estas fikcia libro.)

## AI

Ĉiu el ĉi tiuj estas unu el viaj dosieroj, do ĝi ankaŭ havas funkcion "malfari". [Labori kun AI](ai.md) diras, kion ĉiu faras.

| Por ŝanĝi | Fari |
|---|---|
| La modelo, kiun Super+i uzas (kaj la chat-fenestroj de la redaktoroj, Super+F10 kaj `note`) | `vikix ai use local`, `vikix ai use claude` aŭ `vikix ai use codex` (nur Super+i kaj Super+F10); `vikix ai use` sola diras, kiun. La modelo kaj la lingvoj, al kiuj traduki, estas en `~/.config/vikix/ai` ([Lokala aŭ Claude](ai.md#loka-aŭ-claude)) |
| La agento, kiun Super+a startas (kaj la redaktoroj, kaj Super+F11) | `vikix agent --default opencode`; `vikix agent --which` diras, kiun ([Alia agento](ai.md#alia-agento)) |
| La lingvo de la diktado | `vikix dictate models small` (aŭ `large-v3-turbo`, la plej bona) por multaj lingvoj, `base.en` por la angla ([Diktado](ai.md#diktaĵo)) |
| La voĉo, kiu respondas, aŭ neniu voĉo | `vikix voice voices alan`; `speak=no` aŭ `idle=` en `~/.config/vikix/voice` ([Parolado kun la AI](ai.md#parolado-kun-la-ai)) |
| La notoj, kiujn `note` legas | `note index FOLDER --skip A,B` unufoje; `folder=`, `skip=`, `embed=` en `~/.config/vikix/notes` ([Demandi viajn notojn](ai.md#demandado-de-viaj-notoj-note)) |
| Kion la agento povas fari sur la labortablo sen demandi | `vikix mcp register` donas al ĝi la labortablon kiel ilojn; `--allow-eval` kaj `--allow-undo` aldonas la du riskanajn, kaj reĝistriĝo sen ili forigas ilin ([La labortablo kiel iloj](ai.md#la-labortablo-kiel-iloj-mcp)) |

## Ŝanĝi la propran Vikix

Kelajn aĵojn oni povas ŝanĝi nur en la propraj dosieroj de Vikix: defaŭltaĵo por ĉiuj, eraro, nova fazo. Ŝanĝu ilin en kopio, kiun vi aldonas al la versada sistemo, ne rekte:

1. Klonu github.com/vukini/vikix kaj direktu vian kopion al la klono: `git -C ~/vikix remote set-url origin https://github.com/YOU/vikix.git`
2. Faru la ŝanĝon en `~/vikix`, ruligu `tests/run.sh`, kaj aldonu ĝin al la versada sistemo.
3. `vikix update` nun alprenas vian klonon. Por enpreni novajn versiojn de Vikix, kunigu ilin en la klonon.

Aŭ, se tio helpus al ĉiuj, malfermu problemon aŭ peton por aldonoj.
