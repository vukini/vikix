# Via unua horo

Vi instalis Vikix kaj ensalutis. Ĉi tiu paĝo estas via unua horo: kio estas en la ekrano, kiujn klavokombinaĵojn oni devus lerni unue, aldoni kion vi bezonas, fari ĝin ŝajni kiel via propra, kaj teni ĝin ĝisdata. ["Instali Void por Vikix"](install-void.md) estas la antaŭa paĝo.

## Kio estas en la ekrano

Ĉe la supro estas **la baro**: la labrejoj maldekstre, poste la fenestroj en ĉi tiu; dekstre la reto, la sono, la baterio kaj la horo, kaj antaŭ ili vorto kiam io bezonas vin ("ĝisdatigoj 12", "kopiaĵo 9d"). Ĝi bezonas klakojn: la numero de labrejo aperas tie, la titolo de fenestro fokusigas ĝin, `vol` malfermas la sonmiksilon, la reto malfermas ĝiajn agordojn.

La resto de la ekrano estas fenestroj. Ne ekzistas titolaj strioj kaj nenio intermiksiĝas: ĉiu fenestro plenigas sian parton de la ekrano, kaj vi dividas la ekranon por meti du kune. Tio estas StumpWM, kaj la klavokombinaĵoj sube estas kiel vi kontrolas ĝin.

![La labortablo ĉe la unua ensaluto: la baro ĉe la supro, kaj la bonveniga mesaĝo](shots/vikix-first-login.png)

La unua fojo, terminalo malfermiĝas kun **la bonveniga mesaĝo**. Sekvu ĝin: ĝi aldonas programaron, montras la klavokombinaĵojn, elektas temon kaj vian klaviataran aranĝon, kaj markas ĉiu paŝon post kiam ĝi estas finita. `Super+m` → *Bonveniga mesaĝo* alportas ĝin reen.

## La klavokombinaĵoj kiuj gravas

`Super` estas la klavo kun la logo de Windows. Kvin por komenci:

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+Return` | terminalo |
| `Super+Space` | ĉio en unu kesto: tajpu kelkajn literojn de fenestro, komando, projekto, retaplikaĵo, konservita aranĝo aŭ programo, kaj premu Enter. Unue, ĝi serĉas nur unu tipo: `>` la menuo, `@` projektoj kaj labrejoj, `#` la dokumentoj, `?` kio estas ĉi tio, `/` dosiero (la malplena kesto nomas ilin); Enter montras la rezultojn, Enter denove malfermas unu |
| `Super+d` | la lanĉilo: nur programoj |
| `Super+m` | la menuo de Vikix: ĉio, en sekcioj; tajpu vorton por trovi eniron |
| `Super+/` | ĉiuj klavokombinaĵoj en unu fenestro; la sekva klavo fermas ĝin |
| `Super+q` | fermi la fenestron |

