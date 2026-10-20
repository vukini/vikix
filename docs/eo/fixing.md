# Kiam io rompiĝas

Komencu per:

```sh
vikix doctor
```

Ĝi kontrolas la programojn, servojn, ligilojn, la historion de la momentaj kopioj, la pasvorton de Swank kaj `vikix eval`, la gvidilon de la programo, USB-memorujojn, kaj la redaktilojn, kiujn vi elektis (ĉu Emacs havas la agordon de la AI de Vikix ŝarĝitan, ĉu la kromprogramoj de Neovim estas instalitaj kaj kiuj estas iliaj versioj), kaj diras, kio mankas.

## La instalado haltis

La unu-linia instalado (`curl -fsSL https://vikix.dev/install | bash`) unue kontrolas la maŝinon, kaj haltas antaŭ ol modifi ion, se:

- **ĝi ne estas Void**, aŭ ĝi estas Void kun musl: Vikix bezonas la glibc-version de Void (voidlinux.org/download)
- **vi estas superuzanto (root)**: ruligu ĝin kiel via kutima uzanto; ĝi petos sudo kiam ĝi bezonos ĝin
- **`~/vikix` ekzistas, sed ne estas klono de Vikix**: forigu ĝin kaj ruligu la programon denove

Kiam ĝi funkcias, la etapoj ĝis la eniro haltas ĉe la unua, kiu malsukĉesas, ĉar ĉiu bezonas la antaŭan. Ĝi diras, kiu ĝi estas, kaj la tuta procezo estas en `~/.local/state/vikix/logs/install-<tempo>.log`. Korektu kion ĝi diras, poste ruligu nur tiun etapon, kaj la instalon denove; finitaj etapoj estos preterlasitaj:

```sh
~/vikix/install.sh --only 30-lisp
~/vikix/install.sh
```

Sono, aparataro de la komputilo, la iloj de la gastigilo de la virtuala maŝino kaj la funkcioj daŭras eĉ post fiasko, kaj la fino de la procezo montras, kio fiaskis.

## La grafika interfaco ne komenciĝis

Vi restos ĉe la teksta konzolo aŭ kun nigra ekrano.

1. Iru al alia konzolo: **Ctrl+Alt+F2**, kaj ensalutu tie.
2. Legu, kion la sesio eldonis: `less ~/.local/state/vikix/session.log` (la antaŭa estas `session.log.old`). Ĉiu komando, kiun ĝi ekzekutis, estas tie, sekvita de ajna eraro.
3. Kelkaj kutimaj kaŭzoj:
   - **`stumpwm: not found`**, aŭ Lisp-ero, antaŭ ol StumpWM komenciĝas: rekompilu ĝin per `vikix rebuild-wm`.
   - **Problemo en dosiero, kiun vi ŝanĝis** (`.bash_profile`, `.bashrc`, `.Xresources`): `vikix changes` montras, kio estas malsama de la lasta kopio, kaj `vikix undo` remetigas ĝin.
   - **X mem fiaskis**: ĝia registro estas `/var/log/Xorg.0.log` (serĉu liniojn, kiuj komenciĝas per `(EE)`).
4. Elŝalu de ĉi tiu konzolo (`exit`), revenu per **Ctrl+Alt+F1**, kaj ensalutu tie denove.

## Kiam la grafika interfaco demandas, kion fari

StumpWM estas Lisp-programo, kaj Lisp ne devas perfidiĝi, kiam io fiaskas: ĝi povas proponi manierojn por daŭri. Vikix montras ilin en malgranda menuo (sagoj kaj Enter elektas; Escape daŭrigas sen la fiaskinta parto).

**Ero en `user.lisp`** (aŭ en unu el la dosieroj de Vikix), dum la ensaluto aŭ post *Rekargi agordon*. La menuo diras, kiu dosiero, kiu linio, kaj kio okazis, kaj proponas:

- *Preterpasi ĉi tiun parton kaj ŝarĝi la reston de la dosiero*: la resto de viaj agordoj ankoraŭ aplikiĝas.
- *Malfermi `user.lisp` ĉe linio N en Emacs*: korektu ĝin tie, konservu, kaj `Super+m` → *Rekargi agordon*.
- *Ŝarĝi vian lastan kopion de `user.lisp`*: la versio de via lasta `vikix snapshot` (aŭ `vikix agent` starto) funkcios ĉi-foje; via dosiero restas kiel ĝi estas, ankoraŭ esti korektita (`vikix changes` montras, kio ŝanĝiĝis ekde tiam; `vikix undo` remetigas ĝin).
- *Preterpasi la reston de `user.lisp`*.

