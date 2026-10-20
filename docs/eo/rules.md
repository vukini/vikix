# Reguloj por la labortablo

Regulo estas unu linio, kiu diras, kion la labortablo faras memstare: Firefox malfermiĝas en labortablo 2, la sonmiksilo flosas, programo startiĝas kiam vi ensalutas, aperas notifo je la unua horo. Vi skribas ĝin unufoje, kaj ĝi validas de tiam.

```lisp
(when-window (:class "Firefox") (workspace 2))
(when-window (:class (:has "pavucontrol")) (float :width "50%" :height "60%"))
(at-login (run "syncthing --no-browser"))
(at "13:00" :weekdays (notify "One o'clock" "Lunch."))
```

La reguloj estas sekuraj por provi. Eraro en unu estas trovita kiam la dosiero estas ŝargata kaj kostas nur tiun regulon; regulo, kiu malsukĉesas poste, neniam haltigas la labortablon; kaj `vikix undo` remetas vian dosieron kiel ĝi estis.

## Kien loĝas viaj reguloj

En `~/.stumpwm.d/rules.lisp`. Ĝi estas via: Vikix kreas ĝin unufoje, kun ĉiuj ekzemploj malŝaltitaj (`;` antaŭe), kaj neniam anstataŭigas ĝin. Forigu la `;` de ekzemplo, ŝanĝu ĝin por taŭgi, kaj reŝarĝu per `Super+m` → *Reŝarĝi la konfiguracion*.

Regulo funkcias ankaŭ en `~/.stumpwm.d/user.lisp`, kaj tio estas la loko por unu, kiu vokas funkcion, kiun vi skribis tie. `rules.lisp` estas ŝargata juste antaŭ `user.lisp`.

## La plej rapida regulo: memoru ĉi tiun fenestron

Vi ne devas skribi regulon por akiri ĝin. Metu fenestron, kie vi volas ĝin: sur ĝia labortablo, kaj se ĝi flosas, en la grandeco kaj loko, kiujn vi ŝatas. Poste, premu `Super+Shift+t`.

La regulo, kiu metus fenestron kiel tiu tie, estas montrata unue. Elektu *Skribu ĝin* kaj ĝi estas aldonita al `rules.lisp` sub datita komento, nomita `"memorita: ..."`, post foto de viaj dosieroj. La menuo ofertas ankaŭ nur la labortabelon (por flosanta fenestro, sen ĝia grandeco kaj loko), kaj alian manieron koni la fenestron: ĝia ekzemplaro aŭ ĝia titolo anstataŭ ĝia klaso.

Memorigo de la sama fenestro denove anstataŭigas ĝian regulon. `vikix rules forget 3` forigas regulon el `rules.lisp` denove, laŭ ĝia nombro aŭ ĝia nomo, kaj `vikix undo` remetas la dosieron. Nur `rules.lisp` estas iam skribata ĉi tiu maniero, neniam `user.lisp`.

## De ideo al regulo

Kvar ideoj, ĉiu prenita de la deziro pri regulo, kiu funkcias. Ĉiuj iras la saman vojon: diru, kion vi volas en frazo, trovu, kiel la labortablo nomas la fenestron, skribu la linion, kaj kontrolu ĝin antaŭ ol fidi al ĝi.

### Poŝto sur sia propra labortablo

**La ideo.** "Mia poŝto malfermiĝas sur labortablo 7, kaj mi iras tien kun ĝi."

**Kiel nomiĝas la fenestro?** Regulo konas fenestron per ĝia klaso, la nomo, kiun ĝia programo donas al ĝi. Malfermu vian poŝton, poste demandu en terminalo pri la fenestro, per vorto de ĝia titolo:

```
$ vikix rules why fastmail
vikix-fastmail "Fastmail" (workspace 1, window 0)
  No rule has run for it.
  No rule matches it either: it is where StumpWM, or you, put it.
```

La unua vorto estas la klaso, `vikix-fastmail`; poste venas ĝia titolo kaj kie ĝi troviĝas nuntempe. Ankoraŭ ne ekzistas regulo pri ĝi, kaj tion ni antaŭvidis. (`Super+m` → *Reguloj* kun la fenestro de poŝto en la unua vico montras la klason, en sia unua eniraĵo.)