Tiam, kiam vi havas du fenestrojn:

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+b`, `Super+v` | dividi la ekranon kune aŭ unu super la alia |
| `Super+h` `j` `k` `l` | movi inter ili; aldoni `Shift` por movi la fenestron |
| `Super+r` | forigi dividon |
| `Super+f` | ekrano plenigita, kaj reen |
| `Super+Tab` | la lasta fenestro denove |
| `Super+o` | ĉiuj labrejoj desegnitaj malgrandaj, ĉiu fenestro estas kesto; elektu unu |
| `Super+u` | malfari la lastan ŝanĝon de la aranĝo |
| `Super+1` … `Super+9` | labrejoj; `Super+Shift+1` … sendas la fenestron tien; `Super+0` la nomitaj, po unu litero (`/` tie tajpas nomon, kreitan kiam ĝi estas nova) |
| `Super+Left`, `Super+Right` | la labrejo maldekstre, dekstre, ĉirkaŭ la randoj; aldoni `Shift` por preni la fenestron kun ĝi |

Kaj kelkaj por ĉiutagaj aferoj: `Super+w` la retumilo, `Super+e` viaj dosieroj, `Print` ekrankopio de areo (al la intertavolo, por enmeti kun `Ctrl+v`; `Shift+Print` konservas ĝin kiel dosiero en `~/Pictures/Screenshots` anstataŭe), `Super+c` la historio de la intertavolo, `Super+Escape` bloki, `Super+Shift+Escape` suspenzi, elŝalti aŭ malŝalti.

**Kiam tri fenestroj ne sufiĉas:** labrejo povas esti strio anstataŭe (`Super+m`, *Strio: ĉi tiu labrejo ruliĝas horizontale (Viri), aŭ denove kun kahelaroj*, aŭ `vikix viri`). Ĝiaj fenestroj staras kune en vico pli larĝa ol la ekrano, ĉiu duona ekrano larĝa; du montriĝas samtempe, kaj `Super+h` / `Super+l` moviĝas laŭ la vico, kiu glitas sub vi. Nova fenestro malfermiĝas apud tiu, en kiu vi estas, kaj nenio malpliiĝas por doni spacon. La sama menuo faras ĝin denove kun kahelaroj, dividita kiel ĝi estis. ["La strio, labrejo kiu ruliĝas"](strip.md) estas ĝia paĝo: la klavokombinaĵoj, la muso, larĝoj kaj stapoj, kaj kiel ĝi funkcias.

**Unu ĉefa fenestro, la resto apud ĝi:** `Super+Ctrl+m` metas la labrejojn en la ĉefan kaj la stakon (kion dwm kaj xmonad nomas "master" kaj "stack"). La fenestro, en kiu vi estas, prenas la maldekstron de la ekrano, tri kvinonoj larĝa, kaj la aliaj dividas kolonon sur ĝia dekstro. Ĝi restas tiel dum fenestroj malfermiĝas kaj fermiĝas: nova fenestro malfermiĝas ĉe la supro de la stako. `Super+Shift+h` faras la fenestron, en kiu vi estas, la ĉefa (kun `Shift`, `h` `j` `k` `l` interŝanĝas ĝin kun la fenestro tie), kaj `Super+r` ŝanĝas la larĝon de la ĉefa fenestro: du trionoj, duona, tri kvinonoj denove. La stako montras kvar fenestrojn; pli atendas malantaŭ la lasta (`` Super+` `` alportas ilin). Dividoj, kiujn vi faras per la mano, estas reinstalitaj tuj, ĝis `Super+Ctrl+m` ŝanĝas la reĝimon kaj la aranĝo estas via denove. Por ke labrejo ĉiam estu tiel, regulo en `~/.stumpwm.d/rules.lisp`: `(when-workspace 2 (command "vikix-main on"))`. Por ke novaj fenestroj malfermiĝu kiel la ĉefa, kiel en dwm: `(setf *vikix-main-new* :main)` en `user.lisp`.

**Elekti aranĝon:** `Super+Ctrl+Space` malfermas la klavokombinaĵojn de la aranĝoj: malgranda fenestro de unuopaj klavokombinaĵoj, kiuj funkcias dum ĝi montriĝas. `m` estas ĉefa kaj stako, `s` strio, `g` reto (ĉiu fenestro, denove kun kahelaroj dum fenestroj malfermiĝas kaj fermiĝas; `Super+Shift+o` ŝanĝas ĝin ankaŭ), `t` simplaj kahelaroj, `w` kaj `h` trairas la larĝojn de kolono kaj la altojn de fenestro en strio, `u` kaj `r` malfaras kaj refaras la lastan ŝanĝon, kaj `Space` malfermas la menuon de ĉiuj kun la aranĝoj, kiujn vi konservas per la nomo (`vikix layout save NAME`) sub ili, malfermante ĝin ĉe tiu, kiun la labrejo havas nune. La fenestro restas dum duona minuto post ĉiu klavo, do `m` tiam `w`, `w` funkcias; Escape aŭ `Super+Ctrl+Space` denove fermas ĝin, kaj la fenestroj restas. Por klavo al unu: `(vikix-bind "s-C-F1" "vikix-layout-pick main")` en `user.lisp` (`tiles`, `main`, `grid` aŭ `strip`).