Kiam `(` neniam estas fermita, la dosiero ne povas esti legita post ĝi, do nur la lastaj tri estas proponitaj.

Ero en unu el la propraj dosieroj de Vikix (`keys.lisp`…) estas eraro en Vikix. `vikix update` eble jam enhavas la korekton. Se ne, bonvolu raporti ĝin.

**Io fiaskis, kion StumpWM ne kaptas** (ero en temporiloj, aŭ dum la prilaboro de fenestro). La respondo de StumpWM estis restartigi: agordi ĉion denove kaj rekargi ĉiun dosieron. La menuo unue proponas:

- *Daŭrigi*: freŝa starto de la eventociklo de StumpWM, nenio rekargita; viaj fenestroj kaj agordoj restas. Kiam la eraro venis de temporilo, kiu ripetiĝas, daŭrigi haltigas tiun temporilon, aŭ ĝi fiaskus denove. Temporilo, al kiu oni donis tempon kun dekuma punkto (`0.3`, kiun StumpWM ne povas akcepti: skribu `3/10`), estas korektita.
- *Daŭrigi, kaj montri, kio okazis en Emacs*.
- *Restartigi la grafikan interfacon*, kiel antaŭe. Viaj fenestroj restas malfermaj ĉiuokaze. (Antaŭ ĉi tiu menuo, tiu restartigo mem povis mortigi la grafikan interfacon: StumpWM konservis la malnovan ekranon, kaj ĝia unua redraŭo fiaskis. Vikix nun unue forigas la ekranon, kaj poste remetigas ĝin dum la ŝarĝo.)

Se eraroj daŭre aperas (tri en 20 sekundoj), Vikix ĉesas peti kaj restartigas, kiel StumpWM.

Ĉiu eraro estas skribita, kun ĝia retroirvojo, en `~/.local/state/vikix/errors/` (`vikix debug` inkluzivas la plej novan; agento ankaŭ povas legi ilin). Por ke eraroj estu raportitaj sen peti, metu `(setf *vikix-errors-ask* nil)` en `user.lisp`.

## Io okazis kaj vi ne scias kial

Fenestro memvole iris al alia labra spaco, klavo faris ion, kion vi ne atendis, la aranĝo ŝanĝiĝis sub vi. Premu `Super+?` (aŭ `Super+m` → *Kial tio okazis?*). La grafika interfaco listigas la lastajn aferojn, kiujn ĝi faris, plej nova unue, ĉiu kun tio, kio igis ĝin fari tion, kaj kie tio estas skribita:

```
21:04:10  Super+Ctrl+d ran vikix-quiet (Do not disturb on/off)  ·  Vikix's key: registry.lisp, line 83
21:03:59  A rule, as a window opened ran (when-window (:class "Firefox") (workspace 2))  ·  rules.lisp:3, for Firefox "Mozilla Firefox"
21:03:40  Super+s ran user-dropterm  ·  your key: user.lisp, line 242
```

Preno kun la komando, per kiu ĝi funkcias; regulo kun la fenestro, por kiu ĝi funkcias; eniro de `Super+m`; komando, kiun agentejo faris; la lasta sciigo, kun la programo, kiu ĝin sendis; kaj komando, kiun neniu el tiuj klarigas (kliko sur la breto, skripto, `vikix eval`). La sama afero denove estas unu linio, kalkita (`×3`), do regulo, kiu funkcias ĉiufoje, kiam fenestro ricevas la fokuson, ne malhelpas la reston.

Elektu linion, kaj ĝi proponas, kion oni povas fari pri ĝi:

- **Redaktu ĝin**, se ĝi estas via: `user.lisp` aŭ `rules.lisp` malfermiĝas en Emacs ĉe tiu linio. Se ĝi estas propra de Vikix, vi povas vidi la linion, por legi; kion vi volas ŝanĝi, enmetu en `user.lisp` ([Faru ĝin via](customize.md)).
- **Forigu ĝin**, se io faras: regulo estas refarita, ŝanĝo de la aranĝo estas forigita (`Super+u`).
- **Alportu tiun fenestron ĉi tien**, por fenestro, kiun regulo sendis al alia labortablo.
- **Malaktivigu tiun regulon** ĝis la sekva rekomenco (`vikix rules on` reaktivigas ĝin).

`vikix why` elprintas la saman liston en terminalo. Ĝi estas konservata nur en la aktiva labortablo, la lastaj kvindek, ĝis vi eliros: nenio estas skribata. Por fenestro specife, `vikix rules why` diras, kiuj reguloj funkcis por ĝi, kaj kiuj kongruas kun ĝi, sed ne funkcias ([Reguloj por la labortablo](rules.md)).