**La regulo.** La frazo transformiĝas en unu linio, en du partoj: kio la fenestro devas esti, kaj poste kion fari kun ĝi.

```lisp
(when-window (:class "vikix-fastmail") (workspace 7 :follow t))
```

`(:class "vikix-fastmail")` estas la fenestro: precize tiu klaso, nenio pli longa. `(workspace 7 :follow t)` sendas ĝin al labra spaco 7, kaj `:follow t` igas, ke vi sekvas ĝin; sen ĝi, vi restus tie, kie vi estas. Metu la linion en `~/.stumpwm.d/rules.lisp` kaj reŝarĝu (`Super+m` → *Reŝarĝi konfiguracion*).

**Kontrolu ĝin.** `vikix rules` listigas ĝin. La du propraj reguloj de Vikix aperas unue, do via estas numero 3:

```
 3  on     0×  never         (when-window (:class "vikix-fastmail") (workspace 7 :follow t))   rules.lisp:3
```

Ĝi estas ŝaltita, sed ankoraŭ ne funkcias, kaj ĝi estas skribita en la 3-a linio de via dosiero. La fenestro de la poŝto ankoraŭ estas en laborareo 1: refreŝigo neniam movos la fenestrojn, kiujn vi havas. Demandu, kion la regulo farus kun ili:

```
$ vikix rules test 3
vikix-fastmail "Fastmail" (workspace 1, window 0)
    3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))
2 windows open; 1 of them matches that rule. Nothing was done: vikix rules apply 3 does it.
```

Ĝi trovis la ĝustan fenestron kaj nenian alian. Nun faru ĝin:

```
$ vikix rules apply 3
vikix-fastmail "Fastmail" (workspace 1, window 0)
    ran     3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))
1 run.
```

Vi estas en labortablo 7, kie vi havas vian poŝton. De nun, ĝi malfermiĝos tie memature, kaj `vikix rules why fastmail` diras, kio okazis:

```
vikix-fastmail "Fastmail" (workspace 7, window 0)
  Rules that ran for it:
    15:36  on apply  3  (when-window (:class "vikix-fastmail") (workspace 7 :follow t))   rules.lisp:3
```

### Kalkulilo en la angulo

**La ideo.** "La kalkulilo flosas en la supra dekstra angulo, ĝi okupas kvaronon de la ekrano, anstataŭ duonon de la ekrano kiel fenestro."

**La regulo, farita manuele.**

```lisp
(when-window (:class "Gnome-calculator")
  (float :width "25%" :height "40%" :corner :top-right))
```

`float` forigas la fenestron el la tajlita aranĝo. `"25%"` kaj `"40%"` estas proporcioj de la ekrano sub la breto, do la regulo funkcios sur ajna ekrano; simpla nombro, `400`, estas en pikseloj. `:corner :top-right` lokigas ĝin tie, kelkajn pikselojn for de la randoj. Forlasu la angulon, kaj ĝi flosos meze.

**Aŭ lasu la labortablon fari ĝin.** Flosigu la kalkulilon per `Super+t`, tiru ĝin tien, kie vi volas (Super kaj la maldekstra butono movigas ĝin, Super kaj la dekstra butono ŝanĝas ĝian grandecon), kaj premu `Super+Shift+t`. La regulo, kiun ĝi proponas, estas la fenestro en sia nuna stato:

```lisp
(when-window (:class "Gnome-calculator") :name "remembered: Gnome-calculator" (workspace 1) (float :width "25%" :height "40%" :x "74%" :y "1%"))
```

Ĝi skribis la lokon kiel `:x` kaj `:y`, partoj de la ekrano el ĝia maldekstro kaj supra rando, ĉar ĝi ne povas scii, ke vi celis "la angulo". Ĝi ankaŭ skribis la labraeron, sur kiu la fenestro estas. Se la kalkulilo devas malfermiĝi ĉe ajna loko, kie vi estas, forigu `(labraero 1)` el la sekva linio; la dosiero estas via, por redakti ĝin.

**Kontrolu ĝin.** `vikix rules apply 4` faras ĝin funkcii sur la kalkulilo, kiu estas malfermita, kiel en la unua ekzemplo. Fermu la kalkulilon kaj malfermu ĝin denove, por vidi, ke la regulo funkcias sur nova fenestro.