**Dremo por la aferoj, kiujn oni volas dum momento:** `Super+Ctrl+b` glitas kolonon de programoj de la dekstra rando, super viajn fenestrojn: terminalo kaj la dosieroj, ĝis vi nomas vian propran (kalkulilo, viaj notoj: [Fari ĝin via](customize.md), *La dremo*). La klavo denove kaj ĝi foriras, la programoj ankoraŭ funkcias; en alia labrejo la klavo alportas ĝin tien.

**Kiam la labortablo faras ion, kiun vi ne petis:** `Super+?` diras kial. Ĝi listigas la lastajn aĵojn, kiuj okazis, ĉiu kun kio kaŭzis ĝin (la klavo, kiun vi premis kaj ĝia komando, regulo kaj la fenestro, por kiu ĝi funkciis, kaj kie tio estas skribita; elektu unu por redakti ĝin tie, aŭ por forigi ĝin. [Ripari aferojn](fixing.md) havas pli.

**Vidi ĉiun labrejojn:** `Super+o` desegnas ĉiun labrejon, kiu havas fenestrojn, malgrandajn, sur unu fenestro super la ekrano. Kahelita labrejo estas ĝiaj dividoj, kie ili estas kaj kiel grandaj ili estas; strio estas ĝiaj kolumnoj. Ĉiu fenestro estas kesto kun ĝia numero kaj nomo kaj, sub ili, kio ĝi estas (la dosierujo de terminalo kaj kio funkcias en ĝi). Divido, kiu tenas plurajn fenestrojn, montras unu el ili; la aliaj, malantaŭ ĝi, estas listigitaj en ĝia kesto, kaj povas esti elektitaj kiel ajn alia. La sagoj (aŭ `h` `j` `k` `l`) movas kadron de fenestro al fenestro, ankaŭ trans labrejoj, kaj Enter iras al tiu en ĝi, labrejo kaj ĉio; klako sur kestu faras la saman. Cifero iras rekte al la fenestro kun tiu numero en la labrejo, en kiu la kadro estas; `/` estas la listo de ĉiuj fenestroj por tajpi en; Escape, aŭ ajna alia klavo, fermas la fenestron. Nenio estas movita ĝis vi elektas. `g` tie estas la pli malnova maniero, nur por ĉi tiu labrejo: ĝiaj fenestroj metitaj en vera reto, kie vi vidas ilin kaj elektas unu per sia numero (`Super+u` metas la labrejon reen kiel ĝi estis).

**Trovi fenestron:** `Super+g` listigas ĉiun fenestron en ĉiuj labrejoj: ĝia labrejo, ĝia titolo kaj kio ĝi estas (por terminalo, ĝia dosierujo kaj kio funkcias en ĝi, do kvin terminaloj ne estas kvin linioj de "Alacritty"). Tajpu kelkajn literojn de ajna el tiuj kaj Enter iras tien; `Super+Shift+g` estas la sama listo, kaj alportas la fenestron al vi anstataŭe. Por la fenestroj de la tuta labrejo samtempe, `Super+m` → *Fenestroj* → *Alporti ĉiujn fenestrojn de alia labrejo ĉi tien*: ili alvenas kiel ordinaraj fenestroj, kahelitaj ĉi tie (kiel kolumnoj, en strio), ĉu ili staris sur strio aŭ flosis tie, kie ili estis.

`Super+F1` listigas ĉiun klavokombinaĵon kun kio ĝi faras, por serĉi kaj funkcii de tie. Fokuso de la muso estas sur: fenestro prenas vian tipadon kiam la kursoro estas super ĝi.

## Aldonu kion vi bezonas

Kio venis, estas **la bazo**: tuta labortablo, sed sen programlingvoj, redaktoroj aŭ oficeja aro. Tiuj estas **funkciaĵoj**, aldonitaj kiam vi volas ilin:

```sh
vikix features              # what there is, [x] for what you have
vikix add essentials        # Emacs, and C, Python and Lisp
vikix add python neovim     # any features, by name
vikix add office printing   # LibreOffice, and printers
```

`Super+m` → *Aldoni programaron* estas la sama, kiel listo por marki. Ununura programo, kiu ne estas funkcio: `vikix pkg add NOMO`. `vikix remove NOMO` forigas funkcion denove. [Kiel ĝi kunlaboras](how-it-works.md#la-baza-sistemo-kaj-la-funkcioj) klarigas la diferencon.

## Faru, ke ĝi aspektu kiel via

```sh
vikix theme                 # the themes there are
vikix theme nord-dark       # switch: the bar, terminals, menus, lock screen, wallpaper, editors
```

Aŭ `Super+m` → *Temo*. Ses temoj estas inkluzivitaj kun Vikix: nula (la defaŭlta), papera (hela), gruvbox, nord, tokio-nokto kaj kontrasto (por brilaj ĉambroj kaj lacigitaj okuloj). `vikix theme import` aldonas unu el la temoj de Omarchy. La fonbildo sekvas la temon ĝis vi elektas vian propran (`Super+m` → *Fonbildo*).

Viaj propraj klavoj, programoj, kiuj startiĝas kaj agordoj, lokiĝas en `~/.stumpwm.d/user.lisp`, kiu estas ŝarĝata laste, do ĝi venkas: [Adaptu ĝin al via gusto](customize.md) montras kiel. Antaŭ ol vi ŝanĝas dosieron, `vikix snapshot`; se io funkcias malbone, `vikix undo`.

## Tenas ĝin ĝisdata

Kiam la breto montras `ĝisdatigoj`, ekzistas io nova:

```sh
vikix update                # Vikix, Void's packages, your languages and tools
vikix update core           # only Vikix: seconds
```

`Super+m` → *Ĝisdatigi Vikix* faras la unuan, en terminalo.

## Kiam vi estas senvoja

- **La asistanto:** `Super+a`, *Asistanto ĉi tie*, komencigas la AI-asistanton, kiu konas ĉi tiun labortablon: petu ĝin ŝanĝi klavon, trovi agordon, aŭ klarigi eraron. Ĝi unue faras kopion de viaj dosieroj.
- **La kontrolado:** `vikix doctor` rigardas ĉion, kion Vikix metis en lokon, kaj diras, kio mankas.
- **Kio estas ĉi tio?** Metu la kursoron sur kampo de la panelo (`bat 84%`, `ĝisdatigoj 12`, la horloĝo, la numero de labloko) kaj premu `Super+Alt+?`, aŭ premu ĝin kun fenestro antaŭe. Karto diras, kion tiu afero faras nun, kelkajn liniojn pri tio, kio tia afero estas, kaj kie legi pli: Eniro malfermas la unuan, la sekcion de ĉi tiuj gvidiloj. `vikix what firefox`, `vikix what Super+t`, `vikix what sshd` kaj `vikix what battery` estas la samaj en terminalo, por programo, kiu funkcias, klavo, servo, pordo, pakaĵo, komando, dosiero aŭ kampo. Se vi skribas, viaj propraj ĉapitroj povas aperi unue: [Adapti ĝin al vi](customize.md) diras kiel.
- **La gvidiloj:** ĉi tiuj paĝoj, ankaŭ sur via komputilo (`Super+m` → *Vikix-gvidilo*); en Help, *Vikix-gvidilo: paĝo hazarde* malfermas unu, kiun vi ne elektis. [Kiam io rompiĝas](fixing.md) estas la gvidilo por problemoj. `Super+F2` serĉas ilin per kelkaj vortoj, kune kun ĉiuj manpaĝoj, la dokumentoj de viaj projektoj kaj viaj notoj.