## Klavo ne funkcias

- `Super+m` → *Kion faras klavo?*, poste premu la klavon. Ĝi diras, al kio la klavo estas ligita, se io.
- Se ĝi faras ion, sed ne tion, kion vi atendis: `Super+?` tuj poste diras, kiun komandon ĝi faris, kaj kie tiu klavo estas skribita (supre).
- `Super+/` montras ĉiujn klavojn, al kiuj Vikix ligas, grupitajn; `Super+F1` listigas ilin, serĉeblaj. Post `Ctrl+t`, atendu momenton, kaj StumpWM listigas siajn proprajn klavojn.
- En VM, la gastiganto eble prenas la klavon, antaŭ ol la gastigato vidas ĝin: en Windows, Super+L ŝlosas Windows.

## Io mankas en la menuo aŭ la lanĉilo

- **Eniro ne estas en Super+m** (JupyterLab, Zeal, Printers, Windows, Local AI, Dictation, Voice, Dropbox): ĝi estas forlasita ĝis ĝia funkcio estas ĉi tie. `vikix features` montras, kion vi havas; `vikix add python` (aŭ `printing`, `windows`, `local-ai`, `dictation`, `voice` …) alportas ĝin, kaj la eniron kun ĝi.
- **Programo mankas el Super+m → *Aplikoj***: ĉiu eniro aperas unuafoje, kiam ĝia programo estas instalita. `vikix add video` (aŭ `graphics`, `blender`, `study`, `passwords`, `phone`, `cli-extras`) alportas ilin.
- **Programo ne estas en la lanĉilo (Super+d)**: la lanĉilo listigas programojn, kiuj venas kun `.desktop`-dosiero. Tajpu ĝian nomon, kiel la dosiero donas ĝin: JupyterLab ankaŭ respondas al `jlab`. Programo sen ĝi (la plej multaj komandliniaj iloj) funkcias el terminalo, aŭ el Super+m, se Vikix havas eniron por ĝi.
- **La bonveniga ekrano ne malfermiĝis, aŭ vi fermis ĝin**: `Super+m` → *Bonveniga ekrano*, aŭ `vikix welcome` en terminalo.

## Aldono de funkcio malsukĉesis

`vikix add` nomas, kio ne finiĝis (elŝutado, plej ofte). La funkcio estas registrita tiel aŭ tiel, do `vikix add NAME` denove, aŭ la sekva `vikix update`, finigas la laboron. Funkcio kun sia propra agordo, kiel `windows`, estas registrita nur post kiam ĝia agordo sukcesas: ĝi diras, kion ĝi bezonas unue (KVM ŝaltita en la BIOS, 40 GB da libera spaco).

Diktaĵo kaj voĉo konstruas aŭ elŝutas siajn partojn unufoje, kiel vi, sen pasvorto. Se `vikix add dictation` haltas ĉe la konstruo, la fino de la eliro de la konstruo estas montrita, kaj ĉio estas en `~/.local/state/vikix/logs/whisper-build.log`. Elŝutado, kiu malsukĉesas en sia kontrolsumo, estas forigita, neniam uzata; refaru la agordon.

## Io sur la ekrano ĉesis ĝisdatigi

Se la horloĝo de la breto ĉesas, aŭ fenestroj malfermiĝas, sed ne aperas, la komponanto (picom) verŝajne estas haltigita. Restartigu ĝin el terminalo:

```sh
pkill picom; picom -b
```

## La labortablo funkcias malrapide

`vikix times` diras, por kiom da tempo la eniro kaj ĉiu reŝarĝo daŭris sur ĉi tiu labortablo, la lasta fojo kaj kutime, kompare al limo. `vikix times measure` mezuras pli, dum kelkaj sekundoj kaj sen tuŝi vian ekranon: sur kaŝita ekrano, kun la konfiguracio de Vikix, la starto de StumpWM, reŝarĝo, klavo al ĝia komando, malfermo de Emacs-fenestro kaj StumpWM respondas post ĉio tio (kaj, se xterm estas instalita, kun malfermita, kahelita xterm, kiu iam tenis ĝin tro okupita por respondi); ĝi konservas ĉiun ekzekucion, do la sekva diras, kio ŝanĝiĝis. Silente, sur la X1 Carbon: ĉirkaŭ 2 s por starti, 1 s por reŝargi, 10 ms de klavo al ĝia komando, malpli ol unu sekundo por Emacs-fenestro.