### Memorilo pri laboraj tagoj

**La ideo.** "Je la dek unu kaj je la tri, de lundo ĝis vendredo, diru al mi leviĝi."

**La regulo.** Ĉi tie ne estas fenestro, do ne estas koincigililo: la regulo komenciĝas per "kiam".

```lisp
(at ("11:00" "15:00") :weekdays (notify "Stand up" "Two minutes away from the screen."))
```

`at` ricevas tempon laŭ la 24-hora horloĝo, aŭ liston de tiaj tempoj. `:weekdays` limigas ĝin al la tempoj de la lundo ĝis la vendredo. `notify` montras notifon: unue ĝian titolon, poste ĝian tekston.

**Provu ĝin.** `vikix rules` montras ĝin kiel aktiva, `0×`, `neniam`: ĝia tempo ankoraŭ ne venis. Por vidi ĝin funkcii sen atendi ĝis la dek unu, metu tempon du minutojn de nun en ties lokon (kaj forigu `:weekdays`, se hodiaŭ estas semajnfino), reŝarĝu, kaj atendu: la notifo aperos ene de duona minuto de la tempo, kaj `vikix rules` tiam montros `1×` kaj la tempon. Poste metu la realajn tempojn reen.

Du aferoj, kiujn oni devas scii pri la tempoj. Regulo skribita post kiam ĝia tempo pasis, atendas la sekvan tagon; ĝi ne funkcios tuj. Kaj se la portebla komputilo dormis je la dek unu, la memorigilo aperos kiam ĝi vekiĝos, kondiĉe ke tio estas ene de la horo.

### Regulo, kiu ne funkcias, kaj la serĉo pri la kialo

**La ideo.** "Firefox en labortablo 4." Sed la linio enhavas eraron:

```lisp
(when-window (:class "Firefox") (workspace 42))
```

**Kio okazas.** Nenio rompiĝas. Firefox malfermiĝas tie, kie vi estas, mesaĝo diras, ke regulo fiaskis, kaj la labortablo daŭras sian funkcion. `vikix rules` montras la fiaskon sub la koncerna regulo:

```
 6  on     0×  never         (when-window (:class "Firefox") (workspace 42))   rules.lisp:7
        failed 1 time, last: There is no workspace 42.
```

Kaj la fenestro mem memoras:

```
$ vikix rules why Firefox
Firefox "Mozilla Firefox" (workspace 1, window 0)
  Rules that ran for it:
    15:36  on open  6  (when-window (:class "Firefox") (workspace 42))   rules.lisp:7
        FAILED: There is no workspace 42.
```

Anstataŭigu 42 per 4, refreŝigu la paĝon, kaj `vikix rules apply 6` sendos la malfermitan Firefox tien. Se vi ne farus tion, la tria malsukceso malaktivigus la regulon ĝis la sekva refreŝigo.

**Ero en vorto, ne en numero,** estas pli rapide detektata, kiam la dosiero estas ŝarĝata. `(flaot)` anstataŭ `(float)`:

```
Vikix: error in rules.lisp, line 8 (skipped):
flaot isn't a verb, nor a function defined before this rule. The verbs: command, dialog, float, focus, fullscreen, join, layout, notify, open-project, run, say, sticky, theme, tile, title, width, workspace.
```

Nur tiu ĉi regulo estas preterlasata. La ceteraj en la dosiero estas aplikataj, kiel se ĝi ne ekzistus.

## Reguloj por fenestroj

```lisp
(when-window (:class "Firefox") (workspace 2))                 ; Firefox opens on workspace 2
(when-window (:class "Slack") (workspace 4 :follow t))         ; and you go along
(when-window (:instance "vikix-nmtui") (float :width "65%" :height "80%"))
(when-window (:class "mpv" :title (:has "picture in picture"))
  (float :width "30%" :height "30%" :corner :bottom-right) (sticky))
(when-window (:class "Gcolor3") (dialog))                      ; float, centred, kept in front
```

Unue venas, kio la fenestro estas, kaj poste, kion fari kun ĝi.

### Kion regulo kongruas