- **Malrapida reŝarĝo:** `vikix times files` montras la lastan ŝargitan dosieron laŭ dosiero, kaj ĉu ĉiu venis de sia kompilita kopio aŭ sia teksta formo. La unua reŝarĝo post ĝisdatigo legas la ŝanĝitajn dosierojn de ilia teksta formo (ĉirkaŭ du sekundoj pli) kaj kompilas ilin en la fono; la sekva estas denove rapida. Dosiero, kiu ĉiam estas "de sia teksto", havas kompilian kopion, kiu malsukĉesas: la plej nova raporto en `~/.local/state/vikix/errors/` diras, kial.
- **Unu super sia limo** (`SLOW`), kiam la maŝino estas okupata (ĝisdatigo, starto de VM), diras malmulte: mezuru denove, kiam ĝi estas silenta.
- **Malrapida kiam silenta** indikas, ke valoras raporti: `vikix debug` skribas unu, kun la mezuroj en ĝi.
- **Ĉiam pli malrapida, ju pli longe ĝi funkcias?** `vikix times soak` severe laborigas kaŝitan labortablon dum unu horo (malfermo, fermo, movo, reŝargoj de fenestroj) kaj diras, ĉu StumpWM malrapidiĝis, kreskis, konserviĝis horloĝoj aŭ hokoj, kiujn ĝi ne devus, aŭ skribis eraron; la specimenoj estas konservitaj en `~/.local/state/vikix/soak/`. Via ekrano ne estas tuŝita, sed la portebla komputilo laboras pli forte dum tio.
- **StumpWM malrapide respondas:** tio signifas, ke ĝia ĉefa fadeno estas okupata: klavoj ankoraŭ funkcias, sed `vikix eval` kaj la iloj de la agentoj atendas. Fenestro, kiu daŭre ŝanĝas sian grandecon, povas fari tion (bugs.md enhavas unu, xterm); fermu fenestrojn unu post la alia ĝis ĝi denove respondas.

## La labortablo "ekfrostiĝis", aŭ funkcias dum minutoj

La memoro elĉerpiĝis: Linux movas programojn al la disko kaj reen. La baro montras `mem 91%` antaŭ ol ĝi atingas tion, kun sciigo nomanta la plej grandajn programojn; kiam vi vidas ĝin, fermu ion.

```sh
vikix memory          # what uses it, biggest first; files kept in memory (/tmp); what's left over
vikix memory clean    # end the programs left over (hidden screens and tests nobody ended)
```

Kiam la memoro preskaŭ pleniĝas, la programo aŭtomate finas la restantajn programojn. Kaj se la memoro ankoraŭ malpleniĝas, earlyoom (sistema servo, kiun Vikix aktivigas) finas unu programon anstataŭ permesi, ke ĉio haltas: unue teston aŭ kompiladon, poste sesion de AI-agento aŭ virtualan maŝinon, sed neniam la labortablon aŭ vian redaktilon; notifo informas pri tio. `vikix memory` finas per indikado, ĉu ĝi estas aktivigita.

Se `vikix memory` diras "Grafikaĵoj kaj aliaj dividitaj memoroj... Tio estas multe", programo lasas bildojn en la X-servero (ili apartenas al neniu programo kaj foriĝas nur kiam tiu programo finiĝas): el- kaj re-ensaliri redonas ĝin.

La kutimaj kaŭzoj: virtuala maŝino (la indikaĵo diras `win`), pluraj AI-agentoj samtempe, navigilo kun multaj langetoj, grandaj dosieroj en `/tmp` (ili estas stokitaj en la memoro) kaj programoj lasitaj de testoj. Se la ekrano jam estas blokita, ŝanĝu al teksta konzolo per Ctrl+Alt+F2, ensaliru kaj ekzekutu `vikix memory` tie (`pkill` la plej grandan), poste Ctrl+Alt+F1 por reveni.

## La labortablo estas blokita, aŭ neniu klavo funkcias

Du malsamaj aferoj ŝajnas similaj. Komencu per unu klavo kaj unu komando:

- **Super+Ctrl+Alt+Escape** liberigas blokitan labortablon. StumpWM legas ĉi tiun klavon aparte de la ceteraj, do ĝi funkcias, kiam ili ne funkcias. Kiam nenio estas blokita, ĝi nur diras tion.
- **`vikix rescue`**, en ajna terminalo, en teksta konzolo (Ctrl+Alt+F2, ensaliru) aŭ per ssh, diras, kiu el ĉi tiuj estas:

```sh
vikix rescue          # coming round, waiting, or stuck; what the desktop is doing; is the screen locked
vikix rescue free     # out of a loop: every rule paused, focus on clicks, then a fresh event loop
vikix rescue undo     # rules and focus back (Reload config does the same)
vikix rescue lock     # the lock screen in front of the windows again
```

**Blokita** signifas, ke StumpWM senfine ripetas ion: ekzemple, regulo kaj la muso persekutas la fokuson de la alia. Ĝi laboras senĉese kaj ne plenumas nenion alian: la horloĝo de la panelo ne moviĝas, `vikix eval` ne ricevas respondon, la iloj de la programo ne funkcias. Interna observanto en StumpWM rimarkas tion ene de kvarono de minuto kaj informas vin per mesaĝo; kio okazis sur la labortablo estas skribita en `~/.local/state/vikix/errors/`. Se lasita sole, ĝi plimalboniĝas post minuto (la reguloj estas paŭzitaj, la fokuso sekvas klakojn anstataŭ la muson), kaj post tri provoj komenciĝas nova ciklo: viaj fenestroj kaj agordoj restas kiel ili estis. La plimalboniĝo daŭras ĝis `vikix rescue undo` aŭ refreŝigo, ĉar tio, kio kaŭzis la ciklon, ankoraŭ ekzistas: `vikix rules` listigas viajn regulojn, kaj la raporto identigas tion, kio senĉese funkcias. Por ke la observanto nur informu vin, enmetu `(setf *vikix-rescue-auto* nil)` en `user.lisp`.

**Atendante** ne estas blokita: malfermiĝas menuo aŭ mesaĝo de StumpWM (rigardu la supron de la ekrano), kaj ĝi atendas la klavojn ĝis la klavo Escape fermas ĝin.

**Blokita, kaj vi ne povas vidi ĝin.** Se la labortablo estas videbla, sed neniu klavo funkcias, la ekrano de la blokado eble aperas malantaŭ la fenestroj, absorbante ĉiun klavon. Enmetu vian pasvorton kaj premu Enter: ĝi malŝlosas, kvankam vi ne povas vidi ĝin. La ekrano de la blokado nun re-aperas dufoje ĉiu sekundo, do ĉi tio ne plu devus okazi; `vikix rescue` indikas kiam la ekrano estas blokita, kaj `vikix rescue lock` alportas ĝin reen.

Se `vikix rescue` mem ne ricevas respondon, StumpWM ne plu respondas. De teksta konsolo, `pkill -x stumpwm` finigas la sesion de la labortablo kaj vi denove ensalutiĝas; programoj kun nesendetitaj laboraĵoj perdas ilin, do ĉi tio estas la lasta afero, kiun vi devus provi.

## Agordoj eraris

```sh
vikix history        # snapshots of your files, newest first
vikix changes ID     # what a snapshot changed
vikix undo           # back one snapshot
vikix undo ID        # back to that snapshot
```

En terminalo, `vikix undo` listigas la dosierojn, kiujn ĝi reaktivas, kaj unue demandas, do vi povas diri "ne" kaj elekti alian kopion. Reaktivigo unue faras kopion, do `vikix undo` denove reaktivas ĝin. Poste `Super+m` → *Reŝargi konfiguracion*, aŭ re-ensaligu por aĵoj, kiuj estis legitaj dum eniro (`.Xresources`, la tempomaj limoj).

Dosiero, kiu obstrukcis unu el la ligoj de Vikix, estis movita, ne forigita. Por trovi tiujn:

```sh
find ~ -name '*.vikix-bak.*' 2>/dev/null
```

## Ĝisdatigo malsukĉesis

Fine de la procezo, oni montras la etapojn, kiuj malsukĉesis, kaj la tuta procezo estas en `~/.local/state/vikix/logs/update-<tempo>.log`. La ceteraj etapoj ankoraŭ funkcis. La plej oftaj kaŭzoj de la malsukĉo estas problemoj kun la reto; portanto, ripetu la komandon `vikix update`.

**Ŝanĝoj faritaj en la procezo** (`~/vikix`: redaktitaj mane aŭ per alia programo) haltigus la procezon, do la ĝisdatigo unue forigas ilin kaj informas pri tio al la komenco kaj al la fino. Nenio estas forigita. Ili troviĝas en dosiero, kiun vi povas legi:

```sh
ls ~/.local/state/vikix/checkout-changes/        # one file per update that set something aside
less ~/.local/state/vikix/checkout-changes/<date>.patch
```

Ŝanĝo, kiun vi volas konservi, apartenas al viaj propraj dosieroj (`~/.stumpwm.d/user.lisp` …; vidu [Farante ĝin via](customize.md)): la elŝutado estas anstataŭigita per ĉiu ĝisdatigo. Restaĵoj de redaktiloj (`#file#`, `file~`) estas ignorataj, do ili neniam haltigas ĝin.