| Por kongrui | Skribu |
|---|---|
| La klaso de la fenestro, aŭ ĝia ekzemplaro (`xprop WM_CLASS` kaj klako sur la fenestro montras ambaŭ: unue la ekzemplaron, poste la klason) | `:class "Firefox"`, `:instance "Navigator"` |
| Ĝia titolo, aŭ ĝia rolo | `:title "Calculator"`, `:role "pop-up"` |
| Ĝia tipo | `:type :dialog` |
| La labortablo, sur kiu ĝi aperas | `:workspace 3` |
| Nenio el io | `:not (:title "Esploro")` |
| Ĉio alia | `:where #'my-test`, funkcio de la fenestro |

Simpla ŝtato kongruas precize kun tio, kaj nenio pli longa. `(:has "fox")` kongruas kun teksto, kiu enhavas ĝin, kun aŭ sen majuskloj; `(:like "^Mozilla .*")` estas ŝablo; listo, `("Chromium" "Brave")`, estas ajna el ili. Malplena kongruigilo, `()`, estas ĉiu fenestro.

### Kion regulo faras

| Verbo | Kion ĝi faras |
|---|---|
| `(workspace 2)` | Sendas la fenestron al labortablo, per numero aŭ nomo: ĝi aperas tie, sen unue aperi ĉi tie. `:follow t` kunigas vin |
| `(float ...)` | Flosigas ĝin. `:width` kaj `:height` estas pikseloj (`400`) aŭ parto de la ekrano sub la supra baraĵo (`"65%"`), 60% se ne specifita. Ĝi aperas meze, aŭ al `:corner` (`:top-left`, `:top-right`, `:bottom-left`, `:bottom-right`, `:top`, `:bottom`, `:left`, `:right`), aŭ al `:x` kaj `:y`. `(float :own t)` nur flosigas ĝin, kun la grandeco kaj loko, kiun la fenestro mem petas. Ĝi ricevas la fokuson kiam ĝi aperas, kiel kahelaroita fenestro; se ĝi aperas por labortablo, kiu ne estas videbla, ĝi montriĝas tie, kun la fokuso, kiam vi iras tien |
| `(tile)` | Remetas flosantan fenestron reen en la kahelaron |
| `(fullscreen)` | Plenigas la ekranon per ĝi |
| `(sticky)` | Tenas ĝin sur ĉiuj labortabloj (ĝi flosas) |
| `(dialog)` | Flosigas ĝin meze kaj tenas ĝin antaŭ la kahelaroj, kiel pasvortaj kuvoj. Ĝi daŭras dum la fenestro flosas: se ĝi estas remetita en la kahelaron, ĝi estas ordinara fenestro. Sur horizona aron, kolumno neniam estas dialogo, kvankam fenestroj de horizona aro flosas: regulo por ĉiu flosanta fenestro ne signifas, ke ĉiuj ili estas regulitaj |
| `(title "name")` | Donas al ĝi nomon, en ĝia titolbaraĵo kaj la supra baraĵo |
| `(focus)` | Iras al ĝi |
| `(run "command")`, `(command "vikix-grid")` | Ekzekutas ŝelan komandon, aŭ komandon de StumpWM |
| `(notify "text")`, `(say "text")` | Notifo, aŭ mesaĝo meze de la ekrano |
| `(open-project "name")`, `(theme "vikix-light")` | Malfermas unu el viaj projektoj; ŝanĝas la temon |
| `(layout "writing")` | Remetas la labortablon reen kiel aranĝon, kiun vi konservis ([Farante ĝin via](customize.md#konservitaj-aranĝoj)) |
| `(width 2/3)`, `(join :left)` | Sur horizona aro (`vikix viri`): la kolumno de la fenestro estas du trionoj de la ekrano larĝa (`1/3`, `1/2`, `1`, `"40%"`); la fenestro aperas sub la kolumno sur sia maldekstro (aŭ `:right`). For de horizona aro, ili ne faras ion |

Ĉio alia en regulo estas Lisp, kiun vi mem kreis, kie `(window)` estas la fenestro. `vikix rules verbs` elprenas ĉi tiun liston de la aktiva labortablo, do ĝi neniam estas malantaŭ.

### Opcioj

Inter la kongruigilo kaj la verboj, regulo povas havi opciojn:

| Opcio | Kion ĝi ŝanĝas |
|---|---|
| `:once t` | Nur la unua fenestro, kiu kongruas: Firefox al labortablo 2, kiam vi ensalutas, poste fenestroj, kie vi estas |
| `:on :focus`, `:on :close` | Kiam la fenestro ricevas la fokuson, aŭ fermiĝas, anstataŭe de kiam ĝi aperas |
| `:name "..."` | Kio la regulo estas konata en la listo kaj por `vikix rules off` |

## Reguloj por la tempo, la baterio kaj labortabloj

La sama dosiero, la samaj verboj (tiuj, kiuj ne bezonas fenestron: `run`, `command`, `notify`, `say`, `open-project`, `theme`), kaj ajna Lisp, kiun vi mem kreas:

```lisp
(at "09:00" :weekdays (open-project "vikix"))            ; each working day at nine
(at ("12:30" "18:00") (notify "Stand up"))               ; more than one time
(each 30 :minutes (run "vikix-wallpaper next"))
(when-battery-below 20 (notify "Battery at 20%" "Where's the charger?"))
(when-charging (say "On the charger"))
(when-on-battery (run "brightnessctl set 40%"))
(at-login (run "syncthing --no-browser"))
(when-workspace 3 (command "vikix-grid"))                ; on arriving at workspace 3
(when-network "Home" (run "dropbox start"))              ; on joining that Wi-Fi network
(when-screen "HDMI-1" (layout "desk"))                   ; the second screen plugged in
(when-drive "BACKUP" (run "vikix backup"))               ; a drive plugged in
(when-idle 10 (run "vikix-lock"))                        ; ten minutes away
(at "09:00" :weekdays (command "vikix-focus-time 50"))   ; focus time at nine: do not disturb, then a break
```

| Regulo | Kiam ĝi ekzekutatas |
|---|---|
| `(at "09:00" ...)` | Je tiu tempo, laŭ la 24-hora horloĝo, unufoje tage. `:weekdays`, `:weekends` aŭ `:on (:mon :thu)` limigas ĝin al tiuj tagoj. Se la portebla komputilo estis en reĝimo de dormo je tiu tempo, ĝi ekzekutatas kiam ĝi vekiĝas, se tio estas malpli ol unu horo poste; `:late t` ekzekutatas je kiom ajn poste tiu tago, `:late nil` nur je la preciza tempo. Rekargaĵo aŭ denova ensaluto ne ekzekutigas ĝin dufoje, kaj regulo, kiun vi skribas post ĝia tempo, atendas la sekvan tagon. |
| `(each 30 :minutes ...)` | Ĉiujn kelkajn `:minutes` aŭ `:hours`, kalkante de la lasta ekzekuto, do ne tuj kiam vi skribas ĝin. Post longa reĝimo de dormo, ĝi ekzekutatas unufoje, ne unufoje por ĉiu forlasita ekzekuto. |
| `(when-battery-below 20 ...)` | Unufoje, kiam la ŝarĝo malpliiĝas sub 20% sen la ŝargilo. Ĝi estas preta denove, kiam la ŝarĝo revenas super tiun nivelon, aŭ la ŝargilo estas konektita. |
| `(when-charging ...)`, `(when-on-battery ...)` | Kiam la ŝargilo estas konektita, aŭ malŝaltata |
| `(at-login ...)` | Unufoje ĉiu ensaluto, ne je rekargaĵo. Regulo, kiun vi aldonas dum ensalutita stato, ekzekutatas je la rekargaĵo, kiu aperigas ĝin, unufoje. |
| `(when-workspace 3 ...)` | Ĉiufoje, kiam vi iras al tiu labortablo: numero, nomo aŭ listo de ili. |
| `(when-screen "HDMI-1" ...)`, `(when-screen-gone "HDMI-1" ...)` | Kiam tiu ekrano estas konektita kaj ŝaltita, aŭ forigita. |
| `(when-network "Home" ...)`, `(when-network-gone "Home" ...)` | Kiam vi aliĝas al tiu Wi-Fi-reto (`"wired"` estas kablo), aŭ forlasas ĝin. |
| `(when-drive "BACKUP" ...)`, `(when-drive-gone "BACKUP" ...)` | Kiam tiu disko estas konektita kaj malfermata, aŭ elĵetita aŭ forprenita. |
| `(when-idle 10 ...)` | Unufoje, kiam nenio estis tajpita aŭ movita dum dek minutoj. Ĝi estas preta denove ĉe la sekva klavo aŭ movo de la muso. |

Ili estas kontrolataj ĉiujn 30 sekundojn, do tempo estas atingita ene de duonminuto. `at-login` estas la maniero, kiel programo startas kun la labortablo: `user.lisp` ekzekutatas denove ĉe ĉiu rekargaĵo kaj la regulo ne, do ne estas bezono de `pgrep -x … ||` antaŭe por eviti la starton de dua kopio.

**Ekranaj paneloj, reto kaj diskoj estas identigitaj per nomo.** `vikix rules now` elmontas tiujn, kiuj ekzistas, ĉar regulo skribas ilin:

```
$ vikix rules now
Screens: "eDP1"  "HDMI-1"
Network: "Home"
Drives:  none
Idle:    0 min
```

La nomo povas esti ŝnuraro (ĝuste tiel), `(:has "hdmi")` (entenas ĝin, en ĉiu okazo), `(:like "^DP-")` (modelo), listo de tiuj, aŭ `:any`. En regulo por `:any`, `(rule-thing)` estas la objekto, por kiu ĝi ekzekutatas: `(when-drive :any (notify "Drive" (rule-thing)))`. Ĉi tiuj kvar estas kontrolataj ĉiuj kvin sekundoj.

**Dum ensaluto, tio, kio jam estas tie, estas konsiderata kiel alveninta.** Do `(when-network "Home" ...)` ekzekutatas kiam vi ensalutas hejme, ne nur kiam vi eniras kun la poŝkomputilo malfermita; kaj regulo, kiun vi aldonas dum ensalutita, ekzekutatas dum la reŝarĝo, kiu alportas ĝin, se ĝia ekrano, reto aŭ disko estas tie. Nur reŝarĝo ne kaŭzas ion. Regulo kun `-gone` ekzekutatas nur kiam io, kio estis tie, foriras.

## Vidi, kion viaj reguloj faras

`vikix rules`, en terminalo, listigas ĉiun regulon: ĝian numeron, ĉu ĝi estas aktiva, kiel ofte ĝi ekzekutatis ekde la lasta reŝarĝo kaj kiam lastfoje, la regulon, kaj kie ĝi estas skribita. `Super+m` → *Rules* estas la sama listo en menuo.

| Komando | Ĉio, kion ĝi faras |
|---|---|
| `vikix rules why` | Kial la fenestro antaŭe estas tie, kie ĝi estas: la reguloj, kiuj ekzekutatis por ĝi, kaj tiuj, kiuj kongruas kun ĝi sed ne ekzekutatis, ĉiu kun la kialo. `vikix rules why Firefox` por la fenestroj de klaso |
| `vikix rules test` | Kion la reguloj farus kun la fenestroj malfermitaj nun, sen fari ion. `vikix rules test 3` por unu regulo |
| `vikix rules apply` | Fari ĝin. Reŝarĝo neniam movas la fenestrojn, kiujn vi jam havas; ĉi tio faras tion. `vikix rules apply 3` por unu regulo |
| `vikix rules off 3` | Malŝalti regulon ĝis la sekva reŝarĝo, laŭ ĝia numero, ĝia `:name`, aŭ vortoj, kiujn ĝi nur enhavas. `vikix rules on 3` remetigas ĝin |
| `vikix rules forget 3` | Forigi regulon el `rules.lisp` por ĉiam, post kopio |
| `vikix rules verbs` | Ĉio, kion regulo povas esti, kongrui kaj fari, ĉiu kun sia linio |
| `vikix rules now` | La ekranoj, la reto kaj la diskoj, kiuj estas tie nun, ĉiu laŭ la nomo, kiun regulo skribas, kaj kiom longe vi ne agis |
| `vikix rules proposed` | La reguloj, kiujn agento proponis kaj kiuj atendas vin (sube) |

Bona kutimo post skribi regulon: reŝarĝi, poste `vikix rules test` por vidi, kiujn malfermitajn fenestrojn ĝi prenos, antaŭ ol vi konfidas ĝin kun novaj. [La komandoj](commands.md#vikix-rules) enhavas la tuton de `vikix rules`.

## Regulo, kiun agento proponas

AI-agento laboranta sur via labortablo (Claude Code kun la iloj de Vikix, [Vikix kaj AI](ai.md)) povas proponi regulon, kaj ĝi ne povas aldoni regulon. Petu ĝin "fari, ke la kalkulilo flosu en la angulo", kaj ĝi proponas:

```lisp
(when-window (:class "SpeedCrunch") (float :width "25%" :height "30%" :corner :bottom-right))
```

Kio poste okazas:

1. **Ĝi estas kontrolata.** Propono devas esti unu regulo, farita nur el tio, kion ĉi tiu paĝo priskribas: la kompariloj, la verboj kaj simplaj valoroj (tekstaj vicoj, nombroj, ŝlosilvortoj). `:where`, variablo aŭ ajna propra Lisp-kodo estas rifuzata, kaj la agentecon oni informas pri la kialo, do tio, kion oni montras, estas ĉio, kion la regulo faras.
2. **Ĝi atendas.** Notifo diras, ke agente proponas regulon, kun la regulo kaj la kialo de la agente. Nenio estas skribita kaj nenio funkcias.
3. **Vi decidas.** `Super+m` → *Reguloj* unue listigas proponojn. Elektu unu, kaj vi vidas la regulon, la kialon, kaj, se ĝi enhavas `run` aŭ `command`, kion ĝi funkpigus. La menuo malfermiĝas sur la propra linio de la regulo, do tuj premi Enter nenion ŝanĝas: iru malsupren al *Aldonu ĝin al miaj reguloj.lisp* (unue estas farita kopio, kaj la regulo tuj estas aktivigita) aŭ *Ne: forĵetu ĝin*.

Aldonita regulo estas skribata ĉe la fino de via `rules.lisp` sub komento kun la dato kaj la kialo, kiel oni skribis ĝin. `vikix rules forget` forigas ĝin denove.

`vikix rules proposed`, en terminalo, listigas tiujn, kiuj atendas. Ĝi nur listigas: la aldono estas farata en la menuo, de vi. Ĝis dek povas atendi; la agente povas vidi, kiujn vi aldonis kaj kiujn vi forigis, kaj oni rifuzas regulon, kiu jam estas tie.

## Kiam regulo funkcias malbone

- **Misliterita verbo aŭ komparilo** estas trovata dum la dosiero estas ŝarĝata, kun sia linio, kiel ajna eraro en `user.lisp`. Nur tiu regulo estas perdita; la resto estas ŝarĝata.
- **Regulo, kiu fiaskas dum ĝi funkcias** (laborspaco, kiu ne ekzistas, verbo, kiu ne povas fari sian laboron) neniam haltigas la labortablon. Mesaĝo diras tion, la eraro estas konservata en `~/.local/state/vikix/errors/`, kaj `vikix rules` montras ĝin sub la regulo.
- **Post tri fiaskoj**, la regulo estas malŝaltata ĝis la sekva ŝarĝo, do rompita regulo ne fiaskas por ĉiu fenestro, kiu malfermiĝas. `vikix rules on 3` donas al ĝi tri pliajn provojn, kaj `vikix doctor` nomas regulon, kiu estas tiel malŝaltata.
- **Fenestro ne iris tien, kie vi esperis:** `vikix rules why` sur ĝi diras, kiuj reguloj funkcigis kaj kiuj nur korespondis. Regulo skribita post kiam la fenestro malfermiĝis, ne funkciis por ĝi; `vikix rules apply` funkcigas ĝin nun.

[Kiam io rompiĝas](fixing.md) enhavas la reston de tio, kion fari, kiam la labortablo funkcias malbone.

## Ĉiaj reguloj funkcias, kaj en kia ordo

Reguloj funkcias en la ordo, en kiu ili estas skribitaj: la propraj de Vikix, poste la de la kromprogramoj, poste `rules.lisp`, poste `user.lisp`. Kiam du sendas fenestron al malsamaj laborspacoj, la lasta venkas.

Vikix diras, kion ĝi volas de fenestroj, en la sama maniero, do `vikix rules` unue listigas siajn regulojn: la dialogoj de Lazarus flosas je sia propra grandeco, dum ĝia ĉefa fenestro estas aranĝata, kaj la leciono kaj la konsolo de `vikix learn` ĉiu iras en sian duonon. La kromprogramoj venas poste (la notkesto de la enirujo flosas; la notoj de la agente estas forigitaj, kiam vi rigardas ĝian fenestron), kaj foriras, kiam la kromprogramo estas forigita. Ĉiu el ili povas esti malŝaltita kiel via propra, per `vikix rules off`.

Ŝarĝo donas precize tion, kion la dosieroj diras: regulo, kiun vi forigis, estas forigita, regulo, kiun vi ŝanĝis, estas anstataŭigita, kaj neniu aperas dufoje.

## Propra verbo

Kiam pluraj reguloj bezonas la samajn kelkajn liniojn de Lisp, donu al ili nomon:

```lisp
(define-rule-verb quarter ()
  "Float the window in the top right quarter of the screen."
  (vikix-verb-float :width "50%" :height "50%" :corner :top-right))

(when-window (:class "Gnome-calculator") (quarter))
```

La ŝnuro estas ĝia linio en `vikix rules verbs`. En ĝi, `(rule-window)` estas la fenestro. Metu ĝin en `user.lisp`, kun la reguloj, kiuj uzas ĝin, post ĝi.

## Por la interesatoj: kiel funkcias la reguloj

Ĉio estas en unu dosiero, `~/vikix/config/stumpwm/vikix/rules.lisp`.

- **Regulo estas datumoj.** `when-window`, `at` kaj la aliaj estas makrooj, kiuj aldonas eniron al unu tabulo, `*vikix-rules*` (`vikix-add-rule`), kun la propra teksto de la regulo, kiu estas stokita apud ĝia kompilita testo kaj korpo. Tiel la labortablo povas listi siajn regulojn kaj diri, kie ĉiu estis skribita.
- **Tri funkcioj, ne unu regulo.** `vikix-rules-new-window`, `vikix-rules-focus-window` kaj `vikix-rules-destroy-window` funkcias sur la fenestraj funkcioj de StumpWM kaj trapasas la tabulon. Neniu alia en Vikix, kaj neniu kromprogramo, aldonas propran fenestran funkcion, kie regulo faras la laboron.
- **Fenestro estas en sia labortablo, antaŭ ol ĝi aperas.** StumpWM elektas novan labortablon por la fenestro, antaŭ ol ĝi afiŝas ĝin (`get-window-placement`); Vikix envolvas tiun funkcion (`vikix-rules-get-window-placement`) kaj unue demandas la regulojn per la verbo `workspace`, tiel ke la fenestro neniam aperas tie, kie vi ne volas.
- **Verboj estas serĉataj en tabulo**, `*vikix-rule-verbs*`, kaj ne estas vokataj kiel funkcioj kun tiuj nomoj: `float` estas la propra funkcio de Common Lisp, kaj `fullscreen` kaj `title` estas la komandoj de StumpWM. Tial ankaŭ mislitera verbo estas detektata kiam la dosiero estas ŝarĝata.
- **Ĉiu ekzekutado estas envolvita** (`vikix-run-rule`): eraro estas notata kaj kalkata, kaj neniam atingas la traktadon de la fenestro fare de StumpWM, kie ĝi signifus menuon aŭ refaron.
- **Unu ripetilo** (`vikix-rules-tick`, ĉiujn 30 sekundojn) ekzekutas la regulojn por la horloĝo, la akumulatoro kaj la eniro. Kio la regulo `at` aŭ `each` faris laste, estas stokata en `~/.local/state/vikix/rules/ran`, tiel ke rekargaĵo ne ripetas ĝin. Kio estis ekzekutita dum ĉi tiu eniro estas notata sur la radikalfenestro de la X-servero, kiu ekzistas ĝuste dum la daŭro de eniro.
- **Ĉiu fenestro konservas kelkajn notojn** pri la reguloj, kiuj estis ekzekutitaj por ĝi. `vikix rules why` legas ilin.

AI-agento vidas la saman liston: la MCP-servero de la labortablo havas leg-nur-ilon `rules`, kun la kialo por fenestro ([Kunlaboro kun AI](ai.md)).