**Alŝutitaj versioj** haltigas la ĝisdatigon: Vikix ne povas ĝisdatigi super ili. Ĝi diras tion, kun la komandoj por konservi ilin kiel dosieroj de ŝanĝoj kaj remeti la alŝutitan version kiel la eldonitan. **Konflikto lasita en la alŝutita versio** (dosieroj de Vikix kun markoj `<<<<<<<`, pro remetado de ŝanĝoj per la mano) ankaŭ haltigas ĝin, kun la komandoj por solvi ĝin; la labortablo eble ne lanĉiĝos ĝis tiam.

Alie, se ĝi haltas ĉe **elŝutado de Vikix**, temas pri la reto aŭ GitHub: denove ruligu `vikix update`.

Por denove ruligi unu instaladan fazon (ĉiu estas sekura por reruligi):

```sh
~/vikix/install.sh --only 40-config
~/vikix/install.sh --list      # all the stages
```

## Io ajn en la reto ne povas atingi ĉi tiun komputilon

La fajrobarilo estas aktivigita (`vikix firewall` montras ĝin kaj ĝiajn regulojn): nur SSH, kaj la portoj pri kiuj ĝi ricevis informojn, estas permesitaj. Telefono sendante dosieron, alia komputilo malfermante servilon, kiun vi lanĉis, ludo: ĉiu bezonas, ke ĝia porto estu permesita, `vikix firewall allow PORT` (`53317` por LocalSend, se ĝi estis instalita post kiam la fajrobarilo estis aktivigita). `vikix firewall close PORT` fermas ĝin denove. Por kontroli, ĉu la fajrobarilo estas la kaŭzo, `vikix firewall off` dum minuto, poste `vikix firewall on`.

## La reto ŝajnas malrapida

Unue, kontrolu ĉu la konekto aŭ unu programo estas la kaŭzo. `ping -c 5 1.1.1.1` devus respondi dum kelkaj milisekundoj sen perdo; testado de rapido estas `curl -o /dev/null -w '%{speed_download}\n' https://speed.cloudflare.com/__down?bytes=25000000` (oktajtoj por sekundo; multiplikante per 8, vi ricevas bitojn). Poste Super+m → *Retuma uzado* (`sudo nethogs`) montras, kiel "top", kiu programo sendas kaj ricevas kiom da datumoj: `m` ŝanĝas inter valoroj kaj totaloj, `q` eliras. Se la konekto estas rapida sed `git push` aŭ `pull` estas malrapida kaj nethogs montras, ke `ssh` ne faras ion, git atendas, ofte la pasfrazon de la SSH-ŝlosilo: `ssh-add -l` devus montri la ŝlosilon, kaj `ssh-add` aldonas ĝin.

## Loka AI ne respondas

`vikix ai status` diras, ĉu Ollama funkcias kaj kiu modelo estas ŝargita. Se ĝi ne funkcias: `vikix ai setup` lanĉas ĝin (de tiam ĝi funkcios kun la labortablo), kaj ĝia registro estas `~/.local/state/vikix/ollama.log`. Se ĝi estas malrapida: tio estas la CPU; pli malgranda modelo (`vikix ai models`) respondas pli rapide, kaj `vikix ai stop` liberigas la memoron, kiun granda modelo uzas. Sur aparato, kies grafika chipo dividas la memoron (Ryzen AI Max), `vikix ai status` diras, ĉu la chipo estas uzata kaj kiom da la ŝargita modelo estas sur ĝi: modelo tro granda por la parto de la chipo funkcias parte sur la CPU; `vikix ai share` diras, kiom la kerno permesas, ke la chipo uzu, kaj `vikix ai share most` pligigas ĝin por la venonta lanĉo. Kiam la ekrano iĝas nigra dum granda modelo ŝarĝiĝas, la X-servilo perdas sian grafikan memoron al la modelo, ne la aparato falas: Ctrl+Alt+F2 donas konsolon, `vikix ai stop` malŝargas la modelon, kaj reeniri en tty1 lanĉas la labortablon; ne necesas la elektra butono.

## `llm` ne respondas

- **`No key found - add one using 'llm keys set anthropic'`**: ne faru tion; tio kreas duan kopion de la ŝlosilo. Uzu `vikix ai key set anthropic`, poste malfermu novan terminalon (la ŝlosiloj atingas novajn ŝelojn, ne la jam malfermitan).
- **Erara konekto** kun loka modelo: Ollama ne funkcias; `vikix ai status`, poste `vikix ai setup`.
- **Ne certas, kiun modelon ĝi uzas**: `llm models default`. `vikix ai llm` klarigas sian elekton; `vikix ai llm --default MODEL` agordas vian.

## `vikix eval` malsukĉesas

- **Elira kodo 2** signifas, ke ĝi ne povis atingi StumpWM: ĝi ne funkcias, menuo aŭ peto estas malferma (fermu ĝin kaj provu denove), aŭ ĝi estas blokita. `vikix rescue` diras, kio estas, kaj liberigas la blokitan.
- **`… is another user's (uid N), not StumpWM's: the password isn't sent`**: io de alia uzanto aŭskultas sur la 4004-a porto, plej verŝajne ĉar via StumpWM ne funkcias (vi estas en teksta konsolo). `vikix eval` ne sendos ĝin vian Swank-pasvorton. Lanĉu la labortablon, aŭ trovu, kio tio estas: `ss -ltnp 'sport = :4004'`.
- **`error: …`** estas eraro en la Lisp, kiun vi sendis; la labortablo funkcias bone.

## Redaktilo ne funkcias

[Neovim kaj Emacs](editors.md#kiam-redaktilo-ne-funkcias) diras, kion vi povas provi: la registron de la kromprogramoj, `eq` por Emacs sen ĝia agordo, kaj la lingvaj servoj. `vikix doctor` diras, ĉu Emacs ŝargis la agordon de Vikix AI kaj ĉu la kromprogramoj de Neovim estas en la ĝusta loko. Post `vikix update`, Emacs, kiu funkcias, ricevas la novan agordon de Vikix AI sen rekomenco; tiu, kiu estis lanĉita antaŭ Vikix 0.59, ricevas la ordon `emacs-restart`.

## La agento ne havas la ilojn de la labortablo

Post `vikix mcp register`, rekomencu la agenton: ĝi legas sian liston de serviloj, kiam ĝi lanĉas. Poste `vikix mcp status` diras, ĉu Claude Code havas ĝin, kiuj riskaj iloj estas aktivigitaj, kiom da serviloj funkcias kaj sur kiu versio, kaj la lastajn vokon. Antigravity CLI ricevas ĝin en la sama maniero, per `agy mcp add`, kiam ĝi estas instalita (`agy mcp list` montras ĝin). Por Codex, Gemini CLI kaj OpenCode, `vikix mcp register` eldonas la liniojn, kiujn vi devas meti en iliajn agordojn mem. Ilo, kiu diras, ke ĝi estis malakceptita, diras, kion ĝi bezonus (labrospacon, kiu ekzistas, temon, kiun vi havas); ĉiuj vokon estas en `~/.local/state/vikix/mcp.log`.

## Serĉante vin mem: kion la kerno kaj la sistemo faris

Kiam io okazas sub la labortablo (la laptopo strange dormiĝas, aparato aperas kaj malaperas, la ekrano fulmas), la kerno kutime skribis tion. La maniero trovi tion estas ĉiam la sama: igi ĝin okazi unue, poste rigardi, kio estis skribita tiam.

**La mesaĝoj de la kerno.** La kerno tenas siajn lastajn mesaĝojn en la memoro, ekde la lasta lanĉo. Void permesas nur al la supera uzanto legi ilin:

```sh
sudo dmesg -T | less          # all of them, with the time of day (-T); / searches, q quits
sudo dmesg -T | tail -40      # the newest 40: right after something happened, that's it
sudo dmesg -Tw                # live: leave it open, make it happen, watch (Ctrl+c stops)
sudo dmesg -T --level=err,warn    # only errors and warnings
sudo dmesg -T | grep -i usb   # only the lines about one thing
```

Legu ilin laŭ ilia tempo (`-T`) kaj laŭ la vortoj ĉe la komenco: `PM:` estas pri energia administrado (dormo kaj vekiĝo), `usb`, `ACPI`, `i915` aŭ `amdgpu` (la grafika karto), `wlan`/`iwlwifi` (senfada konekto). Linio kun `error`, `failed` aŭ `timeout` proksime al la momento, kiun vi volas kontroli, estas la linio, kiun vi devas kontroli. Ili malaperas post la rekomenco; `/var/log/dmesg.log` konservas la unuajn mesaĝojn de la lasta rekomenco.

**Kiu programo respondas al evento.** Ofte du programoj respondas al la sama evento, aŭ neniu faras tion. Por la kovrilo, la butono de la energio kaj la dormo:

```sh
ls /var/service                    # the services runit runs
cat /etc/acpi/handler.sh           # what acpid does with the lid and buttons (when it runs)
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitch      # what elogind does with the lid
elogind-inhibit --list             # who may hold off sleep, and why (the lock screen does)
ls /etc/zzz.d/*/                   # what runs before sleeping and after waking
```

**Propraj kalkiloj de la dormo.** La kerno kalkas ĉiun provon dormi:

```sh
cat /sys/power/mem_sleep                      # [deep] is real sleep (S3); s2idle is lighter
grep -r "" /sys/power/suspend_stats/          # successes, failures, and the step that failed
```

Notu la nombrojn, unufoje fermu kaj malfermu la kovrilon, kaj rigardu denove: unu plia `sukceso` estas ĝusta; nova `fiasko` kun `last_failed_step:freeze` kaj `last_failed_errno:-16` ("okupata") signifas, ke io petis dormi dum la dormo jam estis en progreso.

**Ekzemplo: la kovrilo** (korektita en 0.71.31). Malfermi la kovrilon lasis la ekranon blanka dum iom da tempo, poste ĝi vekiĝis. `suspend_stats` montris 15 sukcesojn kaj 5 fiaskojn, okupata dum la paŭza fazo. `handler.sh` ruligis `zzz` sur la kovrilo, kaj `HandleLidSwitch` de elogind diris `suspend`: du programoj paŭzas sur unu kovrilo. `sudo dmesg -T | grep -E "PM: suspend (entry|exit)"` montris ĝin kiel du enirojn por unu fermo. La korekto estis teni nur unu: elogind, kiu unue ŝlosas la ekranon.

**La resto de tio, kio estis skribita**, de Vikix kaj la labortablo: `~/.local/state/vikix/session.log` (la sesio), `~/.local/state/vikix/errors/` (eroj en la labortablo), `/var/log/Xorg.0.log` (la ekrano), kaj `vikix debug`, kiu kolektas ilin. Void ne havas sisteman protokolon kiel defaŭlto; `sudo xbps-install socklog-void` kaj `sudo ln -s /etc/sv/socklog-unix /etc/sv/nanoklogd /var/service/` konservas la mesaĝojn de la servoj kaj de la kerno en `/var/log/socklog/`, post reŝargoj.

## Petu helpon

Unue, demandu al la agento. `vikix diagnose` (aŭ Super+m → *Io estas malbona? Demandu al la agento*) skribas raporton pri tio, kio okazas, kaj transdonas ĝin al via AI-agento, demandante, kio estas malbona kaj kiel solvi ĝin. La agento komencas per legi kaj proponi (Claude Code en ĝia planreĝimo, Codex nur-legi), demandante antaŭ ol ŝanĝi ion ajn, kaj unue estas farita momentfoto, do `vikix undo` reigas ĝiajn ŝanĝojn. Ĝiaj raportoj estas konservitaj en `~/.local/state/vikix/diagnose/` (la lastaj kvin).

Por peti helpo de homo, malfermu problemon ĉe github.com/vukini/vikix kaj aldonu la raporton, kiun skribas `vikix debug`:

```sh
vikix debug            # writes ~/vikix-debug-<date>.txt, readable only by you
less ~/vikix-debug-*.txt
```

Ĝi komenciĝas per rapida rigardo al la problemoj (la linioj en la protokoloj, kiuj indikas, ke io fiaskis), poste la versio kaj elŝutado de Vikix, viaj lastaj kopiaĵoj, la sistemo, la aparataro kaj ekranoj, viaj funkciaĵoj, kion diras `vikix doctor`, la servoj kaj la propraj linioj de Vikix el la protokoloj: la komenco kaj fino de la sesio (`~/.local/state/vikix/session.log`), la lasta instalado kaj ĝisdatigo (`~/.local/state/vikix/logs/`), kaj la eraroj de X.

Kio estas forlasita: la protokollinioj de aliaj programoj (la protokolo de navigilo enhavas la paĝojn, kiuj estis malfermitaj), la adresoj de retejoj (la retejo restas), sekretoj de ĉiu tipo (API-ŝlosiloj, tokenoj, pasvortoj, privataj ŝlosiloj, ĉiu ajn ilia formo), via hejma dosierujo, uzantonomo, kompleta nomo kaj nomo de la maŝino. La finita dosiero estas ree kontrolata, kaj la komando fiaskas, se io, kiu ŝajnas sekreta, restas. Tamen, legu ĝin antaŭ ol vi dividas ĝin: nenio estas sendata al iu ajn loko memstare.

Sur GitHub, malfermu novan problemraporton kaj trenu la dosieron en la skatolon "Debug-raporto": ĝi estas tro longa por kopi-glui.
